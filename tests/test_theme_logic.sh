#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=${TEST_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-theme-logic.XXXXXX")}
TEST_HOME="$TEST_ROOT/home"
COMMAND_LOG="$TEST_ROOT/theme-commands.log"
VSCODE_SETTINGS="$TEST_ROOT/vscode-settings.json"
OBSIDIAN_VAULT="$TEST_ROOT/ObsidianVault"
THEME_STATE="$TEST_ROOT/theme-current"
ZSH_THEME_TARGET="$TEST_ROOT/current-theme.zsh"

if [ -e "$TEST_ROOT" ] && [ -n "$(ls -A "$TEST_ROOT")" ]; then
    echo "Test directory must be empty: $TEST_ROOT" >&2
    exit 1
fi
mkdir -p "$TEST_HOME" "$OBSIDIAN_VAULT/.obsidian/themes/Obsidian gruvbox"

printf '{\n  "editor.fontSize": 14,\n}\n' > "$VSCODE_SETTINGS"
printf '/* test theme */\n' > "$OBSIDIAN_VAULT/.obsidian/themes/Obsidian gruvbox/theme.css"

HOME="$TEST_HOME" \
DOTFILES_VSCODE_SETTINGS_PATH="$VSCODE_SETTINGS" \
DOTFILES_OBSIDIAN_VAULTS="$OBSIDIAN_VAULT" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_THEME_SKIP_EXTENSION_CHECK=1 \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bin/dotfiles" theme apply gruvbox --apps vscode,obsidian,iterm,terminal,zsh

python3 - "$VSCODE_SETTINGS" "$OBSIDIAN_VAULT/.obsidian/appearance.json" <<'PY'
import json
import sys

vscode = json.load(open(sys.argv[1]))
obsidian = json.load(open(sys.argv[2]))

assert vscode["workbench.colorTheme"] == "Gruvbox Dark Medium"
assert obsidian["cssTheme"] == "Obsidian gruvbox"
assert obsidian["accentColor"] == "#458588"
PY

test -L "$ZSH_THEME_TARGET"
test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/config/themes/zsh/gruvbox.zsh-theme"
grep -q 'open .*/config/themes/iterm/gruvbox-dark.itermcolors' "$COMMAND_LOG"
grep -q 'open .*/config/themes/terminal/gruvbox-dark.terminal' "$COMMAND_LOG"
grep -q '^gruvbox$' "$THEME_STATE"

HOME="$TEST_HOME" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bin/dotfiles" theme apply gruvbox-material --apps terminal,zsh

test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/config/themes/zsh/gruvbox-material.zsh-theme"
grep -q 'open .*/config/themes/terminal/gruvbox-material-dark.terminal' "$COMMAND_LOG"

HOME="$TEST_HOME" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bin/dotfiles" theme apply everforest --apps terminal,zsh

test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/config/themes/zsh/everforest.zsh-theme"
grep -q 'open .*/config/themes/terminal/everforest-dark.terminal' "$COMMAND_LOG"

echo "Theme logic test passed."
