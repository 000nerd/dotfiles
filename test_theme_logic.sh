#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=${TEST_ROOT:-/private/tmp/dotfiles-theme-logic-test}
TEST_HOME="$TEST_ROOT/home"
COMMAND_LOG="$TEST_ROOT/theme-commands.log"
CODEX_STATE="$TEST_ROOT/codex-state.json"
VSCODE_SETTINGS="$TEST_ROOT/vscode-settings.json"
INTELLIJ_COLORS="$TEST_ROOT/JetBrains/IntelliJIdea/colors"
OBSIDIAN_VAULT="$TEST_ROOT/ObsidianVault"
THEME_STATE="$TEST_ROOT/theme-current"
ZSH_THEME_TARGET="$TEST_ROOT/current-theme.zsh"

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_HOME" "$INTELLIJ_COLORS" "$OBSIDIAN_VAULT/.obsidian/themes/Obsidian gruvbox"

printf '{"appearanceTheme":"system"}\n' > "$CODEX_STATE"
printf '{\n  "editor.fontSize": 14,\n}\n' > "$VSCODE_SETTINGS"
printf '/* test theme */\n' > "$OBSIDIAN_VAULT/.obsidian/themes/Obsidian gruvbox/theme.css"

HOME="$TEST_HOME" \
DOTFILES_CODEX_STATE_PATH="$CODEX_STATE" \
DOTFILES_VSCODE_SETTINGS_PATH="$VSCODE_SETTINGS" \
DOTFILES_INTELLIJ_COLORS_DIRS="$INTELLIJ_COLORS" \
DOTFILES_OBSIDIAN_VAULTS="$OBSIDIAN_VAULT" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_THEME_SKIP_EXTENSION_CHECK=1 \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bins/dotfiles" theme apply gruvbox --apps codex,vscode,intellij,obsidian,iterm,terminal,zsh

python3 - "$CODEX_STATE" "$VSCODE_SETTINGS" "$OBSIDIAN_VAULT/.obsidian/appearance.json" <<'PY'
import json
import sys

codex = json.load(open(sys.argv[1]))
vscode = json.load(open(sys.argv[2]))
obsidian = json.load(open(sys.argv[3]))

assert codex["appearanceDarkCodeThemeId"] == "gruvbox"
assert codex["appearanceDarkChromeTheme"]["surface"] == "#282828"
assert vscode["workbench.colorTheme"] == "Gruvbox Dark Medium"
assert obsidian["cssTheme"] == "Obsidian gruvbox"
assert obsidian["accentColor"] == "#458588"
PY

test -f "$INTELLIJ_COLORS/GruvboxDark.icls"
test -L "$ZSH_THEME_TARGET"
test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/themes/zsh/gruvbox.zsh-theme"
grep -q 'open .*/themes/iTerm/gruvbox-dark.itermcolors' "$COMMAND_LOG"
grep -q 'open .*/themes/terminal/gruvbox-dark.terminal' "$COMMAND_LOG"
grep -q '^gruvbox$' "$THEME_STATE"

HOME="$TEST_HOME" \
DOTFILES_INTELLIJ_COLORS_DIRS="$INTELLIJ_COLORS" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bins/dotfiles" theme apply gruvbox-material --apps terminal,intellij,zsh

test -f "$INTELLIJ_COLORS/GruvboxMaterial.icls"
test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/themes/zsh/gruvbox-material.zsh-theme"
grep -q 'open .*/themes/terminal/gruvbox-material-dark.terminal' "$COMMAND_LOG"

HOME="$TEST_HOME" \
DOTFILES_INTELLIJ_COLORS_DIRS="$INTELLIJ_COLORS" \
DOTFILES_THEME_COMMAND_LOG="$COMMAND_LOG" \
DOTFILES_THEME_STATE_FILE="$THEME_STATE" \
DOTFILES_ZSH_THEME_TARGET="$ZSH_THEME_TARGET" \
"$ROOT_DIR/bins/dotfiles" theme apply everforest --apps terminal,intellij,zsh

test -f "$INTELLIJ_COLORS/Everforest.icls"
test "$(readlink "$ZSH_THEME_TARGET")" = "$ROOT_DIR/themes/zsh/everforest.zsh-theme"
grep -q 'open .*/themes/terminal/everforest-dark.terminal' "$COMMAND_LOG"

echo "Theme logic test passed."
