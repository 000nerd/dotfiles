#!/usr/bin/env bash
set -euxo pipefail

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

if test ! "$(which brew)"; then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling Java and Android enviroment"
echo "=============================="

# Make sure we’re using the latest Homebrew.
brew update

formulas=(
	# install java and android dev tools
	gradle
	jenv
	maven
	openjdk@11
    openjdk@17
)

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done

eval "$(jenv init -)"

jenv enable-plugin export

sudo ln -sfn "$(brew --prefix)"/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk
sudo ln -sfn "$(brew --prefix)"/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

jenv add "$(brew --prefix)"/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home
jenv add "$(brew --prefix)"/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home

# Remove outdated versions from the cellar.
brew cleanup
