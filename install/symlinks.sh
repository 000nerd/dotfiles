#!/usr/bin/env bash

#   $$$$$$\ $$\     $$\ $$\      $$\ $$\       $$$$$$\ $$\   $$\ $$\   $$\  $$$$$$\
#  $$  __$$\\$$\   $$  |$$$\    $$$ |$$ |      \_$$  _|$$$\  $$ |$$ | $$  |$$  __$$\
#  $$ /  \__|\$$\ $$  / $$$$\  $$$$ |$$ |        $$ |  $$$$\ $$ |$$ |$$  / $$ /  \__|
#  \$$$$$$\   \$$$$  /  $$\$$\$$ $$ |$$ |        $$ |  $$ $$\$$ |$$$$$  /  \$$$$$$\
#   \____$$\   \$$  /   $$ \$$$  $$ |$$ |        $$ |  $$ \$$$$ |$$  $$<    \____$$\
#  $$\   $$ |   $$ |    $$ |\$  /$$ |$$ |        $$ |  $$ |\$$$ |$$ |\$$\  $$\   $$ |
#  \$$$$$$  |   $$ |    $$ | \_/ $$ |$$$$$$$$\ $$$$$$\ $$ | \$$ |$$ | \$$\ \$$$$$$  |
#   \______/    \__|    \__|     \__|\________|\______|\__|  \__|\__|  \__| \______/

# Get the absolute path of the dotfiles directory
DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo -e "\nCreating symlinks"
echo "=============================="
linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )
for file in $linkables ; do
    if [[ "$(basename "$(dirname "$file")")" == "ssh" ]]; then
        target="$HOME/.ssh/$( basename "$file" '.symlink' )"
        mkdir -p "$HOME/.ssh"
    else
        target="$HOME/.$( basename "$file" '.symlink' )"
    fi
    if [[ -e "$target" ]]; then
        echo "~${target#$HOME} already exists... Skipping."
    else
        echo "Creating symlink for $file @ $target"
        ln -s "$file" "$target"
    fi
done

echo -e "\nInstalling to ~/.config"
echo "=============================="
if [ ! -d "$HOME/.config" ]; then
    echo "Creating ~/.config"
    mkdir -p "$HOME/.config"
fi

config_files=$( find "$DOTFILES/config" -maxdepth 1 -not -path "$DOTFILES/config" -not -name '.*' )
for config in $config_files; do
    target="$HOME/.config/$( basename "$config" )"
    if [ -e "$target" ]; then
        echo "~${target#$HOME} already exists... Skipping."
    else
        echo "Creating symlink for $config"
        ln -s "$config" "$target"
    fi
done
