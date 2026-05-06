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

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Installing."
    # Use HEAD instead of master
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Load brew for the current session
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -d "$HOME/.linuxbrew" ]; then
        eval "$($HOME/.linuxbrew/bin/brew shellenv)"
    fi
fi

echo -e "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=(
    # flags should pass through the the `brew list check`
    awscli
    bat # cat replacement
    cocoapods
    curl
    eza # ls replacement
    fd # find replacement
    ffmpeg
    fzf
    gh
    git
    git-delta # git diff replacement
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

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done

brew tap homebrew/cask-fonts

# Remove outdated versions from the cellar.
brew cleanup

brew cleanup
