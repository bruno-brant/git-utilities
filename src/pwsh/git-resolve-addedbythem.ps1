#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "added by them" merge conflicts by keeping the file.

.DESCRIPTION
	For each file `git status` reports as "added by them" — added on the other
	side but absent on the current branch — stages it with `git add`, keeping
	the incoming file. Relies on the `git get-fileswithstatus` helper being on
	your PATH (installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-addedbythem

	Keeps every "added by them" file in the current conflict.
#>
git get-fileswithstatus "added by them" | ForEach-Object {
	"Adding new file $_"
	git add $_
}
