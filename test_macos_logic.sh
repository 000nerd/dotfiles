#!/usr/bin/env bash
set -euo pipefail

# Safe macOS logic test. This does not require a clean macOS install and does
# not run real defaults/sudo/scutil/open/killall commands.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=${TEST_ROOT:-/private/tmp/dotfiles-macos-logic-test}
TEST_HOME="$TEST_ROOT/home"
COMMAND_LOG="$TEST_ROOT/macos-commands.log"

rm -rf "$TEST_ROOT"
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
test -L "$TEST_HOME/.tmux.conf"
test -L "$TEST_HOME/.ssh/config"
test -d "$TEST_HOME/.config"
test -L "$TEST_HOME/.config/conda"
test ! -e "$TEST_HOME/.config/.DS_Store"

echo "Verifying captured macOS commands"
test -s "$COMMAND_LOG"
grep -q 'sudo scutil --set ComputerName Codex\\ Test\\ Mac' "$COMMAND_LOG"
grep -q 'sudo scutil --set HostName CodexTest' "$COMMAND_LOG"
grep -q 'defaults write com.apple.finder ShowPathbar -bool true' "$COMMAND_LOG"
grep -q 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on' "$COMMAND_LOG"
grep -q 'killall Finder' "$COMMAND_LOG"

echo
echo "macOS logic test passed."
echo "Command log: $COMMAND_LOG"
