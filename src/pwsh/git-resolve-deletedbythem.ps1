#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "deleted by them" merge conflicts by removing the file.

.DESCRIPTION
	For each file `git status` reports as "deleted by them" — deleted on the
	other side but present on the current branch — removes it with `git rm`,
	accepting the deletion. Relies on the `git get-fileswithstatus` helper being
	on your PATH (installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-deletedbythem

	Removes every "deleted by them" file in the current conflict.
#>
git get-fileswithstatus "deleted by them" | ForEach-Object {
	"Removing deleted file $_"
	git rm $_
}
