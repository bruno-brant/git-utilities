#!/usr/bin/env pwsh
param (
	[string] $Remote = "origin"
)

$url = git remote get-url $Remote

start $url
