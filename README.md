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

## Conflict resolvers (git-resolve-*.ps1)

Helpers for resolving merge/rebase conflicts, one script per conflict type.
Each applies the sensible default for that type to every matching file. Run
them from `src/`, e.g. `./src/git-resolve-all.ps1`.

| Script | Conflict | Action |
| --- | --- | --- |
| `git-resolve-bothmodified.ps1` | both modified | keep theirs (`checkout --theirs` + add) |
| `git-resolve-deletedbyus.ps1` | deleted by us | keep the file (`git add`) |
| `git-resolve-deletedbythem.ps1` | deleted by them | remove the file (`git rm`) |
| `git-resolve-addedbythem.ps1` | added by them | keep the file (`git add`) |
| `git-resolve-addedbyus.ps1` | added by us | remove the file (`git rm`) |
| `git-resolve-bothdeleted.ps1` | both deleted | remove the file (`git rm`) |

Two orchestrators build on those:

- `git-resolve-all.ps1` — applies every strategy above in one pass.
- `git-resolve-rebase.ps1` — repeatedly runs the resolvers and `git rebase
  --continue` until the rebase finishes or hits a conflict it can't
  auto-resolve. (Replaces the old `git-tools.ps1` `Start-Resolve`.)
