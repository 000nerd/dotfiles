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
nvm install node  # Didn't work on first go
nvm use node      # Didn't work on first go
nvm alias default node # Didn't work on first go

# Globally install with npm

packages=(
    nodemon
    vtop
    typescript
)
for package in "${packages[@]}"; do
	npm install -g "${packages[@]}"  #Didn't work on first go
done

# Update npm
npm install -g npm@latest # Didn't work on first Go.

# Remove outdated versions from the cellar.
brew cleanup