#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Mirror the source repo's current working state into an existing worktree,
    replacing every git-ignored path with a link back to the source.

.DESCRIPTION
    The source is the repository's main worktree, found automatically, so this
    works on any linked worktree -- including one you created yourself with
    plain `git worktree add`. git-worktree-add runs it for you after creating
    a worktree.

    It then:
      1. Mirrors the current on-disk state of the source tree into the worktree
         (including uncommitted changes), excluding .git and ignored paths.
      2. Replaces every git-ignored path in the worktree with a link pointing
         back to the source. Directory-level ignored entries are linked as
         JUNCTIONS (so e.g. node_modules is one link, not millions); file-level
         entries are linked as file symlinks.

    Junctions are used for directories deliberately: git treats a junction as a
    real directory and walks into it, so existing .gitignore rules apply and the
    contents stay ignored. A directory *symlink*, by contrast, is reported by git
    as a symlink entry and can show up as untracked. Junctions also never require
    elevation.

    File symlinks are created in-process and unelevated first; with Windows
    Developer Mode enabled this needs no admin rights and shows no UAC prompt.
    Any that still require elevation are created together in a SINGLE elevated
    process, so at most ONE UAC prompt appears (no gsudo dependency).

    Mirroring overwrites the target: files that aren't in the source are
    deleted, and ignored paths are replaced by links. So it refuses to run when
    the target has uncommitted changes, or real (non-link) files in ignored
    paths, unless -Force is given. It never runs on the main worktree itself.

    Re-mirroring a worktree needs -Force: the previous mirror copied the
    source's uncommitted changes into it, so it no longer looks clean.

.PARAMETER Path
    Worktree to mirror into. Defaults to the current one.

.PARAMETER Force
    Mirror even if the target has uncommitted changes or files in ignored paths.

.EXAMPLE
    git-worktree-mirror.ps1

.EXAMPLE
    git-worktree-mirror.ps1 ..\myrepo-fix-class-view -Force
#>
param (
    [Parameter(Position = 0)]
    [string] $Path = '.',

    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# --- 1. Resolve the target worktree ------------------------------------------
$target = (& git -C $Path rev-parse --show-toplevel 2>$null)
if (-not $target) {
    throw "Not a git worktree: $Path"
}
$target = (Resolve-Path -LiteralPath $target).Path

# --- 2. Find the source: the main worktree, always listed first --------------
$sourceRoot = $null
$sourceBare = $false
foreach ($line in (& git -C $target worktree list --porcelain)) {
    if ([string]::IsNullOrEmpty($line)) { break }
    if ($line.StartsWith('worktree ')) { $sourceRoot = $line.Substring(9) }
    elseif ($line -eq 'bare') { $sourceBare = $true }
}
if (-not $sourceRoot) {
    throw "Could not determine the repository's main worktree."
}
if ($sourceBare) {
    throw "The main repository is bare ($sourceRoot); there's no working tree to mirror from."
}
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "The main worktree no longer exists at $sourceRoot; nothing to mirror from."
}
$sourceRoot = (Resolve-Path -LiteralPath $sourceRoot).Path

# Windows paths are case-insensitive; compare accordingly.
$comparison = if ($IsLinux -or $IsMacOS) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
if ([string]::Equals($target.TrimEnd('\', '/'), $sourceRoot.TrimEnd('\', '/'), $comparison)) {
    throw "Refusing to mirror: $target is the main worktree (the source itself). Point it at, or run it from, a linked worktree instead."
}

# --- 3. Refuse to overwrite work in the target unless -Force -----------------
if (-not $Force) {
    $problems = @()

    if (& git -C $target status --porcelain 2>$null) {
        $problems += 'it has uncommitted changes'
    }

    # `git status` hides ignored files, so check those separately. Links left by
    # a previous mirror (junctions/symlinks) are fine; real content would be lost.
    # core.quotePath=false stops git octal-escaping non-ASCII names; the other
    # characters it quotes can't appear in Windows filenames.
    $realIgnored = @(
        & git -c core.quotePath=false -C $target status --ignored --porcelain=v1 2>$null |
            Where-Object { $_.StartsWith('!!') } |
            ForEach-Object { $_.Substring(2).Trim().TrimEnd('/') } |
            Where-Object {
                $p = Join-Path $target $_
                (Test-Path -LiteralPath $p) -and
                    -not ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
            }
    )
    if ($realIgnored.Count -gt 0) {
        $problems += "it has files in git-ignored paths: $($realIgnored -join ', ')"
    }

    if ($problems.Count -gt 0) {
        Write-Host "Refusing to mirror into ${target}:" -ForegroundColor Red
        foreach ($problem in $problems) { Write-Host "  - $problem" -ForegroundColor Red }
        Write-Host "Mirroring would overwrite that. Commit or stash it, or pass -Force to overwrite anyway." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Source repo : $sourceRoot" -ForegroundColor Cyan
Write-Host "Worktree    : $target"     -ForegroundColor Cyan

# --- 4. Discover git-ignored top-level paths in the SOURCE repo ---------------
# Capture these BEFORE mirroring so we know exactly which paths to link.
# `!! ` lines from porcelain v1 are the ignored entries; directories carry a
# trailing slash. Paths are forward-slashed and relative to the repo root.
$ignoredRaw = & git -c core.quotePath=false -C $sourceRoot status --ignored --porcelain=v1 2>$null
$ignoredPaths = @(
    $ignoredRaw |
        Where-Object { $_.StartsWith('!!') } |
        ForEach-Object { $_.Substring(2).Trim().TrimEnd('/') }
)
Write-Host "Found $($ignoredPaths.Count) git-ignored path(s) to link." -ForegroundColor Cyan

# --- 5. Mirror the current on-disk state into the worktree -------------------
# robocopy /MIR makes the worktree a byte-for-byte mirror of the source working
# directory (including dirty changes). We must NOT clobber the worktree's own
# .git file, and we exclude the ignored paths here so robocopy doesn't waste
# time copying node_modules etc. that we're about to replace with links.
$excludeDirs = New-Object System.Collections.Generic.List[string]
$excludeFiles = New-Object System.Collections.Generic.List[string]

# Never touch git's bookkeeping.
$excludeDirs.Add((Join-Path $sourceRoot '.git'))
$excludeFiles.Add((Join-Path $sourceRoot '.git'))   # worktrees use a .git FILE

foreach ($rel in $ignoredPaths) {
    $srcFull = (Join-Path $sourceRoot $rel) -replace '/', '\'
    if (Test-Path -LiteralPath $srcFull -PathType Container) {
        $excludeDirs.Add($srcFull)
    }
    else {
        $excludeFiles.Add($srcFull)
    }
}

Write-Host "Mirroring working tree into worktree (excluding ignored paths)..." -ForegroundColor Cyan
$roboArgs = @(
    $sourceRoot,
    $target,
    '/MIR',          # mirror (purge extras in dest)
    '/NFL', '/NDL',  # no per-file / per-dir logging
    '/NJH', '/NJS',  # no job header / summary
    '/NP',           # no progress %
    '/R:1', '/W:1'   # fail fast on locked files
)
if ($excludeDirs.Count -gt 0)  { $roboArgs += '/XD'; $roboArgs += $excludeDirs }
if ($excludeFiles.Count -gt 0) { $roboArgs += '/XF'; $roboArgs += $excludeFiles }

& robocopy @roboArgs | Out-Null
# robocopy exit codes < 8 are success (0-7 = various "copied/extra/mismatch" states).
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE." }
$global:LASTEXITCODE = 0

# --- 6. Replace each ignored path with a link back to the source -------------
# Directories -> JUNCTIONS: git walks into them as real dirs (so .gitignore still
# applies and contents stay ignored), and junctions never need elevation.
# Files -> SYMLINKS: created unelevated first; with Developer Mode on this is
# instant and silent. Any that fail on privilege are created together in a SINGLE
# elevated process (one UAC prompt for the whole batch, no gsudo).
if ($ignoredPaths.Count -gt 0) {
    Write-Host "Creating links for ignored paths..." -ForegroundColor Cyan

    # Build the plan: resolve link/target paths, note dir-vs-file, and clear any
    # stale entries up front (deleting in the unelevated parent avoids needing
    # elevation just to clean).
    $linkPlan = foreach ($rel in $ignoredPaths) {
        $linkTarget = (Join-Path $sourceRoot $rel) -replace '/', '\'   # real path in source
        $link       = (Join-Path $target $rel)     -replace '/', '\'   # link in worktree

        if (-not (Test-Path -LiteralPath $linkTarget)) {
            Write-Warning "Skipping '$rel' - source no longer exists."
            continue
        }

        $isDir = Test-Path -LiteralPath $linkTarget -PathType Container

        $linkParent = Split-Path -Parent $link
        if (-not (Test-Path -LiteralPath $linkParent)) {
            New-Item -ItemType Directory -Path $linkParent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $link) {
            # NOTE: -Recurse on a junction removes the junction, not its target.
            Remove-Item -LiteralPath $link -Recurse -Force
        }

        [pscustomobject]@{ Rel = $rel; Link = $link; Target = $linkTarget; IsDir = $isDir }
    }

    # Directories: junctions. Always unelevated, so just do them in-process.
    foreach ($item in ($linkPlan | Where-Object { $_.IsDir })) {
        New-Item -ItemType Junction -Path $item.Link -Target $item.Target | Out-Null
        Write-Host "  junction: $($item.Rel)" -ForegroundColor DarkGray
    }

    # Files: symlinks. Pass 1 unelevated (instant + silent under Developer Mode).
    $needElevation = foreach ($item in ($linkPlan | Where-Object { -not $_.IsDir })) {
        try {
            New-Item -ItemType SymbolicLink -Path $item.Link -Target $item.Target -ErrorAction Stop | Out-Null
            Write-Host "  link: $($item.Rel)" -ForegroundColor DarkGray
        }
        catch {
            $item   # couldn't make it unelevated -> defer to the elevated batch
        }
    }

    # Pass 2: one elevated process for every file symlink that failed -> single UAC prompt.
    if ($needElevation) {
        Write-Host "  $($needElevation.Count) file link(s) need elevation; requesting admin once..." -ForegroundColor Yellow

        # Emit one New-Item line per deferred link into a temp script, then run
        # that script in a single elevated pwsh. Single-quote the paths and
        # escape embedded quotes so spaces/odd chars survive intact.
        $lines = foreach ($item in $needElevation) {
            $l = $item.Link   -replace "'", "''"
            $t = $item.Target -replace "'", "''"
            "New-Item -ItemType SymbolicLink -Path '$l' -Target '$t' -Force | Out-Null"
        }
        $tmp = Join-Path $env:TEMP "wt-symlinks-$PID.ps1"
        Set-Content -LiteralPath $tmp -Value $lines -Encoding UTF8

        $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $p = Start-Process -FilePath $shell `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tmp) `
            -Verb RunAs -Wait -PassThru
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

        if ($p.ExitCode -ne 0) {
            Write-Warning "Elevated symlink batch exited with code $($p.ExitCode); some links may be missing."
        } else {
            foreach ($item in $needElevation) { Write-Host "  link: $($item.Rel)" -ForegroundColor DarkGray }
        }
    }
}

Write-Host ""
Write-Host "Done. Mirrored $sourceRoot into $target." -ForegroundColor Green
