# Dotfiles
# UNDER CONSTRUCTION

Contains:
  1. [System defaults]() and [Dock icons setup]()
  2. [Git config with aliases](), [Git global ignore]()
  3. [Bash settings]()
  4. []()
  5. []()
  6. Custom [/etc/hosts](https://github.com/mihaliak/dotfiles/blob/master/etc/hosts) file with blocked Ads, Trackers & 🔥 stuff on internet
  8. `ssh-manager` command to manage ssh config hosts and keys, including copy public keys to clipboard, transfer to server and more with autocomplete
  <!-- 9. Packages / CLI (brew, brew cask, dockutil, htop, iftop, openssl, tig, composer, httpie, nmap, php71, git, subversion, node, python3, thefuck, wget, yarn, zsh, zsh-completions)
  10. Applications (alfred, google-chrome, slack, spotify, sublime-text, vlc, phpstorm, sequel-pro, filezilla, postman, iterm2, teamviewer, lastpass, spectacle, appcleaner, skype) -->

## Install

On fresh installation of MacOS:

    sudo softwareupdate -i -a
    xcode-select --install

Clone and install dotfiles:

    git clone https://github.com/SouthernBlackNerd/dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    chmod +wx setup.sh
    chmod -R +wx ~/dotfiles/bin
    ./setup.sh

## Additional steps

1. Install fonts
3. Import Intellij/Xcode/PyCharm/VSCode settings
4. `sudo reboot`
5. Enjoy

## The `dotfiles` command

    $ dotfiles
    ￫ Usage: dotfiles <command>

    Commands:
        help             This help message
        update           Update packages and pkg managers (OS, brew, npm, yarn, commposer)
        clean            Clean up caches (brew, npm, yarn, composer)
        symlinks         Run symlinks script
        brew             Run brew script
        homestead        Run homestead script
        valet            Run valet script
        ohmyzsh          Run oh my zsh script
        hosts            Run hosts script
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
 -->


*TODO :Fixes needed to be made *
 1) Mapping Trackpad for Right Click
 2) Changing UI to Dark theme
 5) Update just the most recent for android sdk. do not need all the API levels
