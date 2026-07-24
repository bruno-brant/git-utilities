#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Auto-resolves conflicts and continues an in-progress rebase to completion.

.DESCRIPTION
	Repeatedly runs `git resolve-all` and `git rebase --continue`, looping until
	the rebase finishes or hits an error that can't be auto-resolved. Sets
	GIT_EDITOR to `true` so `git rebase --continue` doesn't open an editor.
	Relies on the git-resolve-* subcommands being on your PATH. Formerly
	git-tools' Start-Resolve.

.EXAMPLE
	git resolve-rebase

	Drives the current rebase forward, auto-resolving conflicts as it goes.
#>
function Test-IsRebasing {
	return $(git status | Select-String "rebase in progress;" | Measure-Object).Count -gt 0
}

# Don't open the editor on `git rebase --continue`.
$env:GIT_EDITOR = "true"

while (Test-IsRebasing) {
	"Resolving issues..."
	git resolve-all

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
