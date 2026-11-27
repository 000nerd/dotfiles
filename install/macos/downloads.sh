#!/usr/bin/env bash

# Only VLC's official mirror is allowed here. Homebrew still installs the
# original cask, with its original checksum, signature, and quarantine checks.
dotfiles_cache_vlc_from_official_mirror() {
    local metadata details mirror_url expected cache_file temporary actual
    metadata=$(brew info --cask --json=v2 vlc) || return $?
    details=$(printf '%s' "$metadata" | python3 -c '
import json, re, sys
cask = json.load(sys.stdin)["casks"][0]
url, checksum = cask["url"], cask["sha256"]
prefix = "https://get.videolan.org/"
if not url.startswith(prefix) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
    sys.exit("VLC fallback requires the official HTTPS URL and a pinned SHA-256")
print("https://download.videolan.org/pub/videolan/" + url[len(prefix):])
print(checksum)
') || return $?
    mirror_url=${details%%$'\n'*}
    expected=${details#*$'\n'}
    cache_file=$(brew --cache --cask vlc) || return $?
    mkdir -p "$(dirname "$cache_file")" || return $?
    temporary=$(mktemp "${cache_file}.mirror.XXXXXX") || return $?
    echo "Trying VLC's official mirror: $mirror_url"
    if ! curl --fail --location --retry 3 --proto '=https' --silent --show-error --output "$temporary" "$mirror_url"; then
        rm -f "$temporary"
        return 1
    fi
    actual=$(shasum -a 256 "$temporary" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "VLC mirror checksum does not match Homebrew metadata; refusing the download." >&2
        rm -f "$temporary"
        return 1
    fi
    mv "$temporary" "$cache_file" || return $?
    echo "VLC mirror artifact matches Homebrew SHA-256: $expected"
}
