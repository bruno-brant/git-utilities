#!/usr/bin/env pwsh
# Resolve "both modified" conflicts by taking their version of each file.
$statusLine = "both modified: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Checking out theirs for $file"
	git checkout --theirs $file
	git add $file
}
