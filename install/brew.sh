#!/usr/bin/env bash

##############################################################################
#                                  Brew                                      #
##############################################################################

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=(
    # flags should pass through the the `brew list check`
    'macvim --with-override-system-vim'
    bash
    bash-completion
    ack
    diff-so-fancy
    git
    highlight
    markdown
    mongodb # Do not forget to create /data/db and add permissions
    reattach-to-user-namespace
    tmux
    tree
    youtube-dl
    ffmpeg
    maven
)

cask_formulas=(
    # General Applications
    adapter
    appcleaner
    cheatsheet
    chrome-remote-desktop-host
    disk-inventory-x # or Grand Perspective
    dropbox
    dupeguru
    flux
    google-chrome
    handbrake
    iterm2
    libreoffice
    music-manager
    radiant-player
    spotify
    sublime-text
    the-unarchiver
    transmission
    visual-studio-code
    vlc
    veertu-desktop
    wireshark
)


quicklook_formulas=(
    # QuickLook plugins
    # Source https://github.com/sindresorhus/quick-look-plugins
    qlcolorcode
    qlstephen
    qlmarkdown
    quicklook-json
    qlprettypatch
    quicklook-csv
    betterzipql
    suspicious-package
    provisionql
    quicklookapk
    qlvideo
)

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install $formula
    fi
done

#Update Bash
grep "/usr/local/bin/bash" /private/etc/shells &>/dev/null || sudo bash -c "echo /usr/local/bin/bash >> /private/etc/shells"
chsh -s /usr/local/bin/bash

brew tap caskroom/cask

for cask_formula in "${cask_formulas[@]}"; do
    if brew list "$cask_formula" > /dev/null 2>&1; then
        echo "$cask_formula already installed... skipping."
    else
        brew cask install $cask_formula
    fi
done

for quicklook_formula in "${quicklook_formulas[@]}"; do
    if brew list "$quicklook_formula" > /dev/null 2>&1; then
        echo "$quicklook_formula already installed... skipping."
    else
        brew cask install $quicklook_formula
    fi
done

# Remove outdated versions from the cellar.
brew cleanup
