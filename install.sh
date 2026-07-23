#!/usr/bin/env sh
#
# Installs the git-utilities scripts onto your PATH so they work as native
# git subcommands (e.g. `git config-email`, `git worktree-add`).
#
# By default this symlinks the scripts from this repo into a bin directory,
# so edits to the repo are picked up immediately. Use --copy to copy instead.
#
# Usage:
#   ./install.sh [--bin DIR] [--copy] [--skip-pwsh-check]
#
# Options:
#   --bin DIR           Where to install (default: $HOME/.local/bin).
#   --copy              Copy scripts instead of symlinking them.
#   --skip-pwsh-check   Don't verify that pwsh is installed.
#   -h, --help          Show this help.

set -eu

# Library scripts that are meant to be dot-sourced, not run as subcommands.
# (Space-separated basenames without the .ps1 extension.)
EXCLUDE=""

BIN_DIR="${GIT_UTILITIES_BIN:-$HOME/.local/bin}"
COPY=0
SKIP_PWSH_CHECK=0

usage() {
	# Print the leading comment block (skip the shebang, stop at the first
	# non-comment line).
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

while [ $# -gt 0 ]; do
	case "$1" in
		--bin) BIN_DIR="$2"; shift 2 ;;
		--bin=*) BIN_DIR="${1#*=}"; shift ;;
		--copy) COPY=1; shift ;;
		--skip-pwsh-check) SKIP_PWSH_CHECK=1; shift ;;
		-h|--help) usage 0 ;;
		*) echo "Unknown option: $1" >&2; usage 1 ;;
	esac
done

# Resolve the directory this script lives in (so it works from anywhere).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DIR="$SCRIPT_DIR/src"

if [ ! -d "$SRC_DIR" ]; then
	echo "Error: could not find src/ next to install.sh ($SRC_DIR)" >&2
	exit 1
fi

# --- pwsh check ------------------------------------------------------------

if [ "$SKIP_PWSH_CHECK" -eq 0 ] && ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell (pwsh) is not on your PATH." >&2
	echo "These utilities run on pwsh, which is cross-platform. Install it with:" >&2
	echo >&2
	case "$(uname -s)" in
		Darwin) echo "  brew install powershell/tap/powershell" >&2 ;;
		Linux)  echo "  sudo snap install powershell --classic" >&2
		        echo "  (or see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)" >&2 ;;
		*)      echo "  see https://learn.microsoft.com/powershell/scripting/install/installing-powershell" >&2 ;;
	esac
	echo >&2
	echo "Then re-run, or pass --skip-pwsh-check to install anyway." >&2
	exit 1
fi

# --- install ---------------------------------------------------------------

mkdir -p "$BIN_DIR"

is_excluded() {
	for e in $EXCLUDE; do
		[ "$1" = "$e" ] && return 0
	done
	return 1
}

count=0
for script in "$SRC_DIR"/git-*.ps1; do
	[ -e "$script" ] || continue
	base=$(basename "$script" .ps1)
	is_excluded "$base" && continue

	target="$BIN_DIR/$base"
	chmod +x "$script"

	if [ "$COPY" -eq 1 ]; then
		cp "$script" "$target"
	else
		ln -sf "$script" "$target"
	fi
	chmod +x "$target"
	count=$((count + 1))
done

echo "Installed $count git subcommand(s) into $BIN_DIR."

# --- PATH check ------------------------------------------------------------

case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*)
		echo
		echo "NOTE: $BIN_DIR is not on your PATH. Add it, e.g.:"
		echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.profile"
		;;
esac

echo
echo "Try it:  git config-email --help  (or ./src/git-config-email.ps1)"
