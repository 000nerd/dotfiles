#!/usr/bin/env bash

dotfiles_default_bool personal user com.apple.dock autohide true Dock \
    "Hide the Dock so maximized windows can use the desktop area"
dotfiles_default_string personal user NSGlobalDomain AppleActionOnDoubleClick Fill none \
    "Fill the available desktop when double-clicking a window title bar"
dotfiles_default_bool personal user com.apple.WindowManager EnableTiledWindowMargins false none \
    "Remove margins around tiled and filled windows"

# Reviewed against the reference VM in the setting-by-setting walkthrough.
dotfiles_default_bool personal user com.apple.finder ShowPathbar true Finder \
    "Show the folder-location path bar in Finder windows"
dotfiles_default_string personal user com.apple.finder FXPreferredViewStyle icnv Finder \
    "Use icon view for Finder's preferred view"
dotfiles_default_string personal user com.apple.finder NewWindowTarget PfDe Finder \
    "Open new Finder windows at Desktop"
dotfiles_default_string personal user com.apple.finder NewWindowTargetPath \
    "file://${HOME}/Desktop/" Finder "Use the user's Desktop for new Finder windows"
