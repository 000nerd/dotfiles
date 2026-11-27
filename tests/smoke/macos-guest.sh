#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PROFILE=${DOTFILES_SMOKE_PROFILE:-personal}
LOG_DIR=${DOTFILES_SMOKE_LOG_DIR:-"$HOME/dotfiles-smoke-logs"}
LOG_FILE="$LOG_DIR/smoke-$(date +%Y%m%d%H%M%S).log"
DRY_RUN=${DOTFILES_SMOKE_DRY_RUN:-false}
INSTALL_ONLY=${DOTFILES_SMOKE_INSTALL_ONLY:-}
INSTALL_SKIP=${DOTFILES_SMOKE_INSTALL_SKIP:-}
VERIFY_ONLY=${DOTFILES_SMOKE_VERIFY_ONLY:-false}
BASELINE_CAPTURED=false

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

section() {
    printf '\n== %s ==\n' "$*"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run() {
    echo "+ $*"
    "$@"
}

install_selected() {
    local status=0
    run ./install.sh "${selected_install_args[@]}" || status=$?
    if [ "$status" -eq 2 ] && python3 - "$DOTFILES_APPSTORE_STATUS_FILE" <<'PY'
import json, sys
from pathlib import Path
path=Path(sys.argv[1])
sys.exit(0 if path.exists() and json.loads(path.read_text()).get('status') == 'pending' else 1)
PY
    then
        echo "Core install completed; selected App Store apps remain pending."
        return 0
    fi
    return "$status"
}

collect_failed_baseline() {
    local status=$?
    if [ "$DRY_RUN" != true ] && [ -n "${DOTFILES_SMOKE_BASELINE:-}" ] && [ "$BASELINE_CAPTURED" != true ]; then
        echo "Collecting baseline evidence after incomplete smoke run (status=$status)."
        zsh -lic 'python3 scripts/setup-state.py capture --output "$1" --profile "$2"' _ "$LOG_DIR/observed.json" "$PROFILE" || true
        if [ -f "$LOG_DIR/observed.json" ]; then
            python3 "$ROOT_DIR/scripts/setup-state.py" compare "$DOTFILES_SMOKE_BASELINE" "$LOG_DIR/observed.json" --output "$LOG_DIR/comparison.json" || true
        fi
    fi
    return "$status"
}
trap collect_failed_baseline EXIT

list_contains() {
    local list="$1"
    local item="$2"
    case ",$list," in
        *",$item,"*) return 0 ;;
        *) return 1 ;;
    esac
}

should_install_step() {
    local step="$1"
    if [ -n "$INSTALL_ONLY" ] && ! list_contains "$INSTALL_ONLY" "$step"; then
        return 1
    fi
    if [ -n "$INSTALL_SKIP" ] && list_contains "$INSTALL_SKIP" "$step"; then
        return 1
    fi
    return 0
}

expect_command() {
    command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
    echo "ok command $1"
}

expect_symlink() {
    [ -L "$1" ] || fail "$1 is not a symlink"
    echo "ok symlink $1 -> $(readlink "$1")"
}

expect_brew_formula() {
    brew list "$1" >/dev/null 2>&1 || fail "missing brew formula: $1"
    echo "ok brew formula $1"
}

expect_app() {
    local name="$1"
    if [ -d "/Applications/$name.app" ] || [ -d "$HOME/Applications/$name.app" ]; then
        echo "ok app $name"
    else
        fail "missing app: $name"
    fi
}

expect_defaults_value() {
    local domain="$1"
    local key="$2"
    local expected="$3"
    local actual

    if [ "$domain" = "-g" ]; then
        actual=$(defaults read -g "$key" 2>/dev/null || true)
    else
        actual=$(defaults read "$domain" "$key" 2>/dev/null || true)
    fi

    [ "$actual" = "$expected" ] || fail "default $domain $key expected $expected, got ${actual:-<unset>}"
    echo "ok default $domain $key = $expected"
}

prime_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    if [ -n "${DOTFILES_SUDO_PASSWORD:-}" ]; then
        printf '%s\n' "$DOTFILES_SUDO_PASSWORD" | sudo -S -v
    else
        sudo -v
    fi
}

cd "$ROOT_DIR"

section "Environment"
echo "profile: $PROFILE"
echo "dry_run: $DRY_RUN"
echo "install_only: ${INSTALL_ONLY:-<none>}"
echo "install_skip: ${INSTALL_SKIP:-<none>}"
echo "root: $ROOT_DIR"
uname -a

[ "$(uname)" = "Darwin" ] || fail "macOS smoke test must run on Darwin"
if command -v caffeinate >/dev/null 2>&1; then
    # Installer sleep preferences must not suspend a long package build.
    caffeinate -i -w "$$" >/dev/null 2>&1 &
fi

export NONINTERACTIVE=1
export DOTFILES_HEADLESS=true
export DOTFILES_SETUP_NOTICES="$LOG_DIR/macos-notices.log"
export DOTFILES_APPSTORE_STATUS_FILE="$LOG_DIR/appstore-status.json"
if [ "$VERIFY_ONLY" != true ]; then : > "$DOTFILES_SETUP_NOTICES"; fi
export DOTFILES_COMPUTER_NAME="${DOTFILES_COMPUTER_NAME:-Dotfiles Smoke}"
export DOTFILES_HOST_NAME="${DOTFILES_HOST_NAME:-DotfilesSmoke}"
export DOTFILES_INSTALL_CASKS="${DOTFILES_INSTALL_CASKS:-true}"
export DOTFILES_SMOKE_EXPECT_CASKS="${DOTFILES_SMOKE_EXPECT_CASKS:-$DOTFILES_INSTALL_CASKS}"
selected_install_args=(--profile "$PROFILE")
if [ -n "$INSTALL_ONLY" ]; then
    selected_install_args+=(--only "$INSTALL_ONLY")
fi
if [ -n "$INSTALL_SKIP" ]; then
    selected_install_args+=(--skip "$INSTALL_SKIP")
fi

section "Preflight"
run ./tests/test_dotfiles_help.sh
run ./tests/test_macos_logic.sh
run ./tests/test_macos_defaults.sh
run ./tests/test_theme_logic.sh
run python3 tests/test_setup.py
run ./install.sh "${selected_install_args[@]}" --dry-run

section "Install"
if [ "$DRY_RUN" = true ]; then
    echo "Dry-run install requested; skipping mutating install and post-install assertions."
    echo "SMOKE_OK dry-run profile=$PROFILE"
    exit 0
fi

if [ "$VERIFY_ONLY" != true ]; then
    prime_sudo
    install_selected
fi

export PATH="$HOME/.dotfiles/bin:$PATH"
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if should_install_step symlinks; then
    section "Doctor"
    run ./bin/dotfiles doctor run

    section "Symlinks"
    expect_symlink "$HOME/.zshrc"
    expect_symlink "$HOME/.zprofile"
    expect_symlink "$HOME/.gitconfig"
    expect_symlink "$HOME/.gitignore_global"
    expect_symlink "$HOME/.ssh/config"
fi

if should_install_step brew; then
    if [ "$VERIFY_ONLY" != true ]; then
        section "Fresh headless plugin state"
        run bash tests/smoke/plugins-guest.sh
    fi
    section "Shell Login"
    run zsh -lic 'command -v dotfiles && command -v brew && command -v git && command -v rg && command -v tmux'
    run zsh -lic 'zplug check'

    section "Commands"
    for command in dotfiles brew git zsh rg tmux gh jq fd eza bat; do
        expect_command "$command"
    done

    section "Homebrew Formulas"
    for formula in git ripgrep tmux gh jq fd eza bat shellcheck zplug; do
        expect_brew_formula "$formula"
    done
fi

if should_install_step javascript; then
    section "JavaScript Tooling"
    run zsh -lic 'test "$(nvm current)" = "$(nvm version default)" && node --version && npm --version'
fi

if should_install_step python; then
    section "Python Tooling"
    run zsh -lic 'python --version && python3 --version && python -c "import sys, ssl, sqlite3, venv; assert sys.version_info.major == 3" && uv --version'
    expect_brew_formula python
    expect_brew_formula uv
fi

if should_install_step java; then
    section "Java Tooling"
    run zsh -lic 'java -version && javac -version && jenv version-name'
    expect_brew_formula openjdk@17
    expect_brew_formula openjdk@21
fi

if should_install_step macos; then
    section "macOS Defaults"
    run ./bin/dotfiles macos audit --profile "$PROFILE"
fi

if should_install_step brew; then
    section "Applications"
    if [ "${DOTFILES_SMOKE_EXPECT_CASKS:-true}" = true ]; then
        expect_app "Google Chrome"
        expect_app "Visual Studio Code"
        expect_app "iTerm"
        expect_app "ChatGPT"
        expect_app "Obsidian"
        expect_app "Android Studio"
        expect_app "Windows App"
        for removed_app in "IntelliJ IDEA" "IntelliJ IDEA CE"; do
            if [ -d "/Applications/$removed_app.app" ] || [ -d "$HOME/Applications/$removed_app.app" ]; then
                fail "excluded app is still present: $removed_app"
            fi
        done
    else
        echo "Skipping cask app assertions."
    fi
fi

section "Idempotency"
if [ "$VERIFY_ONLY" != true ]; then
    install_selected
fi

section "Complete declared inventory"
selected_steps=""
for step in symlinks brew macos javascript java python; do
    if should_install_step "$step"; then selected_steps="${selected_steps:+$selected_steps,}$step"; fi
done
verify_args=(--steps "$selected_steps" --profile "$PROFILE")
if [ "$DOTFILES_SMOKE_EXPECT_CASKS" != true ]; then verify_args+=(--skip-casks); fi
verification_status=0
run zsh -lic 'python3 scripts/setup-state.py verify "$@"' _ "${verify_args[@]}" || verification_status=$?
if [ "$verification_status" -ne 0 ] && [ "$verification_status" -ne 2 ]; then exit "$verification_status"; fi
if should_install_step brew && [ "$DOTFILES_SMOKE_EXPECT_CASKS" = true ]; then
    python3 scripts/appstore.py verify --status-file "$DOTFILES_APPSTORE_STATUS_FILE" || true
fi

result_file="$LOG_DIR/install-result.json"
if [ "$VERIFY_ONLY" = true ]; then result_file="$LOG_DIR/post-reboot-result.json"; fi
python3 - "$result_file" "$VERIFY_ONLY" "$DOTFILES_SETUP_NOTICES" "$verification_status" "$DOTFILES_APPSTORE_STATUS_FILE" <<'PY'
import json, sys
from pathlib import Path
verification_only = sys.argv[2] == 'true'
notices = Path(sys.argv[3])
data = {
    'installation': 'not-run' if verification_only else 'partial' if sys.argv[4] == '2' else 'passed',
    'core_installation': 'not-run' if verification_only else 'passed',
    'repeat_install': 'not-run' if verification_only else 'passed',
    'declared_inventory': 'partial' if sys.argv[4] == '2' else 'passed',
    'operational_notices': notices.read_text().splitlines() if notices.exists() else [],
    'baseline_comparison': 'not-run',
}
appstore=Path(sys.argv[5])
data['app_store']=json.loads(appstore.read_text()) if appstore.exists() else None
Path(sys.argv[1]).write_text(json.dumps(data, indent=2) + '\n')
PY
if [ "$verification_status" -eq 0 ]; then
    echo "SMOKE_DECLARED_OK profile=$PROFILE verify_only=$VERIFY_ONLY"
else
    echo "SMOKE_DECLARED_PARTIAL profile=$PROFILE verify_only=$VERIFY_ONLY"
fi

if [ -n "${DOTFILES_SMOKE_BASELINE:-}" ]; then
    section "Observed baseline comparison"
    run zsh -lic 'python3 scripts/setup-state.py capture --output "$1" --profile "$2"' _ "$LOG_DIR/observed.json" "$PROFILE"
    BASELINE_CAPTURED=true
    compare_args=("$DOTFILES_SMOKE_BASELINE" "$LOG_DIR/observed.json" --output "$LOG_DIR/comparison.json")
    if [ "${DOTFILES_SMOKE_EXACT_VERSIONS:-false}" = true ]; then compare_args+=(--exact-versions); fi
    comparison_status=0
    run python3 scripts/setup-state.py compare "${compare_args[@]}" || comparison_status=$?
    python3 - "$result_file" "$LOG_DIR/comparison.json" <<'PY'
import json, sys
from pathlib import Path
result, comparison = map(Path, sys.argv[1:])
data = json.loads(result.read_text())
data['baseline_comparison'] = json.loads(comparison.read_text())['status'] if comparison.exists() else 'error'
result.write_text(json.dumps(data, indent=2) + '\n')
PY
    if [ "$verification_status" -ne 0 ]; then exit "$verification_status"; fi
    if [ "$comparison_status" -ne 0 ]; then exit "$comparison_status"; fi
fi

if [ "$verification_status" -ne 0 ]; then exit "$verification_status"; fi

section "Result"
echo "SMOKE_OK profile=$PROFILE log=$LOG_FILE"
