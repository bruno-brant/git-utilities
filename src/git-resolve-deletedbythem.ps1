#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "deleted by them" merge conflicts by removing the file.

.DESCRIPTION
	Scans `git status` for files in the "deleted by them" conflict state —
	deleted on the other side but present on the current branch — and removes
	each with `git rm`, accepting the deletion.

.EXAMPLE
	git resolve-deletedbythem

	Removes every "deleted by them" file in the current conflict.
#>
$statusLine = "deleted by them: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing deleted file $file"
	git rm $file
}
