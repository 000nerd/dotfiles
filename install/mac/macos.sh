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
sudo scutil --set HostName "${device}"
sudo scutil --set LocalHostName "${device}"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "${device}"

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Replace Time Machine with Volume on the menu bar
defaults write com.apple.systemuiserver menuExtras -array \
    "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
    "/System/Library/CoreServices/Menu Extras/Volume.menu" \
    "/System/Library/CoreServices/Menu Extras/Battery.menu" \
    "/System/Library/CoreServices/Menu Extras/Clock.menu"

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Enable Auto Mode
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

###############################################################################
# Security                                                                    #
# read more: https://github.com/kristovatlas/osx-config-check                 #
#            https://github.com/drduh/macOS-Security-and-Privacy-Guide        #
###############################################################################

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# # Disable remote login
sudo systemsetup -f -setremotelogin off

# # Destroy file vault key when going into standby
# sudo pmset -a destroyfvkeyonstandby 1

# Modify if we want to use evict file vault keys when going into standby
# May be redudant with APFS
# sudo pmset -a powernap 0
# sudo pmset -a standby 0
# sudo pmset -a standbydelay 0
# sudo pmset -a autopoweroff 0

# Disable the guest account
sudo sysadminctl -guestAccount off &> /dev/null

# Restart automatically if the computer freezes
sudo systemsetup -setrestartfreeze on

# # Enable automatic software update checks
softwareupdate --schedule on
# # Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Disable ad tracking library: System Preferences → Security & Privacy → Privacy → Advertising
defaults write com.apple.AdLib forceLimitAdTracking -bool true
# Disable Identifier for Advertising
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
# NOTE: https://github.com/blochberger/IDFA#facts
# Override ad tracking device ID with a zeroed ID
defaults write com.apple.AdLib AD_DEVICE_IDFA -string '00000000-0000-0000-0000-000000000000'

# Firewall is enabled. (State = 1)
# 0 = off
# 1 = on for specific services
# 2 = on for essential services
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Turning on log mode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

# Stealth mode enabled
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Trackpad tracking speed
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 0.7

# Trackpad: enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: map bottom right corner to right-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Increase sound quality for Bluetooth headphones/headsets
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Turn off keyboard illumination when computer is not used for 5 minutes
defaults write com.apple.BezelServices kDimTime -int 300

# Set language and text formats
defaults write NSGlobalDomain AppleLanguages -array "en"
defaults write NSGlobalDomain AppleLocale -string "en_US@currency=USD"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
defaults write NSGlobalDomain AppleMetricUnits -bool false

###############################################################################
# Screen                                                                      #
###############################################################################

# Enable subpixel font rendering on non-Apple LCDs
defaults write NSGlobalDomain AppleFontSmoothing -int 1

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
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Enable spring loading for directories
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# Tweak the spring loading delay for directories
defaults write NSGlobalDomain com.apple.springing.delay -float .5

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

###############################################################################
# Dock, MenuBar                                                               #
###############################################################################

# Enable highlight hover effect for the grid view of a stack (Dock)
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# Set the icon size of Dock items to 48 pixels
defaults write com.apple.dock tilesize -int 48

# Set the Dock magnification off
defaults write com.apple.dock magnification -bool false

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Change minimize/maximize window effect
defaults write com.apple.dock mineffect -string "genie"

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Privacy: don’t send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Show the full URL in the address bar (note: this still hides the scheme)
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Press Tab to highlight each item on a web page
defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Hide Safari’s bookmarks bar by default
defaults write com.apple.Safari ShowFavoritesBar -bool false

# Hide Safari’s sidebar in Top Sites
defaults write com.apple.Safari ShowSidebarInTopSites -bool false

# Make Safari’s search banners default to Contains instead of Starts With
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# Enable continuous spellchecking
defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true

# Warn about fraudulent websites
defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

# Block pop-up windows
defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false

# Enable “Do Not Track”
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true


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

# Install the Solarized Dark theme for iTerm
open "${HOME}/.dotfiles/themes/iTerm/gruvbox-light.itermcolors"
open "${HOME}/.dotfiles/themes/iTerm/gruvbox-dark.itermcolors"

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

###############################################################################
# Xcode                                                                       #
###############################################################################

# Trim trailing whitespace
defaults write com.apple.dt.Xcode DVTTextEditorTrimTrailingWhitespace -bool true

# Trim whitespace only lines
defaults write com.apple.dt.Xcode DVTTextEditorTrimWhitespaceOnlyLines -bool true

# Show line numbers
defaults write com.apple.dt.Xcode DVTTextShowLineNumbers -bool true

# Enable automatic updates
defaults write com.apple.dt.Xcode DVTDownloadableAutomaticUpdate -bool true

# Live issues
defaults write com.apple.dt.Xcode IDEEnableLiveIssues -bool true

# Setup page guide
defaults write com.apple.dt.Xcode DVTTextShowPageGuide -bool true
defaults write com.apple.dt.Xcode DVTTextPageGuideLocation -int 110

# Max number of lines
defaults write com.apple.dt.Xcode IDEIssueNavigatorDetailLevel -int 10
defaults write com.apple.dt.Xcode IDESearchNavigatorDetailLevel -int 10

# Enable internal debug menu
defaults write com.apple.dt.Xcode ShowDVTDebugMenu -bool true

# Source control local revision side
defaults write com.apple.dt.Xcode DVTComparisonOrientationDefaultsKey -int 0

# Stack assitant editors vertically
defaults write com.apple.dt.Xcode AssistantEditorsLayout -int 1

# Use open quickly to open in the focused pane
defaults write com.apple.dt.Xcode IDEEditorCoordinatorTarget_Click -string FocusedEditor

# Use custom derived data location
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation -string build

# Disable source control
defaults write com.apple.dt.Xcode IDESourceControlEnableSourceControl_7_1 -bool false

# Show build times in toolbar
# http://cocoa.tumblr.com/post/131023038113/build-speed
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool true

# Add more information to Xcode's build output about why specific commands are being run
# https://twitter.com/bdash/status/661742266487205888
# http://www.openradar.me/27516128
defaults write com.apple.dt.Xcode ExplainWhyBuildCommandsAreRun -bool true

# Stop Xcode from reopening files (specifically storyboards) on launch.
# I also have a `xcuser` shell command to wipe this state so you don't reopen
# storyboards and dirty the diff, or just take 30 seconds to launch
defaults write com.apple.dt.Xcode IDEDisableStateRestoration -bool true

# Write detailed build system info into derived data
# If you don't enable this but `mkdir /tmp/xcode_dependency_logs` the logs will
# be created there instead
defaults write com.apple.dt.Xcode EnableBuildSystemLogging -bool true

###############################################################################
# Transmission.app                                                            #
###############################################################################

# Trash original torrent files
defaults write org.m0k.transmission DeleteOriginalTorrent -bool true

# # Use `~/Documents/Torrents` to store incomplete downloads
# defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
# defaults write org.m0k.transmission IncompleteDownloadFolder -string "${HOME}/Documents/Torrents"

# # Use `~/Downloads` to store completed downloads
# defaults write org.m0k.transmission DownloadLocationConstant -bool true

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

# # Set a custom user account image
# dscl . delete "${HOME}" JPEGPhoto
# dscl . delete "${HOME}" Picture
# sudo dscl . create "${HOME}" Picture "${PWD}/avatar.jpg"

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
