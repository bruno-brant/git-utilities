#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Auto-resolves conflicts and continues an in-progress rebase to completion.

.DESCRIPTION
	Repeatedly applies the default per-type resolution strategies (the same ones
	git-resolve-all uses) and runs `git rebase --continue`, looping until the
	rebase finishes or hits an error that can't be auto-resolved. Sets
	GIT_EDITOR to `true` so `git rebase --continue` doesn't open an editor.

	Formerly git-tools' Start-Resolve.

.EXAMPLE
	git resolve-rebase

	Drives the current rebase forward, auto-resolving conflicts as it goes.
#>

function Resolve-Status([string] $StatusLine, [scriptblock] $Action) {
	git status | Select-String $StatusLine | ForEach-Object {
		$file = $_.ToString().Replace($StatusLine, "").Trim()
		& $Action $file
	}
}

function Resolve-All {
	Resolve-Status "both modified: "   { param($f) "Checking out theirs for $f"; git checkout --theirs $f; git add $f }
	Resolve-Status "deleted by us: "   { param($f) "Adding new file $f";          git add $f }
	Resolve-Status "deleted by them: " { param($f) "Removing deleted file $f";     git rm $f }
	Resolve-Status "added by them: "   { param($f) "Adding new file $f";           git add $f }
	Resolve-Status "both deleted: "    { param($f) "Removing deleted file $f";     git rm $f }
	Resolve-Status "added by us: "     { param($f) "Removing added file $f";       git rm $f }
}

function Test-IsRebasing {
	return $(git status | Select-String "rebase in progress;" | Measure-Object).Count -gt 0
}

# Don't open the editor on `git rebase --continue`.
$env:GIT_EDITOR = "true"

while (Test-IsRebasing) {
	"Resolving issues..."
	Resolve-All

	$(git rebase --continue) | Tee-Object -Variable output

	if ($? -eq $false) {
		if ($output.Contains("Could not apply")) {
			continue
		} else {
			"Rebase failed"
			break
		}
	}
}
