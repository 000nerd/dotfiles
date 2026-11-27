#!/usr/bin/env bash

dotfiles_macos_toggle_help() {
    cat <<'EOF'
Usage: dotfiles macos toggle <name> <on|off>

Toggles:
  hidden-files    Show or hide hidden files in Finder
  desktop-icons   Show or hide all Desktop icons
EOF
}

dotfiles_macos_toggle() {
    local name="${1:-}"
    local state="${2:-}"
    local value

    case "$state" in
        on) value=true ;;
        off) value=false ;;
        *)
            dotfiles_macos_toggle_help >&2
            return 2
            ;;
    esac

    case "$name" in
        hidden-files)
            defaults write com.apple.finder AppleShowAllFiles -bool "$value"
            ;;
        desktop-icons)
            defaults write com.apple.finder CreateDesktop -bool "$value"
            ;;
        *)
            dotfiles_macos_toggle_help >&2
            return 2
            ;;
    esac

    killall Finder >/dev/null 2>&1 || true
}
