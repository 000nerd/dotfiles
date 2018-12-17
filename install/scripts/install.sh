#!/bin/bash

# suppress welcome message
if [ ! -f $HOME/.hushlogin ]; then
  touch $HOME/.hushlogin
fi

# prepare for vim
source ./scripts/vim.sh

# install with brew
source ./scripts/brew.sh

# update terminal
source ./scripts/term.sh

# install tmux plugins
source ./scripts/tmux.sh

# install with curl
source ./scripts/curl.sh

# install atom packages
source ./scripts/apm.sh
