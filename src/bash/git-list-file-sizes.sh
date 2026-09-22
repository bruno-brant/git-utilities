#!/usr/bin/env bash
# Lists every blob in the repository's history, smallest first, with a
# human-readable size. Useful for finding what is bloating the repo.
#
# Usage: git list-file-sizes
set -u

git rev-list --objects --all \
| git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
| awk '$1 == "blob" {
	path = ""
	for (i = 4; i <= NF; i++) path = path (i > 4 ? " " : "") $i
	print $3 "\t" $2 "\t" path
}' \
| sort -n \
| awk -F'\t' '
	function human(s) {
		if (s > 1099511627776) return sprintf("%.2f TB", s / 1099511627776)
		if (s > 1073741824)    return sprintf("%.2f GB", s / 1073741824)
		if (s > 1048576)       return sprintf("%.2f MB", s / 1048576)
		if (s > 1024)          return sprintf("%.2f kB", s / 1024)
		if (s > 0)             return sprintf("%.2f B", s)
		return ""
	}
	BEGIN { printf "%-40s  %-10s  %s\n", "Id", "Size", "Path" }
	{ printf "%-40s  %-10s  %s\n", $2, human($1), $3 }
'
