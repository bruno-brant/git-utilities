#!/usr/bin/env bash
# Open origin's URL in your browser.
#
# Usage: git show-web
url=$(git remote get-url origin) || exit 1

if command -v xdg-open >/dev/null 2>&1; then
	xdg-open "$url"
elif command -v open >/dev/null 2>&1; then
	open "$url"
else
	echo "$url"
fi
