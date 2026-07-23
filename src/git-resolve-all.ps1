#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Resolves every conflicted file using the per-type default strategy.

.DESCRIPTION
	Applies the default resolution for each conflict type in one pass, mirroring
	the individual git-resolve-* subcommands:

	  both modified    -> keep theirs (checkout --theirs + add)
	  deleted by us    -> keep the file (git add)
	  deleted by them  -> remove the file (git rm)
	  added by them    -> keep the file (git add)
	  both deleted     -> remove the file (git rm)
	  added by us      -> remove the file (git rm)

.EXAMPLE
	git resolve-all

	Resolves all conflicted files in the current merge or rebase.
#>

function Resolve-Status([string] $StatusLine, [scriptblock] $Action) {
	git status | Select-String $StatusLine | ForEach-Object {
		$file = $_.ToString().Replace($StatusLine, "").Trim()
		& $Action $file
	}
}

Resolve-Status "both modified: "   { param($f) "Checking out theirs for $f"; git checkout --theirs $f; git add $f }
Resolve-Status "deleted by us: "   { param($f) "Adding new file $f";          git add $f }
Resolve-Status "deleted by them: " { param($f) "Removing deleted file $f";     git rm $f }
Resolve-Status "added by them: "   { param($f) "Adding new file $f";           git add $f }
Resolve-Status "both deleted: "    { param($f) "Removing deleted file $f";     git rm $f }
Resolve-Status "added by us: "     { param($f) "Removing added file $f";       git rm $f }
