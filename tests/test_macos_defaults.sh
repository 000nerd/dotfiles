#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOTFILES="$ROOT_DIR/bin/dotfiles"
TEST_ROOT=${TEST_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-defaults.XXXXXX")}

if [ -e "$TEST_ROOT" ] && [ -n "$(ls -A "$TEST_ROOT")" ]; then
    echo "Test directory must be empty: $TEST_ROOT" >&2
    exit 1
fi
mkdir -p "$TEST_ROOT/fake-bin"

echo "Testing canonical macOS defaults registry"
echo "=========================================="

personal_list=$($DOTFILES macos list --profile personal)
grep -q $'personal\tuser\tNSGlobalDomain\tAppleActionOnDoubleClick\tFill' <<< "$personal_list"
grep -q $'personal\tuser\tcom.apple.finder\tShowPathbar\ttrue' <<< "$personal_list"
grep -q $'personal\tuser\tcom.apple.finder\tFXPreferredViewStyle\ticnv' <<< "$personal_list"
grep -q $'personal\tuser\tcom.apple.finder\tNewWindowTarget\tPfDe' <<< "$personal_list"
if grep -Eq $'\t(magnification|orientation|mineffect|tilesize|NSAutomaticCapitalizationEnabled|AppleShowAllExtensions)\t' <<< "$personal_list"; then
    echo "Default or unverified preferences unexpectedly became managed settings." >&2
    exit 1
fi
personal_count=$(python3 -c 'import json,sys; print(sum(e.get("apply",False) for e in json.load(open(sys.argv[1]))["entries"])+7)' "$ROOT_DIR/install/macos/defaults/captured-personal.json")
grep -q "Total settings: $personal_count" <<< "$personal_list"

work_list=$($DOTFILES macos list --profile work)
grep -q 'Total settings: 44' <<< "$work_list"
if grep -q $'personal\t' <<< "$work_list"; then
    echo "Work defaults unexpectedly include personal settings." >&2
    exit 1
fi

if $DOTFILES macos list --profile unknown >/dev/null 2>&1; then
    echo "Unknown macOS defaults profile unexpectedly succeeded." >&2
    exit 1
fi

# A fake defaults command makes audit exercise the complete registry without
# reading or changing the host. Every read is reported as missing.
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$TEST_ROOT/fake-bin/defaults"
chmod +x "$TEST_ROOT/fake-bin/defaults"
if PATH="$TEST_ROOT/fake-bin:$PATH" $DOTFILES macos audit --profile personal \
    > "$TEST_ROOT/audit.log" 2>&1; then
    echo "Audit unexpectedly passed with every setting missing." >&2
    exit 1
fi
grep -q "Audit summary: total=$personal_count matched=0 drifted=0 missing=$personal_count unverified=0" \
    "$TEST_ROOT/audit.log"

# Reversible aliases must route through the canonical toggle implementation.
toggle_log="$TEST_ROOT/toggles.log"
(
    defaults() { printf 'defaults %s\n' "$*" >> "$toggle_log"; }
    killall() { printf 'killall %s\n' "$*" >> "$toggle_log"; }
    # shellcheck source=install/macos/defaults/toggles.sh
    source "$ROOT_DIR/install/macos/defaults/toggles.sh"
    dotfiles_macos_toggle hidden-files on
    dotfiles_macos_toggle hidden-files off
    dotfiles_macos_toggle desktop-icons off
    dotfiles_macos_toggle desktop-icons on
)
grep -q 'defaults write com.apple.finder AppleShowAllFiles -bool true' "$toggle_log"
grep -q 'defaults write com.apple.finder AppleShowAllFiles -bool false' "$toggle_log"
grep -q 'defaults write com.apple.finder CreateDesktop -bool false' "$toggle_log"
grep -q 'defaults write com.apple.finder CreateDesktop -bool true' "$toggle_log"

# Raw active writes are allowed only in the registry implementation and its
# named toggles. This keeps future one-off writes from bypassing classification.
violations=""
while IFS= read -r file; do
    case "$file" in
        install/macos/defaults/* | tests/*) continue ;;
        *.sh | *.bash | bin/* | config/zsh/*) ;;
        *) continue ;;
    esac
    matches=$(grep -nE '(sudo[[:space:]]+)?defaults[[:space:]]+(-currentHost[[:space:]]+)?write[[:space:]]' \
        "$ROOT_DIR/$file" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)
    if [ -n "$matches" ]; then
        violations="${violations}${file}:${matches}\n"
    fi
done < <(cd "$ROOT_DIR" && find bin install scripts config/zsh -type f)

if [ -n "$violations" ]; then
    printf 'Unclassified macOS defaults writes found:\n%b' "$violations" >&2
    exit 1
fi

echo "macOS defaults registry test passed."
