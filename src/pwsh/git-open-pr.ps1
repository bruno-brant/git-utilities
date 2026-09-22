#!/usr/bin/env pwsh
# Get the current branch name
$currentBranch = git rev-parse --abbrev-ref HEAD

# Get the remote URL
$remoteUrl = git config --get remote.origin.url

# Extract organization, project and repository from Azure DevOps URL
if ($remoteUrl -match "dev\.azure\.com/(?<org>[^/]+)/(?<project>[^/]+)/_git/(?<repo>[^/]+)") {
    $organization = $matches.org
    $project = $matches.project
    $repository = $matches.repo
} elseif ($remoteUrl -match "(?<org>[^/]+)\.visualstudio\.com(?:/DefaultCollection)?/(?<project>[^/]+)/_git/(?<repo>[^/]+)") {
    $organization = $matches.org  
    $project = $matches.project
    $repository = $matches.repo
} else {
    Write-Error "Could not parse Azure DevOps URL"
    exit 1
}

# Construct the pull request URL
$prUrl = "https://dev.azure.com/$organization/$project/_git/$repository/pullrequestcreate?sourceRef=$currentBranch"

# Open URL in default browser
Start-Process $prUrl
