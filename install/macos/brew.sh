#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR=${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
DOTFILES_APPSTORE_PENDING=false

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/downloads.sh"

#  $$$$$$$\  $$$$$$$\  $$$$$$$$\ $$\      $$\
#  $$  __$$\ $$  __$$\ $$  _____|$$ | $\  $$ |
#  $$ |  $$ |$$ |  $$ |$$ |      $$ |$$$\ $$ |
#  $$$$$$$\ |$$$$$$$  |$$$$$\    $$ $$ $$\$$ |
#  $$  __$$\ $$  __$$< $$  __|   $$$$  _$$$$ |
#  $$ |  $$ |$$ |  $$ |$$ |      $$$  / \$$$ |
#  $$$$$$$  |$$ |  $$ |$$$$$$$$\ $$  /   \$$ |
#  \_______/ \__|  \__|\________|\__/     \__|

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done >/dev/null 2>&1 &

retry() {
    local attempt
    local max_attempts=3

    for attempt in $(seq 1 "$max_attempts"); do
        if "$@"; then
            return 0
        fi
        if [ "$attempt" -lt "$max_attempts" ]; then
            echo "Command failed; retrying ($attempt/$max_attempts): $*"
            sleep $((attempt * 10))
        fi
    done

    return 1
}

install_homebrew() {
    # Run as a login shell (non-interactive) so that the script doesn't pause for user input.
    curl --retry 5 --retry-delay 10 --retry-max-time 300 -fsSL "$homebrew_install_url" | bash --login
}

if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if test ! "$(command -v brew)"; then
    echo "Homebrew not installed. Installing."
    homebrew_install_url=${HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}
    retry install_homebrew
fi

if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if test ! "$(command -v brew)"; then
    echo "Homebrew is installed but not available on PATH." >&2
    exit 1
fi

echo -e "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=("${DOTFILES_MAC_FORMULAS[@]}")

cask_formulas=("${DOTFILES_MAC_CASKS[@]}")

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        retry brew install "$formula"
    fi
done

if [ "${CI:-false}" = "true" ] || [ "${DOTFILES_INSTALL_CASKS:-true}" = "false" ]; then
    echo "Skipping heavy cask installations."
else
    for cask_formula in "${cask_formulas[@]}"; do
        if brew list --cask "$cask_formula" > /dev/null 2>&1; then
            echo "$cask_formula already installed... skipping."
        else
            if [ "$cask_formula" = vlc ]; then
                if ! brew install --cask vlc; then
                    dotfiles_cache_vlc_from_official_mirror
                    retry brew install --cask vlc
                fi
            else
                retry brew install --cask "$cask_formula"
            fi
        fi
    done
    appstore_status=0
    python3 "$DOTFILES_DIR/scripts/appstore.py" install --status-file "${DOTFILES_APPSTORE_STATUS_FILE:-$HOME/.local/state/dotfiles/appstore-status.json}" || appstore_status=$?
    if [ "$appstore_status" -eq 2 ]; then
        # shellcheck disable=SC2034 # Read by install.sh or bin/dotfiles.
        DOTFILES_APPSTORE_PENDING=true
        echo "App Store setup is pending. Core setup will continue." >&2
    elif [ "$appstore_status" -ne 0 ]; then
        exit "$appstore_status"
    fi
fi

# Provision the configured plugins during installation, rather than leaving a
# new terminal with an empty plugin cache. No user-local shell hooks are run.
DOTFILES_INSTALL_ZSH_PLUGINS=true zsh -f -c '
    source "$1/config/zsh/exports"
    source "$1/config/zsh/plugins" || exit $?
    zplug check
' _ "${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}" </dev/null

# Remove outdated versions from the cellar.
brew cleanup
