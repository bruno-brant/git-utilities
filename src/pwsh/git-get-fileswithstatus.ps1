#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Lists the files currently in a given merge-conflict state.

.DESCRIPTION
	Parses `git status` and prints the path of every file reported in the given
	conflict state, one per line. The git-resolve-* commands build on this.

.PARAMETER Status
	The conflict state to filter by — one of the standard git conflict labels.
	Tab-completes, and only these values are accepted.

.EXAMPLE
	git get-fileswithstatus "both modified"

	Lists every file currently marked "both modified".
#>
param(
	[Parameter(Mandatory = $true, Position = 0)]
	[ValidateSet(
		'both modified',
		'deleted by us',
		'deleted by them',
		'added by them',
		'added by us',
		'both deleted'
	)]
	[string] $Status
)

$statusLine = "${Status}: "
git status | Select-String $statusLine | ForEach-Object {
	$_.ToString().Replace($statusLine, "").Trim()
}
