#!/usr/bin/env bash

#  $$$$$$\ $$\   $$\  $$$$$$\ $$$$$$$$\  $$$$$$\  $$\       $$\
#  \_$$  _|$$$\  $$ |$$  __$$\\__$$  __|$$  __$$\ $$ |      $$ |
#    $$ |  $$$$\ $$ |$$ /  \__|  $$ |   $$ /  $$ |$$ |      $$ |
#    $$ |  $$ $$\$$ |\$$$$$$\    $$ |   $$$$$$$$ |$$ |      $$ |
#    $$ |  $$ \$$$$ | \____$$\   $$ |   $$  __$$ |$$ |      $$ |
#    $$ |  $$ |\$$$ |$$\   $$ |  $$ |   $$ |  $$ |$$ |      $$ |
#  $$$$$$\ $$ | \$$ |\$$$$$$  |  $$ |   $$ |  $$ |$$$$$$$$\ $$$$$$$$\
#  \______|\__|  \__| \______/   \__|   \__|  \__|\________|\________|



#   $$$$$$\  $$$$$$$$\ $$$$$$$$\ $$\   $$\ $$$$$$$\
#  $$  __$$\ $$  _____|\__$$  __|$$ |  $$ |$$  __$$\
#  $$ /  \__|$$ |         $$ |   $$ |  $$ |$$ |  $$ |
#  \$$$$$$\  $$$$$\       $$ |   $$ |  $$ |$$$$$$$  |
#   \____$$\ $$  __|      $$ |   $$ |  $$ |$$  ____/
#  $$\   $$ |$$ |         $$ |   $$ |  $$ |$$ |
#  \$$$$$$  |$$$$$$$$\    $$ |   \$$$$$$  |$$ |
#   \______/ \________|   \__|    \______/ \__|


command_exists() {
    type "$1" > /dev/null 2>&1
}

echo "Installing dotfiles."

source install/symlinks.sh

# only perform macOS-specific install
if [ "$(uname)" == "Darwin" ]; then
    echo -e "\n\nRunning on macOS"

    # Install Applications and macOS tweaks for Development

    source install/mac/brew.sh

    source install/mac/macos.sh

    # Install programming enviroments

    source install/javascript.sh

    source install/java.sh

    source install/python.sh

fi

echo "Done. Reload your terminal."
# For adding SSH to keychain. May need later
# ssh-add -A 2>/dev/null;
