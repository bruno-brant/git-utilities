#!/usr/bin/env bash
# Lists the files currently in a given merge-conflict state, one per line.
# The git-resolve-* commands build on this.
#
# Usage: git get-fileswithstatus <status>
#
# <status> must be one of the standard git conflict labels:
#   both modified | deleted by us | deleted by them
#   added by them | added by us   | both deleted
set -u

status="${1:-}"

case "$status" in
	"both modified"|"deleted by us"|"deleted by them"|"added by them"|"added by us"|"both deleted")
		;;
	"")
		echo "usage: git get-fileswithstatus <status>" >&2
		exit 1
		;;
	*)
		echo "git get-fileswithstatus: unknown status '$status'" >&2
		echo "expected one of: both modified, deleted by us, deleted by them, added by them, added by us, both deleted" >&2
		exit 1
		;;
esac

git status | sed -n "s/.*${status}:[[:space:]]*//p" | sed 's/[[:space:]]*$//'
