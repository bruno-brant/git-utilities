#!/usr/bin/env bash
# Resolves "added by us" conflicts by removing each file.
#
# Usage: git resolve-addedbyus
git get-fileswithstatus "added by us" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Removing added file $file"
	git rm "$file"
done
