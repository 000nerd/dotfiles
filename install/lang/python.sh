#!/usr/bin/env bash
set -euxo pipefail

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

packages=(
    cyberdrop-dl
    streamlink
)

if command -v uv > /dev/null; then
    for package in "${packages[@]}"; do
        uv tool install "$package" || echo "Failed to install $package via uv, continuing..."
    done
fi

# Remove outdated versions from the cellar.
brew cleanup
