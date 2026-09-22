#!/usr/bin/env bash
# Create and check out a branch under the u/brunobr/ namespace.
#
# Usage: git new-branch <name>
set -u
name="${1:-}"
if [ -z "$name" ]; then
	echo "usage: git new-branch <name>" >&2
	exit 1
fi
git checkout -b "u/brunobr/$name"
