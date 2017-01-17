#!/usr/bin/env bash

###############################################################################
#                             ANDROID + Java                                  #
###############################################################################


if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling Java and Android enviroment"
echo "=============================="

# Make sure we’re using the latest Homebrew.
brew update

cask_formulas=(
	# Install java and android IDEs
	java
	intellij-idea-ce
	android-studio
	intel-haxm # For hardware acceleration
	jd-gui # For java decompilation.
)

formulas=(
	# install java and android dev tools
	ant
	maven
	gradle
	android-sdk
	android-ndk
	apktool  # For android reverse engineering.
	dex2jar  # For android reverse engineering.
	jadx     # For android reverse engineering.
)

for cask_formula in "${cask_formulas[@]}"; do
    if brew list "$cask_formula" > /dev/null 2>&1; then
        echo "$cask_formula already installed... skipping."
    else
        brew install $cask_formula
    fi
done

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install $formula
    fi
done

# Install all of the Android SDK components
android update sdk --no-ui

# Remove outdated versions from the cellar.
brew cleanup
