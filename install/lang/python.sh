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
brew install python3

brew tap caskroom/versions
brew cask install pycharm-ce
brew cask install anaconda

packages=(
    livestreamer
    peewee
    requests
    bpython
    ptpython
    streamlink
    pylint
    flake8
)
for package in "${packages[@]}"; do
	pip install "${packages[@]}"  #Didn't work on first go
done

# Remove outdated versions from the cellar.
brew cleanup
