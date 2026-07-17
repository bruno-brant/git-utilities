#!/usr/bin/env pwsh
git stash --include-untracked
git pull --rebase
git stash pop
