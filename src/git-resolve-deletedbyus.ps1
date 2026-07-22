#!/usr/bin/env pwsh
# Resolve "deleted by us" conflicts by keeping (adding) each file.
$statusLine = "deleted by us: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Adding new file $file"
	git add $file
}
