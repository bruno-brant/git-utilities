#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a git worktree for the current repo that mirrors the current working
    state, with all git-ignored paths replaced by symbolic links back to the
    source repo.

.DESCRIPTION
    Given a workstream name, this script:
      1. Resolves the root of the repo you're currently in (works from any subdir).
      2. Creates a worktree in a SIBLING directory named "<repo>-<workstream>",
         on a new branch u/<user>/<workstream> derived from the current branch.
      3. Mirrors the current on-disk state of the source tree into the worktree
         (including uncommitted/dirty changes), excluding .git.
      4. For every path currently ignored by git, replaces it in the worktree
         with a link pointing back to the source repo. Directory-level ignored
         entries are linked as JUNCTIONS (so e.g. node_modules is one link, not
         millions); file-level entries are linked as file symlinks.

    Junctions are used for directories deliberately: git treats a junction as a
    real directory and walks into it, so existing .gitignore rules apply and the
    contents stay ignored. A directory *symlink*, by contrast, is reported by git
    as a symlink entry and can show up as untracked. Junctions also never require
    elevation.

    File symlinks are created in-process and unelevated first; with Windows
    Developer Mode enabled this needs no admin rights and shows no UAC prompt.
    Any that still require elevation are created together in a SINGLE elevated
    process, so at most ONE UAC prompt appears (no gsudo dependency).

.PARAMETER WorkstreamName
    Suffix used for the worktree directory name.

.PARAMETER BranchName
    Optional. Name (the u/<user>/... leaf) for the new branch. If omitted,
    the workstream name is used.

.EXAMPLE
    git-worktree-add.ps1 fix-class-view

.EXAMPLE
    git-worktree-add.ps1 fix-class-view -BranchName classview-hotfix
#>
param (
    [Parameter(Mandatory = $true)]
    [string] $WorkstreamName,

    [Parameter(Mandatory = $false)]
    [string] $BranchName
)

$ErrorActionPreference = 'Stop'

# --- 1. Resolve repo root (works even when called from a subdirectory) --------
$repoRoot = (& git rev-parse --show-toplevel 2>$null                   )
if (-not $repoRoot) {
    throw "Not inside a git repository. cd into the repo (or a subdirectory of it) and try again."
}
$repoRoot = (Resolve-Path -LiteralPath $repoRoot).Path
$repoName = Split-Path -Leaf $repoRoot

# --- 2. Compute sibling worktree path and branch name ------------------------
$parentDir    = Split-Path -Parent $repoRoot
$worktreePath = Join-Path $parentDir "$repoName-$WorkstreamName"

$currentBranch = (& git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
$user          = if ($env:USERNAME) { $env:USERNAME } else { 'user' }
$branchLeaf    = if ($BranchName) { $BranchName } else { $WorkstreamName }
$newBranch     = "u/$user/$branchLeaf"

if (Test-Path -LiteralPath $worktreePath) {
    throw "Target path already exists: $worktreePath"
}

Write-Host "Source repo   : $repoRoot"        -ForegroundColor Cyan
Write-Host "Worktree path : $worktreePath"    -ForegroundColor Cyan
Write-Host "New branch    : $newBranch (from $currentBranch)" -ForegroundColor Cyan

# --- 3. Create the worktree from the current branch --------------------------
& git -C $repoRoot worktree add -b $newBranch $worktreePath $currentBranch
if ($LASTEXITCODE -ne 0) { throw "git worktree add failed." }

# --- 4. Discover git-ignored top-level paths in the SOURCE repo ---------------
# Capture these BEFORE mirroring so we know exactly which paths to symlink.
# `!! ` lines from porcelain v1 are the ignored entries; directories carry a
# trailing slash. Paths are forward-slashed and relative to the repo root.
$ignoredRaw = & git -C $repoRoot status --ignored --porcelain=v1 2>$null
$ignoredPaths = @(
    $ignoredRaw |
        Where-Object { $_.StartsWith('!!') } |
        ForEach-Object { $_.Substring(2).Trim().TrimEnd('/') }
)
Write-Host "Found $($ignoredPaths.Count) git-ignored path(s) to symlink." -ForegroundColor Cyan

# --- 5. Mirror the current on-disk state into the worktree -------------------
# robocopy /MIR makes the worktree a byte-for-byte mirror of the source working
# directory (including dirty changes). We must NOT clobber the worktree's own
# .git file, and we exclude the ignored paths here so robocopy doesn't waste
# time copying node_modules etc. that we're about to replace with symlinks.
$excludeDirs = New-Object System.Collections.Generic.List[string]
$excludeFiles = New-Object System.Collections.Generic.List[string]

# Never touch git's bookkeeping.
$excludeDirs.Add((Join-Path $repoRoot '.git'))
$excludeFiles.Add((Join-Path $repoRoot '.git'))   # worktrees use a .git FILE

foreach ($rel in $ignoredPaths) {
    $srcFull = (Join-Path $repoRoot $rel) -replace '/', '\'
    if (Test-Path -LiteralPath $srcFull -PathType Container) {
        $excludeDirs.Add($srcFull)
    }
    else {
        $excludeFiles.Add($srcFull)
    }
}

Write-Host "Mirroring working tree into worktree (excluding ignored paths)..." -ForegroundColor Cyan
$roboArgs = @(
    $repoRoot,
    $worktreePath,
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
        $target = (Join-Path $repoRoot $rel)     -replace '/', '\'   # real path in source
        $link   = (Join-Path $worktreePath $rel) -replace '/', '\'   # link in worktree

        if (-not (Test-Path -LiteralPath $target)) {
            Write-Warning "Skipping '$rel' - source no longer exists."
            continue
        }

        $isDir = Test-Path -LiteralPath $target -PathType Container

        $linkParent = Split-Path -Parent $link
        if (-not (Test-Path -LiteralPath $linkParent)) {
            New-Item -ItemType Directory -Path $linkParent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $link) {
            # NOTE: -Recurse on a junction removes the junction, not its target.
            Remove-Item -LiteralPath $link -Recurse -Force
        }

        [pscustomobject]@{ Rel = $rel; Link = $link; Target = $target; IsDir = $isDir }
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
Write-Host "Done. Worktree ready at:" -ForegroundColor Green
Write-Host "  $worktreePath" -ForegroundColor Green
Write-Host "  branch: $newBranch" -ForegroundColor Green
