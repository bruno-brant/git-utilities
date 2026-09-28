#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a git worktree for the current repo as a sibling directory on a new
    branch, then mirror the current working state into it.

.DESCRIPTION
    Given a workstream name, this script:
      1. Resolves the root of the repo you're currently in (works from any subdir).
      2. Creates a worktree in a SIBLING directory named "<repo>-<workstream>",
         on a new branch u/<user>/<workstream> derived from the current branch.
      3. Runs git-worktree-mirror on it, which copies over your uncommitted
         changes and links every git-ignored path (node_modules, build output,
         ...) back to the source repo.

    Pass -NoMirror to stop after step 2; you can mirror later with
    `git worktree-mirror <path>`. That also works on worktrees you create
    yourself with plain `git worktree add`.

.PARAMETER WorkstreamName
    Suffix used for the worktree directory name.

.PARAMETER BranchName
    Optional. Name (the u/<user>/... leaf) for the new branch. If omitted,
    the workstream name is used.

.PARAMETER NoMirror
    Only create the worktree; don't mirror into it.

.EXAMPLE
    git-worktree-add.ps1 fix-class-view

.EXAMPLE
    git-worktree-add.ps1 fix-class-view -BranchName classview-hotfix

.EXAMPLE
    git-worktree-add.ps1 fix-class-view -NoMirror
#>
param (
    [Parameter(Mandatory = $true)]
    [string] $WorkstreamName,

    [Parameter(Mandatory = $false)]
    [string] $BranchName,

    [switch] $NoMirror
)

$ErrorActionPreference = 'Stop'

# Fail before creating anything if the mirror step can't run at all.
if (-not $NoMirror -and -not (Get-Command git-worktree-mirror -ErrorAction SilentlyContinue)) {
    throw "git-worktree-mirror isn't on your PATH. Install the tools (install.ps1), or pass -NoMirror to only create the worktree."
}

# --- 1. Resolve repo root (works even when called from a subdirectory) --------
$repoRoot = (& git rev-parse --show-toplevel 2>$null)
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

if ($NoMirror) {
    Write-Host ""
    Write-Host "Created worktree at $worktreePath (branch $newBranch); not mirrored." -ForegroundColor Green
    Write-Host "Mirror it later with:  git worktree-mirror `"$worktreePath`""
    return
}

# --- 4. Mirror the working state into it -------------------------------------
Write-Host ""
& git worktree-mirror $worktreePath
if ($LASTEXITCODE -ne 0) {
    Write-Warning "The worktree was created at $worktreePath, but mirroring failed."
    Write-Warning "Fix the problem above, then run:  git worktree-mirror `"$worktreePath`""
    exit 1
}

Write-Host "  branch: $newBranch" -ForegroundColor Green
