#!/usr/bin/env python3
"""Apply dotfiles theme profiles to local applications."""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PROFILE_DIR = ROOT / "themes" / "profiles"


def info(message: str) -> None:
    print(message)


def warn(message: str) -> None:
    print(f"warn: {message}", file=sys.stderr)


def expand_path(value: str | Path) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(str(value))))


def repo_path(value: str | Path) -> Path:
    path = expand_path(value)
    if path.is_absolute():
        return path
    return ROOT / path


def backup_file(path: Path, dry_run: bool) -> None:
    if not path.exists():
        return
    stamp = dt.datetime.now().strftime("%Y%m%d%H%M%S")
    backup = path.with_name(f"{path.name}.bak.{stamp}")
    if dry_run:
        info(f"[dry-run] Would back up {path} to {backup}")
    else:
        shutil.copy2(path, backup)


def atomic_write_text(path: Path, text: str, dry_run: bool) -> None:
    if dry_run:
        info(f"[dry-run] Would write {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def strip_jsonc(text: str) -> str:
    text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r",(\s*[}\]])", r"\1", text)


def read_json(path: Path, *, jsonc: bool = False) -> dict[str, Any]:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    return json.loads(strip_jsonc(text) if jsonc else text)


def write_json(path: Path, data: dict[str, Any], dry_run: bool) -> None:
    backup_file(path, dry_run)
    atomic_write_text(path, json.dumps(data, indent=2, sort_keys=False) + "\n", dry_run)


def load_profile(name: str) -> dict[str, Any]:
    path = PROFILE_DIR / f"{name}.json"
    if not path.exists():
        raise SystemExit(f"Theme profile not found: {path}")
    return read_json(path)


def list_profiles(_: argparse.Namespace) -> None:
    for path in sorted(PROFILE_DIR.glob("*.json")):
        profile = read_json(path)
        print(profile.get("name", path.stem))


def current_theme(_: argparse.Namespace) -> None:
    state_file = expand_path(os.environ.get("DOTFILES_THEME_STATE_FILE", "~/.dotfiles-state/theme-current"))
    if state_file.exists():
        print(state_file.read_text(encoding="utf-8").strip())
    else:
        print("none")


def selected_apps(args: argparse.Namespace, profile: dict[str, Any]) -> list[str]:
    apps = profile.get("apps", {})
    if args.apps:
        requested = [app.strip().lower() for app in args.apps.split(",") if app.strip()]
        unknown = [app for app in requested if app not in apps]
        if unknown:
            raise SystemExit(f"Theme does not define app(s): {', '.join(unknown)}")
        return requested
    return sorted(apps.keys())


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def run_or_log(command: list[str], dry_run: bool) -> None:
    log_path = os.environ.get("DOTFILES_THEME_COMMAND_LOG")
    if dry_run:
        info("[dry-run] Would run: " + " ".join(command))
    elif log_path:
        path = expand_path(log_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(" ".join(command) + "\n")
    else:
        subprocess.run(command, check=False)


def apply_vscode(config: dict[str, Any], args: argparse.Namespace) -> None:
    settings_path = expand_path(
        os.environ.get(
            "DOTFILES_VSCODE_SETTINGS_PATH",
            "~/Library/Application Support/Code/User/settings.json" if sys.platform == "darwin" else "~/.config/Code/User/settings.json",
        )
    )
    settings = read_json(settings_path, jsonc=True)
    settings["workbench.colorTheme"] = config["colorTheme"]
    info(f"VS Code: set workbench.colorTheme to {config['colorTheme']}")
    write_json(settings_path, settings, args.dry_run)

    missing = []
    if os.environ.get("DOTFILES_THEME_SKIP_EXTENSION_CHECK"):
        missing = []
    elif config.get("extensions") and command_exists("code"):
        result = subprocess.run(["code", "--list-extensions"], capture_output=True, text=True, check=False)
        installed = set(result.stdout.splitlines())
        missing = [ext for ext in config["extensions"] if ext not in installed]
    elif config.get("extensions"):
        missing = list(config["extensions"])

    for extension in missing:
        if args.install_missing:
            run_or_log(["code", "--install-extension", extension], args.dry_run)
        else:
            warn(f"VS Code extension may be needed: {extension}")


def apply_codex(config: dict[str, Any], args: argparse.Namespace) -> None:
    state_path = expand_path(os.environ.get("DOTFILES_CODEX_STATE_PATH", "~/.codex/.codex-global-state.json"))
    state = read_json(state_path)
    state["appearanceTheme"] = config.get("appearanceTheme", state.get("appearanceTheme", "system"))
    state["appearanceLightCodeThemeId"] = config["lightCodeThemeId"]
    state["appearanceDarkCodeThemeId"] = config["darkCodeThemeId"]
    state["appearanceLightChromeTheme"] = config["lightChromeTheme"]
    state["appearanceDarkChromeTheme"] = config["darkChromeTheme"]
    info(f"Codex: set code theme to {config['darkCodeThemeId']} and chrome colors from profile")
    write_json(state_path, state, args.dry_run)
    warn("Codex may need a restart to pick up theme changes.")


def apply_iterm(config: dict[str, Any], args: argparse.Namespace) -> None:
    color_file = repo_path(config["colorFile"])
    if not color_file.exists():
        warn(f"iTerm color file not found: {color_file}")
        return
    info(f"iTerm: import {color_file}")
    run_or_log(["open", str(color_file)], args.dry_run)
    warn("iTerm imports the color preset; select it in the active profile if it does not switch automatically.")


def apply_terminal(config: dict[str, Any], args: argparse.Namespace) -> None:
    color_file = repo_path(config["colorFile"])
    if not color_file.exists():
        warn(f"Terminal color file not found: {color_file}")
        return
    info(f"Terminal: import {color_file}")
    run_or_log(["open", str(color_file)], args.dry_run)
    warn("Terminal imports the profile; make it default in Terminal settings if needed.")


def intellij_color_dirs() -> list[Path]:
    override = os.environ.get("DOTFILES_INTELLIJ_COLORS_DIRS")
    if override:
        return [expand_path(item) for item in override.split(os.pathsep) if item]
    if sys.platform == "darwin":
        patterns = [
            "~/Library/Application Support/JetBrains/*/colors",
            "~/Library/Preferences/IntelliJ*/colors",
            "~/Library/Preferences/IdeaIC*/colors",
            "~/Library/Preferences/PyCharm*/colors",
            "~/Library/Preferences/WebStorm*/colors",
            "~/Library/Preferences/AndroidStudio*/colors",
        ]
    else:
        patterns = ["~/.config/JetBrains/*/colors", "~/.IntelliJ*/config/colors", "~/.IdeaIC*/config/colors"]
    dirs = []
    for pattern in patterns:
        dirs.extend(Path(path) for path in glob.glob(str(expand_path(pattern))))
    return sorted(set(dirs))


def apply_intellij(config: dict[str, Any], args: argparse.Namespace) -> None:
    scheme_file = repo_path(config["schemeFile"])
    if not scheme_file.exists():
        warn(f"IntelliJ scheme file not found: {scheme_file}")
        return
    dirs = intellij_color_dirs()
    if not dirs:
        warn("No JetBrains colors directories found. Open IntelliJ once, then rerun theme apply.")
        return
    for colors_dir in dirs:
        target = colors_dir / scheme_file.name
        info(f"IntelliJ: install {scheme_file.name} to {colors_dir}")
        if args.dry_run:
            info(f"[dry-run] Would copy {scheme_file} to {target}")
        else:
            colors_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(scheme_file, target)
    warn("JetBrains IDEs may need restart/reselecting the color scheme.")


def obsidian_vaults(config: dict[str, Any]) -> list[Path]:
    override = os.environ.get("DOTFILES_OBSIDIAN_VAULTS")
    if override:
        return [expand_path(item) for item in override.split(os.pathsep) if item]
    return [expand_path(item) for item in config.get("vaults", [])]


def apply_obsidian(config: dict[str, Any], args: argparse.Namespace) -> None:
    vaults = obsidian_vaults(config)
    if not vaults:
        warn("No Obsidian vaults configured for this theme.")
        return
    for vault in vaults:
        obsidian_dir = vault / ".obsidian"
        if not obsidian_dir.exists():
            warn(f"Obsidian vault not found or not initialized: {vault}")
            continue
        appearance_path = obsidian_dir / "appearance.json"
        appearance = read_json(appearance_path)
        css_theme = config.get("cssTheme")
        if css_theme:
            theme_css = obsidian_dir / "themes" / css_theme / "theme.css"
            if theme_css.exists() or args.force:
                appearance["cssTheme"] = css_theme
                info(f"Obsidian: set {vault} cssTheme to {css_theme}")
            else:
                warn(f"Obsidian theme '{css_theme}' is not installed in {vault}")
        if config.get("accentColor"):
            appearance["accentColor"] = config["accentColor"]
        write_json(appearance_path, appearance, args.dry_run)


APPLIERS = {
    "codex": apply_codex,
    "intellij": apply_intellij,
    "iterm": apply_iterm,
    "obsidian": apply_obsidian,
    "terminal": apply_terminal,
    "vscode": apply_vscode,
}


def apply_theme(args: argparse.Namespace) -> None:
    profile = load_profile(args.theme)
    apps = profile.get("apps", {})
    for app in selected_apps(args, profile):
        info(f"\nApplying {profile['name']} to {app}")
        APPLIERS[app](apps[app], args)

    state_file = expand_path(os.environ.get("DOTFILES_THEME_STATE_FILE", "~/.dotfiles-state/theme-current"))
    if args.dry_run:
        info(f"[dry-run] Would record current theme in {state_file}")
    else:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(profile["name"] + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="dotfiles theme")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List available theme profiles")
    list_parser.set_defaults(func=list_profiles)

    current_parser = subparsers.add_parser("current", help="Show the last applied theme")
    current_parser.set_defaults(func=current_theme)

    apply_parser = subparsers.add_parser("apply", help="Apply a theme profile")
    apply_parser.add_argument("theme", help="Theme profile name")
    apply_parser.add_argument("--apps", help="Comma-separated apps to apply")
    apply_parser.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    apply_parser.add_argument("--force", action="store_true", help="Apply even when an app asset cannot be verified")
    apply_parser.add_argument("--install-missing", action="store_true", help="Install missing app extensions when supported")
    apply_parser.set_defaults(func=apply_theme)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
