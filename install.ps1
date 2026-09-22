#!/usr/bin/env pwsh
<#
.SYNOPSIS
	Installs the git-utilities scripts onto your PATH so they work as native
	git subcommands (e.g. `git config-email`, `git-resolve-all`).

.DESCRIPTION
	The tools ship in two flavors: PowerShell (src/pwsh) and bash (src/bash).
	This installer uses the pwsh flavor by default; pass -Flavor bash to
	install the bash one instead (needs bash on PATH, e.g. Git for Windows).

	Two ways to run it:

	  1. Piped from the web (no clone needed) — downloads the latest release,
	     unpacks it, and shims the scripts:

	       irm https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.ps1 | iex

	  2. From a checkout of this repo — shims the scripts straight out of src/,
	     so your edits take effect immediately.

	Generates a small .cmd shim for each script in a bin directory and adds
	that directory to your user PATH. This installer targets Windows; on
	macOS/Linux, use ./install.sh.

.PARAMETER Flavor
	Which flavor to install: 'pwsh' (default) or 'bash'.

.PARAMETER BinDir
	Where to put the shims (default: $HOME\bin).

.PARAMETER Copy
	Copy the scripts into the data dir even when installing from a checkout.

.PARAMETER Version
	Install a specific release tag (default: latest).

.PARAMETER SkipPathUpdate
	Don't modify your user PATH.
#>
param(
	[ValidateSet('pwsh', 'bash')]
	[string] $Flavor = 'pwsh',
	[string] $BinDir = (Join-Path $HOME 'bin'),
	[switch] $Copy,
	[string] $Version,
	[switch] $SkipPathUpdate
)

$ErrorActionPreference = 'Stop'
$Repo = 'bruno-brant/git-utilities'

if (-not $IsWindows) {
	Write-Error "install.ps1 targets Windows. On macOS/Linux, run ./install.sh instead."
	exit 1
}

$ext = if ($Flavor -eq 'bash') { '.sh' } else { '.ps1' }
$dataDir = Join-Path $env:LOCALAPPDATA 'git-utilities'

# --- locate the scripts: a local src/ checkout, or a downloaded release ------

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
$localSrc = if ($scriptRoot) { Join-Path (Join-Path $scriptRoot 'src') $Flavor } else { $null }

if ($localSrc -and (Test-Path $localSrc)) {
	$srcDir = $localSrc
	Write-Host "Installing the $Flavor flavor from source checkout: $srcDir"
} else {
	# Piped from the web (or run outside a checkout): download a release.
	if ($Version) {
		$url = "https://github.com/$Repo/releases/download/$Version/git-utilities.zip"
	} else {
		$url = "https://github.com/$Repo/releases/latest/download/git-utilities.zip"
	}

	$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("git-utilities-" + [guid]::NewGuid())
	New-Item -ItemType Directory -Force -Path $tmp | Out-Null
	$zip = Join-Path $tmp 'git-utilities.zip'

	Write-Host "Downloading $url"
	try {
		Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
	} catch {
		Write-Error "Download failed. Has a release been published yet? ($url)"
		exit 1
	}

	# Refresh the install into a stable, clone-free location.
	if (Test-Path $dataDir) { Remove-Item -Recurse -Force $dataDir }
	New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
	Expand-Archive -Path $zip -DestinationPath $dataDir -Force
	Remove-Item -Recurse -Force $tmp

	$flavorDir = Join-Path $dataDir $Flavor
	if (Test-Path $flavorDir) {
		$srcDir = $flavorDir
	} else {
		# Releases before the bash flavor shipped a flat (pwsh-only) layout.
		$srcDir = $dataDir
	}
	Write-Host "Unpacked release into $srcDir"
}

# --- dependency check --------------------------------------------------------

if ($Flavor -eq 'bash') {
	$bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
	if (-not $bashPath) {
		Write-Error "The bash flavor needs bash on your PATH (e.g. from Git for Windows). Use -Flavor pwsh instead."
		exit 1
	}
} else {
	$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
	if (-not $pwshPath) { $pwshPath = (Join-Path $PSHOME 'pwsh.exe') }
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$count = 0
Get-ChildItem -Path $srcDir -Filter "git-*$ext" | ForEach-Object {
	$base = $_.BaseName

	if ($Copy) {
		$scriptPath = Join-Path $dataDir $_.Name
		Copy-Item $_.FullName $scriptPath -Force
	} else {
		$scriptPath = $_.FullName
	}

	# A .cmd shim lets `git <name>` and `<name>` both resolve on Windows.
	$shim = Join-Path $BinDir "$base.cmd"
	if ($Flavor -eq 'bash') {
		$line = "`"$bashPath`" `"$scriptPath`" %*"
	} else {
		$line = "`"$pwshPath`" -NoProfile -File `"$scriptPath`" %*"
	}
	@('@echo off', $line) | Set-Content -Path $shim -Encoding Ascii
	$count++
}

if ($count -eq 0) {
	Write-Error "No git-*$ext scripts found in $srcDir. This release may predate the $Flavor flavor; try a newer release or another -Flavor."
	exit 1
}

Write-Host "Installed $count git subcommand(s) ($Flavor flavor) into $BinDir."

# --- PATH update -------------------------------------------------------------

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
