#!/usr/bin/env bash

###############################################################################
#                                 python                                      #
############################################################################### 
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

# Install latest node and set it as default
pyenv install 3.5.1
pyenv global 3.5.1

# Remove outdated versions from the cellar.
brew cleanup

# ToDo Update
# brew update pyenv
# brew upgrade pyenv-virtualenv
