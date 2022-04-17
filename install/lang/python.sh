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

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! "$(which brew)"; then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling python enviroment"
echo "=============================="

# Install Python
brew install python
# Install Conda. Will switch to anaconda or miniconda when apple silicon ready
brew install --cask miniforge

packages=(
    black
    coverage[toml]
    flake8
    flake8-bandit
    flake8-black
    flake8-bugbear
    flake8-docstrings
    flake8-import-order
    nox
    poetry
    pytest
    pytest-cov
    pytest-mock
    requests
    streamlink
)

for package in "${packages[@]}"; do
	pip install --upgrade "$package"
done

# Remove outdated versions from the cellar.
brew cleanup
