#!/usr/bin/env bash
# Accept deletions for every file git reports as "deleted by us".
#
# Usage: git accept-deleted
git status | sed -n 's/.*deleted by us:[[:space:]]*//p' | while IFS= read -r file; do
	[ -n "$file" ] || continue
	git rm "$file"
done
