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
DOTFILES_OS=${DOTFILES_OS:-$(uname)}

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

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --only)
            ONLY_STEPS="${2:-}"
            shift
            ;;
        --only=*)
            ONLY_STEPS="${1#*=}"
            ;;
        --skip)
            SKIP_STEPS="${2:-}"
            shift
            ;;
        --skip=*)
            SKIP_STEPS="${1#*=}"
            ;;
        --profile)
            PROFILE="${2:-}"
            shift
            ;;
        --profile=*)
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
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

echo "Installing dotfiles."

run_step symlinks "$DOTFILES_DIR/install/symlinks.sh"

case "$DOTFILES_OS" in
    Darwin)
        run_step brew "$DOTFILES_DIR/install/mac/brew.sh"
        run_step macos "$DOTFILES_DIR/install/mac/macos.sh"
        ;;
    Linux)
        run_step brew "$DOTFILES_DIR/install/linux/brew.sh"
        ;;
    *)
        echo "Unsupported OS for brew/macos steps: $DOTFILES_OS"
        ;;
esac

run_step javascript "$DOTFILES_DIR/install/lang/javascript.sh"
run_step java "$DOTFILES_DIR/install/lang/java.sh"
run_step python "$DOTFILES_DIR/install/lang/python.sh"

echo "Done. Reload your terminal."
# For adding SSH to keychain. May need later
# ssh-add -A 2>/dev/null;
