#!/usr/bin/env python3
"""Capture portable typed UI preferences without exporting private domains."""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "install/macos/defaults/capture-policy.json"


def domain_filename(target, domain):
    return hashlib.sha256((target + "|" + domain).encode()).hexdigest() + ".plist"


def portable(value, home):
    if isinstance(value, str):
        if value.startswith(str(home) + "/") or value == str(home):
            return "__DOTFILES_HOME__" + value[len(str(home)):]
        if value.startswith("file://" + str(home) + "/"):
            return "file://__DOTFILES_HOME__" + value[len("file://" + str(home)):]
    return value


def kind(value):
    if isinstance(value, bool): return "bool"
    if isinstance(value, int): return "int"
    if isinstance(value, float) and math.isfinite(value): return "float"
    if isinstance(value, str) and not any(c in value for c in "\n\r\t\0"): return "string"
    if isinstance(value, dict) and value and all(k.isalnum() and isinstance(v, (bool, int)) and v in (0, 1) for k, v in value.items()):
        return "dict-bool"
    return None


def capture(policy, directory=None, home=None):
    home = Path(home or Path.home())
    entries, unavailable, excluded = [], [], []
    for spec in policy["domains"]:
        target, domain = spec["target"], spec["domain"]
        try:
            if directory:
                raw = (Path(directory) / domain_filename(target, domain)).read_bytes()
            else:
                args = ["defaults"] + (["-currentHost"] if target == "current-host" else []) + ["export", domain, "-"]
                result = subprocess.run(args, capture_output=True, timeout=20)
                if result.returncode: raise ValueError("domain unavailable")
                raw = result.stdout
            data = plistlib.loads(raw)
        except (OSError, ValueError, plistlib.InvalidFileException, subprocess.TimeoutExpired):
            unavailable.append(target + "|" + domain)
            continue
        for key in spec["keys"]:
            if key not in data: continue
            value = data[key]
            value_kind = kind(value)
            if not value_kind:
                excluded.append(target + "|" + domain + "|" + key + ": unsupported type")
                continue
            entries.append({"target": target, "domain": domain, "key": key, "kind": value_kind,
                            "value": portable(value, home), "restart": spec["restart"]})
    return {"entries": entries, "unavailable_domains": unavailable, "excluded": excluded}


def build(current, reference, policy=None):
    policy = policy or json.loads(POLICY.read_text())
    allowed = {(spec['target'], spec['domain'], key) for spec in policy['domains'] for key in spec['keys']}
    lookup = {(e["target"], e["domain"], e["key"]): e for e in reference["entries"]}
    selected, same = [], []
    same_os = current.get("macos") == reference.get("macos")
    for entry in current["entries"]:
        key = (entry["target"], entry["domain"], entry["key"])
        if key not in allowed or kind(entry['value']) != entry['kind']:
            raise ValueError("Preference is not permitted by the capture policy: " + "|".join(key))
        before = lookup.get(key)
        if before and before["kind"] == entry["kind"] and before["value"] == entry["value"]:
            same.append(entry)
            status = "same-as-reference"
        elif before:
            status = "different-from-reference"
        else:
            status = "reference-missing; factory-default-unknown"
        # Capturing a setting is not authorization to pin a macOS default.
        # Provisioned/cross-version references are comparison evidence only.
        apply = bool(status == "different-from-reference" and same_os
                     and reference.get("factory_defaults_verified") is True)
        selected.append({**entry, "comparison": status, "apply": apply,
                         "management": "apply-nondefault" if apply else "leave-default" if status == "same-as-reference" else "needs-default-verification",
                         "default_confidence": "same-os-reference" if same_os and before else "provisional",
                         "reference_value": before["value"] if before else None})
    return {"schema_version": 1, "captured_at": current["captured_at"], "macos": current.get("macos"),
            "reference_macos": reference.get("macos"), "same_os_version": same_os,
            "reference_context": {key: reference.get(key) for key in ('desktop_ready', 'image', 'reference_kind', 'factory_defaults_verified')},
            "rule": "Apply only verified non-default differences. Leave reference matches and unknown/provisional defaults unmanaged. Separately reviewed intentional overrides are explicit.",
            "entries": selected, "same_as_reference_count": len(same),
            "unavailable_current_domains": current.get("unavailable_domains", []),
            "unavailable_reference_domains": reference.get("unavailable_domains", [])}


def render(snapshot):
    lines = ["#!/usr/bin/env bash", "", "# Generated by scripts/preferences.py; named portable UI preferences only.",
             "# Evidence: captured-personal.json. Only verified non-default differences are applied.",
             "# Reference matches and unverified defaults remain unmanaged.",
             "# Separately reviewed Dock/window overrides are applied afterward.", ""]
    for entry in snapshot["entries"]:
        if entry["kind"] not in {"bool", "int", "float", "string", "dict-bool"}:
            raise ValueError("Unsupported preference type")
        if entry.get("apply") is not True:
            continue
        value = entry["value"]
        if entry["kind"] == "bool": value = str(value).lower()
        elif entry["kind"] == "dict-bool": value = ",".join(k + "=" + str(bool(v)).lower() for k, v in sorted(value.items()))
        else: value = str(value)
        command = "dotfiles_default_" + entry["kind"].replace("-", "_")
        args = ["personal", entry["target"], entry["domain"], entry["key"], value, entry["restart"], "Preserve current " + entry["key"]]
        lines.append(command + " " + " ".join(shlex.quote(x) for x in args))
    return "\n".join(lines) + "\n"


def write(path, data):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n"); path.chmod(0o600)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    cap = sub.add_parser("capture"); cap.add_argument("--output", required=True); cap.add_argument("--directory"); cap.add_argument("--macos"); cap.add_argument("--home")
    make = sub.add_parser("build"); make.add_argument("current"); make.add_argument("reference"); make.add_argument("--output", required=True); make.add_argument("--shell-output", required=True)
    args = parser.parse_args()
    if args.command == "capture":
        data = capture(json.loads(POLICY.read_text()), args.directory, args.home)
        if args.macos: version = args.macos
        else: version = subprocess.check_output(["sw_vers", "-productVersion"], text=True).strip()
        write(args.output, {**data, "macos": version, "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat()})
        print("Captured " + str(len(data["entries"])) + " named portable preferences")
    else:
        snapshot = build(json.loads(Path(args.current).read_text()), json.loads(Path(args.reference).read_text()))
        write(args.output, snapshot)
        Path(args.shell_output).write_text(render(snapshot))
        print("Compared " + str(len(snapshot["entries"])) + " preferences; generated " + str(sum(e['apply'] for e in snapshot['entries'])) + " verified non-default declarations")
