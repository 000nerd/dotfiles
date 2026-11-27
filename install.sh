#!/usr/bin/env bash
set -euo pipefail

#  $$$$$$\ $$\   $$\  $$$$$$\ $$$$$$$$\  $$$$$$\  $$\       $$\
#  \_$$  _|$$$\  $$ |$$  __$$\\__$$  __|$$  __$$\ $$ |      $$ |
#    $$ |  $$$$\ $$ |$$ /  \__|  $$ |   $$ /  $$ |$$ |      $$ |
#    $$ |  $$ $$\$$ |\$$$$$$\    $$ |   $$$$$$$$ |$$ |      $$ |
#    $$ |  $$ \$$$$ | \____$$\   $$ |   $$  __$$ |$$ |      $$ |
#    $$ |  $$ |\$$$ |$$\   $$ |  $$ |   $$ |  $$ |$$ |      $$ |
#  $$$$$$\ $$ | \$$ |\$$$$$$  |  $$ |   $$ |  $$ |$$$$$$$$\ $$$$$$$$\
#  \______|\__|  \__| \______/   \__|   \__|  \__|\________|\________|


DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DRY_RUN=false
ONLY_STEPS=""
SKIP_STEPS=""
PROFILE=""
DOTFILES_APPSTORE_PENDING=false
DOTFILES_OS=${DOTFILES_OS:-$(uname)}

if [ -n "${DOTFILES_SUDO_PASSWORD:-}" ]; then
    sudo() {
        printf '%s\n' "$DOTFILES_SUDO_PASSWORD" | command sudo -S "$@"
    }
fi

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run              Show what would run without changing the system.
  --only step[,step]     Run only selected steps.
  --skip step[,step]     Skip selected steps.
  --profile name         Load install/profiles/name.env before running.
  -h, --help             Show this help.

Steps:
  symlinks, brew, macos, javascript, java, python
EOF
}

require_value() {
    if [ -z "${2:-}" ] || [[ "$2" = -* ]]; then
        echo "Missing value for $1." >&2
        exit 2
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --only)
            require_value "$1" "${2:-}"
            ONLY_STEPS="${2:-}"
            shift
            ;;
        --only=*)
            require_value --only "${1#*=}"
            ONLY_STEPS="${1#*=}"
            ;;
        --skip)
            require_value "$1" "${2:-}"
            SKIP_STEPS="${2:-}"
            shift
            ;;
        --skip=*)
            require_value --skip "${1#*=}"
            SKIP_STEPS="${1#*=}"
            ;;
        --profile)
            require_value "$1" "${2:-}"
            PROFILE="${2:-}"
            shift
            ;;
        --profile=*)
            require_value --profile "${1#*=}"
            PROFILE="${1#*=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ -n "$PROFILE" ]; then
    case "$PROFILE" in
        *[!a-zA-Z0-9_-]*) echo "Invalid profile name: $PROFILE" >&2; exit 2 ;;
    esac
    profile_file="$DOTFILES_DIR/install/profiles/$PROFILE.env"
    if [ ! -r "$profile_file" ]; then
        echo "Profile not found: $profile_file" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$profile_file"
    ONLY_STEPS="${ONLY_STEPS:-${DOTFILES_ONLY_STEPS:-}}"
    SKIP_STEPS="${SKIP_STEPS:-${DOTFILES_SKIP_STEPS:-}}"
fi

validate_steps() {
    local list="$1" step
    [ -n "$list" ] || return 0
    case "$list" in
        ,* | *, | *,,*) echo "Invalid step list: $list" >&2; exit 2 ;;
    esac
    local steps
    IFS=, read -r -a steps <<< "$list"
    for step in "${steps[@]}"; do
        case "$step" in
            symlinks | brew | macos | javascript | java | python) ;;
            *) echo "Unknown install step: $step" >&2; exit 2 ;;
        esac
    done
}
validate_steps "$ONLY_STEPS"
validate_steps "$SKIP_STEPS"

list_contains() {
    local list="$1"
    local item="$2"
    case ",$list," in
        *",$item,"*) return 0 ;;
        *) return 1 ;;
    esac
}

should_run() {
    local step="$1"
    if [ -n "$ONLY_STEPS" ] && ! list_contains "$ONLY_STEPS" "$step"; then
        return 1
    fi
    if [ -n "$SKIP_STEPS" ] && list_contains "$SKIP_STEPS" "$step"; then
        return 1
    fi
    return 0
}

run_step() {
    local step="$1"
    local script="$2"
    if ! should_run "$step"; then
        echo "Skipping $step."
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        echo "[dry-run] Would run $step: $script"
        return 0
    fi
    echo -e "\n\nRunning $step"
    echo "=============================="
    # shellcheck source=/dev/null
    source "$script"
}

needs_sudo() {
    [ "$DRY_RUN" = false ] && { should_run brew || should_run macos || should_run java; }
}

if needs_sudo && [ -z "${DOTFILES_COMMAND_LOG:-}" ]; then
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done >/dev/null 2>&1 &
fi

echo "Installing dotfiles."

run_step symlinks "$DOTFILES_DIR/install/symlinks.sh"

case "$DOTFILES_OS" in
    Darwin)
        run_step brew "$DOTFILES_DIR/install/macos/brew.sh"
        run_step macos "$DOTFILES_DIR/install/macos/defaults.sh"
        ;;
    Linux)
        run_step brew "$DOTFILES_DIR/install/linux/brew.sh"
        ;;
    *)
        echo "Unsupported OS for brew/macos steps: $DOTFILES_OS"
        ;;
esac

run_step javascript "$DOTFILES_DIR/install/languages/javascript.sh"
run_step java "$DOTFILES_DIR/install/languages/java.sh"
run_step python "$DOTFILES_DIR/install/languages/python.sh"

if [ "$DOTFILES_APPSTORE_PENDING" = true ]; then
    echo "Core setup finished; App Store apps still require user action."
    exit 2
fi
echo "Done. Reload your terminal."
# For adding SSH to keychain. May need later
# ssh-add -A 2>/dev/null;
