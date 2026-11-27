#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VM=dotfiles-default-reference
IMAGE=ghcr.io/cirruslabs/macos-sequoia-vanilla:latest
OUTPUT="${DOTFILES_REFERENCE_OUTPUT:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/defaults-reference}"
mkdir -p "$OUTPUT/raw"
ssh_args=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no)
cleanup() { tart stop "$VM" >/dev/null 2>&1 || true; }
trap cleanup EXIT
if ! tart list | awk -v vm="$VM" 'NR > 1 && $2 == vm {found=1} END {exit !found}'; then
    free_gb=$(df -Pk "$HOME" | awk 'NR==2 {print int($4/1024/1024)}')
    [ "$free_gb" -ge 80 ] || { echo "Reference image requires 80 GiB free; found $free_gb." >&2; exit 1; }
    tart clone "$IMAGE" "$VM"
fi
tart run --no-graphics "$VM" > "$OUTPUT/tart.log" 2>&1 &
ip=""
for _ in {1..120}; do
    ip=$(tart ip "$VM" 2>/dev/null || true)
    if [ -n "$ip" ] && sshpass -p admin ssh "${ssh_args[@]}" "admin@$ip" true >/dev/null 2>&1; then break; fi
    sleep 5
done
[ -n "$ip" ] || { echo "Reference VM unavailable." >&2; exit 1; }
desktop_ready=false
for _ in {1..36}; do
    # Expansion must happen in the guest shell.
    # shellcheck disable=SC2016
    if sshpass -p admin ssh "${ssh_args[@]}" "admin@$ip" 'test "$(stat -f %Su /dev/console)" = admin && pgrep -u admin -x Finder >/dev/null && pgrep -u admin -x Dock >/dev/null' >/dev/null 2>&1; then
        desktop_ready=true
        break
    fi
    sleep 5
done
echo "Reference desktop_ready=$desktop_ready"
sshpass -p admin ssh "${ssh_args[@]}" "admin@$ip" 'sw_vers -productVersion' > "$OUTPUT/macos.txt"
while IFS=$'\t' read -r target domain filename; do
    host_arg=""
    [ "$target" != current-host ] || host_arg=-currentHost
    remote=$(printf 'defaults %s export %q -' "$host_arg" "$domain")
    # SSH must not consume the remaining domain records from this loop.
    sshpass -p admin ssh -n "${ssh_args[@]}" "admin@$ip" "$remote" > "$OUTPUT/raw/$filename" 2>/dev/null || true
done < <(python3 - "$ROOT_DIR" <<'PY'
import sys, json, hashlib
from pathlib import Path
policy=json.loads((Path(sys.argv[1])/'install/macos/defaults/capture-policy.json').read_text())
for spec in policy['domains']:
    name=hashlib.sha256((spec['target']+'|'+spec['domain']).encode()).hexdigest()+'.plist'
    print(spec['target'], spec['domain'], name, sep='\t')
PY
)
python3 "$ROOT_DIR/scripts/preferences.py" capture --directory "$OUTPUT/raw" --home /Users/admin --macos "$(cat "$OUTPUT/macos.txt")" --output "$OUTPUT/reference.json"
python3 - "$OUTPUT/reference.json" "$desktop_ready" "$IMAGE" <<'PY'
import sys, json
from pathlib import Path
p=Path(sys.argv[1]); d=json.loads(p.read_text())
d.update(desktop_ready=sys.argv[2]=='true', image=sys.argv[3], reference_kind='Tart vanilla with documented provisioning tweaks')
p.write_text(json.dumps(d, indent=2, sort_keys=True)+'\n')
PY
echo "REFERENCE_OK $OUTPUT/reference.json image=$IMAGE"
