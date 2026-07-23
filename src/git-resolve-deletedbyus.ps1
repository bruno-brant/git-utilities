#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "deleted by us" merge conflicts by keeping the file.

.DESCRIPTION
	Scans `git status` for files in the "deleted by us" conflict state — deleted
	on the current branch but present on the other side — and stages each with
	`git add`, keeping the incoming version rather than the deletion.

.EXAMPLE
	git resolve-deletedbyus

	Keeps every "deleted by us" file in the current conflict.
#>
$statusLine = "deleted by us: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Adding new file $file"
	git add $file
}
