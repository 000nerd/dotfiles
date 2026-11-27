#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOTFILES="$ROOT_DIR/bin/dotfiles"

echo "Testing dotfiles command help"
echo "============================="

main_help=$("$DOTFILES")
grep -q "dotfiles <command>" <<< "$main_help"

for command in update clean doctor backup symlinks brew appstore macos java javascript python; do
    output=$("$DOTFILES" "$command")
    grep -q "dotfiles $command run" <<< "$output"
    grep -q "run" <<< "$output"
done

install_help=$("$DOTFILES" install)
grep -q "Usage: ./install.sh \\[options\\]" <<< "$install_help"

theme_help=$("$DOTFILES" theme)
grep -q "usage: dotfiles theme" <<< "$theme_help"

editors_help=$("$DOTFILES" editors)
grep -q "dotfiles editors" <<< "$editors_help"
grep -q "apply,check,render" <<< "$editors_help"
if "$DOTFILES" editors invalid >/dev/null 2>&1; then
    echo "Expected invalid editor action to fail." >&2
    exit 1
fi

macos_help=$("$DOTFILES" macos)
grep -q "dotfiles macos <command>" <<< "$macos_help"
grep -q "list" <<< "$macos_help"
grep -q "audit" <<< "$macos_help"
grep -q "toggle" <<< "$macos_help"
macos_list=$("$DOTFILES" macos list --profile personal)
grep -q "AppleActionOnDoubleClick" <<< "$macos_list"

if "$DOTFILES" clean nope >/dev/null 2>&1; then
    echo "Expected invalid subcommand argument to fail." >&2
    exit 1
fi

if "$DOTFILES" macos nope >/dev/null 2>&1; then
    echo "Expected invalid macOS subcommand to fail." >&2
    exit 1
fi

DOTFILES_THEME_STATE_FILE=/private/tmp/dotfiles-help-theme-current "$DOTFILES" theme list >/dev/null
DOTFILES_OS=Darwin "$DOTFILES" install --dry-run --only symlinks >/dev/null

echo "dotfiles command help test passed."
