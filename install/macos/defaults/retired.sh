#!/usr/bin/env bash

# Intentionally inactive historical settings. Keeping them here makes their
# status explicit without applying them on a fresh machine.

# App-specific press-and-hold override; superseded by the global setting.
# defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

# Subpixel font smoothing; not consistently supported on modern macOS.
# defaults write -g AppleFontSmoothing -int 1

# Dock spring loading; retained as a possible future preference.
# defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
