#!/usr/bin/env bash
set -euo pipefail

# Safe macOS logic test. This does not require a clean macOS install and does
# not run real defaults/sudo/scutil/open/killall commands.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=${TEST_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-macos-logic.XXXXXX")}
TEST_HOME="$TEST_ROOT/home"
COMMAND_LOG="$TEST_ROOT/macos-commands.log"

if [ -e "$TEST_ROOT" ] && [ -n "$(ls -A "$TEST_ROOT")" ]; then
    echo "Test directory must be empty: $TEST_ROOT" >&2
    exit 1
fi
mkdir -p "$TEST_HOME"

echo "Testing macOS dotfiles logic in $TEST_ROOT"
echo "=========================================="

HOME="$TEST_HOME" \
DOTFILES_OS=Darwin \
DOTFILES_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_COMPUTER_NAME="Codex Test Mac" \
DOTFILES_HOST_NAME="CodexTest" \
"$ROOT_DIR/install.sh" --profile personal --only symlinks,macos

echo
echo "Verifying symlinks"
test -L "$TEST_HOME/.zshrc"
test -L "$TEST_HOME/.gitconfig"
test -L "$TEST_HOME/.gitignore_global"
test -L "$TEST_HOME/.ssh/config"
test ! -e "$TEST_HOME/.config/.DS_Store"

echo "Verifying captured macOS commands"
test -s "$COMMAND_LOG"
grep -q 'sudo scutil --set ComputerName Codex\\ Test\\ Mac' "$COMMAND_LOG"
grep -q 'sudo scutil --set HostName CodexTest' "$COMMAND_LOG"
grep -q 'defaults write com.apple.dock autohide -bool true' "$COMMAND_LOG"
grep -q 'defaults write com.apple.finder ShowPathbar -bool true' "$COMMAND_LOG"
grep -q 'defaults write com.apple.finder FXPreferredViewStyle -string icnv' "$COMMAND_LOG"
grep -q 'defaults write com.apple.finder NewWindowTarget -string PfDe' "$COMMAND_LOG"
grep -Fq "defaults write com.apple.finder NewWindowTargetPath -string file://$TEST_HOME/Desktop/" "$COMMAND_LOG"
if grep -Eq 'defaults write (com.apple.dock (magnification|orientation|mineffect|tilesize)|NSGlobalDomain (NSAutomaticCapitalizationEnabled|AppleShowAllExtensions))' "$COMMAND_LOG"; then
    echo "Installer unexpectedly wrote a default or unverified preference." >&2
    exit 1
fi
grep -q 'defaults write NSGlobalDomain AppleActionOnDoubleClick -string Fill' "$COMMAND_LOG"
grep -q 'defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false' "$COMMAND_LOG"
grep -q 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on' "$COMMAND_LOG"
grep -q 'killall Finder' "$COMMAND_LOG"

expected_defaults=$(
    DOTFILES_DEFAULTS_MODE=count
    DOTFILES_DEFAULTS_PROFILE=personal
    DOTFILES_COMPUTER_NAME_VALUE="Codex Test Mac"
    # shellcheck source=install/macos/defaults/registry.sh
    source "$ROOT_DIR/install/macos/defaults/registry.sh"
    dotfiles_defaults_run_registry
)
actual_defaults=$(grep -Ec '^(sudo )?defaults (write |-currentHost write )' "$COMMAND_LOG")
if [ "$actual_defaults" -ne "$expected_defaults" ]; then
    echo "Expected $expected_defaults defaults writes, captured $actual_defaults." >&2
    exit 1
fi

echo
echo "macOS logic test passed."
echo "Command log: $COMMAND_LOG"
