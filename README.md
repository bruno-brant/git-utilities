# git-utilities

A collection of PowerShell git helper scripts.

## git-config-email.ps1

Sets `git config user.name` / `user.email` for the current repo, with tab
completion for names/emails you've used before.

Completions are sourced from `~/.git-config-email.json`, a file in your home
directory (machine-specific, never checked in).

- `./git-config-email.ps1 -Init` — creates `~/.git-config-email.json` if it
  doesn't already exist.
- `./git-config-email.ps1 -UserName "..." -Email "..."` — sets the git config.
- `./git-config-email.ps1 -UserName "..." -Email "..." -Save` — sets the git
  config and also saves the name/email into `~/.git-config-email.json` so
  they show up in future tab completions.
