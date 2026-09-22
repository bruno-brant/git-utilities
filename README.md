# git-utilities

A collection of git helper scripts that install as native git subcommands, so
you can call them like `git-resolve-all` or `git config-email`.

They ship in **two flavors**, maintained side by side:

| Flavor | Location    | Requires            |
|--------|-------------|---------------------|
| bash   | `src/bash/` | bash (no pwsh)      |
| pwsh   | `src/pwsh/` | [PowerShell](https://learn.microsoft.com/powershell) |

Every command exists in both flavors under the same name — only the extension
differs (`git-resolve-all.sh` / `git-resolve-all.ps1`). Installed, both drop
the extension, so the command is `git-resolve-all` either way.

`install.sh` installs the **bash** flavor by default and `install.ps1` installs
the **pwsh** flavor; either can be overridden.

## Install

### Quick install (macOS / Linux)

No clone and no pwsh required — this downloads the latest release, unpacks it,
and links the bash commands into `~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.sh | sh
```

To pass options, append them after `-s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.sh | sh -s -- --bin ~/bin --flavor pwsh
```

### Windows

```powershell
irm https://raw.githubusercontent.com/bruno-brant/git-utilities/main/install.ps1 | iex
```

Downloads the latest release, generates a `.cmd` shim per command in
`%USERPROFILE%\bin`, and adds it to your user PATH. Use `-Flavor bash` to shim
the bash scripts instead (needs bash on PATH, e.g. from Git for Windows).

### From a checkout (for development)

Run the installer from inside a clone; it links straight out of
`src/<flavor>/`, so your edits take effect immediately:

```sh
./install.sh                  # bash flavor
./install.sh --flavor pwsh    # pwsh flavor
```

Add `--copy` (or `-Copy`) to copy the scripts instead of symlinking them.

## Usage

Once installed and on your PATH, each script works both as a standalone command
and as a git subcommand — `git-config-email` or `git config-email`:

```sh
git config-email --email me@example.com
git new-branch my-feature
git resolve-all
```

> **Flag conventions differ between flavors.** The bash scripts take POSIX-style
> flags (`--email`, `--force`, `--branch`); the pwsh scripts take PowerShell
> parameters (`-Email`, `-Force`, `-BranchName`). Run any command with `--help`
> (bash) or `Get-Help` (pwsh) for its own usage.

### git config-email

Sets `git config user.name` / `user.email` for the current repo, and can
remember identities in `~/.git-config-email.json` (machine-specific, never
checked in).

```sh
git config-email --init                                   # create the file
git config-email --email me@example.com                   # set the config
git config-email --email me@example.com --save            # set and remember
git config-email --name "Some One" --email me@example.com
```

The pwsh flavor takes `-Init`, `-UserName`, `-Email`, `-Save` instead.

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
in a given conflict state (e.g. `git-get-fileswithstatus "both modified"`). It
accepts only the six conflict labels above.

Because the resolvers invoke each other and the helper as git subcommands, they
need to be installed / on your PATH to run.

### git worktree-add

Creates a sibling worktree that mirrors your current working state, replacing
every git-ignored path with a link back to the source repo (so `node_modules`
and friends are one link, not a copy).

The two flavors are **not** literal ports of each other:

- **pwsh** is Windows-specific — it uses `robocopy`, NTFS junctions, and a
  single elevated batch for file symlinks.
- **bash** is the Unix counterpart — `rsync` plus plain symlinks, no elevation.
  Note that git reports a directory *symlink* as a symlink rather than walking
  into it, so a `.gitignore` rule written as `node_modules/` may not match it;
  prefer rules without a trailing slash if you hit that.

## Releases

Pushing a `v*` tag (or dispatching the `release` workflow with a version)
packs both flavors into `git-utilities.tar.gz` and `git-utilities.zip` and
attaches them to a GitHub Release. Both archives contain `bash/` and `pwsh/`
subdirectories, so either installer can pick the flavor it wants.
