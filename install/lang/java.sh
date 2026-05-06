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

echo -e "\n\nInstalling Java environment"
echo "=============================="

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Skipping Java environment setup via brew."
    exit 0
fi

formulas=(
    # install java and android dev tools
    gradle
    jenv
    maven
    openjdk@17
    openjdk@21
)

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done

# Initialize jenv
eval "$(jenv init -)"

jenv enable-plugin export
jenv enable-plugin gradle
jenv enable-plugin maven

BREW_PREFIX=$(brew --prefix)

if [ "$(uname)" == "Darwin" ]; then
    # MacOS specific openjdk links
    sudo ln -sfn "$BREW_PREFIX"/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk || true
    sudo ln -sfn "$BREW_PREFIX"/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk || true

    jenv add "$BREW_PREFIX"/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home || true
    jenv add "$BREW_PREFIX"/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home || true
elif [ "$(uname)" == "Linux" ]; then
    # Linux specific openjdk links (usually they are already in a good place, but let's add them to jenv)
    jenv add "$BREW_PREFIX"/opt/openjdk@17/libexec || true
    jenv add "$BREW_PREFIX"/opt/openjdk@21/libexec || true
fi

# Remove outdated versions from the cellar.
brew cleanup
