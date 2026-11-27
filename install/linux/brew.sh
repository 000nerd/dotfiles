#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages.sh"

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
        eval "$("$HOME"/.linuxbrew/bin/brew shellenv)"
    fi
fi

echo -e "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=("${DOTFILES_LINUX_FORMULAS[@]}")

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done


# Remove outdated versions from the cellar.
brew cleanup
