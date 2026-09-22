#!/usr/bin/env bash
# Resolves "deleted by us" conflicts by keeping (adding) each file.
#
# Usage: git resolve-deletedbyus
git get-fileswithstatus "deleted by us" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Adding new file $file"
	git add "$file"
done
