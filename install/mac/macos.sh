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
# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Set computer name (as done via System Preferences → Sharing)
read -r -p "Name this computer (e.g. iObsa Air): " device
sudo scutil --set ComputerName "${device}"
sudo scutil --set HostName "iObsa"
sudo scutil --set LocalHostName "${device// /-}"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "${device}"

# Save to disk (not to iCloud) by default
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

# # Replace Time Machine with Volume on the menu bar  - ADD POSITIONS
defaults -currentHost write  com.apple.controlcenter Sound -int 18

# Disable smart quotes as they’re annoying when typing code
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

# Enable Auto Mode
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

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
sudo systemsetup -setrestartfreeze on
# Sleep settings for Computer, Display, and HardDisk
sudo systemsetup -setcomputersleep 1
sudo systemsetup -setdisplaysleep 5
sudo systemsetup -setharddisksleep 10

# # Enable automatic software update checks
softwareupdate --schedule on

# # Disable ad tracking library: System Preferences → Security & Privacy → Privacy → Advertising
defaults write com.apple.AdLib forceLimitAdTracking -bool true
# # Disable Identifier for Advertising
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
# # NOTE: https://github.com/blochberger/IDFA#facts
# # Override ad tracking device ID with a zeroed ID
defaults write com.apple.AdLib AD_DEVICE_IDFA -string '00000000-0000-0000-0000-000000000000'

# Firewall is enabled. (State = 1)
# 0 = off
# 1 = on for specific services
# 2 = on for essential services
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Turning on log mode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

# Turning on incoming connection for built in and signed download apps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

# Stealth mode enabled
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# ###############################################################################
# # Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
# ###############################################################################

# Trackpad: map bottom right corner to right-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Disable press-and-hold for keys in favor of key repeat
# Do it for Spefici Programs (IDE, Terminal) or Global
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

###############################################################################
# Screen                                                                      #
###############################################################################

# # Enable subpixel font rendering on non-Apple LCDs
# defaults write -g AppleFontSmoothing -int 1

###############################################################################
# Finder                                                                      #
###############################################################################

# Finder: allow quitting via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Set Desktop as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Show icons for external hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use icon view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# Expand the following File Info panes:
# “General”, “Open with”, and “Sharing & Permissions”
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    Name -bool true \
    OpenWith -bool true

# ###############################################################################
# # Dock, MenuBar                                                               #
# ###############################################################################

# Set the icon size of Dock items to 48 pixels
defaults write com.apple.dock tilesize -int 48

# Set the Dock magnification off
defaults write com.apple.dock magnification -bool true

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# # Enable spring loading for all Dock items
# defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write -g WebKitDeveloperExtras -bool true

# Enable continuous spellchecking
defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true

# Warn about fraudulent websites
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

# Update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

# Show Safari in Compact Tab Mode
defaults write com.apple.Safari ShowStandaloneTabBar -bool false

# Show color in compact tab bar
defaults write com.apple.Safari NeverUseBackgroundColorInToolbar -bool true


###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Enable “focus follows mouse” for Terminal.app
# i.e. hover over a window and start typing in it without clicking first
defaults write com.apple.terminal FocusFollowsMouse -bool true

# Enable Secure Keyboard Entry in Terminal.app
# See: https://security.stackexchange.com/a/47786/8918
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# Disable the annoying line marks
defaults write com.apple.Terminal ShowLineMarks -int 0

# Install the Gruvbox Dark theme for iTerm
open "${HOME}/.dotfiles/themes/iTerm/gruvbox-light.itermcolors"
open "${HOME}/.dotfiles/themes/iTerm/gruvbox-dark.itermcolors"

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

###############################################################################
# Transmission.app                                                            #
###############################################################################

# Trash original torrent files
defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

# Hide the donate message
defaults write org.m0k.transmission WarningDonate -bool false

# Hide the legal disclaimer
defaults write org.m0k.transmission WarningLegal -bool false

# Randomize port on launch
defaults write org.m0k.transmission RandomPort -bool true

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
	killall "${app}" &> /dev/null
done

echo "Done. Note that some of these changes require a logout/restart to take effect."
