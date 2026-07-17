#!/usr/bin/env pwsh
param (
	[string] $name
)

git checkout -b "u/brunobr/$name"
