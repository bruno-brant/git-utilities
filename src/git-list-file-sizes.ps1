#!/usr/bin/env pwsh

function Format-FileSize() {
	Param ([int64]$size)

	If     ($size -gt 1TB) {[string]::Format("{0:0.00} TB", [int][Math]::Round($size / 1TB))}
	ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", [int][Math]::Round($size / 1GB))}
	ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", [int][Math]::Round($size / 1MB))}
	ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} kB", [int][Math]::Round($size / 1KB))}
	ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B",  [int][Math]::Round($size))}
	Else                   {""}
}

$hashes = git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | %{ 
		$s = $_.Split(" ")
			@{ type = $s[0]; id = $s[1]; size = $s[2]; path = $s[3] } 
} 

$hashes = $hashes | %{ New-Object PSObject -Property $_ }

$hashes | where { $_.type -eq "blob" } | Sort-Object {[int]($_.size)} | Format-Table Id, Path, @{Label = "Size"; Expression = {Format-FileSize $_.Size}}
