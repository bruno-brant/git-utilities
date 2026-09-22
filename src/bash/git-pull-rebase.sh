#!/usr/bin/env bash
# Stash (including untracked), pull with rebase, then restore the stash.
#
# Usage: git pull-rebase
git stash --include-untracked
git pull --rebase
git stash pop
