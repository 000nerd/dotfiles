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

## The `dotfiles` command

    $ dotfiles
    ￫ Usage: dotfiles <command>

    Commands:
        help             This help message
        update           Update packages and pkg managers (OS, brew, npm, yarn)
        clean            Clean up caches (brew, npm, yarn)
        symlinks         Run symlinks script
        brew             Run brew script
        defaults         Run MacOS defaults script
        dock             Run MacOS dock script

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
