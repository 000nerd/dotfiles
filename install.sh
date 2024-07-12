#!/usr/bin/env bash

#  $$$$$$\ $$\   $$\  $$$$$$\ $$$$$$$$\  $$$$$$\  $$\       $$\
#  \_$$  _|$$$\  $$ |$$  __$$\\__$$  __|$$  __$$\ $$ |      $$ |
#    $$ |  $$$$\ $$ |$$ /  \__|  $$ |   $$ /  $$ |$$ |      $$ |
#    $$ |  $$ $$\$$ |\$$$$$$\    $$ |   $$$$$$$$ |$$ |      $$ |
#    $$ |  $$ \$$$$ | \____$$\   $$ |   $$  __$$ |$$ |      $$ |
#    $$ |  $$ |\$$$ |$$\   $$ |  $$ |   $$ |  $$ |$$ |      $$ |
#  $$$$$$\ $$ | \$$ |\$$$$$$  |  $$ |   $$ |  $$ |$$$$$$$$\ $$$$$$$$\
#  \______|\__|  \__| \______/   \__|   \__|  \__|\________|\________|


command_exists() {
    type "$1" > /dev/null 2>&1
}

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Installing dotfiles."

source install/symlinks.sh

# only perform macOS-specific install
if [ "$(uname)" == "Darwin" ]; then
    echo -e "\n\nRunning on macOS"

    # Install Applications and macOS tweaks for Development

    if [[ $OSTYPE == 'darwin'* ]]; then
        source install/mac/brew.sh
        source install/mac/macos.sh
    fi

    if [[ $OSTYPE == 'linux'* ]]; then
        source install/linux/brew.sh
    fi
    # Install programming enviroments

    source install/lang/javascript.sh

    source install/lang/java.sh

    source install/lang/python.sh

fi

echo "Done. Reload your terminal."
# For adding SSH to keychain. May need later
# ssh-add -A 2>/dev/null;
