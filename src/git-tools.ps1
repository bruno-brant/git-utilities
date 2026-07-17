#!/usr/bin/env pwsh
function Get-FilesWithStatus($StatusLine) {
	return $(git status | Select-String $StatusLine | ForEach-Object { $_.ToString().Replace($StatusLine, "").Trim() })
}

function Resolve-DeletedByUs() {
	Get-FilesWithStatus -StatusLine "deleted by us: " | ForEach-Object{
		"Adding new file $_" 
		git add $_ 
	}
}

function Resolve-DeletedByThem() {
	Get-FilesWithStatus -StatusLine "deleted by them: " | ForEach-Object{
		"Removing deleted file $_" 
		git rm $_
	}
}

function Resolve-BothModified() {
	Get-FilesWithStatus -StatusLine "both modified: " | ForEach-Object{ 
		"Checking out theirs for $_"
		git checkout --theirs $_
		git add $_ 
	}
}

function Resolve-AddedByThem() {
	Get-FilesWithStatus -StatusLine "added by them: " | ForEach-Object{
		"Adding new file $_" 
		git add $_
	}
}

function Resolve-AddedByUs() {
	Get-FilesWithStatus -StatusLine "added by us: " | ForEach-Object{
		"Removing added file $_" 
		git rm $_
	}
}

function Resolve-BothDeleted() {
	Get-FilesWithStatus -StatusLine "both deleted: " | ForEach-Object{
		"Removing deleted file $_" 
		git rm $_
	}
}

function Test-IsRebasing() {
	return $(git status | Select-String "rebase in progress;" | Measure-Object).Count -gt 0
}

function Resolve-All() {
	Resolve-BothModified
	Resolve-DeletedByUs
	Resolve-DeletedByThem
	Resolve-AddedByThem
	Resolve-BothDeleted
	Resolve-AddedByUs
}

function Start-Resolve() {
	# Don't open the editor
	$env:GIT_EDITOR="true"
	
	while (Test-IsRebasing) {
		"Resolving issues..."
		Resolve-All

		$(git rebase --continue) | Tee-Object -Variable output
		
		if ($? -eq $false) 	{
			$conflict_message = $output.Contains("Could not apply")
			
			if ($conflict_message) {
				continue;
			} else {
				"Rebase failed"
				break;
			}
		}
	}
}
