#!/usr/bin/env bash

#  $$\      $$\  $$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\
#  $$$\    $$$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\
#  $$$$\  $$$$ |$$ /  $$ |$$ /  \__|$$ /  $$ |$$ /  \__|
#  $$\$$\$$ $$ |$$$$$$$$ |$$ |      $$ |  $$ |\$$$$$$\
#  $$ \$$$  $$ |$$  __$$ |$$ |      $$ |  $$ | \____$$\
#  $$ |\$  /$$ |$$ |  $$ |$$ |  $$\ $$ |  $$ |$$\   $$ |
#  $$ | \_/ $$ |$$ |  $$ |\$$$$$$  | $$$$$$  |\$$$$$$  |
#  \__|     \__|\__|  \__| \______/  \______/  \______/

echo -e "\n\nChanging macOS settings"
echo "=============================="

if [ -n "${DOTFILES_COMMAND_LOG:-}" ]; then
    mkdir -p "$(dirname "$DOTFILES_COMMAND_LOG")"
    dotfiles_log_command() {
        printf '%q ' "$@" >> "$DOTFILES_COMMAND_LOG"
        printf '\n' >> "$DOTFILES_COMMAND_LOG"
    }
    osascript() { dotfiles_log_command osascript "$@"; }
    sudo() { dotfiles_log_command sudo "$@"; }
    # shellcheck disable=SC2032
    defaults() { dotfiles_log_command defaults "$@"; }
    softwareupdate() { dotfiles_log_command softwareupdate "$@"; }
    open() { dotfiles_log_command open "$@"; }
    killall() { dotfiles_log_command killall "$@"; }
fi

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done >/dev/null 2>&1 &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Set computer name (as done via System Preferences → Sharing)
if [ -n "${DOTFILES_COMPUTER_NAME:-}" ]; then
    device="$DOTFILES_COMPUTER_NAME"
else
    read -r -p "Name this computer (e.g. iObsa Air): " device
fi
sudo scutil --set ComputerName "${device}"
sudo scutil --set HostName "${DOTFILES_HOST_NAME:-iObsa}"
sudo scutil --set LocalHostName "${device// /-}"

# Apply the canonical, auditable defaults registry. The install profile selects
# captured personal settings or common + work; direct runs default to personal.
MACOS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export DOTFILES_COMPUTER_NAME_VALUE="$device"
export DOTFILES_DEFAULTS_MODE=apply
export DOTFILES_DEFAULTS_PROFILE=${DOTFILES_DEFAULTS_PROFILE:-${PROFILE:-personal}}
# shellcheck disable=SC1091
source "$MACOS_DIR/defaults/registry.sh"
dotfiles_defaults_run_registry

###############################################################################
# Security                                                                    #
# read more: https://github.com/kristovatlas/osx-config-check                 #
#            https://github.com/drduh/macOS-Security-and-Privacy-Guide        #
###############################################################################

# Destroy file vault key when going into standby
sudo pmset -a destroyfvkeyonstandby 1

# Disable the guest account
sudo sysadminctl -guestAccount off &> /dev/null

# Restart automatically if the computer freezes
freeze_status=0
freeze_output=$(sudo systemsetup -setrestartfreeze on 2>&1) || freeze_status=$?
if [ "$freeze_status" -ne 0 ] || [[ "$freeze_output" = *Error* ]] || [[ "$freeze_output" = *not\ supported* ]]; then
    notice="Restart-on-freeze could not be verified on this Mac/VM: $freeze_output"
    echo "$notice" >&2
    if [ -n "${DOTFILES_SETUP_NOTICES:-}" ]; then printf '%s\n' "$notice" >> "$DOTFILES_SETUP_NOTICES"; fi
fi
# Sleep settings for Computer, Display, and HardDisk
sudo pmset -a sleep 1 displaysleep 5 disksleep 10

# # Enable automatic software update checks
softwareupdate --schedule on

# Firewall is enabled. (State = 1)
# 0 = off
# 1 = on for specific services
# 2 = on for essential services
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Turning on log mode
if ! sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on; then
    echo "Firewall logging mode is not supported on this macOS version; skipping."
fi

# Turning on incoming connection for built in and signed download apps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

# Stealth mode enabled
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

###############################################################################
# Terminal themes                                                             #
###############################################################################

# Install the Gruvbox Dark theme for iTerm
if [ "${DOTFILES_HEADLESS:-false}" = "true" ]; then
    echo "Headless environment detected. Skipping iTerm color imports."
else
    open "${HOME}/.dotfiles/config/themes/iterm/gruvbox-light.itermcolors"
    open "${HOME}/.dotfiles/config/themes/iterm/gruvbox-dark.itermcolors"
fi

###############################################################################
# 21stBam                                                                     #
###############################################################################

# # Set a custom wallpaper image. `DefaultDesktop.jpg` is already a symlink, and
# # all wallpapers are in `/Library/Desktop Pictures/`. The default is `Wave.jpg`.
# #rm -rf ~/Library/Application Support/Dock/desktoppicture.db
# #sudo rm -rf /System/Library/CoreServices/DefaultDesktop.jpg
# #sudo ln -s /path/to/your/image /System/Library/CoreServices/DefaultDesktop.jpg

# # Set a dark gray wallpaper on all desktops
# if [[ '10.13' =~ ${os_release} ]]; then
#   # High Sierra
#   osascript -e 'tell application "System Events" to set picture of every desktop to "/Library/Desktop Pictures/Solid Colors/Solid Gray Pro Ultra Dark.png"'
# fi
# if [[ '10.14' =~ ${os_release} ]]; then
#   # Mojave
#   osascript -e 'tell application "System Events" to set picture of every desktop to "/Library/Desktop Pictures/Solid Colors/Stone.png"'
# fi
# if [[ '10.15' =~ ${os_release} ]]; then
#   # Catalina
#   osascript -e 'tell application "System Events" to set picture of every desktop to "/System/Library/Desktop Pictures/Solid Colors/Stone.png"'
# fi

# # Add Rectangle to login items
# osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Rectangle.app", hidden:false}' 1> /dev/null

###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "Activity Monitor" "Calendar" "cfprefsd" "Dock" "Finder" \
	"Photos" "Safari" "SystemUIServer" "Transmission" "iterm2" "Xcode"; do
	killall "${app}" &> /dev/null || true
done

echo "Done. Note that some of these changes require a logout/restart to take effect."
