#!/usr/bin/env pwsh
# Resolve "both deleted" conflicts by removing each file.
$statusLine = "both deleted: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing deleted file $file"
	git rm $file
}
