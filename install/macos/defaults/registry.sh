#!/usr/bin/env bash

DOTFILES_DEFAULTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "$DOTFILES_DEFAULTS_DIR/lib.sh"

dotfiles_defaults_run_registry() {
    local profile profile_file result
    profile=${DOTFILES_DEFAULTS_PROFILE:-personal}

    case "$profile" in
        common | personal | work) ;;
        *)
            echo "Unknown macOS defaults profile: $profile" >&2
            return 2
            ;;
    esac

    if [ -z "${DOTFILES_COMPUTER_NAME_VALUE:-}" ]; then
        if [ "${DOTFILES_DEFAULTS_MODE:-apply}" = audit ] && command -v scutil >/dev/null 2>&1; then
            DOTFILES_COMPUTER_NAME_VALUE=$(scutil --get ComputerName 2>/dev/null || printf '<computer-name>')
        else
            DOTFILES_COMPUTER_NAME_VALUE='<computer-name>'
        fi
    fi

    dotfiles_defaults_reset
    if [ "${DOTFILES_DEFAULTS_MODE:-apply}" = list ]; then
        printf 'scope\ttarget\tdomain\tkey\tvalue\trestart\tdescription\n'
    fi

    if [ "$profile" = personal ]; then
        # Manage verified non-default differences and reviewed intentional
        # overrides. Captured reference matches and unknowns remain unmanaged.
        source "$DOTFILES_DEFAULTS_DIR/captured-personal.sh"
        source "$DOTFILES_DEFAULTS_DIR/personal-overrides.sh"
    else
        # shellcheck disable=SC1091
        source "$DOTFILES_DEFAULTS_DIR/common.sh"
    fi
    if [ "$profile" = work ]; then
        profile_file="$DOTFILES_DEFAULTS_DIR/work.sh"
        # shellcheck source=/dev/null
        source "$profile_file"
    fi

    case "${DOTFILES_DEFAULTS_MODE:-apply}" in
        list)
            printf 'Total settings: %s\n' "$DOTFILES_DEFAULTS_TOTAL"
            ;;
        count)
            printf '%s\n' "$DOTFILES_DEFAULTS_TOTAL"
            ;;
        audit)
            printf '\nAudit summary: total=%s matched=%s drifted=%s missing=%s unverified=%s\n' \
                "$DOTFILES_DEFAULTS_TOTAL" "$DOTFILES_DEFAULTS_MATCHED" \
                "$DOTFILES_DEFAULTS_DRIFTED" "$DOTFILES_DEFAULTS_MISSING" \
                "$DOTFILES_DEFAULTS_UNVERIFIED"
            result=$((DOTFILES_DEFAULTS_DRIFTED + DOTFILES_DEFAULTS_MISSING))
            [ "$result" -eq 0 ]
            ;;
    esac
}
