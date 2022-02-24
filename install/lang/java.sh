#!/usr/bin/env bash

#     $$$$$\  $$$$$$\  $$\    $$\  $$$$$$\  
#     \__$$ |$$  __$$\ $$ |   $$ |$$  __$$\ 
#        $$ |$$ /  $$ |$$ |   $$ |$$ /  $$ |
#        $$ |$$$$$$$$ |\$$\  $$  |$$$$$$$$ |
#  $$\   $$ |$$  __$$ | \$$\$$  / $$  __$$ |
#  $$ |  $$ |$$ |  $$ |  \$$$  /  $$ |  $$ |
#  \$$$$$$  |$$ |  $$ |   \$  /   $$ |  $$ |
#   \______/ \__|  \__|    \_/    \__|  \__|

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

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
	android-studio
    intellij-idea-ce
	jd-gui # For java decompilation.
)

formulas=(
	# install java and android dev tools
	gradle
	jenv
	maven
	openjdk
	openjdk@11
	openjdk@8
)

# for cask_formula in "${cask_formulas[@]}"; do
#     if brew list "$cask_formula" > /dev/null 2>&1; then
#         echo "$cask_formula already installed... skipping."
#     else
#         brew cask install $cask_formula
#     fi
# done

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install $formula
    fi
done

# Remove outdated versions from the cellar.
brew cleanup
