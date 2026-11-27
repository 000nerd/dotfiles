#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages.sh"

#  $$$$$$$\ $$\     $$\ $$$$$$$$\ $$\   $$\  $$$$$$\  $$\   $$\
#  $$  __$$\\$$\   $$  |\__$$  __|$$ |  $$ |$$  __$$\ $$$\  $$ |
#  $$ |  $$ |\$$\ $$  /    $$ |   $$ |  $$ |$$ /  $$ |$$$$\ $$ |
#  $$$$$$$  | \$$$$  /     $$ |   $$$$$$$$ |$$ |  $$ |$$ $$\$$ |
#  $$  ____/   \$$  /      $$ |   $$  __$$ |$$ |  $$ |$$ \$$$$ |
#  $$ |         $$ |       $$ |   $$ |  $$ |$$ |  $$ |$$ |\$$$ |
#  $$ |         $$ |       $$ |   $$ |  $$ | $$$$$$  |$$ | \$$ |
#  \__|         \__|       \__|   \__|  \__| \______/ \__|  \__|

echo -e "\n\nInstalling python environment"
echo "=============================="

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Skipping Python environment setup via brew."
    exit 0
fi

# Install Python
if ! brew list python > /dev/null 2>&1; then
    brew install python
fi

# Install uv
if ! brew list uv > /dev/null 2>&1; then
    brew install uv
fi

packages=("${DOTFILES_UV_TOOLS[@]}")

if command -v uv > /dev/null; then
    for package in "${packages[@]}"; do
        uv tool install "$package"
    done
fi

# Remove outdated versions from the cellar.
brew cleanup
