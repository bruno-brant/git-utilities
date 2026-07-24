#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "both modified" merge conflicts by taking their version.

.DESCRIPTION
	For each file `git status` reports as "both modified", checks out the other
	side's version (`git checkout --theirs`) and stages it with `git add`.
	Relies on the `git get-fileswithstatus` helper being on your PATH (installed
	via install.sh / install.ps1).

.EXAMPLE
	git resolve-bothmodified

	Takes theirs for every "both modified" file in the current conflict.
#>
git get-fileswithstatus "both modified" | ForEach-Object {
	"Checking out theirs for $_"
	git checkout --theirs $_
	git add $_
}
