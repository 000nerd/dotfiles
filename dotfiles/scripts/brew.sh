#!/bin/bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Taps
brew tap thoughtbot/formulae

# Installs
brew install 'ccat'
brew install 'coreutils'
brew install 'git'
brew install 'mas'
brew install 'node'
brew install 'rcm'
brew install 'reattach-to-user-namespace'
brew install 'the_silver_searcher'
brew install 'tmux'
brew install 'trash'
brew install 'vim'
brew install 'watchman'
brew install 'zsh'

# Casks
brew cask install 'atom'
brew cask install 'keybase'
brew cask install 'dropbox'
brew cask install 'enpass'
brew cask install 'opera'
brew cask install 'iterm2'
brew cask install 'microsoft-office'
brew cask install 'viscosity'

# Mas
# mas install 824183456
# mas install 824171161
