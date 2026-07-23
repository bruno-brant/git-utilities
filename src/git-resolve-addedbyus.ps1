#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "added by us" merge conflicts by removing the file.

.DESCRIPTION
	For each file `git status` reports as "added by us" — added on the current
	branch but absent on the other side — removes it with `git rm`, dropping our
	file. Relies on the `git get-fileswithstatus` helper being on your PATH
	(installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-addedbyus

	Removes every "added by us" file in the current conflict.
#>
git get-fileswithstatus "added by us" | ForEach-Object {
	"Removing added file $_"
	git rm $_
}
