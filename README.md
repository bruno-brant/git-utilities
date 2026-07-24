# git-utilities

A collection of PowerShell git helper scripts that work on macOS, Linux, and
Windows. They run on [PowerShell (`pwsh`)](https://learn.microsoft.com/powershell),
which is cross-platform, and install as native git subcommands so you can call
them like `git config-email` or `git-resolve-all`.

## Install

### Quick install (macOS / Linux)

No clone required — this downloads the latest release, unpacks it, and links the
commands into `~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.sh | sh
```

To pass options, append them after `-s --`, e.g. a custom bin directory:

```sh
curl -fsSL https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.sh | sh -s -- --bin ~/bin
```

You still need `pwsh` installed — the script tells you how if it's missing.

### Homebrew (macOS)

```sh
brew install bruno-brant/tap/git-utilities
```

Homebrew pulls in `pwsh` for you (via the `powershell` cask). On Linux, `pwsh`
isn't available as a brew formula, so install it from Microsoft's package repo
and use the quick-install script above instead.

### Windows

```powershell
irm https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.ps1 | iex
```

Downloads the latest release, unpacks it, generates a `.cmd` shim per command in
`%USERPROFILE%\bin`, and adds it to your user PATH.

### From a checkout (for development)

Clone the repo and run the installer from inside it; it links the commands
straight out of `src/`, so your edits take effect immediately:

```sh
./install.sh          # macOS / Linux
./install.ps1         # Windows
```

Add `--copy` (or `-Copy`) to copy the scripts instead of symlinking them.

## Usage

Once installed and on your PATH, each script works both as a standalone command
and as a git subcommand — `git-config-email` or `git config-email`:

```sh
git config-email -Init
git new-branch my-feature
git worktree-add
```

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

### Conflict resolvers (git-resolve-*)

Helpers for resolving merge/rebase conflicts, one command per conflict type.
Each applies the sensible default for that type to every matching file:

| Command                     | Conflict        | Action                                  |
|-----------------------------|-----------------|-----------------------------------------|
| `git-resolve-bothmodified`  | both modified   | keep theirs (`checkout --theirs` + add) |
| `git-resolve-deletedbyus`   | deleted by us   | keep the file (`git add`)               |
| `git-resolve-deletedbythem` | deleted by them | remove the file (`git rm`)              |
| `git-resolve-addedbythem`   | added by them   | keep the file (`git add`)               |
| `git-resolve-addedbyus`     | added by us     | remove the file (`git rm`)              |
| `git-resolve-bothdeleted`   | both deleted    | remove the file (`git rm`)              |

Two orchestrators build on those:

- `git-resolve-all` — applies every strategy above in one pass.
- `git-resolve-rebase` — repeatedly runs `git-resolve-all` and `git rebase
  --continue` until the rebase finishes or hits a conflict it can't
  auto-resolve.

They all share a single helper, `git-get-fileswithstatus`, which lists the files
in a given conflict state (e.g. `git-get-fileswithstatus "both modified"`). Its
`Status` argument tab-completes and accepts only the six conflict labels.
