#!/usr/bin/env sh
#
# Installs the git-utilities scripts onto your PATH so they work as native
# git subcommands (e.g. `git config-email`, `git-resolve-all`).
#
# The tools ship in two flavors: bash (src/bash, no dependencies) and
# PowerShell (src/pwsh, needs pwsh). This installer uses the bash flavor by
# default; pass --flavor pwsh to install the PowerShell one instead.
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
#   ./install.sh [--flavor bash|pwsh] [--bin DIR] [--copy] [--version vX.Y.Z]
#
# Options:
#   --flavor F          Which flavor to install: bash (default) or pwsh.
#   --bin DIR           Where to link the commands (default: $HOME/.local/bin).
#   --copy              Copy scripts instead of symlinking them.
#   --version vX.Y.Z    Install a specific release (default: latest).
#   --skip-pwsh-check   Don't verify pwsh is installed (pwsh flavor only).
#   -h, --help          Show this help.

set -eu

REPO="bruno-brant/git-utilities"

BIN_DIR="${GIT_UTILITIES_BIN:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/git-utilities"
FLAVOR="${GIT_UTILITIES_FLAVOR:-bash}"
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
		--flavor) FLAVOR="$2"; shift 2 ;;
		--flavor=*) FLAVOR="${1#*=}"; shift ;;
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

case "$FLAVOR" in
	bash) EXT=".sh" ;;
	pwsh) EXT=".ps1" ;;
	*) echo "Unknown flavor: $FLAVOR (expected 'bash' or 'pwsh')" >&2; exit 1 ;;
esac

# --- locate the scripts: a local src/ checkout, or a downloaded release ------

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || echo "")

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/src/$FLAVOR" ]; then
	# Run from a checkout: link straight out of src/<flavor>/.
	SRC_DIR="$SCRIPT_DIR/src/$FLAVOR"
	echo "Installing the $FLAVOR flavor from source checkout: $SRC_DIR"
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

	if [ -d "$DATA_DIR/$FLAVOR" ]; then
		SRC_DIR="$DATA_DIR/$FLAVOR"
	else
		# Releases before the bash flavor shipped a flat (pwsh-only) layout.
		SRC_DIR="$DATA_DIR"
	fi
	echo "Unpacked release into $SRC_DIR"
fi

# --- dependency check --------------------------------------------------------

if [ "$FLAVOR" = "pwsh" ] && [ "$SKIP_PWSH_CHECK" -eq 0 ] && ! command -v pwsh >/dev/null 2>&1; then
	echo "PowerShell (pwsh) is not on your PATH, but you asked for the pwsh flavor." >&2
	echo "Either install pwsh, or use the dependency-free bash flavor:" >&2
	echo >&2
	echo "  ./install.sh --flavor bash" >&2
	echo >&2
	case "$(uname -s)" in
		Darwin) echo "  ...or install pwsh with: brew install --cask powershell" >&2 ;;
		Linux)  echo "  ...or install pwsh with: sudo snap install powershell --classic" >&2 ;;
		*)      echo "  ...or see https://learn.microsoft.com/powershell/scripting/install/installing-powershell" >&2 ;;
	esac
	echo >&2
	echo "Pass --skip-pwsh-check to install anyway." >&2
	exit 1
fi

if [ "$FLAVOR" = "bash" ] && ! command -v bash >/dev/null 2>&1; then
	echo "Error: the bash flavor needs bash on your PATH." >&2
	exit 1
fi

# --- link the commands onto PATH ---------------------------------------------

mkdir -p "$BIN_DIR"

count=0
for script in "$SRC_DIR"/git-*"$EXT"; do
	[ -e "$script" ] || continue
	base=$(basename "$script" "$EXT")

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

if [ "$count" -eq 0 ]; then
	echo "Error: no git-*$EXT scripts found in $SRC_DIR." >&2
	if [ "$FLAVOR" = "bash" ]; then
		echo "This release may predate the bash flavor. Try a newer release, or" >&2
		echo "install the PowerShell flavor with --flavor pwsh." >&2
	fi
	exit 1
fi

echo "Installed $count git subcommand(s) ($FLAVOR flavor) into $BIN_DIR."

# --- PATH check --------------------------------------------------------------

case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*)
		echo
		echo "NOTE: $BIN_DIR is not on your PATH. Add it, e.g.:"
		echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.profile"
		;;
esac

echo
echo "Try it:  git resolve-all --help  (or git config-email --help)"
