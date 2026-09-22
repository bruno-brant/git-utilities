#!/usr/bin/env bash
# Resolves every conflicted file using the per-type default strategy, by
# running each git-resolve-* command in turn. Relies on those commands being
# on your PATH (installed via install.sh).
#
# Usage: git resolve-all
git resolve-bothmodified
git resolve-deletedbyus
git resolve-deletedbythem
git resolve-addedbythem
git resolve-bothdeleted
git resolve-addedbyus
