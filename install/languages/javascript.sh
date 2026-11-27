#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages.sh"

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

retry() {
    local attempt
    local max_attempts=3

    for attempt in $(seq 1 "$max_attempts"); do
        if "$@"; then
            return 0
        fi
        if [ "$attempt" -lt "$max_attempts" ]; then
            echo "Command failed; retrying ($attempt/$max_attempts): $*"
            sleep $((attempt * 10))
        fi
    done

    return 1
}

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
    # shellcheck disable=SC1091
    [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
elif [ "$(uname)" == "Linux" ]; then
    # Homebrew on Linux usually installs to /home/linuxbrew/.linuxbrew
    BREW_PREFIX=$(brew --prefix)
    # shellcheck disable=SC1091
    [ -s "$BREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$BREW_PREFIX/opt/nvm/nvm.sh"
fi

# Choose supported versions explicitly; old versions are opt-in.
node_versions=()
read -r -a node_versions <<< "${DOTFILES_NODE_VERSIONS:-lts/*}"
node_default=${DOTFILES_NODE_DEFAULT:-${node_versions[0]}}
if command -v nvm > /dev/null; then
    for node_version in "${node_versions[@]}"; do
        if [ "$node_version" = 'lts/*' ]; then
            retry nvm install --lts
        else
            retry nvm install "$node_version"
        fi
    done
    nvm alias default "$node_default"
    nvm use default
else
    echo "nvm command not found; JavaScript installation failed." >&2
    exit 1
fi

packages=("${DOTFILES_NPM_PACKAGES[@]}")

if command -v npm > /dev/null; then
    for package in "${packages[@]}"; do
        retry npm install -g "$package"
    done
    # Update npm
    retry npm install -g npm@latest
fi

# Remove outdated versions from the cellar.
brew cleanup
