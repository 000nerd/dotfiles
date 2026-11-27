#!/usr/bin/env bash

# Explicit source/destination pairs shared by installation, backup, and doctor.
# Sources are relative to the checkout; destinations are relative to HOME.
dotfiles_each_link() {
    local callback="$1" source relative
    local manifest="$DOTFILES_DIR/install/links.tsv"
    if [ ! -r "$manifest" ]; then
        echo "Link manifest not found: $manifest" >&2
        return 1
    fi
    while IFS=$'\t' read -r source relative || [ -n "$source" ]; do
        case "$source" in '' | \#*) continue ;; esac
        "$callback" "$DOTFILES_DIR/$source" "$HOME/$relative" "$relative" || return $?
    done < "$manifest"
}
