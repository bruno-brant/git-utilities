#!/usr/bin/env pwsh
# Resolve "added by us" conflicts by removing each file.
$statusLine = "added by us: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing added file $file"
	git rm $file
}
