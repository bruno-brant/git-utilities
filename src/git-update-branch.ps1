#!/usr/bin/env pwsh
function Test-Clean {
	param ([switch] $Cached)
	if ($Cached) { git diff --cached --exit-code; }
	else { git diff --exit-code; }

	return $LASTEXITCODE;
}

$cached = Test-Clean -Cached
$notcached = Test-Clean
$shouldStash = $cached -eq 1 -or $notcached -eq 1

if ($shouldStash) {
	Write-Output "Stashing changes..."	
	git stash --include-untracked
}

$isMaster = git branch | sls master 
$isMain = git branch | sls main

$trunk = if ($isMaster) { "master" } elseif ($isMain) { "main" } else { throw "Error: No master or main branch found" }

Write-Verbose "Trunk is $trunk"

$branch = git rev-parse --abbrev-ref HEAD

Write-Verbose "Branch is $branch"

Write-Output "Updating trunk..."
git checkout $trunk
git pull

Write-Output "Rebasing..."
git checkout $branch
git rebase $trunk

if ($shouldStash) {
	Write-Output "Popping stash..."
	git stash pop
}
