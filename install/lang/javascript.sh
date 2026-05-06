#!/usr/bin/env bash
set -euxo pipefail

#     $$$$$\  $$$$$$\  $$\    $$\  $$$$$$\   $$$$$$\   $$$$$$\  $$$$$$$\  $$$$$$\ $$$$$$$\ $$$$$$$$\
#     \__$$ |$$  __$$\ $$ |   $$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\ \_$$  _|$$  __$$\\__$$  __|
#        $$ |$$ /  $$ |$$ |   $$ |$$ /  $$ |$$ /  \__|$$ /  \__|$$ |  $$ |  $$ |  $$ |  $$ |  $$ |
#        $$ |$$$$$$$$ |\$$\  $$  |$$$$$$$$ |\$$$$$$\  $$ |      $$$$$$$  |  $$ |  $$$$$$$  |  $$ |
#  $$\   $$ |$$  __$$ | \$$\$$  / $$  __$$ | \____$$\ $$ |      $$  __$$<   $$ |  $$  ____/   $$ |
#  $$ |  $$ |$$ |  $$ |  \$$$  /  $$ |  $$ |$$\   $$ |$$ |  $$\ $$ |  $$ |  $$ |  $$ |        $$ |
#  \$$$$$$  |$$ |  $$ |   \$  /   $$ |  $$ |\$$$$$$  |\$$$$$$  |$$ |  $$ |$$$$$$\ $$ |        $$ |
#   \______/ \__|  \__|    \_/    \__|  \__| \______/  \______/ \__|  \__|\______|\__|        \__|

echo -e "\n\nInstalling JavaScript environment"
echo "=============================="

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Skipping JS environment setup via brew."
    exit 0
fi

# Install nvm for node versions
if ! brew list nvm > /dev/null 2>&1; then
    brew install nvm
fi

if [[ ! -d "$HOME/.nvm" ]]; then
    mkdir -p "$HOME/.nvm"
fi

export NVM_DIR="$HOME/.nvm"

# Load NVM
if [ "$(uname)" == "Darwin" ]; then
    [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
elif [ "$(uname)" == "Linux" ]; then
    # Homebrew on Linux usually installs to /home/linuxbrew/.linuxbrew
    BREW_PREFIX=$(brew --prefix)
    [ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$BREW_PREFIX/opt/nvm/nvm.sh"
fi

# Install latest node and set it as default
if command -v nvm > /dev/null; then
    nvm install 18
    nvm install 20
    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default
else
    echo "nvm command not found. Skipping node installation."
fi

packages=(
    @angular/cli
    @nestjs/cli
    aws-cdk
    eas-cli
    nodemon
    yarn
)

if command -v npm > /dev/null; then
    for package in "${packages[@]}"; do
        npm install -g "$package"
    done
    # Update npm
    npm install -g npm@latest
fi

# Remove outdated versions from the cellar.
brew cleanup
