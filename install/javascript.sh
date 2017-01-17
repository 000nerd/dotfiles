#!/usr/bin/env bash

###############################################################################
#                               JavaScript                                    #
############################################################################### 

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling JavaScript enviroment"
echo "=============================="

# Install nvm for node versions
brew install nvm

mkdir ~/.nvm

# Install latest node and set it as default
nvm install node
nvm use node
nvm alias default node

# Globally install with npm

packages=(
    nodemon
    vtop
    typescript
)

npm install -g "${packages[@]}"

# Update npm
npm install -g npm@latest

# Remove outdated versions from the cellar.
brew cleanup