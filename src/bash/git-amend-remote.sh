#!/usr/bin/env bash
# Fold all current changes into the last commit and force-push it.
#
# Usage: git amend-remote
git add -A .
git commit --amend --no-edit
git push -f
