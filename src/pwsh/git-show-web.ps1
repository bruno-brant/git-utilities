#!/usr/bin/env pwsh
git remote get-url origin | %{ start $_ }
