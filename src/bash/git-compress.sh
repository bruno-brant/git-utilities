#!/usr/bin/env bash
# Aggressively repack the repository, dropping all reflog history first.
#
# Usage: git compress
git reflog expire --expire=now --all
git gc --prune=now --aggressive
