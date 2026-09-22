#!/usr/bin/env bash
# Resolves "deleted by them" conflicts by removing each file.
#
# Usage: git resolve-deletedbythem
git get-fileswithstatus "deleted by them" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Removing deleted file $file"
	git rm "$file"
done
