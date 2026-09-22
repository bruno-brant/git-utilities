#!/usr/bin/env bash
# Opens the Azure DevOps "create pull request" page for the current branch.
#
# Usage: git open-pr
set -u

branch=$(git rev-parse --abbrev-ref HEAD) || exit 1
remote=$(git config --get remote.origin.url) || exit 1

if [[ $remote =~ dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+) ]]; then
	org="${BASH_REMATCH[1]}"
	project="${BASH_REMATCH[2]}"
	repo="${BASH_REMATCH[3]}"
elif [[ $remote =~ ([^/@.]+)\.visualstudio\.com(/DefaultCollection)?/([^/]+)/_git/([^/]+) ]]; then
	org="${BASH_REMATCH[1]}"
	project="${BASH_REMATCH[3]}"
	repo="${BASH_REMATCH[4]}"
else
	echo "Could not parse Azure DevOps URL: $remote" >&2
	exit 1
fi

url="https://dev.azure.com/$org/$project/_git/$repo/pullrequestcreate?sourceRef=$branch"

if command -v xdg-open >/dev/null 2>&1; then
	xdg-open "$url"
elif command -v open >/dev/null 2>&1; then
	open "$url"
else
	echo "$url"
fi
