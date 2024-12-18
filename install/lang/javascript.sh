#!/usr/bin/env bash
set -euxo pipefail

#     $$$$$\  $$$$$$\  $$\    $$\  $$$$$$\   $$$$$$\   $$$$$$\  $$$$$$$\  $$$$$$\ $$$$$$$\ $$$$$$$$\
#     \__$$ |$$  __$$\ $$ |   $$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\ \_$$  _|$$  __$$\\__$$  __|
#        $$ |$$ /  $$ |$$ |   $$ |$$ /  $$ |$$ /  \__|$$ /  \__|$$ |  $$ |  $$ |  $$ |  $$ |  $$ |
#        $$ |$$$$$$$$ |\$$\  $$  |$$$$$$$$ |\$$$$$$\  $$ |      $$$$$$$  |  $$ |  $$$$$$$  |  $$ |
#  $$\   $$ |$$  __$$ | \$$\$$  / $$  __$$ | \____$$\ $$ |      $$  __$$<   $$ |  $$  ____/   $$ |
#  $$ |  $$ |$$ |  $$ |  \$$$  /  $$ |  $$ |$$\   $$ |$$ |  $$\ $$ |  $$ |  $$ |  $$ |        $$ |
#  \$$$$$$  |$$ |  $$ |   \$  /   $$ |  $$ |\$$$$$$  |\$$$$$$  |$$ |  $$ |$$$$$$\ $$ |        $$ |
#   \______/ \__|  \__|    \_/    \__|  \__| \______/  \______/ \__|  \__|\______|\__|        \__|

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Installing."
    # Run as a login shell (non-interactive) so that the script doesn't pause for user input
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login
fi

echo -e "\n\nInstalling JavaScript enviroment"
echo "=============================="

# Install nvm for node versions
brew install nvm

if [[ ! -d "~/.nvm" ]]; then
    mkdir ~/.nvm
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh" # This loads nvm

# Install latest node and set it as default
nvm install 18
nvm install 20
nvm install --lts
nvm alias default 'lts/*'
nvm use default # need to open new terminal/tab for changes to work

packages=(
    @angular/cli
    @nestjs/cli
    aws-cdk
    eas-cli
    nodemon
    yarn
)

for package in "${packages[@]}"; do
	npm install -g "$package"
done

# Update npm
npm install -g npm@latest

# Remove outdated versions from the cellar.
brew cleanup
