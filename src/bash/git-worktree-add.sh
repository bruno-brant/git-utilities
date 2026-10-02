#!/usr/bin/env bash
# Create a git worktree for the current repo as a sibling directory on a new
# branch, then mirror the current working state into it.
#
# Given a workstream name, this:
#   1. Resolves the root of the repo you're in (works from any subdirectory).
#   2. Creates a worktree in a SIBLING directory named "<repo>-<workstream>",
#      on a new branch u/<user>/<workstream> derived from the current branch.
#   3. Runs git-worktree-mirror on it, which copies over your uncommitted
#      changes and links every git-ignored path (node_modules, build output,
#      ...) back to the source repo.
#
# Pass --no-mirror to stop after step 2; you can mirror later with
# `git worktree-mirror <path>`. That also works on worktrees you create
# yourself with plain `git worktree add`.
#
# Usage: git worktree-add <workstream> [--branch <leaf>] [--no-mirror]
#
# Options:
#   --branch LEAF  Leaf name for the new branch (default: the workstream name).
#   --no-mirror    Only create the worktree; don't mirror into it.
#   -h, --help     Show this help.
set -eo pipefail

usage() {
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

workstream=""
branch_leaf=""
no_mirror=0

while [ $# -gt 0 ]; do
	case "$1" in
		--branch) branch_leaf="$2"; shift 2 ;;
		--branch=*) branch_leaf="${1#*=}"; shift ;;
		--no-mirror) no_mirror=1; shift ;;
		-h|--help) usage 0 ;;
		-*) echo "Unknown option: $1" >&2; usage 1 ;;
		*)
			if [ -z "$workstream" ]; then
				workstream="$1"; shift
			else
				echo "Unexpected argument: $1" >&2; usage 1
			fi
			;;
	esac
done

if [ -z "$workstream" ]; then
	echo "usage: git worktree-add <workstream> [--branch <leaf>] [--no-mirror]" >&2
	exit 1
fi

# Fail before creating anything if the mirror step can't run at all.
if [ "$no_mirror" -eq 0 ] && ! command -v git-worktree-mirror >/dev/null 2>&1; then
	echo "error: git-worktree-mirror isn't on your PATH." >&2
	echo "Install the tools (install.sh), or pass --no-mirror to only create the worktree." >&2
	exit 1
fi

# This script finds worktrees by their path, so ignore any repository the
# caller's environment pinned git to. A git shell alias, a hook or an IDE can
# export GIT_DIR, and with GIT_DIR set but GIT_WORK_TREE unset git treats the
# *current directory* as the top of the work tree -- so a run from a subfolder
# would have mirrored into that subfolder. git lists the variables to clear.
unset $(git rev-parse --local-env-vars)

# --- 1. Resolve repo root ----------------------------------------------------
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
	echo "Not inside a git repository. cd into the repo and try again." >&2
	exit 1
}
repo_name=$(basename "$repo_root")
parent_dir=$(dirname "$repo_root")

# --- 2. Compute worktree path and branch name --------------------------------
worktree_path="$parent_dir/$repo_name-$workstream"
current_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)
user="${USER:-user}"
leaf="${branch_leaf:-$workstream}"
new_branch="u/$user/$leaf"

if [ -e "$worktree_path" ]; then
	echo "Target path already exists: $worktree_path" >&2
	exit 1
fi

echo "Source repo   : $repo_root"
echo "Worktree path : $worktree_path"
echo "New branch    : $new_branch (from $current_branch)"

# --- 3. Create the worktree --------------------------------------------------
git -C "$repo_root" worktree add -b "$new_branch" "$worktree_path" "$current_branch"

if [ "$no_mirror" -eq 1 ]; then
	echo
	echo "Created worktree at $worktree_path (branch $new_branch); not mirrored."
	echo "Mirror it later with:  git worktree-mirror \"$worktree_path\""
	exit 0
fi

# --- 4. Mirror the working state into it -------------------------------------
echo
if ! git worktree-mirror "$worktree_path"; then
	echo >&2
	echo "The worktree was created at $worktree_path, but mirroring failed." >&2
	echo "Fix the problem above, then run:  git worktree-mirror \"$worktree_path\"" >&2
	exit 1
fi

echo "  branch: $new_branch"
