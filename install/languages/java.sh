#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages.sh"

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

formulas=("${DOTFILES_JAVA_FORMULAS[@]}")

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install "$formula"
    fi
done

# Initialize jenv
# Its Bash export hook reads this interactive-shell variable during init, even
# in a noninteractive installer. Keep nounset enabled and provide its default.
: "${PROMPT_COMMAND:=}"
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

jenv global "${DOTFILES_JAVA_DEFAULT:-21}"

# Remove outdated versions from the cellar.
brew cleanup
