#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "both deleted" merge conflicts by removing the file.

.DESCRIPTION
	For each file `git status` reports as "both deleted", removes it with
	`git rm`, confirming the deletion. Relies on the `git get-fileswithstatus`
	helper being on your PATH (installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-bothdeleted

	Removes every "both deleted" file in the current conflict.
#>
git get-fileswithstatus "both deleted" | ForEach-Object {
	"Removing deleted file $_"
	git rm $_
}
