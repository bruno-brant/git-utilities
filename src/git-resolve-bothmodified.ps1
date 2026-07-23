#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves "both modified" merge conflicts by taking their version.

.DESCRIPTION
	Scans `git status` for files in the "both modified" conflict state and, for
	each, checks out the other side's version (`git checkout --theirs`) and
	stages it with `git add`.

.EXAMPLE
	git resolve-bothmodified

	Takes theirs for every "both modified" file in the current conflict.
#>
$statusLine = "both modified: "
git status | Select-String $statusLine | ForEach-Object {
	$file = $_.ToString().Replace($statusLine, "").Trim()
	"Checking out theirs for $file"
	git checkout --theirs $file
	git add $file
}
