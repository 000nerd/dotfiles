#!/usr/bin/env bash

# Shared package inventory. Sourcing this file never installs anything.

DOTFILES_MAC_FORMULAS=(
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
    mas
    mycli
    mysql
    ncdu
    ios-deploy
    p7zip
    pacvim
    pgcli
    postgresql
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
    yt-dlp
    z # cd replacement
    zplug
    zsh-completions
)

DOTFILES_MAC_CASKS=(
    # General Applications
    android-studio
    appcleaner
    chatgpt
    devtoys
    # dupeguru: disabled by Homebrew (Gatekeeper failure, 2026-09-01).
    google-chrome
    google-drive
    grandperspective
    handbrake-app
    iina
    iterm2
    maccy
    memory-meter-3
    microsoft-edge
    obsidian
    # microsoft-teams
    # mysqlworkbench
    pgadmin4
    postman
    # pritunl
    pycharm
    react-native-debugger
    rectangle
    the-unarchiver
    # tibco-jaspersoft-studio
    transmission
    visual-studio-code
    zed
    windows-app
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

DOTFILES_LINUX_FORMULAS=(
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
    yt-dlp
    z # cd replacement
    zplug
    zsh-completions
)

DOTFILES_JAVA_FORMULAS=(
    # install java and android dev tools
    gradle
    jenv
    maven
    openjdk@17
    openjdk@21
)

DOTFILES_NPM_PACKAGES=(
    @angular/cli
    @nestjs/cli
    aws-cdk
    eas-cli
    nodemon
    yarn
)

DOTFILES_UV_TOOLS=(
    cyberdrop-dl
    streamlink
)

DOTFILES_MAC_APP_STORE_APPS=(
    '6745342698|uBlock Origin Lite.app|net.raymondhill.uBlock-Origin-Lite'
)

dotfiles_appstore_manifest() {
    local item
    for item in "${DOTFILES_MAC_APP_STORE_APPS[@]}"; do
        printf '%s\n' "$item"
    done
}

dotfiles_package_manifest() {
    local platform="${1:-$(uname)}" name
    if [ "$platform" = Darwin ]; then
        for name in "${DOTFILES_MAC_FORMULAS[@]}"; do printf 'brew\tformula\t%s\n' "$name"; done
        for name in "${DOTFILES_MAC_CASKS[@]}"; do printf 'brew\tcask\t%s\n' "$name"; done
        for name in "${DOTFILES_MAC_APP_STORE_APPS[@]}"; do printf 'brew\tmas-app\t%s\n' "${name%%|*}"; done
    elif [ "$platform" = Linux ]; then
        for name in "${DOTFILES_LINUX_FORMULAS[@]}"; do printf 'brew\tformula\t%s\n' "$name"; done
    else
        echo "Unsupported package platform: $platform" >&2
        return 1
    fi
    for name in "${DOTFILES_JAVA_FORMULAS[@]}"; do printf 'java\tformula\t%s\n' "$name"; done
    printf 'javascript\tformula\tnvm\n'
    for name in "${DOTFILES_NPM_PACKAGES[@]}"; do printf 'javascript\tnpm\t%s\n' "$name"; done
    printf 'python\tformula\tpython\npython\tformula\tuv\n'
    for name in "${DOTFILES_UV_TOOLS[@]}"; do printf 'python\tuv-tool\t%s\n' "$name"; done
}
