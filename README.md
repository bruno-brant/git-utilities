# git-utilities

A collection of PowerShell git helper scripts that work on macOS, Linux, and
Windows. They run on [PowerShell (`pwsh`)](https://learn.microsoft.com/powershell),
which is cross-platform, and install as native git subcommands so you can call
them like `git config-email` or `git worktree-add`.

## Install

**macOS / Linux:**

```sh
./install.sh
```

This symlinks each script into `~/.local/bin` (override with `--bin DIR`) so
edits to the repo take effect immediately. Pass `--copy` to copy instead of
symlink. If `pwsh` isn't installed, the script tells you how to get it; the
utilities need it to run.

**Windows:**

```powershell
./install.ps1
```

This generates a `.cmd` shim for each script in `%USERPROFILE%\bin` (override
with `-BinDir`) and adds that directory to your user PATH.

## Usage

Once installed and on your PATH, the scripts are available as git subcommands
(drop the `git-` prefix and the `.ps1`):

```sh
git config-email -Init
git new-branch my-feature
git worktree-add
```

You can also run most scripts directly from `src/` without installing, e.g.
`./src/git-config-email.ps1 -Init`. The exception is the conflict resolvers
below, which call each other as git subcommands and so need to be installed
first.

### git config-email

Sets `git config user.name` / `user.email` for the current repo, with tab
completion for names/emails you've used before.

Completions are sourced from `~/.git-config-email.json`, a file in your home
directory (machine-specific, never checked in).

- `git config-email -Init` — creates `~/.git-config-email.json` if it doesn't
  already exist.
- `git config-email -UserName "..." -Email "..."` — sets the git config.
- `git config-email -UserName "..." -Email "..." -Save` — sets the git config
  and also saves the name/email into `~/.git-config-email.json` so they show up
  in future tab completions.

### git resolve-* (conflict resolvers)

Helpers for resolving merge/rebase conflicts, one subcommand per conflict type.
Each applies the sensible default for that type to every matching file:

| Command                     | Conflict        | Action                                  |
|-----------------------------|-----------------|-----------------------------------------|
| `git resolve-bothmodified`  | both modified   | keep theirs (`checkout --theirs` + add) |
| `git resolve-deletedbyus`   | deleted by us   | keep the file (`git add`)               |
| `git resolve-deletedbythem` | deleted by them | remove the file (`git rm`)              |
| `git resolve-addedbythem`   | added by them   | keep the file (`git add`)               |
| `git resolve-addedbyus`     | added by us     | remove the file (`git rm`)              |
| `git resolve-bothdeleted`   | both deleted    | remove the file (`git rm`)              |

Two orchestrators build on those:

- `git resolve-all` — applies every strategy above in one pass.
- `git resolve-rebase` — repeatedly runs `resolve-all` and `git rebase
  --continue` until the rebase finishes or hits a conflict it can't
  auto-resolve.

They all share a single helper, `git get-fileswithstatus`, which lists the
files in a given conflict state (e.g. `git get-fileswithstatus "both modified"`).
Its `Status` argument tab-completes and accepts only the six conflict labels.
