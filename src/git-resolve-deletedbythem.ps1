#!/usr/bin/env pwsh
# Resolve "deleted by them" conflicts by removing each file.
$statusLine = "deleted by them: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing deleted file $file"
	git rm $file
}
