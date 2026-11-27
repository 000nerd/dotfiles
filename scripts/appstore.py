#!/usr/bin/env python3
"""Install the explicitly selected free App Store apps; never handle credentials."""
import argparse
import json
from pathlib import Path
import plistlib
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def apps():
    result = subprocess.check_output(["bash", "-c", 'source "$1/install/packages.sh"; dotfiles_appstore_manifest', "_", str(ROOT)], text=True)
    return [dict(zip(("id", "name", "bundle_id"), line.split("|"))) for line in result.splitlines()]


def installed(app, directories=None):
    for directory in directories or (Path("/Applications"), Path.home() / "Applications"):
        path = directory / app["name"]
        try:
            with (path / "Contents/Info.plist").open("rb") as stream:
                info = plistlib.load(stream)
            if info.get("CFBundleIdentifier") == app["bundle_id"] and (path / "Contents/_MASReceipt/receipt").is_file():
                return True
        except (OSError, ValueError, plistlib.InvalidFileException):
            pass
    return False


def install(selected, timeout=45):
    results = []
    for app in selected:
        if installed(app):
            results.append({**app, "status": "installed"})
            continue
        reason = None
        try:
            result = subprocess.run(["mas", "get", app["id"]], capture_output=True, text=True, timeout=timeout)
            if result.returncode: reason = "mas-exit-" + str(result.returncode)
        except subprocess.TimeoutExpired:
            reason = "App Store request timed out; authentication may be required"
        except OSError:
            reason = "mas is unavailable"
        if installed(app):
            results.append({**app, "status": "installed"})
        else:
            results.append({**app, "status": "pending", "reason": reason or "app receipt not yet verified",
                            "action": "Sign in to the App Store and install this free app; then enable it in Safari Extensions."})
    return {"status": "pending" if any(item["status"] == "pending" for item in results) else "installed", "apps": results}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("install", "verify"))
    parser.add_argument("--status-file", default=str(Path.home() / ".local/state/dotfiles/appstore-status.json"))
    args = parser.parse_args()
    if platform.system() != "Darwin":
        sys.exit("App Store apps require macOS")
    selected = apps()
    if args.command == "install":
        report = install(selected)
    else:
        report = {"status": "installed" if all(installed(app) for app in selected) else "pending", "apps": [{**app, "status": "installed" if installed(app) else "pending"} for app in selected]}
    path = Path(args.status_file); path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n"); path.chmod(0o600)
    print(json.dumps(report, indent=2))
    sys.exit(2 if report["status"] == "pending" else 0)
