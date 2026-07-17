#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive picker to delete local git branches (flicker-free).

.DESCRIPTION
    Lists local branches in a mini console UI.
        Up / Down   - move the cursor
        Space       - toggle selection
        Enter       - confirm and delete selected branches
        Esc or Q    - quit without doing anything

    The currently checked-out branch is shown but cannot be selected.

.PARAMETER Force
    Use 'git branch -D' (force) instead of the safe 'git branch -d'.

.NOTES
    Run from inside a git repository in a real console (Windows Terminal,
    pwsh, or powershell.exe). Does NOT work in the PowerShell ISE.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

# --- Sanity checks ---------------------------------------------------------

$inside = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') {
    Write-Host "Not inside a git repository." -ForegroundColor Red
    exit 1
}

$current = (git rev-parse --abbrev-ref HEAD).Trim()

$branches = git branch --format='%(refname:short)' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ }

if (-not $branches) {
    Write-Host "No local branches found." -ForegroundColor Yellow
    exit 0
}

# --- Build the menu model --------------------------------------------------

$items = foreach ($b in $branches) {
    [pscustomobject]@{
        Name      = $b
        Selected  = $false
        IsCurrent = ($b -eq $current)
    }
}
$items = @($items)

$index = 0

# --- Rendering (in-place, no Clear-Host) -----------------------------------

# Write one full-width line so leftover characters from a previous frame are
# overwritten. Truncates if the text is wider than the window.
function Write-Line {
    param([string]$Text, $Fg = $null, $Bg = $null)

    $w = [Console]::WindowWidth - 1
    if ($w -lt 1) { $w = 1 }
    if ($Text.Length -gt $w) { $Text = $Text.Substring(0, $w) }
    $Text = $Text.PadRight($w)

    $params = @{ Object = $Text }
    if ($Fg) { $params.ForegroundColor = $Fg }
    if ($Bg) { $params.BackgroundColor = $Bg }
    Write-Host @params
}

function Render {
    # Jump back to the top-left instead of clearing the screen.
    [Console]::SetCursorPosition(0, 0)

    Write-Line "Select branches to delete" -Fg Cyan
    Write-Line "  Up/Down move | Space toggle | Enter confirm | Esc/Q quit" -Fg DarkGray
    if ($Force) {
        Write-Line "  Mode: FORCE delete (git branch -D)" -Fg Red
    } else {
        Write-Line "  Mode: safe delete (git branch -d)" -Fg DarkGray
    }
    Write-Line ""

    for ($i = 0; $i -lt $items.Count; $i++) {
        $it     = $items[$i]
        $cursor = if ($i -eq $index) { '>' } else { ' ' }
        $box    = if ($it.Selected)  { '[x]' } else { '[ ]' }
        $label  = $it.Name
        if ($it.IsCurrent) { $label += '  (current - cannot delete)' }

        $line = " $cursor $box $label"

        if ($i -eq $index) {
            Write-Line $line -Fg Black -Bg White
        } elseif ($it.Selected) {
            Write-Line $line -Fg Green
        } elseif ($it.IsCurrent) {
            Write-Line $line -Fg DarkGray
        } else {
            Write-Line $line
        }
    }
}

# --- Interaction loop ------------------------------------------------------

$cancelled = $false
try {
    [Console]::CursorVisible = $false
    Clear-Host   # one clear up front; after this we only reposition

    $done = $false
    while (-not $done) {
        Render
        $key = [System.Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow'   { $index = ($index - 1 + $items.Count) % $items.Count }
            'DownArrow' { $index = ($index + 1) % $items.Count }
            'Spacebar'  {
                $it = $items[$index]
                if (-not $it.IsCurrent) { $it.Selected = -not $it.Selected }
            }
            'Enter'     { $done = $true }
            'Escape'    { $cancelled = $true; $done = $true }
            default {
                if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                    $cancelled = $true; $done = $true
                }
            }
        }
    }
}
finally {
    [Console]::CursorVisible = $true
}

# Move below the menu so subsequent output doesn't overwrite it.
[Console]::SetCursorPosition(0, $items.Count + 5)

if ($cancelled) {
    Write-Host "Cancelled."
    exit 0
}

# --- Delete ----------------------------------------------------------------

$toDelete = @($items | Where-Object { $_.Selected } | Select-Object -ExpandProperty Name)

if (-not $toDelete) {
    Write-Host "No branches selected. Nothing to delete." -ForegroundColor Yellow
    exit 0
}

Write-Host "The following branches will be deleted:" -ForegroundColor Yellow
$toDelete | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

$confirm = Read-Host "Proceed? (y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Cancelled."
    exit 0
}

$flag = if ($Force) { '-D' } else { '-d' }
foreach ($b in $toDelete) {
    git branch $flag $b
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deleted $b" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete $b (use -Force for unmerged branches)" -ForegroundColor Red
    }
}