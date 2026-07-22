#!/usr/bin/env pwsh
# Resolve every conflicted file using the per-type default strategy.
# Mirrors the individual git-resolve-* subcommands.

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
