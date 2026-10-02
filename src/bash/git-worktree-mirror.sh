#!/usr/bin/env bash
# Mirror the source repo's current working state into an existing worktree,
# replacing every git-ignored path with a symlink back to the source.
#
# The source is the repository's main worktree, found automatically, so this
# works on any linked worktree -- including one you created yourself with
# plain `git worktree add`. git-worktree-add runs it for you after creating
# a worktree.
#
# Mirroring overwrites the target: files that aren't in the source are
# deleted, and ignored paths are replaced by links. So it refuses to run when
# the target has uncommitted changes, or real (non-symlink) files in ignored
# paths, unless --force is given. It never runs on the main worktree itself.
#
# Re-mirroring a worktree needs --force: the previous mirror copied the
# source's uncommitted changes into it, so it no longer looks clean.
#
# NOTE: directories are linked as plain symlinks. Unlike the NTFS junctions
# the PowerShell version uses, git reports a directory symlink as a symlink,
# so a .gitignore rule written as "node_modules/" may not match it; prefer
# rules without a trailing slash if you hit that.
#
# Usage: git worktree-mirror [<worktree-path>] [--force]
#
# Options:
#   <worktree-path>  Worktree to mirror into (default: the current one).
#   --force          Mirror even if the target has uncommitted or ignored work.
#   -h, --help       Show this help.
set -eo pipefail

usage() {
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

target_arg=""
force=0

while [ $# -gt 0 ]; do
	case "$1" in
		--force|-f) force=1; shift ;;
		-h|--help) usage 0 ;;
		-*) echo "Unknown option: $1" >&2; usage 1 ;;
		*)
			if [ -z "$target_arg" ]; then
				target_arg="$1"; shift
			else
				echo "Unexpected argument: $1" >&2; usage 1
			fi
			;;
	esac
done

if ! command -v rsync >/dev/null 2>&1; then
	echo "error: rsync is required by git worktree-mirror." >&2
	exit 1
fi

# This script finds worktrees by their path, so ignore any repository the
# caller's environment pinned git to. A git shell alias, a hook or an IDE can
# export GIT_DIR, and with GIT_DIR set but GIT_WORK_TREE unset git treats the
# *current directory* as the top of the work tree -- so a run from a subfolder
# would have mirrored into that subfolder. git lists the variables to clear.
unset $(git rev-parse --local-env-vars)

# --- 1. Resolve the target worktree ------------------------------------------
target=$(git -C "${target_arg:-.}" rev-parse --show-toplevel 2>/dev/null) || {
	echo "Not a git worktree: ${target_arg:-.}" >&2
	exit 1
}

# --- 2. Find the source: the main worktree, always listed first --------------
source_root=""
source_bare=0
while IFS= read -r line; do
	[ -z "$line" ] && break
	case "$line" in
		"worktree "*) source_root="${line#worktree }" ;;
		bare) source_bare=1 ;;
	esac
done < <(git -C "$target" worktree list --porcelain)

if [ -z "$source_root" ]; then
	echo "Could not determine the repository's main worktree." >&2
	exit 1
fi
if [ "$source_bare" -eq 1 ]; then
	echo "The main repository is bare ($source_root); there's no working tree to mirror from." >&2
	exit 1
fi

if [ ! -d "$source_root" ]; then
	echo "The main worktree no longer exists at $source_root; nothing to mirror from." >&2
	exit 1
fi

canon() { CDPATH= cd -- "$1" 2>/dev/null && pwd -P; }
if [ "$(canon "$target")" = "$(canon "$source_root")" ]; then
	echo "Refusing to mirror: $target is the main worktree (the source itself)." >&2
	echo "Point it at, or run it from, a linked worktree instead." >&2
	exit 1
fi

# --- 3. Refuse to overwrite work in the target unless --force ----------------
if [ "$force" -eq 0 ]; then
	problems=()

	if [ -n "$(git -C "$target" status --porcelain 2>/dev/null)" ]; then
		problems+=("it has uncommitted changes")
	fi

	# `git status` hides ignored files, so check those separately. Links left by
	# a previous mirror are fine; real files and directories would be lost.
	# -z output is NUL-separated and never quoted, so names with spaces, quotes
	# or non-ASCII characters come through exactly as they are on disk.
	real_ignored=()
	while IFS= read -r -d '' rec; do
		case "$rec" in
			'!! '*)
				p="${rec#\!\! }"
				p="${p%/}"
				[ -n "$p" ] || continue
				if [ -e "$target/$p" ] && [ ! -L "$target/$p" ]; then
					real_ignored+=("$p")
				fi
				;;
		esac
	done < <(git -C "$target" status --ignored --untracked-files=normal --porcelain=v1 -z 2>/dev/null || true)

	if [ "${#real_ignored[@]}" -gt 0 ]; then
		problems+=("it has files in git-ignored paths: ${real_ignored[*]}")
	fi

	if [ "${#problems[@]}" -gt 0 ]; then
		echo "Refusing to mirror into $target:" >&2
		for problem in "${problems[@]}"; do
			echo "  - $problem" >&2
		done
		echo "Mirroring would overwrite that. Commit or stash it, or pass --force to overwrite anyway." >&2
		exit 1
	fi
fi

echo "Source repo : $source_root"
echo "Worktree    : $target"

# --- 4. Discover git-ignored paths in the SOURCE repo ------------------------
# '!!' records from porcelain v1 are the ignored entries; directories carry a
# trailing slash. Paths are relative to the repo root. -z keeps them unquoted.
# --untracked-files=normal makes git report a directory whose contents are all
# ignored as ONE entry, so it gets one link; a user's
# status.showUntrackedFiles=all would otherwise list, and link, every file.
ignored=()
while IFS= read -r -d '' rec; do
	case "$rec" in
		'!! '*)
			p="${rec#\!\! }"
			p="${p%/}"
			[ -n "$p" ] && ignored+=("$p")
			;;
	esac
done < <(git -C "$source_root" status --ignored --untracked-files=normal --porcelain=v1 -z 2>/dev/null || true)

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
rsync "${rsync_args[@]}" "$source_root/" "$target/"

# --- 6. Replace each ignored path with a symlink to the source ---------------
if [ "$ignored_count" -gt 0 ]; then
	echo "Creating links for ignored paths..."
	for rel in "${ignored[@]}"; do
		src="$source_root/$rel"
		link="$target/$rel"

		if [ ! -e "$src" ]; then
			echo "  skipping '$rel' - source no longer exists." >&2
			continue
		fi

		mkdir -p "$(dirname "$link")"
		rm -rf "$link"
		ln -s "$src" "$link"

		if [ -d "$src" ]; then
			echo "  link (dir): $rel"
		else
			echo "  link: $rel"
		fi
	done
fi

echo
echo "Done. Mirrored $source_root into $target."
