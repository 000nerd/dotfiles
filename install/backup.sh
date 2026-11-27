#!/usr/bin/env bash
set -euxo pipefail

#  $$$$$$$\   $$$$$$\   $$$$$$\  $$\   $$\ $$\   $$\ $$$$$$$\
#  $$  __$$\ $$  __$$\ $$  __$$\ $$ | $$  |$$ |  $$ |$$  __$$\
#  $$ |  $$ |$$ /  $$ |$$ /  \__|$$ |$$  / $$ |  $$ |$$ |  $$ |
#  $$$$$$$\ |$$$$$$$$ |$$ |      $$$$$  /  $$ |  $$ |$$$$$$$  |
#  $$  __$$\ $$  __$$ |$$ |      $$  $$<   $$ |  $$ |$$  ____/
#  $$ |  $$ |$$ |  $$ |$$ |  $$\ $$ |\$$\  $$ |  $$ |$$ |
#  $$$$$$$  |$$ |  $$ |\$$$$$$  |$$ | \$$\ \$$$$$$  |$$ |
#  \_______/ \__|  \__| \______/ \__|  \__| \______/ \__|

# Backup files that are provided by the dotfiles into a ~/dotfiles-backup directory

DOTFILES_DIR=${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
BACKUP_DIR=${DOTFILES_BACKUP_DIR:-$HOME/dotfiles-backup}
source "$DOTFILES_DIR/install/links.sh"
mkdir -p "$BACKUP_DIR"

backup_link() {
    local target="$2" relative="$3" backup_target collision=0
    if [ ! -e "$target" ] || [ -L "$target" ]; then
        echo "$relative is missing or already a symlink... skipping."
        return 0
    fi
    backup_target="$BACKUP_DIR/$relative"
    mkdir -p "$(dirname "$backup_target")"
    while [ -e "$backup_target" ] || [ -L "$backup_target" ]; do
        collision=$((collision + 1))
        backup_target="$BACKUP_DIR/$relative.$(date +%Y%m%d%H%M%S).$collision"
    done
    echo "Backing up $relative to $backup_target"
    cp -RPp "$target" "$backup_target"
}
dotfiles_each_link backup_link
