#!/usr/bin/env python3
"""Read-only, allowlisted setup inventory, declaration checks, and comparison.

No complete preference domains, shell environments, credentials, SSH keys,
browser profiles, histories, or application configuration files are exported.
An observed baseline is evidence, not an installation policy.
"""

import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from appstore import apps as app_store_apps, installed as app_store_installed
HOME = Path.home()
ENV = {**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1"}


def run(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, env=ENV, timeout=90)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result if result.returncode == 0 else None


def normalized(value):
    return value.replace(str(ROOT), "$DOTFILES").replace(str(HOME), "$HOME")


def managed_links():
    for line in (ROOT / "install/links.tsv").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        source, relative = line.split("\t")
        yield ROOT / source, HOME / relative


def link_inventory():
    result = {}
    for source, target in managed_links():
        state, destination = "missing", None
        if target.is_symlink():
            destination = os.readlink(target)
            state = "correct" if target.exists() and destination == str(source) else "wrong-or-broken"
        elif target.exists():
            state = "unmanaged-file"
        result[str(target.relative_to(HOME))] = {"state": state, "target": normalized(destination) if destination else None}
    return result


def package_manifest():
    result = run(["bash", "-c", 'source "$1/install/packages.sh"; dotfiles_package_manifest "$2"', "_", str(ROOT), platform.system()])
    if result is None:
        raise RuntimeError("Unable to read the package declarations")
    return [dict(zip(("step", "kind", "name"), line.split("\t"))) for line in result.stdout.splitlines()]


def brew_inventory():
    data = {}
    for kind in ("formula", "cask"):
        result = run(["brew", "list", "--" + kind, "--versions"])
        data[kind] = {"status": "ok" if result else "unavailable", "items": {}}
        if result:
            for line in result.stdout.splitlines():
                fields = line.split()
                if fields:
                    data[kind]["items"][fields[0]] = fields[1:]
        elif kind == "cask":
            # A single stale Caskroom entry can make the combined query fail.
            names = run(["brew", "list", "--cask", "-1"])
            if names:
                data[kind]["status"] = "ok"
                data[kind]["unavailable_versions"] = []
                for name in names.stdout.splitlines():
                    version = run(["brew", "list", "--cask", "--versions", name])
                    data[kind]["items"][name] = version.stdout.split()[1:] if version else None
                    if version is None:
                        data[kind]["status"] = "partial"
                        data[kind]["unavailable_versions"].append(name)
    services = run(["brew", "services", "list", "--json"])
    try:
        items = [{"name": item["name"], "status": item.get("status")} for item in json.loads(services.stdout)] if services else []
        data["services"] = {"status": "ok" if services else "unavailable", "items": items}
    except (ValueError, KeyError, TypeError):
        data["services"] = {"status": "unavailable", "items": []}
    return data


def tool_inventory():
    tools = {}
    for name, args in {"node": ["node", "--version"], "npm": ["npm", "--version"],
                       "python": ["python3", "--version"], "uv": ["uv", "--version"],
                       "java": ["java", "-version"], "jenv_default": ["jenv", "version-name"]}.items():
        result = run(args)
        tools[name] = {"status": "ok" if result else "unavailable",
                       "version": normalized((result.stdout or result.stderr).strip()) if result else None}
    return tools


def global_tools():
    npm = run(["npm", "list", "--global", "--depth=0", "--json"])
    try:
        dependencies = json.loads(npm.stdout).get("dependencies", {}) if npm else {}
        npm_data = {"status": "ok" if npm else "unavailable", "items": {key: item.get("version") for key, item in dependencies.items()}}
        npm_data["unavailable_versions"] = [name for name, version in npm_data["items"].items() if version is None]
        if npm_data["unavailable_versions"]:
            npm_data["status"] = "partial"
    except (ValueError, TypeError, AttributeError):
        npm_data = {"status": "unavailable", "items": {}}
    uv = run(["uv", "tool", "list"])
    uv_data = {"status": "ok" if uv else "unavailable", "items": {}}
    if uv:
        for line in uv.stdout.splitlines():
            match = re.match(r"^(\S+) v(\S+)", line)
            if match:
                uv_data["items"][match[1]] = match[2]
    return {"npm": npm_data, "uv-tool": uv_data}


def preferences(profile):
    listing = run([str(ROOT / "bin/dotfiles"), "macos", "list", "--profile", profile])
    if listing is None or platform.system() != "Darwin":
        return {"status": "unavailable", "items": {}}
    items = {}
    for line in listing.stdout.splitlines()[1:]:
        fields = line.split("\t")
        if len(fields) != 7:
            continue
        scope, target, domain, key, intended, restart, description = fields
        args = ["defaults"] + (["-currentHost"] if target == "current-host" else []) + ["read", domain, key]
        result = run(args)
        items["|".join((target, domain, key))] = {
            "status": "readable" if result else "missing-or-unreadable",
            "observed": normalized(result.stdout.strip()) if result else None,
            "declared": normalized(intended), "description": description,
        }
    return {"status": "ok", "items": items}


def app_inventory():
    items, unavailable = {}, []
    for directory in (Path("/Applications"), HOME / "Applications"):
        if not directory.exists():
            continue
        try:
            apps = sorted(directory.glob("*.app"))
        except OSError:
            unavailable.append(normalized(str(directory)))
            continue
        for app in apps:
            try:
                with (app / "Contents/Info.plist").open("rb") as stream:
                    info = plistlib.load(stream)
                items[app.name] = {"id": info.get("CFBundleIdentifier"), "version": info.get("CFBundleShortVersionString"), "build": info.get("CFBundleVersion")}
            except (OSError, ValueError, plistlib.InvalidFileException):
                unavailable.append(app.name)
    return {"status": "partial" if unavailable else "ok", "items": items, "unavailable": unavailable}


def extensions():
    path = HOME / ".vscode/extensions/extensions.json"
    if not path.exists():
        return {"status": "unavailable", "items": {}}
    try:
        data = json.loads(path.read_text())
        return {"status": "ok", "items": {item["identifier"]["id"]: item.get("version") for item in data}}
    except (OSError, ValueError, KeyError, TypeError):
        return {"status": "unavailable", "items": {}}


def capture(profile):
    head = run(["git", "-C", str(ROOT), "rev-parse", "HEAD"])
    status = run(["git", "-C", str(ROOT), "status", "--porcelain"])
    macos = run(["sw_vers", "-productVersion"]) if platform.system() == "Darwin" else None
    return {"schema_version": 1, "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "purpose": "observed-current-setup; review differences before adopting as policy",
            "platform": {"system": platform.system(), "architecture": platform.machine(), "macos": macos.stdout.strip() if macos else None},
            "source": {"head": head.stdout.strip() if head else None, "dirty": bool(status.stdout.strip()) if status else None},
            "profile": profile, "brew": brew_inventory(), "runtimes": tool_inventory(),
            "global_tools": global_tools(), "preferences": preferences(profile), "links": link_inventory(),
            "applications": app_inventory(), "vscode_extensions": extensions(), "declared_packages": package_manifest(),
            "limits": ["Only selected preference keys; missing and unreadable are indistinguishable.",
                       "Application inventory covers top-level /Applications and ~/Applications bundles.",
                       "Services are observations; hardware behavior, GUI permissions, accounts, secrets, other editor settings and plugin readiness require separate checks."]}


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    path.chmod(0o600)


def compare(expected, actual, exact=False):
    if expected.get("schema_version") != 1 or actual.get("schema_version") != 1:
        raise ValueError("Unsupported baseline schema")
    differences, unverified = [], []

    def section(name, before, after, versions=True):
        if before.get("status") != "ok" or after.get("status") != "ok":
            unverified.append(name)
        a, b = before.get("items", {}), after.get("items", {})
        for key in sorted(set(a) | set(b)):
            if key not in a or key not in b or (versions and a[key] != b[key]):
                differences.append({"section": name, "item": key, "baseline": a.get(key), "actual": b.get(key)})

    for kind in ("formula", "cask"):
        section("brew." + kind, expected["brew"][kind], actual["brew"][kind], exact)
    for kind in ("npm", "uv-tool"):
        section("global_tools." + kind, expected["global_tools"][kind], actual["global_tools"][kind], exact)
    section("applications", expected["applications"], actual["applications"], exact)
    section("vscode_extensions", expected["vscode_extensions"], actual["vscode_extensions"], exact)
    for name in sorted(set(expected["runtimes"]) | set(actual["runtimes"])):
        before, after = expected["runtimes"].get(name), actual["runtimes"].get(name)
        if not before or not after or before["status"] != "ok" or after["status"] != "ok":
            unverified.append("runtime." + name)
        elif before != after:
            differences.append({"section": "runtimes", "item": name, "baseline": before, "actual": after})
    section("links", {"status": "ok", "items": expected["links"]}, {"status": "ok", "items": actual["links"]})
    if expected["preferences"]["status"] != "ok" or actual["preferences"]["status"] != "ok":
        unverified.append("preferences")
    before, after = expected["preferences"]["items"], actual["preferences"]["items"]
    for key in sorted(set(before) | set(after)):
        # Machine names intentionally differ in a disposable VM.
        if key.endswith("|NetBIOSName"):
            continue
        a, b = before.get(key), after.get(key)
        if not a or not b or a["status"] != "readable" or b["status"] != "readable":
            unverified.append("preference." + key)
        elif a["observed"] != b["observed"]:
            differences.append({"section": "preferences", "item": key, "baseline": a["observed"], "actual": b["observed"]})
    return {"differences": differences, "unverified": unverified,
            "services": {"baseline": expected["brew"].get("services"), "actual": actual["brew"].get("services")},
            "platform": {"baseline": expected["platform"], "actual": actual["platform"]},
            "exact_package_versions": exact,
            "status": "different" if differences else "partial" if unverified else "matched"}


def verify(steps, casks, profile="personal"):
    failed, unverified = [], []
    if "symlinks" in steps:
        failed += ["link " + path for path, info in link_inventory().items() if info["state"] != "correct"]
    globals_ = global_tools() if set(steps) & {"javascript", "python"} else {}
    for item in package_manifest():
        step, kind, name = item["step"], item["kind"], item["name"]
        if step not in steps or (kind in ("cask", "mas-app") and not casks):
            continue
        if kind == "mas-app":
            app = next(app for app in app_store_apps() if app["id"] == name)
            if not app_store_installed(app):
                unverified.append("App Store " + app["name"] + " (" + name + ")")
                print("pending App Store " + app["name"])
            else:
                print("ok App Store " + app["name"])
            continue
        elif kind in ("formula", "cask"):
            ok = run(["brew", "list", "--" + kind, name]) is not None
        else:
            if globals_[kind]["status"] not in ("ok", "partial"):
                unverified.append(kind + " " + name)
                print("unverified " + kind + " " + name)
                continue
            ok = name in globals_[kind]["items"]
        print(("ok " if ok else "missing ") + kind + " " + name)
        if not ok:
            failed.append(kind + " " + name)
    if "macos" in steps and run([str(ROOT / "bin/dotfiles"), "macos", "audit", "--profile", profile]) is None:
        failed.append("macOS defaults audit")
    print(json.dumps({"status": "failed" if failed else "partial" if unverified else "passed", "failures": failed, "unverified": unverified}, indent=2))
    return 1 if failed else 2 if unverified else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    cap = commands.add_parser("capture")
    cap.add_argument("--output", required=True)
    cap.add_argument("--profile", default="personal", choices=("common", "personal", "work"))
    comp = commands.add_parser("compare")
    comp.add_argument("baseline")
    comp.add_argument("actual")
    comp.add_argument("--output")
    comp.add_argument("--exact-versions", action="store_true")
    check = commands.add_parser("verify")
    check.add_argument("--steps", default="symlinks,brew,macos,javascript,java,python")
    check.add_argument("--skip-casks", action="store_true")
    check.add_argument("--profile", default="personal", choices=("common", "personal", "work"))
    args = parser.parse_args()
    if args.command == "capture":
        write_json(args.output, capture(args.profile))
        print("Captured observed baseline: " + args.output)
        return 0
    if args.command == "verify":
        steps = args.steps.split(",")
        if set(steps) - {"symlinks", "brew", "macos", "javascript", "java", "python"}:
            parser.error("Unknown verification step")
        return verify(steps, not args.skip_casks, args.profile)
    report = compare(json.loads(Path(args.baseline).read_text()), json.loads(Path(args.actual).read_text()), args.exact_versions)
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2))
    return {"matched": 0, "different": 1, "partial": 2}[report["status"]]


if __name__ == "__main__":
    sys.exit(main())
