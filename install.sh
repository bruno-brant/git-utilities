#!/usr/bin/env sh
#
# Installs the git-utilities scripts onto your PATH so they work as native
# git subcommands (e.g. `git config-email`, `git-resolve-all`).
#
# Two ways to run it:
#
#   1. Piped from the web (no clone needed) — downloads the latest release,
#      unpacks it, and links the scripts:
#
#        curl -fsSL https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.sh | sh
#
#   2. From a checkout of this repo — links the scripts straight out of src/,
#      so your edits take effect immediately.
#
# Usage (when downloaded / run locally):
#   ./install.sh [--bin DIR] [--copy] [--version vX.Y.Z] [--skip-pwsh-check]
#
# Options:
#   --bin DIR           Where to link the commands (default: $HOME/.local/bin).
#   --copy              Copy scripts instead of symlinking them.
#   --version vX.Y.Z    Install a specific release (default: latest).
#   --skip-pwsh-check   Don't verify that pwsh is installed.
#   -h, --help          Show this help.

set -eu

REPO="bruno-brant/git-utilities"

# Library scripts that are meant to be dot-sourced, not run as subcommands.
# (Space-separated basenames without the .ps1 extension.)
EXCLUDE=""

BIN_DIR="${GIT_UTILITIES_BIN:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/git-utilities"
COPY=0
SKIP_PWSH_CHECK=0
VERSION="${GIT_UTILITIES_VERSION:-}"

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
		--version) VERSION="$2"; shift 2 ;;
		--version=*) VERSION="${1#*=}"; shift ;;
		--skip-pwsh-check) SKIP_PWSH_CHECK=1; shift ;;
		-h|--help) usage 0 ;;
		*) echo "Unknown option: $1" >&2; usage 1 ;;
	esac
done

# --- locate the scripts: a local src/ checkout, or a downloaded release ------

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || echo "")

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/src" ]; then
	# Run from a checkout: link straight out of src/.
	SRC_DIR="$SCRIPT_DIR/src"
	echo "Installing from source checkout: $SRC_DIR"
else
	# Piped from the web (or run outside a checkout): download a release.
	if command -v curl >/dev/null 2>&1; then
		fetch() { curl -fsSL "$1" -o "$2"; }
	elif command -v wget >/dev/null 2>&1; then
		fetch() { wget -qO "$2" "$1"; }
	else
		echo "Error: need curl or wget to download the release." >&2
		exit 1
	fi

	if [ -n "$VERSION" ]; then
		url="https://github.com/$REPO/releases/download/$VERSION/git-utilities.tar.gz"
	else
		url="https://github.com/$REPO/releases/latest/download/git-utilities.tar.gz"
	fi

	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT

	echo "Downloading $url"
	if ! fetch "$url" "$tmp/git-utilities.tar.gz"; then
		echo "Error: download failed. Has a release been published yet?" >&2
		exit 1
	fi

	# Refresh the install into a stable, clone-free location.
	rm -rf "$DATA_DIR"
	mkdir -p "$DATA_DIR"
	tar -xzf "$tmp/git-utilities.tar.gz" -C "$DATA_DIR"
	SRC_DIR="$DATA_DIR"
	echo "Unpacked release into $SRC_DIR"
fi

# --- pwsh check ------------------------------------------------------------

if [ "$SKIP_PWSH_CHECK" -eq 0 ] && ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell (pwsh) is not on your PATH." >&2
	echo "These utilities run on pwsh, which is cross-platform. Install it with:" >&2
	echo >&2
	case "$(uname -s)" in
		Darwin) echo "  brew install --cask powershell" >&2 ;;
		Linux)  echo "  sudo snap install powershell --classic" >&2
		        echo "  (or see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)" >&2 ;;
		*)      echo "  see https://learn.microsoft.com/powershell/scripting/install/installing-powershell" >&2 ;;
	esac
	echo >&2
	echo "Then re-run, or pass --skip-pwsh-check to install anyway." >&2
	exit 1
fi

# --- link the commands onto PATH -------------------------------------------

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
echo "Try it:  git config-email --help"
