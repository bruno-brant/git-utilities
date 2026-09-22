#!/usr/bin/env bash
# Resolves "added by them" conflicts by keeping (adding) each file.
#
# Usage: git resolve-addedbythem
git get-fileswithstatus "added by them" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Adding new file $file"
	git add "$file"
done
