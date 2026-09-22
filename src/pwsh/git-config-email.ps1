#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets git user.name and user.email, with completions sourced from a
    JSON file in the user's home directory (~/.git-config-email.json), and
    can save new values back to that file.
#>
param (
        [Parameter(ParameterSetName = 'Set')]
        [ArgumentCompleter({
                param($_1, $_2, $word)
                $identities = Get-GitConfigEmailIdentities
                return $identities.names -like "$word*"
        })]
	[string] $UserName = "Bruno Brant",

        [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
        [ArgumentCompleter({
                param($_1, $_2, $word)
                $identities = Get-GitConfigEmailIdentities
                return $identities.emails -like "$word*"
        })]
	[string] $Email,

	# Adds -UserName/-Email to the saved identities file instead of (in
	# addition to) setting the git config.
	[Parameter(ParameterSetName = 'Set')]
	[switch] $Save,

	# Creates the identities file (with no entries) if it doesn't exist yet,
	# then exits without touching git config.
	[Parameter(ParameterSetName = 'Init', Mandatory = $true)]
	[switch] $Init
)

function Get-GitConfigEmailIdentitiesPath {
	Join-Path $HOME ".git-config-email.json"
}

function Get-GitConfigEmailIdentities {
	$identitiesPath = Get-GitConfigEmailIdentitiesPath

	if (Test-Path $identitiesPath) {
		return Get-Content $identitiesPath -Raw | ConvertFrom-Json
	}

	return [PSCustomObject]@{
		names  = @()
		emails = @()
	}
}

function Save-GitConfigEmailIdentity {
	param (
		[string] $UserName,
		[string] $Email
	)

	$identitiesPath = Get-GitConfigEmailIdentitiesPath
	$identities = Get-GitConfigEmailIdentities

	$names = @($identities.names)
	$emails = @($identities.emails)

	if ($UserName -and ($names -notcontains $UserName)) {
		$names += $UserName
	}

	if ($Email -and ($emails -notcontains $Email)) {
		$emails += $Email
	}

	[PSCustomObject]@{
		names  = $names
		emails = $emails
	} | ConvertTo-Json | Set-Content $identitiesPath
}

if ($Init) {
	$identitiesPath = Get-GitConfigEmailIdentitiesPath

	if (Test-Path $identitiesPath) {
		Write-Host "Identities file already exists at $identitiesPath"
	} else {
		[PSCustomObject]@{
			names  = @()
			emails = @()
		} | ConvertTo-Json | Set-Content $identitiesPath

		Write-Host "Created identities file at $identitiesPath"
	}

	return
}

if ($Save) {
	Save-GitConfigEmailIdentity -UserName $UserName -Email $Email
}

git config user.name $UserName
git config user.email $Email
