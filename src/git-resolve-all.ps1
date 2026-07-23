#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves every conflicted file using the per-type default strategy.

.DESCRIPTION
	Runs each git-resolve-* subcommand in turn, applying the default resolution
	for every conflict type in one pass. Relies on those subcommands being on
	your PATH (installed via install.sh / install.ps1).

.EXAMPLE
	git resolve-all

	Resolves all conflicted files in the current merge or rebase.
#>
git resolve-bothmodified
git resolve-deletedbyus
git resolve-deletedbythem
git resolve-addedbythem
git resolve-bothdeleted
git resolve-addedbyus
