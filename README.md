# Dotfiles

Personal Zsh, Git, SSH, editor, and theme configuration, with setup tools for
macOS and Linux. macOS also has package, application, and system-preference setup.

## Get started

Clone into `~/.dotfiles`; shell configuration expects that location.

```sh
git clone https://github.com/000nerd/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
./install.sh --profile personal --dry-run
```

Review [setup and customization](docs/setup.md) before applying the full installer.
To install just the managed links:

```sh
./install.sh --only symlinks
exec zsh -l
```

The full installer can install packages and change macOS preferences. Its dry-run
lists selected scripts; it does not simulate each script's individual changes.

## Common commands

After reloading Zsh, `bin/` is on `PATH` and the `dotfiles` command is available.
Use `./bin/dotfiles` from the repository root before reloading.

| Command | Purpose |
| --- | --- |
| `dotfiles doctor run` | Check expected directories, tools, and managed links |
| `dotfiles install --help` | Show installer steps and options |
| `dotfiles editors apply --dry-run` | Preview shared VS Code/Zed configuration |
| `dotfiles editors check` | Check managed editor settings and requirements |
| `dotfiles theme list` | List bundled theme profiles |
| `dotfiles theme apply gruvbox --apps zsh --dry-run` | Preview a shell theme change |
| `dotfiles macos list --profile personal` | List managed macOS preferences |
| `dotfiles macos audit --profile personal` | Compare those preferences with this Mac |
| `dotfiles backup run` | Copy managed non-symlink files into the backup directory |
| `dotfiles update run` | Update configured package managers and runtimes |
| `dotfiles clean run` | Clean Homebrew and npm caches |

Run `dotfiles help` for all subcommands and `dotfiles <command> --help` for details.
Action-only subcommands require `run`; invoking them without it displays help.

## Documentation

- [Setup](docs/setup.md): prerequisites, installation, profiles, links, backups,
  updates, and local state.
- [Editors](docs/editors.md): shared settings, extensions, device overrides, and
  formatting policy.
- [Themes](docs/themes.md): supported targets, fonts, shell prompts, and imports.
- [Testing](docs/testing.md): local checks, setup inventories, Docker, and Tart.
- [macOS preference policy](install/macos/defaults/README.md): managed defaults and
  the capture/review workflow.

## Repository layout

| Directory | Contents |
| --- | --- |
| `config/` | Zsh, Git, SSH, editor declarations, and theme assets |
| `install/` | Installers, package lists, profiles, link mappings, backup/restore |
| `bin/` | Commands available on `PATH` |
| `scripts/` | Editor, theme, preference, and inventory tools |
| `assets/wallpapers/` | Wallpaper images |
| `tests/` | Regression checks, Docker setup, and VM smoke tests |
| `docs/` | Usage and maintenance guides |

Package lists live in [install/packages.sh](install/packages.sh). Link mappings
live in [install/links.tsv](install/links.tsv). Adding a folder under `config/`
does not automatically install it.

## Development

```sh
bash scripts/check.sh
```

This runs syntax checks and isolated regression tests. See [testing](docs/testing.md)
for prerequisites, optional native integration cases, and full-install validation.

[MIT license](LICENSE).
