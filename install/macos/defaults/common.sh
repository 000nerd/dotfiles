#!/usr/bin/env bash

# Settings applied to every Mac profile.

dotfiles_default_string common system \
    /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName \
    "${DOTFILES_NETBIOS_NAME:-${DOTFILES_COMPUTER_NAME_VALUE// /-}}" SystemUIServer \
    "Use a network-safe computer name for SMB"

dotfiles_default_bool common user -g NSDocumentSaveNewDocumentsToCloud false none \
    "Save new documents locally instead of iCloud"
dotfiles_default_int common current-host com.apple.controlcenter Sound 18 SystemUIServer \
    "Show Sound in Control Center"
dotfiles_default_bool common user -g NSAutomaticQuoteSubstitutionEnabled false none \
    "Disable smart quote substitution"
dotfiles_default_bool common user -g AppleInterfaceStyleSwitchesAutomatically true none \
    "Switch light and dark appearance automatically"
dotfiles_default_bool common user com.apple.print.PrintingPrefs "Quit When Finished" true none \
    "Quit the printer app after jobs finish"

dotfiles_default_bool common user com.apple.AdLib forceLimitAdTracking true none \
    "Limit advertising tracking"
dotfiles_default_bool common user com.apple.AdLib allowIdentifierForAdvertising false none \
    "Disable the advertising identifier"
dotfiles_default_string common user com.apple.AdLib AD_DEVICE_IDFA \
    00000000-0000-0000-0000-000000000000 none \
    "Use a zeroed advertising identifier"

dotfiles_default_int common user com.apple.driver.AppleBluetoothMultitouch.trackpad \
    TrackpadCornerSecondaryClick 2 none \
    "Use the bottom-right trackpad corner for secondary click"
dotfiles_default_bool common user com.apple.driver.AppleBluetoothMultitouch.trackpad \
    TrackpadRightClick true none \
    "Enable trackpad secondary click"
dotfiles_default_int common current-host NSGlobalDomain \
    com.apple.trackpad.trackpadCornerClickBehavior 1 none \
    "Use corner-click behavior on the current host"
dotfiles_default_bool common current-host NSGlobalDomain \
    com.apple.trackpad.enableSecondaryClick true none \
    "Enable secondary click on the current host"
dotfiles_default_bool common user NSGlobalDomain ApplePressAndHoldEnabled false none \
    "Use key repeat instead of press-and-hold accents"

dotfiles_default_bool common user com.apple.finder QuitMenuItem true Finder \
    "Allow Finder to quit"
dotfiles_default_string common user com.apple.finder NewWindowTarget PfDe Finder \
    "Open new Finder windows at the Desktop"
dotfiles_default_string common user com.apple.finder NewWindowTargetPath \
    "file://${HOME}/Desktop/" Finder \
    "Use the Desktop path for new Finder windows"
dotfiles_default_bool common user com.apple.finder ShowExternalHardDrivesOnDesktop true Finder \
    "Show external drives on the Desktop"
dotfiles_default_bool common user com.apple.finder ShowHardDrivesOnDesktop true Finder \
    "Show internal drives on the Desktop"
dotfiles_default_bool common user com.apple.finder ShowPathbar true Finder \
    "Show the Finder path bar"
dotfiles_default_bool common user com.apple.finder QLEnableTextSelection true Finder \
    "Allow text selection in Quick Look"
dotfiles_default_bool common user com.apple.finder _FXSortFoldersFirst true Finder \
    "Keep folders first when sorting"
dotfiles_default_bool common user com.apple.desktopservices DSDontWriteNetworkStores true Finder \
    "Avoid .DS_Store files on network volumes"
dotfiles_default_bool common user com.apple.desktopservices DSDontWriteUSBStores true Finder \
    "Avoid .DS_Store files on USB volumes"
dotfiles_default_string common user com.apple.finder FXPreferredViewStyle icnv Finder \
    "Use icon view by default"
dotfiles_default_dict_bool common user com.apple.finder FXInfoPanesExpanded \
    General=true,Name=true,OpenWith=true Finder \
    "Expand selected Finder Info panes"

dotfiles_default_int common user com.apple.dock tilesize 48 Dock \
    "Set Dock icon size"
dotfiles_default_bool common user com.apple.dock magnification true Dock \
    "Enable Dock magnification"
dotfiles_default_bool common user com.apple.dock minimize-to-application true Dock \
    "Minimize windows into their application icon"
dotfiles_default_bool common user com.apple.dock mru-spaces false Dock \
    "Keep Spaces in a stable order"
dotfiles_default_bool common user com.apple.dock autohide true Dock \
    "Automatically hide the Dock"
dotfiles_default_bool common user com.apple.dock show-recents false Dock \
    "Hide recent applications from the Dock"

dotfiles_default_bool common user com.apple.Safari IncludeDevelopMenu true Safari \
    "Enable the Safari Develop menu"
dotfiles_default_bool common user com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey true Safari \
    "Enable the Safari Web Inspector"
dotfiles_default_bool common user -g WebKitDeveloperExtras true Safari \
    "Enable Web Inspector in WebKit views"
dotfiles_default_bool common user com.apple.Safari WebContinuousSpellCheckingEnabled true Safari \
    "Enable continuous spellchecking in Safari"
dotfiles_default_bool common user com.apple.Safari WarnAboutFraudulentWebsites true Safari \
    "Warn about fraudulent websites"
dotfiles_default_bool common user com.apple.Safari InstallExtensionUpdatesAutomatically true Safari \
    "Update Safari extensions automatically"
dotfiles_default_bool common user com.apple.Safari ShowStandaloneTabBar false Safari \
    "Use Safari compact tab mode"
dotfiles_default_bool common user com.apple.Safari NeverUseBackgroundColorInToolbar true Safari \
    "Use color in Safari's compact tab bar"

dotfiles_default_array_int common user com.apple.terminal StringEncodings 4 Terminal \
    "Use UTF-8 in Terminal"
dotfiles_default_bool common user com.apple.terminal FocusFollowsMouse true Terminal \
    "Focus Terminal windows by hovering"
dotfiles_default_bool common user com.apple.terminal SecureKeyboardEntry true Terminal \
    "Enable Secure Keyboard Entry in Terminal"
dotfiles_default_int common user com.apple.Terminal ShowLineMarks 0 Terminal \
    "Hide Terminal line marks"
