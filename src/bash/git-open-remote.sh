#!/usr/bin/env bash
# Open a remote's URL in your browser (defaults to origin).
#
# Usage: git open-remote [remote]
set -u
remote="${1:-origin}"
url=$(git remote get-url "$remote") || exit 1

if command -v xdg-open >/dev/null 2>&1; then
	xdg-open "$url"
elif command -v open >/dev/null 2>&1; then
	open "$url"
else
	echo "$url"
fi
