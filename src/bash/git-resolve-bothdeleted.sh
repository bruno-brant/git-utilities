#!/usr/bin/env bash
# Resolves "both deleted" conflicts by removing each file.
#
# Usage: git resolve-bothdeleted
git get-fileswithstatus "both deleted" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Removing deleted file $file"
	git rm "$file"
done
