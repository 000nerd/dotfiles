# Setup and customization

[Back to README](../README.md)

Run examples from `~/.dotfiles`. Use `./bin/dotfiles` instead of `dotfiles` until
the repository's `bin/` directory is on your shell's `PATH`.

## Prerequisites

- Bash, Git, and curl for bootstrap scripts.
- Zsh for the managed shell configuration.
- Python 3 for editor/theme commands, inventories, and tests.
- On macOS, the Xcode Command Line Tools. Install them with `xcode-select --install`
  if they are absent, then finish the installation before continuing.

The `brew` step bootstraps Homebrew when needed. On Linux, prepare Homebrew's
system prerequisites with the distribution's package manager first. The macOS
installer checks both `/opt/homebrew` and `/usr/local`; do not hardcode one prefix
into your shell's `PATH`.

## Install

```sh
git clone https://github.com/000nerd/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh --profile personal --dry-run
./install.sh --profile personal
exec zsh -l
```

The full install changes the machine and can request administrator access.
Review [package declarations](../install/packages.sh),
[personal bootstrap settings](../install/profiles/personal.env), and
[macOS policy](../install/macos/defaults/README.md) before running it.
Editor policy and cross-app themes have separate apply commands described in the
[editor](editors.md) and [theme](themes.md) guides.

The dry-run prints which step scripts would run. It does not inspect package
availability or preview every preference, download, or file change inside them.

| Step | Behavior |
| --- | --- |
| `symlinks` | Install the explicit mappings in `install/links.tsv` |
| `brew` | Install platform packages; on macOS also provision shell plugins and selected GUI/App Store apps |
| `macos` | Apply selected preference declarations and machine setup on macOS |
| `javascript` | Configure nvm/Node and declared npm packages |
| `java` | Install declared Java tools and configure jenv |
| `python` | Install Homebrew Python/uv and declared uv tools |

Select or exclude steps with comma-separated names:

```sh
./install.sh --only symlinks
./install.sh --profile personal --only symlinks,brew
./install.sh --profile personal --skip macos
DOTFILES_INSTALL_CASKS=false ./install.sh --profile personal --only brew
```

`DOTFILES_INSTALL_CASKS=false` skips the macOS GUI cask and App Store install
block. The formula and shell-plugin parts of the `brew` step still run.

## Profiles and machine-specific configuration

`--profile personal` loads `install/profiles/personal.env`. No bootstrap profile
is loaded when `--profile` is omitted. Environment values can override that
file's defaults; explicit `--only`/`--skip` flags take precedence over its step
selection defaults.

The personal bootstrap file declares Node LTS and Java 21 defaults. It also
contains machine-name settings. macOS preference profiles (`common`, `personal`,
`work`) are a separate registry selected by `dotfiles macos ... --profile`.
There is no corresponding `install/profiles/work.env` in this checkout.

| Configuration | Location |
| --- | --- |
| Local shell settings and secrets | `~/.local.zsh` |
| Device-specific editor settings | `${XDG_CONFIG_HOME:-~/.config}/dotfiles/editors.local.json` |
| Local SSH hosts and key paths | `~/.ssh/config.local` |
| Shared editor policy | `config/editors/policy.json` |
| Shared package and tool declarations | `install/packages.sh` |

Shell-local settings are loaded by `.zshrc`; the installer does not source
`~/.local.zsh`. Set installer overrides in the environment or bootstrap profile.
Keep secrets, SSH keys, and device-specific application state outside the checkout.

## Links, backups, and restore

[install/links.tsv](../install/links.tsv) maps repository sources to destinations
relative to `$HOME`. Installation, backup, doctor, and setup inventory read this
same file. The mappings cover `.zshrc`, `.zprofile`, `.gitconfig`,
`.gitignore_global`, and `.ssh/config`.

The link installer moves conflicting files or links to `~/dotfiles-backup/`
before replacing them. Correct links are left alone; backup collisions receive
unique names. `DOTFILES_BACKUP_DIR` selects another backup directory.
`dotfiles backup run` separately copies managed non-symlink files; it skips
missing files and existing symlinks.

```sh
dotfiles backup run
python3 install/restore.py --dry-run
python3 install/restore.py
```

Restore uses `~/dotfiles-backup/`, `DOTFILES_BACKUP_DIR`, or an explicit
`--backup-dir PATH`. It replaces entries present in the backup and merges
directories, preserving unrelated files. Review the backup and dry-run first.
Timestamped collision copies are separate entries; select the intended backup
contents before restoring.

## macOS preferences and App Store apps

```sh
dotfiles macos list --profile personal
dotfiles macos audit --profile personal
dotfiles macos run --profile personal
dotfiles macos toggle hidden-files on
```

`list` and `audit` read the preference registry; `run` also performs the machine
setup in [install/macos/defaults.sh](../install/macos/defaults.sh). See the
[preference policy](../install/macos/defaults/README.md) for its scope and review rules.

Selected App Store apps are declared in `install/packages.sh`. A missing App
Store sign-in or unverified app receipt can leave this step pending: core setup
continues, but the installer exits `2`. Sign in through the App Store, then run:

```sh
dotfiles appstore run
```

The installer does not accept or store Apple Account credentials. Enable Safari
extensions in Safari after installing them.

## Update another device

```sh
git -C "$HOME/.dotfiles" pull --ff-only
cd "$HOME/.dotfiles"
./install.sh --only symlinks
exec zsh -l
```

Git pull updates the source files. Run the relevant installer steps when package
or machine policy changes, and run editor/theme apply commands to update their
settings. Reapply the Zsh theme when migrating an old generated theme link.

## Local state

| Data | Default location |
| --- | --- |
| Link-conflict/manual backups | `~/dotfiles-backup/` |
| Editor settings backups | `${XDG_STATE_HOME:-~/.local/state}/dotfiles/editors/backups/` |
| Selected theme and generated prompt link | `${XDG_STATE_HOME:-~/.local/state}/dotfiles/` |
| Host-side Tart logs | `${XDG_CACHE_HOME:-~/.cache}/dotfiles/tart-smoke/` |
| macOS reference captures | `${XDG_CACHE_HOME:-~/.cache}/dotfiles/defaults-reference/` |
| App Store status | `~/.local/state/dotfiles/appstore-status.json` |

Inventory/baseline commands require an output path; the [testing guide](testing.md)
uses the external state directory. App Store status has its own path selection
and does not automatically follow `XDG_STATE_HOME`.
