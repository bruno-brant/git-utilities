#!/usr/bin/env bash
# Rebases the current branch onto an updated trunk (main or master),
# stashing and restoring any local changes around it.
#
# Usage: git update-branch
set -u

should_stash=0
git diff --cached --quiet || should_stash=1
git diff --quiet || should_stash=1

if [ "$should_stash" -eq 1 ]; then
	echo "Stashing changes..."
	git stash --include-untracked
fi

if git branch --format='%(refname:short)' | grep -qx 'master'; then
	trunk=master
elif git branch --format='%(refname:short)' | grep -qx 'main'; then
	trunk=main
else
	echo "Error: No master or main branch found" >&2
	exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)

echo "Updating trunk..."
git checkout "$trunk"
git pull

echo "Rebasing..."
git checkout "$branch"
git rebase "$trunk"

if [ "$should_stash" -eq 1 ]; then
	echo "Popping stash..."
	git stash pop
fi
