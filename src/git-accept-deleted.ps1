#!/usr/bin/env pwsh
git status | Select-String "deleted by us" | ForEach-Object { 
	$_.ToString().Replace("deleted by us:", "") 
} | ForEach-Object { 
	$_.ToString().Trim() 
} | Where-Object { 
	$_.Length -ne 0 
} | ForEach-Object { 
	git rm $_ 
}
