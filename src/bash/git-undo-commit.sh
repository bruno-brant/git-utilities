#!/usr/bin/env bash
# Undo the last commit, keeping its changes staged.
#
# Usage: git undo-commit
git reset --soft HEAD^
