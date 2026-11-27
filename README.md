# Dotfiles

# UNDER CONSTRUCTION

Contains:

1. [System defaults]() and [Dock icons setup]()
2. [Git config with aliases]() and [Git global ignore]()
3. [Packaages and Applications]() and [macOS Defaults]()
4. [Themes]()
5. `ssh-manager` command to manage ssh config hosts and keys, including copy public keys to clipboard, transfer to server and more with autocomplete
6. Packages / CLI (brew, dockutil, mycli, mysql, ncdu, ios-deploy, p7zip, pacvim
   pgcli, postgresql, rclone, redis, tmux, trash, tree, unar, wget, wget, yarn, zsh, zsh-completions)
7. Applications (android-studio, google-chrome, iina, iterm2, microsoft-edge,
   pgadmin4, postman, pycharm, react-native-debugger, rectangle, the-unarchiver, visual-studio-code)

## Install

1.  On fresh installation of MacOS:

        sudo softwareupdate -i -a
        xcode-select --install

2.  Download HomeBrew:

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        export PATH=/opt/homebrew/bin:$PATH
        export PATH=/opt/homebrew/sbin:$PATH

4.  Clone and install dotfiles:

        git clone https://github.com/21stBam/dotfiles.git ~/.dotfiles
        cd ~/.dotfiles
        chmod +x install.sh
        ./install.sh

    Useful focused runs:

        ./install.sh --dry-run
        ./install.sh --profile personal
        ./install.sh --only symlinks
        ./install.sh --skip macos
        ./install.sh --profile personal --dry-run --only symlinks,brew

    Safe local test for the macOS path:

        ./tests/test_macos_logic.sh

    Safe local test for the theme switcher:

        ./tests/test_theme_logic.sh

    End-to-end macOS smoke test in a Tart VM:

        brew install cirruslabs/cli/tart cirruslabs/cli/sshpass
        ./tests/smoke/tart.sh --fresh --profile personal --only symlinks,brew,macos --skip-casks

    The full personal lane is also available when you have enough guest disk for
    language toolchains and GUI apps:

        ./tests/smoke/tart.sh --fresh --profile personal --disk-size 150

## The `dotfiles` command

    $ dotfiles
    ￫ Usage: dotfiles <command>

    Commands:
        help             This help message
        update           Update packages and pkg managers (use: dotfiles update run)
        clean            Clean up caches (use: dotfiles clean run)
        doctor           Check dotfiles health (use: dotfiles doctor run)
        install          Run installer; passes through installer options
        theme            List, inspect, and apply theme profiles
        editors          Apply or check shared VS Code and Zed settings
        backup           Run backup script (use: dotfiles backup run)
        symlinks         Run symlinks script (use: dotfiles symlinks run)
        brew             Run brew script (use: dotfiles brew run)
        macos            List, audit, apply, or toggle macOS defaults
        java             Run java script (use: dotfiles java run)
        javascript       Run javascript script (use: dotfiles javascript run)
        python           Run python script (use: dotfiles python run)

    Bare subcommands show help:

        dotfiles macos
        dotfiles brew
        dotfiles doctor

## macOS defaults

Every intentional macOS `defaults write` is classified in
`install/macos/defaults`. The personal registry manages verified non-default
differences and reviewed intentional customizations. Matching defaults and
uncertain values are left unmanaged. Work uses the separate common
and work declarations.

    dotfiles macos list --profile personal
    dotfiles macos audit --profile personal
    dotfiles macos run --profile personal
    dotfiles macos list --profile work
    dotfiles macos toggle hidden-files on
    dotfiles macos toggle desktop-icons off

`list` and `audit` are read-only. Audit exits non-zero when a setting is
missing or has drifted. See `install/macos/defaults/README.md` for the capture and
classification workflow.

## Personal profile

`install/profiles/personal.env` is the default place for machine bootstrap preferences that should be reusable but still personal. For example, set `DOTFILES_COMPUTER_NAME` there to avoid the macOS computer-name prompt on a fresh machine.

Keep secrets and machine-only overrides in `~/.local.zsh`; it is sourced by `.zshrc` and should not be committed.

## Theme profiles

Theme profiles live in `config/themes/profiles`.

Available profiles:

- `gruvbox`
- `gruvbox-material`
- `everforest`

    dotfiles theme list
    dotfiles theme current
    dotfiles theme apply gruvbox --dry-run
    dotfiles theme apply gruvbox-material --dry-run
    dotfiles theme apply everforest --dry-run
    dotfiles theme apply gruvbox
    dotfiles theme apply gruvbox --apps codex,vscode,obsidian
    dotfiles theme apply everforest --apps iterm,zsh

Supported targets:

- Codex: updates appearance keys under `[desktop]` in `${CODEX_HOME:-~/.codex}/config.toml` through the Codex CLI's native configuration writer. Code fonts come from the shared editor policy.
- VS Code: updates `workbench.colorTheme` in the user settings file and warns about missing extensions.
- Obsidian: updates configured vault `.obsidian/appearance.json` and warns when the CSS theme is not installed.
- iTerm and Terminal: imports the configured color files.
- zsh: points `${XDG_STATE_HOME:-~/.local/state}/dotfiles/current-theme.zsh` at the selected prompt theme.

Use `--install-missing` if you want supported editor extensions installed automatically. Without it, the command only reports what is missing.

### Matching the iTerm font in Codex

The font source is `config/editors/policy.json`: `shared.font_family` and
`shared.font_fallbacks` supply the family for Codex, VS Code, and Zed.
`shared.terminal_font_size` supplies Codex's code size (**12**); `shared.font_size`
keeps the editor buffer size at **15**. The current family is **BlexMono Nerd Font
Mono**, installed by the `font-blex-mono-nerd-font` Homebrew cask.

```sh
dotfiles theme apply gruvbox --apps codex --dry-run
dotfiles theme apply gruvbox --apps codex
```

Every Codex theme application derives the light and dark code font from that
policy, including after switching to `gruvbox-material` or `everforest`. The
script clears a previously selected code face so a bold/italic override cannot
replace the regular family. It preserves UI/prose font choices and unrelated
settings. Use **Settings → Appearance → UI font** separately if you want the
interface to use the same family too.

The installed app stores these settings in `[desktop]` in `config.toml`, rather
than the old `.codex-global-state.json`. The command requires the Codex CLI on
`PATH`; set `DOTFILES_CODEX_CLI` to its executable path for another installation.
`CODEX_HOME` selects another Codex home. The former `DOTFILES_CODEX_STATE_PATH`
override is no longer used. Dry-run prints planned settings without starting
Codex or writing files. Apply uses native `config/read` and `config/batchWrite`,
backs up the config before changes as `config.toml.bak.<timestamp>`, checks its
version to catch concurrent setting changes, and verifies the effective values
afterward. Matching settings are left untouched. A failure returns nonzero and
does not record the theme as successfully applied. Restart the app if its
appearance has not refreshed. This reapplies the policy when the theme command
runs; it does not install a background watcher.

iTerm's current Default profile uses **BlexMono Nerd Font Mono Regular, 12 pt**
(`Normal Font = BlexMonoNFM 12`), matching this policy. Its horizontal and vertical
spacing are **1.0**, with the separate non-ASCII font disabled. The iTerm target
imports colors only: its font remains a profile preference under **Settings →
Profiles → Text**. If you change the shared font or terminal size, update that
iTerm preference to match. Codex and iTerm can render the same numeric size
slightly differently because their layout and scaling differ.

References: [Appearance settings](https://learn.chatgpt.com/docs/reference/settings#appearance),
[native config RPC](https://learn.chatgpt.com/docs/app-server#config-rpc-examples-for-app-settings).

## The `ssh-manager` command

    $ ssh-manager
    ￫ Usage: ssh-manager <command>

    Commands:
        help             This help message
        list             List of all SSH keys and hosts in SSH config
        list-keys        List of all SSH keys
        list-host        List of all hosts in SSH config
        copy             Copy public SSH key
        new              Generate new SSH key
        host             Add host to SSH config, use --key to generate new key
        remove           Remove host from SSH config

<!--
credits:
https://github.com/mihaliak/dotfiles
https://github.com/nicknisi/dotfiles

Outbount Network Firewall
Little Snitch(Paid) or Lulu(free) Look at other Objective-see applications
Block Malicious Domain Names
 -->

## Repository layout

| Directory | Contents |
| --- | --- |
| `config/` | Zsh, Git, SSH, editor settings, and theme assets |
| `install/` | Installers, package declarations, profiles, backups, and explicit link mappings |
| `bin/` | Everyday commands available on PATH, including `dotfiles` |
| `scripts/` | Tools used to manage editors, themes, preferences, and setup inventories |
| `assets/wallpapers/` | Wallpaper images |
| `tests/` | Isolated Python/shell tests, VM smoke tests, and Docker test setup |
| `docs/` | [Testing](docs/testing.md), [editors](docs/editors.md), and [themes](docs/themes.md) |

`install/links.tsv` lists each checkout source and its destination relative to
`$HOME`. Installation, backups, doctor, and setup inventory share this list.
Adding a directory under `config/` does not automatically install it. Editor
settings are merged with `dotfiles editors apply`; themes use `dotfiles theme apply`.

Generated files stay outside the checkout. VM logs and reference captures use
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/`; theme selections and persistent baselines
use `${XDG_STATE_HOME:-~/.local/state}/dotfiles/`. Existing backup overrides remain
supported. Keep local machine settings and secrets outside the repository.

On another machine, pull this layout and run `./install.sh --only symlinks` to
update existing links to their new sources. Restart the shell afterward.

## Reproducibility checks

Run `bash scripts/check.sh` for the isolated regression suite. Capture the
current machine with `python3 scripts/setup-state.py capture --output
"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/baselines/current-mac.json"`. This records an observed baseline without
applying installer settings. See [docs/testing.md](docs/testing.md#9-regression-suite-and-observed-machine-baseline)
for complete inventory verification, fresh Tart tests, exact source exports,
baseline comparisons, and post-reboot checks.

Commands you run directly live in `bin/`; supporting tools live in `scripts/`. Open a new terminal or run
`exec zsh -l` after changing the checkout so PATH uses the canonical directory.
Python environments and CLI tools use uv. `python` resolves to the Homebrew
Python 3 executable; Node defaults to the latest LTS through nvm.

## Shared editor configuration

VS Code and Zed share a policy in `config/editors/policy.json`, with portable editor-specific
settings in `config/editors/vscode.json` and `config/editors/zed.json`. `config/editors/extensions.json`
contains the complete local extension inventories (26 VS Code and 10 Zed extensions
at capture time), including the themes and language formatters. Install VS Code,
Zed, and the BlexMono Nerd Font first; the macOS Homebrew inventory includes them.
Then, on each Mac or Linux device:

```sh
git -C ~/.dotfiles pull --ff-only
~/.dotfiles/bin/dotfiles editors apply --dry-run
~/.dotfiles/bin/dotfiles editors apply
# Launch/restart Zed so its full auto_install_extensions list is installed.
~/.dotfiles/bin/dotfiles editors check
```

`apply` merges managed settings into existing files, backs up changed files,
installs missing VS Code extensions, and declares every required Zed extension for
its supported auto-installer. It retains unrelated settings and extra extensions.
Zed additions can remain pending until it starts; `apply` exits nonzero while
required extensions, the configured font, or other checked requirements are missing.
No editor is restarted and no unknown extension is removed. Semantically unchanged
settings keep their comments and timestamps; rewritten JSONC becomes formatted JSON,
with the original bytes preserved in the backup.

`check` is read-only: it reads extension registries directly (no editor CLI or
network request), checks managed settings, required extension presence and global
VS Code enablement, the configured font's installed filenames, and an explicit JDK
path if present. It does not test live language servers or project overrides.
Normal extension updates are reported as notes; use `check --exact-versions` to
fail on differences from the recorded extension versions. `apply` installs current
compatible releases, not the recorded versions. Extra extensions are reported but
not treated as failures. VS Code profiles and remote/container extensions are outside
this default-profile inventory; see [docs/editors.md](docs/editors.md).

Use `--editor vscode` or `--editor zed` for devices with only one editor. Use
`apply --settings-only` to avoid VS Code downloads, and `render` to inspect generated
settings without applying them. Backups are written under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/editors/backups/`.

Machine-only settings belong in `~/.config/dotfiles/editors.local.json` (or beneath
`$XDG_CONFIG_HOME`). Copy `config/editors/local.example.json` there and replace the example
JDK path with the one on that device. Local overrides win in both apply and check;
existing unmanaged machine settings are preserved. No machine's absolute JDK path
is committed. Keep VS Code Settings Sync from independently managing the same
settings, or expect `check` to report changes made by Sync. This command does not
change your Sync account or preferences.

Edit the policy once, commit and push the intended files, then pull and run apply/check
on each device. Git pull alone does not apply settings. `dotfiles theme apply` can
change managed appearance fields; edit the editor policy for a persistent shared
default or reapply it to return to the declared editor theme. Project formatting
rules and pinned tool versions still belong in each repository, for example
`.editorconfig`, Prettier plus its lockfile, `pyproject.toml`, and `.swift-format`.
