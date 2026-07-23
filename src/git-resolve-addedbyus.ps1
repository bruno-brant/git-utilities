#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "added by us" merge conflicts by removing the file.

.DESCRIPTION
	Scans `git status` for files in the "added by us" conflict state — added on
	the current branch but absent on the other side — and removes each with
	`git rm`, dropping our file.

.EXAMPLE
	git resolve-addedbyus

	Removes every "added by us" file in the current conflict.
#>
$statusLine = "added by us: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing added file $file"
	git rm $file
}
