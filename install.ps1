#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs the git-utilities scripts onto your PATH so they work as native
    git subcommands (e.g. `git config-email`, `git worktree-add`).

.DESCRIPTION
    Generates a small .cmd shim for each script in a bin directory and adds
    that directory to your user PATH. The shims point back at the scripts in
    this repo, so edits are picked up immediately (use -Copy to copy instead).

    This installer targets Windows. On macOS/Linux, use ./install.sh.

.PARAMETER BinDir
    Where to install the shims (default: $HOME\bin).

.PARAMETER Copy
    Copy the scripts into BinDir instead of pointing shims at the repo.

.PARAMETER SkipPathUpdate
    Don't modify your user PATH.
#>
param(
	[string] $BinDir = (Join-Path $HOME 'bin'),
	[switch] $Copy,
	[switch] $SkipPathUpdate
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
	Write-Error "install.ps1 targets Windows. On macOS/Linux, run ./install.sh instead."
	exit 1
}

# Library scripts that are meant to be dot-sourced, not run as subcommands.
$Exclude = @()

$srcDir = Join-Path $PSScriptRoot 'src'
if (-not (Test-Path $srcDir)) {
	Write-Error "Could not find src/ next to install.ps1 ($srcDir)"
	exit 1
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) { $pwshPath = (Join-Path $PSHOME 'pwsh.exe') }

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$count = 0
Get-ChildItem -Path $srcDir -Filter 'git-*.ps1' | ForEach-Object {
	$base = $_.BaseName
	if ($Exclude -contains $base) { return }

	if ($Copy) {
		$scriptPath = Join-Path $BinDir $_.Name
		Copy-Item $_.FullName $scriptPath -Force
	} else {
		$scriptPath = $_.FullName
	}

	# A .cmd shim lets `git <name>` and `<name>` both resolve on Windows.
	$shim = Join-Path $BinDir "$base.cmd"
	@(
		'@echo off'
		"`"$pwshPath`" -NoProfile -File `"$scriptPath`" %*"
	) | Set-Content -Path $shim -Encoding Ascii
	$count++
}

Write-Host "Installed $count git subcommand(s) into $BinDir."

# --- PATH update -----------------------------------------------------------

if (-not $SkipPathUpdate) {
	$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
	$parts = ($userPath -split ';') | Where-Object { $_ -ne '' }
	if ($parts -notcontains $BinDir) {
		[Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
		Write-Host "Added $BinDir to your user PATH. Restart your shell to pick it up."
	}
} else {
	Write-Host "NOTE: ensure $BinDir is on your PATH."
}

Write-Host ""
Write-Host "Try it:  git config-email -Init"
