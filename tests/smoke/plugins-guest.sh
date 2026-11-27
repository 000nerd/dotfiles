#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PLUGIN_TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-plugins.XXXXXX")
trap 'rm -rf "$PLUGIN_TEST_HOME"' EXIT

# Deliberately reproduce SSH with pipe stdin, no terminal type, and no cache.
DOTFILES_INSTALL_ZSH_PLUGINS=true ZPLUG_HOME="$PLUGIN_TEST_HOME" TERM='' \
    zsh -f -c '
        source "$1/config/zsh/exports"
        source "$1/config/zsh/plugins" || exit $?
        zplug check
    ' _ "$ROOT_DIR" </dev/null
echo "SMOKE_PLUGINS_OK empty-state headless"
