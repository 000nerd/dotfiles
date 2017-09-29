#!/usr/bin/env bash

###############################################################################
#                                 python                                      #
###############################################################################

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling python enviroment"
echo "=============================="
brew update
# Install pyenv for python versions
brew install pyenv
brew install pyenv-virtualenv

brew tap caskroom/versions
brew cask install pycharm-ce

############################################
# FAILED AFTER THIS POINT                  #
############################################

# Install latest node and set it as default
pyenv install 3.6.0
pyenv global 3.6.0

# Remove outdated versions from the cellar.
brew cleanup

# ToDo Update
# brew update pyenv
# brew upgrade pyenv-virtualenv
