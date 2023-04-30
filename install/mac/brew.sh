#!/usr/bin/env bash
set -euxo pipefail

#  $$$$$$$\  $$$$$$$\  $$$$$$$$\ $$\      $$\
#  $$  __$$\ $$  __$$\ $$  _____|$$ | $\  $$ |
#  $$ |  $$ |$$ |  $$ |$$ |      $$ |$$$\ $$ |
#  $$$$$$$\ |$$$$$$$  |$$$$$\    $$ $$ $$\$$ |
#  $$  __$$\ $$  __$$< $$  __|   $$$$  _$$$$ |
#  $$ |  $$ |$$ |  $$ |$$ |      $$$  / \$$$ |
#  $$$$$$$  |$$ |  $$ |$$$$$$$$\ $$  /   \$$ |
#  \_______/ \__|  \__|\________|\__/     \__|

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Installing."
    # Run as a login shell (non-interactive) so that the script doesn't pause for user input
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login
fi

echo -e "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=(
    # flags should pass through the the `brew list check`
    awscli
    bat # cat replacement
    cocoapods
    curl
    exa # ls replacement
    ffmpeg
    fzf
    gh
    git
    hub
    jq # or use fx
    markdown
    mycli
    mysql
    ncdu
    ios-deploy
    p7zip
    pacvim
    pgcli
    postgresql
    rclone
    redis
    ripgrep
    rmlint
    rsync
    shellcheck
    source-highlight
    streamlink
    tmux
    trash
    tree
    unar
    wget
    youtube-dl
    yt-dlp
    z # cd replacement
    zplug
    zsh-completions
)

cask_formulas=(
    # General Applications
    android-studio
    appcleaner
    devtoys
    dupeguru
    google-chrome
    google-drive
    grandperspective
    handbrake
    iina
    # intellij-idea
    intellij-idea-ce
    iterm2
    maccy
    microsoft-edge
    # microsoft-teams
    # mysqlworkbench
    pgadmin4
    postman
    # pritunl
    pycharm-ce
    react-native-debugger
    rectangle
    the-unarchiver
    # tibco-jaspersoft-studio
    transmission
    visual-studio-code
    vlc
    # Fonts
    font-blex-mono-nerd-font
    font-go-mono-nerd-font
    font-jetbrains-mono-nerd-font
    # QuickLook plugins
    # Source https://github.com/sindresorhus/quick-look-plugins
    syntax-highlight
    suspicious-package
    betterzip
)

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done

brew tap homebrew/cask-fonts

for cask_formula in "${cask_formulas[@]}"; do
    if brew list --cask "$cask_formula" > /dev/null 2>&1; then
        echo "$cask_formula already installed... skipping."
    else
        brew install --cask "$cask_formula"
    fi
done

# Remove outdated versions from the cellar.
brew cleanup
