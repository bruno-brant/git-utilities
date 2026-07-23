#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "added by them" merge conflicts by keeping the file.

.DESCRIPTION
	Scans `git status` for files in the "added by them" conflict state — added
	on the other side but absent on the current branch — and stages each with
	`git add`, keeping the incoming file.

.EXAMPLE
	git resolve-addedbythem

	Keeps every "added by them" file in the current conflict.
#>
$statusLine = "added by them: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Adding new file $file"
	git add $file
}
