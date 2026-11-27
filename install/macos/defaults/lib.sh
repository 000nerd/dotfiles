#!/usr/bin/env bash

# Shared registry helpers for intentional macOS `defaults` settings.
# This file is sourced by registry.sh; it does not apply settings by itself.

dotfiles_defaults_reset() {
    DOTFILES_DEFAULTS_TOTAL=0
    DOTFILES_DEFAULTS_MATCHED=0
    DOTFILES_DEFAULTS_DRIFTED=0
    DOTFILES_DEFAULTS_MISSING=0
    # Read by registry.sh after this library is sourced.
    # shellcheck disable=SC2034
    DOTFILES_DEFAULTS_UNVERIFIED=0
}

dotfiles_defaults_expected_bool() {
    case "$1" in
        true | 1) printf '1' ;;
        false | 0) printf '0' ;;
        *) printf '%s' "$1" ;;
    esac
}

dotfiles_defaults_write() {
    local target="$1"
    local domain="$2"
    local key="$3"
    shift 3

    case "$target" in
        user)
            defaults write "$domain" "$key" "$@"
            ;;
        current-host)
            defaults -currentHost write "$domain" "$key" "$@"
            ;;
        system)
            sudo defaults write "$domain" "$key" "$@"
            ;;
        *)
            echo "Unknown macOS defaults target: $target" >&2
            return 2
            ;;
    esac
}

dotfiles_defaults_read() {
    local target="$1"
    local domain="$2"
    local key="$3"

    case "$target" in
        user | system)
            defaults read "$domain" "$key"
            ;;
        current-host)
            defaults -currentHost read "$domain" "$key"
            ;;
        *)
            return 2
            ;;
    esac
}

dotfiles_defaults_audit_scalar() {
    local target="$1"
    local domain="$2"
    local key="$3"
    local expected="$4"
    local actual

    if ! actual=$(dotfiles_defaults_read "$target" "$domain" "$key" 2>/dev/null); then
        printf 'missing\t%s\t%s\texpected=%s\n' "$domain" "$key" "$expected"
        DOTFILES_DEFAULTS_MISSING=$((DOTFILES_DEFAULTS_MISSING + 1))
        return 0
    fi

    if [ "$actual" = "$expected" ]; then
        printf 'ok\t%s\t%s\t%s\n' "$domain" "$key" "$expected"
        DOTFILES_DEFAULTS_MATCHED=$((DOTFILES_DEFAULTS_MATCHED + 1))
    else
        printf 'drift\t%s\t%s\texpected=%s actual=%s\n' "$domain" "$key" "$expected" "$actual"
        DOTFILES_DEFAULTS_DRIFTED=$((DOTFILES_DEFAULTS_DRIFTED + 1))
    fi
}

dotfiles_defaults_audit_array_int() {
    local target="$1"
    local domain="$2"
    local key="$3"
    local expected_csv="$4"
    local actual normalized expected

    if ! actual=$(dotfiles_defaults_read "$target" "$domain" "$key" 2>/dev/null); then
        printf 'missing\t%s\t%s\texpected=%s\n' "$domain" "$key" "$expected_csv"
        DOTFILES_DEFAULTS_MISSING=$((DOTFILES_DEFAULTS_MISSING + 1))
        return 0
    fi

    normalized=$(printf '%s' "$actual" | tr -d '[:space:](),')
    expected=$(printf '%s' "$expected_csv" | tr -d ',')
    if [ "$normalized" = "$expected" ]; then
        printf 'ok\t%s\t%s\t%s\n' "$domain" "$key" "$expected_csv"
        DOTFILES_DEFAULTS_MATCHED=$((DOTFILES_DEFAULTS_MATCHED + 1))
    else
        printf 'drift\t%s\t%s\texpected=%s actual=%s\n' "$domain" "$key" "$expected_csv" "$normalized"
        DOTFILES_DEFAULTS_DRIFTED=$((DOTFILES_DEFAULTS_DRIFTED + 1))
    fi
}

dotfiles_defaults_audit_float() {
    local target="$1" domain="$2" key="$3" expected="$4" actual
    if ! actual=$(dotfiles_defaults_read "$target" "$domain" "$key" 2>/dev/null); then
        printf 'missing\t%s\t%s\texpected=%s\n' "$domain" "$key" "$expected"
        DOTFILES_DEFAULTS_MISSING=$((DOTFILES_DEFAULTS_MISSING + 1))
    elif python3 -c 'from decimal import Decimal; import sys; sys.exit(0 if Decimal(sys.argv[1]) == Decimal(sys.argv[2]) else 1)' "$actual" "$expected"; then
        printf 'ok\t%s\t%s\t%s\n' "$domain" "$key" "$expected"
        DOTFILES_DEFAULTS_MATCHED=$((DOTFILES_DEFAULTS_MATCHED + 1))
    else
        printf 'drift\t%s\t%s\texpected=%s actual=%s\n' "$domain" "$key" "$expected" "$actual"
        DOTFILES_DEFAULTS_DRIFTED=$((DOTFILES_DEFAULTS_DRIFTED + 1))
    fi
}

dotfiles_defaults_audit_dict_bool() {
    local target="$1"
    local domain="$2"
    local key="$3"
    local expected_csv="$4"
    local actual entries entry dict_key dict_value expected_value actual_count expected_count ok

    if ! actual=$(dotfiles_defaults_read "$target" "$domain" "$key" 2>/dev/null); then
        printf 'missing\t%s\t%s\texpected=%s\n' "$domain" "$key" "$expected_csv"
        DOTFILES_DEFAULTS_MISSING=$((DOTFILES_DEFAULTS_MISSING + 1))
        return 0
    fi

    ok=true
    expected_count=0
    entries=${expected_csv//,/ }
    for entry in $entries; do
        expected_count=$((expected_count + 1))
        dict_key=${entry%%=*}
        dict_value=${entry#*=}
        expected_value=$(dotfiles_defaults_expected_bool "$dict_value")
        if ! printf '%s\n' "$actual" | grep -Eq "(^|[[:space:]])${dict_key}[[:space:]]*=[[:space:]]*${expected_value};"; then
            ok=false
        fi
    done
    actual_count=$(printf '%s\n' "$actual" | grep -Ec '=' || true)
    [ "$actual_count" -eq "$expected_count" ] || ok=false

    if [ "$ok" = true ]; then
        printf 'ok\t%s\t%s\t%s\n' "$domain" "$key" "$expected_csv"
        DOTFILES_DEFAULTS_MATCHED=$((DOTFILES_DEFAULTS_MATCHED + 1))
    else
        printf 'drift\t%s\t%s\texpected=%s\n' "$domain" "$key" "$expected_csv"
        DOTFILES_DEFAULTS_DRIFTED=$((DOTFILES_DEFAULTS_DRIFTED + 1))
    fi
}

dotfiles_default_dispatch() {
    local kind="$1"
    local scope="$2"
    local target="$3"
    local domain="$4"
    local key="$5"
    local value="$6"
    local restart="$7"
    local description="$8"
    value=${value//__DOTFILES_HOME__/$HOME}
    local expected="$value"

    DOTFILES_DEFAULTS_TOTAL=$((DOTFILES_DEFAULTS_TOTAL + 1))

    if [ "$kind" = bool ]; then
        expected=$(dotfiles_defaults_expected_bool "$value")
    fi

    case "${DOTFILES_DEFAULTS_MODE:-apply}" in
        apply)
            case "$kind" in
                bool) dotfiles_defaults_write "$target" "$domain" "$key" -bool "$value" ;;
                int) dotfiles_defaults_write "$target" "$domain" "$key" -int "$value" ;;
                float) dotfiles_defaults_write "$target" "$domain" "$key" -float "$value" ;;
                string) dotfiles_defaults_write "$target" "$domain" "$key" -string "$value" ;;
                array-int)
                    local array_values old_ifs
                    old_ifs=$IFS
                    IFS=,
                    # shellcheck disable=SC2086
                    set -- $value
                    IFS=$old_ifs
                    array_values=("$@")
                    dotfiles_defaults_write "$target" "$domain" "$key" -array "${array_values[@]}"
                    ;;
                dict-bool)
                    local dict_args entries entry dict_key dict_value
                    dict_args=(-dict)
                    entries=${value//,/ }
                    for entry in $entries; do
                        dict_key=${entry%%=*}
                        dict_value=${entry#*=}
                        dict_args+=("$dict_key" -bool "$dict_value")
                    done
                    dotfiles_defaults_write "$target" "$domain" "$key" "${dict_args[@]}"
                    ;;
            esac
            ;;
        list)
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$scope" "$target" "$domain" "$key" "$value" "$restart" "$description"
            ;;
        audit)
            case "$kind" in
                bool | int | string)
                    dotfiles_defaults_audit_scalar "$target" "$domain" "$key" "$expected"
                    ;;
                array-int)
                    dotfiles_defaults_audit_array_int "$target" "$domain" "$key" "$value"
                    ;;
                float) dotfiles_defaults_audit_float "$target" "$domain" "$key" "$value" ;;
                dict-bool)
                    dotfiles_defaults_audit_dict_bool "$target" "$domain" "$key" "$value"
                    ;;
            esac
            ;;
        count)
            ;;
        *)
            echo "Unknown macOS defaults mode: ${DOTFILES_DEFAULTS_MODE}" >&2
            return 2
            ;;
    esac
}

dotfiles_default_bool() {
    dotfiles_default_dispatch bool "$@"
}

dotfiles_default_int() {
    dotfiles_default_dispatch int "$@"
}

dotfiles_default_float() {
    dotfiles_default_dispatch float "$@"
}

dotfiles_default_string() {
    dotfiles_default_dispatch string "$@"
}

dotfiles_default_array_int() {
    dotfiles_default_dispatch array-int "$@"
}

dotfiles_default_dict_bool() {
    dotfiles_default_dispatch dict-bool "$@"
}
