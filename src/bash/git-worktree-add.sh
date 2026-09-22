#!/usr/bin/env bash
# Create a git worktree for the current repo that mirrors the current working
# state, with all git-ignored paths replaced by symlinks back to the source repo.
#
# Given a workstream name, this:
#   1. Resolves the root of the repo you're in (works from any subdirectory).
#   2. Creates a worktree in a SIBLING directory named "<repo>-<workstream>",
#      on a new branch u/<user>/<workstream> derived from the current branch.
#   3. Mirrors the current on-disk state of the source tree into the worktree
#      (including uncommitted changes), excluding .git and ignored paths.
#   4. Replaces every git-ignored path in the worktree with a symlink back to
#      the source repo, so e.g. node_modules is one link rather than a copy.
#
# NOTE: this is the Unix counterpart of git-worktree-add.ps1, not a literal
# port. The PowerShell version is Windows-specific (robocopy, NTFS junctions,
# UAC elevation). Here, directories are plain symlinks: unlike a junction, git
# reports a directory symlink as a symlink rather than walking into it, so a
# .gitignore rule written as "node_modules/" may not match it. Prefer rules
# without a trailing slash if you hit that.
#
# Usage: git worktree-add <workstream> [--branch <leaf>]
#
# Options:
#   --branch LEAF  Leaf name for the new branch (default: the workstream name).
#   -h, --help     Show this help.
set -eo pipefail

usage() {
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

workstream=""
branch_leaf=""

while [ $# -gt 0 ]; do
	case "$1" in
		--branch) branch_leaf="$2"; shift 2 ;;
		--branch=*) branch_leaf="${1#*=}"; shift ;;
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
	echo "usage: git worktree-add <workstream> [--branch <leaf>]" >&2
	exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
	echo "error: rsync is required by git worktree-add." >&2
	exit 1
fi

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

# --- 4. Discover git-ignored paths in the SOURCE repo ------------------------
# '!!' lines from porcelain v1 are the ignored entries; directories carry a
# trailing slash. Paths are relative to the repo root.
ignored=()
while IFS= read -r line; do
	case "$line" in
		'!!'*)
			p="${line#\!\!}"
			p="${p# }"
			p="${p%/}"
			[ -n "$p" ] && ignored+=("$p")
			;;
	esac
done < <(git -C "$repo_root" status --ignored --porcelain=v1 2>/dev/null || true)

ignored_count=${#ignored[@]}
echo "Found $ignored_count git-ignored path(s) to symlink."

# --- 5. Mirror the working tree into the worktree ----------------------------
echo "Mirroring working tree into worktree (excluding ignored paths)..."
rsync_args=(-a --delete --exclude '/.git')
if [ "$ignored_count" -gt 0 ]; then
	for rel in "${ignored[@]}"; do
		rsync_args+=(--exclude "/$rel")
	done
fi
rsync "${rsync_args[@]}" "$repo_root/" "$worktree_path/"

# --- 6. Replace each ignored path with a symlink to the source ---------------
if [ "$ignored_count" -gt 0 ]; then
	echo "Creating links for ignored paths..."
	for rel in "${ignored[@]}"; do
		target="$repo_root/$rel"
		link="$worktree_path/$rel"

		if [ ! -e "$target" ]; then
			echo "  skipping '$rel' - source no longer exists." >&2
			continue
		fi

		mkdir -p "$(dirname "$link")"
		rm -rf "$link"
		ln -s "$target" "$link"

		if [ -d "$target" ]; then
			echo "  link (dir): $rel"
		else
			echo "  link: $rel"
		fi
	done
fi

echo
echo "Done. Worktree ready at:"
echo "  $worktree_path"
echo "  branch: $new_branch"
