#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "deleted by us" merge conflicts by keeping the file.

.DESCRIPTION
	For each file `git status` reports as "deleted by us" — deleted on the
	current branch but present on the other side — stages it with `git add`,
	keeping the incoming version. Relies on the `git get-fileswithstatus` helper
	being on your PATH (installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-deletedbyus

	Keeps every "deleted by us" file in the current conflict.
#>
git get-fileswithstatus "deleted by us" | ForEach-Object {
	"Adding new file $_"
	git add $_
}
