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

DOTFILES=${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
BACKUP_DIR=${DOTFILES_BACKUP_DIR:-$HOME/dotfiles-backup}

echo "Creating backup directory at $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )

for file in $linkables; do
    if [[ "$(basename "$(dirname "$file")")" == "ssh" ]]; then
        filename=".ssh/$( basename "$file" '.symlink' )"
    else
        filename=".$( basename "$file" '.symlink' )"
    fi
    target="$HOME/$filename"
    if [ ! -e "$target" ]; then
        echo "$filename does not exist... skipping."
    elif [ ! -L "$target" ]; then
        echo "backing up $filename"
        mkdir -p "$BACKUP_DIR/$(dirname "$filename")"
        cp -R "$target" "$BACKUP_DIR/$filename"
    else
        echo -e "$filename is already a symlink... skipping."
    fi
done
