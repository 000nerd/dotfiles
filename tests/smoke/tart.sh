#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

VM_NAME=${DOTFILES_TART_VM_NAME:-dotfiles-smoke}
IMAGE=${DOTFILES_TART_IMAGE:-ghcr.io/cirruslabs/macos-sequoia-base:latest}
PROFILE=${DOTFILES_SMOKE_PROFILE:-personal}
TART_USER=${DOTFILES_TART_USER:-admin}
TART_PASSWORD=${DOTFILES_TART_PASSWORD:-admin}
COMPUTER_NAME=${DOTFILES_COMPUTER_NAME:-Dotfiles Smoke}
HOST_NAME=${DOTFILES_HOST_NAME:-DotfilesSmoke}
MIN_FREE_GB=${DOTFILES_TART_MIN_FREE_GB:-80}
DISK_SIZE_GB=${DOTFILES_TART_DISK_SIZE_GB:-100}
FRESH=false
STOP_AFTER=false
SMOKE_DRY_RUN=false
INSTALL_CASKS=${DOTFILES_INSTALL_CASKS:-true}
INSTALL_ONLY=${DOTFILES_SMOKE_INSTALL_ONLY:-}
INSTALL_SKIP=${DOTFILES_SMOKE_INSTALL_SKIP:-}
SOURCE_MODE=working
BASELINE=""
VERIFY_ONLY=false
EXACT_VERSIONS=false

usage() {
    cat <<EOF
Usage: tests/smoke/tart.sh [options]

Create or reuse a Tart macOS VM, copy this checkout into it, and run the
guest smoke test.

Options:
  --vm name             Tart VM name. Default: $VM_NAME
  --image image         Tart image to clone. Default: $IMAGE
  --profile name        Dotfiles install profile. Default: $PROFILE
  --disk-size gb        Guest disk size in GB. Default: $DISK_SIZE_GB
  --only steps          Run only selected install steps in the guest.
  --skip steps          Skip selected install steps in the guest.
  --skip-casks          Skip GUI app cask installs in the guest.
  --source working|head Export proposed nonignored files or committed HEAD.
  --baseline file       Compare the guest with an observed setup baseline.
  --verify-only         Check an existing guest without reinstalling.
  --exact-versions      Include package/app versions in baseline comparisons.
  --fresh               Delete and recreate the named VM before running.
  --dry-run-install     Run installer dry-run inside the VM.
  --stop-after          Stop the VM after the smoke test finishes.
  -h, --help            Show this help.

Useful environment overrides:
  DOTFILES_TART_USER, DOTFILES_TART_PASSWORD, DOTFILES_COMPUTER_NAME,
  DOTFILES_HOST_NAME, DOTFILES_TART_LOG_DIR, DOTFILES_TART_MIN_FREE_GB,
  DOTFILES_TART_DISK_SIZE_GB
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --vm | --image | --profile | --disk-size | --only | --skip | --source | --baseline)
            if [ -z "${2:-}" ] || [[ "$2" = -* ]]; then
                echo "Missing value for $1." >&2
                exit 2
            fi
            ;;
    esac
    case "$1" in
        --source) SOURCE_MODE="$2"; shift ;;
        --source=*) SOURCE_MODE="${1#*=}" ;;
        --baseline) BASELINE="$2"; shift ;;
        --baseline=*) BASELINE="${1#*=}" ;;
        --verify-only) VERIFY_ONLY=true ;;
        --exact-versions) EXACT_VERSIONS=true ;;
        --vm)
            VM_NAME="${2:-}"
            shift
            ;;
        --vm=*)
            VM_NAME="${1#*=}"
            ;;
        --image)
            IMAGE="${2:-}"
            shift
            ;;
        --image=*)
            IMAGE="${1#*=}"
            ;;
        --profile)
            PROFILE="${2:-}"
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            ;;
        --disk-size)
            DISK_SIZE_GB="${2:-}"
            shift
            ;;
        --disk-size=*)
            DISK_SIZE_GB="${1#*=}"
            ;;
        --only)
            INSTALL_ONLY="${2:-}"
            shift
            ;;
        --only=*)
            INSTALL_ONLY="${1#*=}"
            ;;
        --skip)
            INSTALL_SKIP="${2:-}"
            shift
            ;;
        --skip=*)
            INSTALL_SKIP="${1#*=}"
            ;;
        --skip-casks)
            INSTALL_CASKS=false
            ;;
        --fresh)
            FRESH=true
            ;;
        --dry-run-install)
            SMOKE_DRY_RUN=true
            ;;
        --stop-after)
            STOP_AFTER=true
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

case "$SOURCE_MODE" in working | head) ;; *) echo "Invalid source mode: $SOURCE_MODE" >&2; exit 2 ;; esac
[[ "$VM_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { echo "Invalid VM name." >&2; exit 2; }
[[ "$DISK_SIZE_GB" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid disk size." >&2; exit 2; }
[[ "$MIN_FREE_GB" =~ ^[0-9]+$ ]] || { echo "Invalid free-space threshold." >&2; exit 2; }
if [ "$VERIFY_ONLY" = true ] && { [ "$FRESH" = true ] || [ "$SMOKE_DRY_RUN" = true ]; }; then
    echo "--verify-only cannot be combined with --fresh or --dry-run-install." >&2
    exit 2
fi
if [ -n "$BASELINE" ] && [ ! -f "$BASELINE" ]; then
    echo "Baseline not found: $BASELINE" >&2
    exit 2
fi
LOG_DIR=${DOTFILES_TART_LOG_DIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/tart-smoke/$VM_NAME"}

missing_commands=()
for command in tart sshpass ssh rsync python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        missing_commands+=("$command")
    fi
done

if [ "${#missing_commands[@]}" -gt 0 ]; then
    echo "Missing required command(s): ${missing_commands[*]}" >&2
    echo "Install Tart and sshpass with:" >&2
    echo "  brew install cirruslabs/cli/tart cirruslabs/cli/sshpass" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i -w "$$" >/dev/null 2>&1 &
fi

SSH_CONTROL_PATH=${DOTFILES_TART_SSH_CONTROL_PATH:-"/tmp/dotfiles-tart-${UID}-%C"}
SSH_OPTIONS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=10
    -o PreferredAuthentications=password
    -o PubkeyAuthentication=no
    -o ControlMaster=auto
    -o ControlPersist=120
    -o "ControlPath=$SSH_CONTROL_PATH"
)

vm_exists() {
    tart list 2>/dev/null | awk -v vm="$VM_NAME" 'NR > 1 && $2 == vm { found = 1 } END { exit !found }'
}

vm_state() {
    tart list 2>/dev/null | awk -v vm="$VM_NAME" 'NR > 1 && $2 == vm { print $NF; found = 1 } END { exit !found }'
}

check_free_space_for_clone() {
    local free_kb
    local free_gb

    free_kb=$(df -Pk "$HOME" | awk 'NR == 2 { print $4 }')
    free_gb=$((free_kb / 1024 / 1024))

    if [ "$free_gb" -lt "$MIN_FREE_GB" ]; then
        echo "Not enough free space to clone a macOS Tart image." >&2
        echo "Free: ${free_gb} GiB; required: ${MIN_FREE_GB} GiB." >&2
        echo "Set DOTFILES_TART_MIN_FREE_GB to override after choosing a smaller image or freeing space." >&2
        exit 1
    fi
}

ssh_guest() {
    sshpass -p "$TART_PASSWORD" ssh "${SSH_OPTIONS[@]}" "$TART_USER@$VM_IP" "$@"
}

rsync_ssh_command() {
    printf 'ssh'
    for option in "${SSH_OPTIONS[@]}"; do
        printf ' %q' "$option"
    done
}

copy_repo_to_guest() {
    echo "Copying $SOURCE_MODE source snapshot to $TART_USER@$VM_IP:~/.dotfiles"
    ssh_guest "mkdir -p ~/.dotfiles"
    sshpass -p "$TART_PASSWORD" rsync -az --delete \
        --exclude '.git/' \
        --exclude 'tmp/' \
        --exclude '__pycache__/' \
        --exclude '.DS_Store' \
        -e "$(rsync_ssh_command)" \
        "$STAGING_ROOT/source/" "$TART_USER@$VM_IP:.dotfiles/"
}

copy_logs_from_guest() {
    [ -n "${VM_IP:-}" ] || return 0
    echo "Copying guest smoke logs to $LOG_DIR/guest"
    mkdir -p "$LOG_DIR/guest"
    sshpass -p "$TART_PASSWORD" rsync -az \
        -e "$(rsync_ssh_command)" \
        "$TART_USER@$VM_IP:dotfiles-smoke-logs/" "$LOG_DIR/guest/" >/dev/null 2>&1 || true
}

cleanup() {
    status=$?
    copy_logs_from_guest
    if [ -n "${VM_IP:-}" ]; then
        ssh -O exit "${SSH_OPTIONS[@]}" "$TART_USER@$VM_IP" >/dev/null 2>&1 || true
    fi
    if [ "$STOP_AFTER" = true ] && [ -n "${VM_IP:-}" ]; then
        echo "Stopping Tart VM $VM_NAME"
        tart stop "$VM_NAME" >/dev/null 2>&1 || true
    fi
    if [ -n "${STAGING_ROOT:-}" ]; then
        rm -rf "$STAGING_ROOT"
    fi
    return "$status"
}
trap cleanup EXIT

STAGING_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-source.XXXXXX")
python3 "$ROOT_DIR/tests/smoke/export-source.py" --source "$SOURCE_MODE" --output "$STAGING_ROOT/source"
for required in tests/smoke/macos-guest.sh scripts/setup-state.py install/packages.sh; do
    if [ ! -f "$STAGING_ROOT/source/$required" ]; then
        echo "Source $SOURCE_MODE lacks $required; commit the harness before testing HEAD." >&2
        exit 1
    fi
done
cp "$STAGING_ROOT/source/.dotfiles-source.json" "$LOG_DIR/source.json"
if [ -n "$BASELINE" ]; then
    cp "$BASELINE" "$STAGING_ROOT/source/.dotfiles-baseline.json"
    cp "$BASELINE" "$LOG_DIR/baseline.json"
fi
plan_args=(--profile "$PROFILE" --dry-run)
[ -z "$INSTALL_ONLY" ] || plan_args+=(--only "$INSTALL_ONLY")
[ -z "$INSTALL_SKIP" ] || plan_args+=(--skip "$INSTALL_SKIP")
"$STAGING_ROOT/source/install.sh" "${plan_args[@]}"

if [ "$VERIFY_ONLY" = true ] && ! vm_exists; then
    echo "--verify-only requires an existing VM: $VM_NAME" >&2
    exit 1
fi

if [ "$FRESH" = true ] && vm_exists; then
    echo "Deleting existing Tart VM $VM_NAME"
    tart stop "$VM_NAME" >/dev/null 2>&1 || true
    tart delete "$VM_NAME"
fi

if ! vm_exists; then
    check_free_space_for_clone
    echo "Cloning $IMAGE as $VM_NAME"
    tart clone "$IMAGE" "$VM_NAME"
fi

if [ "$VERIFY_ONLY" != true ] && [ -n "$DISK_SIZE_GB" ]; then
    echo "Ensuring Tart VM $VM_NAME disk size is ${DISK_SIZE_GB}GB"
    tart set "$VM_NAME" --disk-size "$DISK_SIZE_GB"
fi

VM_STATE=$(vm_state || true)
if [ "$VM_STATE" != "running" ]; then
    echo "Starting Tart VM $VM_NAME"
    tart run "$VM_NAME" > "$LOG_DIR/tart-run.log" 2>&1 &
    echo "Tart run log: $LOG_DIR/tart-run.log"
fi

VM_IP=""
echo "Waiting for VM IP"
for _ in {1..120}; do
    if VM_IP=$(tart ip "$VM_NAME" 2>/dev/null) && [ -n "$VM_IP" ]; then
        break
    fi
    sleep 5
done

if [ -z "${VM_IP:-}" ]; then
    echo "Timed out waiting for Tart IP for $VM_NAME" >&2
    exit 1
fi

echo "Waiting for SSH on $VM_IP"
for _ in {1..120}; do
    if ssh_guest "echo ready" >/dev/null 2>&1; then
        break
    fi
    sleep 5
done

ssh_guest "echo ready" >/dev/null

copy_repo_to_guest

BASELINE_GUEST=""
[ -z "$BASELINE" ] || BASELINE_GUEST=.dotfiles-baseline.json
remote_command=$(printf 'cd ~/.dotfiles && DOTFILES_SMOKE_PROFILE=%q DOTFILES_COMPUTER_NAME=%q DOTFILES_HOST_NAME=%q DOTFILES_SUDO_PASSWORD=%q DOTFILES_SMOKE_DRY_RUN=%q DOTFILES_INSTALL_CASKS=%q DOTFILES_SMOKE_EXPECT_CASKS=%q DOTFILES_SMOKE_INSTALL_ONLY=%q DOTFILES_SMOKE_INSTALL_SKIP=%q DOTFILES_SMOKE_BASELINE=%q DOTFILES_SMOKE_VERIFY_ONLY=%q DOTFILES_SMOKE_EXACT_VERSIONS=%q ./tests/smoke/macos-guest.sh' \
    "$PROFILE" "$COMPUTER_NAME" "$HOST_NAME" "$TART_PASSWORD" "$SMOKE_DRY_RUN" "$INSTALL_CASKS" "$INSTALL_CASKS" "$INSTALL_ONLY" "$INSTALL_SKIP" "$BASELINE_GUEST" "$VERIFY_ONLY" "$EXACT_VERSIONS")

echo "Running guest smoke test for profile '$PROFILE'"
ssh_guest "$remote_command"

echo "Tart smoke test passed for $VM_NAME ($VM_IP)."
