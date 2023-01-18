# Dotfiles

# UNDER CONSTRUCTION

Contains:

1. [System defaults]() and [Dock icons setup]()
2. [Git config with aliases]() and [Git global ignore]()
3. [Packaages and Applications]() and [macOS Defaults]()
4. [Themes]()
5. []()
6. `ssh-manager` command to manage ssh config hosts and keys, including copy public keys to clipboard, transfer to server and more with autocomplete
<!-- 9. Packages / CLI (brew, brew cask, dockutil, htop, iftop, openssl, tig, composer, httpie, nmap, php71, git, subversion, node, python3, thefuck, wget, yarn, zsh, zsh-completions)
7. Applications () -->

## Install

On fresh installation of MacOS:

    sudo softwareupdate -i -a
    xcode-select --install

Download HomeBrew:
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master install.sh | bash --login

Clone and install dotfiles:

    git clone https://github.com/21stBam/dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    chmod +wx setup.sh
    chmod -R +wx ~/dotfiles/bin
    ./setup.sh

## Additional steps

1. Install fonts
2. Import Intellij/Xcode/PyCharm/VSCode settings
3. `sudo reboot`
4. Enjoy

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
https://github.com/mathiasbynens/dotfiles
https://github.com/nicknisi/dotfiles
https://github.com/0xadada/dotfiles


TODOs:

Sheldon Plugin Manager
https://github.com/denysdovhan/dotfiles

Outbount Network Firewall
Little Snitch(Paid) or Lulu(free) Look at other Objective-see applications
Block Malicious Domain Names
 -->
