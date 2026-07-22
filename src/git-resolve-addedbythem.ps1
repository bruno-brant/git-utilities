#!/usr/bin/env pwsh
# Resolve "added by them" conflicts by keeping (adding) each file.
$statusLine = "added by them: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Adding new file $file"
	git add $file
}
