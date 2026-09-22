#!/usr/bin/env bash
# Resolves "both modified" conflicts by taking their version of each file.
#
# Usage: git resolve-bothmodified
git get-fileswithstatus "both modified" | while IFS= read -r file; do
	[ -n "$file" ] || continue
	echo "Checking out theirs for $file"
	git checkout --theirs "$file"
	git add "$file"
done
