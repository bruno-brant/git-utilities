#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "both deleted" merge conflicts by removing the file.

.DESCRIPTION
	Scans `git status` for files in the "both deleted" conflict state — deleted
	on both sides — and removes each with `git rm`, confirming the deletion.

.EXAMPLE
	git resolve-bothdeleted

	Removes every "both deleted" file in the current conflict.
#>
$statusLine = "both deleted: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Removing deleted file $file"
	git rm $file
}
