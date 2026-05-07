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
7. Applications (android-studio, google-chrome, iina, intellij-idea, iterm2, microsoft-edge,
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
        chmod +wx install.sh
        chmod -R +wx ~/dotfiles/bins
        ./install.sh

    Useful focused runs:

        ./install.sh --dry-run
        ./install.sh --profile personal
        ./install.sh --only symlinks
        ./install.sh --skip macos
        ./install.sh --profile personal --dry-run --only symlinks,brew

    Safe local test for the macOS path:

        ./test_macos_logic.sh

    Safe local test for the theme switcher:

        ./test_theme_logic.sh

## The `dotfiles` command

    $ dotfiles
    ￫ Usage: dotfiles <command>

    Commands:
        help             This help message
        update           Update packages and pkg managers (OS, brew, npm, yarn)
        clean            Clean up caches (brew, npm, yarn)
        doctor           Check dotfiles health
        install          Run installer; passes through installer options
        theme            List, inspect, and apply theme profiles
        symlinks         Run symlinks script
        brew             Run brew script
        macos            Run MacOS defaults script
        java             Run java script
        javascript       Run javascript script
        python           Run python script

## Personal profile

`install/profiles/personal.env` is the default place for machine bootstrap preferences that should be reusable but still personal. For example, set `DOTFILES_COMPUTER_NAME` there to avoid the macOS computer-name prompt on a fresh machine.

Keep secrets and machine-only overrides in `~/.local.zsh`; it is sourced by `.zshrc` and should not be committed.

## Theme profiles

Theme profiles live in `themes/profiles`.

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

- Codex: updates only appearance keys in `~/.codex/.codex-global-state.json`.
- VS Code: updates `workbench.colorTheme` in the user settings file and warns about missing extensions.
- IntelliJ / JetBrains IDEs: copies the selected `.icls` scheme into discovered JetBrains `colors` directories.
- Obsidian: updates configured vault `.obsidian/appearance.json` and warns when the CSS theme is not installed.
- iTerm and Terminal: imports the configured color files.
- zsh: points `zsh/zsh/current-theme.zsh` at the selected prompt theme.

Use `--install-missing` if you want supported editor extensions installed automatically. Without it, the command only reports what is missing.

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
