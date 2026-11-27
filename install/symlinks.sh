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
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$DOTFILES_DIR/install/links.sh"
BACKUP_DIR=${DOTFILES_BACKUP_DIR:-$HOME/dotfiles-backup}

backup_existing_target() {
    local target="$1"
    local relative_target="$2"
    local backup_target="$BACKUP_DIR/$relative_target"
    local collision=0

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$backup_target")" || return $?
    while [ -e "$backup_target" ] || [ -L "$backup_target" ]; do
        collision=$((collision + 1))
        backup_target="$BACKUP_DIR/$relative_target.$(date +%Y%m%d%H%M%S).$collision"
    done

    echo "Backing up ~${target#"$HOME"} to $backup_target"
    mv "$target" "$backup_target" || return $?
}

install_symlink() {
    local source="$1"
    local target="$2"
    local relative_target="$3"

    if [ ! -e "$source" ]; then
        echo "Symlink source not found: $source" >&2
        return 1
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo "~${target#"$HOME"} already linked... Skipping."
        return 0
    fi

    backup_existing_target "$target" "$relative_target" || return $?
    mkdir -p "$(dirname "$target")" || return $?
    echo "Creating symlink for $source @ $target"
    ln -s "$source" "$target"
}

echo -e "\nCreating symlinks"
echo "=============================="
dotfiles_each_link install_symlink
