#!/usr/bin/env python3
"""Apply dotfiles theme profiles to local applications."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PROFILE_DIR = ROOT / "config" / "themes" / "profiles"
sys.path.insert(0, str(ROOT / "scripts"))
from editors import jsonc as parse_jsonc


def state_dir() -> Path:
    return expand_path(os.environ.get("XDG_STATE_HOME", "~/.local/state")) / "dotfiles"


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
    stamp = dt.datetime.now().strftime("%Y%m%d%H%M%S%f")
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


def read_json(path: Path, *, jsonc: bool = False) -> dict[str, Any]:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return {}
    return parse_jsonc(text) if jsonc else json.loads(text)


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
    state_file = expand_path(os.environ.get("DOTFILES_THEME_STATE_FILE", str(state_dir() / "theme-current")))
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


@contextlib.contextmanager
def codex_config_client():
    """Use the native config writer, which preserves TOML and checks versions."""
    executable = shutil.which(os.environ.get("DOTFILES_CODEX_CLI", "codex"))
    if not executable:
        raise RuntimeError("Codex CLI not found; put codex on PATH or set DOTFILES_CODEX_CLI.")
    home = expand_path(os.environ.get("CODEX_HOME", "~/.codex")).resolve()
    # Exclude this repository's project config from the user-settings operation.
    process = subprocess.Popen(
        [str(Path(executable).resolve()), "app-server", "--listen", "stdio://"],
        cwd=home if home.is_dir() else Path.home(), env={**os.environ, "CODEX_HOME": str(home)},
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, encoding="utf-8",
    )
    responses: queue.Queue = queue.Queue()

    def read_responses():
        try:
            for line in process.stdout:
                responses.put(json.loads(line))
        except (ValueError, OSError) as error:
            responses.put(error)
        finally:
            responses.put(None)

    reader = threading.Thread(target=read_responses, daemon=True)
    reader.start()
    request_id = 0

    def send(message):
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()

    def request(method, params):
        nonlocal request_id
        request_id += 1
        send({"id": request_id, "method": method, "params": params})
        deadline = time.monotonic() + 30
        while True:
            try:
                message = responses.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty:
                raise RuntimeError(f"Codex timed out during {method}.") from None
            if message is None or isinstance(message, Exception):
                raise RuntimeError(f"Codex app-server stopped during {method}; check the CLI installation and config.")
            if "method" in message:
                if "id" in message:
                    send({"id": message["id"], "error": {"code": -32601, "message": "Unsupported request"}})
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(f"Codex {method}: {message['error'].get('message', 'request failed')}")
            return message["result"]

    try:
        initialized = request("initialize", {"clientInfo": {"name": "dotfiles_theme", "version": "1.0"}})
        send({"method": "initialized"})
        yield request, Path(initialized["codexHome"]) / "config.toml"
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        reader.join(timeout=1)
        process.stdin.close()
        process.stdout.close()


def codex_theme_values(config: dict[str, Any]) -> dict[str, Any]:
    policy = read_json(ROOT / "config/editors/policy.json")["shared"]
    family, fallbacks, size = policy["font_family"], policy["font_fallbacks"], policy["terminal_font_size"]
    if not isinstance(family, str) or not family.strip() or not isinstance(fallbacks, list) or any(not isinstance(f, str) for f in fallbacks):
        raise ValueError("Invalid font family/fallbacks in config/editors/policy.json")
    if type(size) not in (int, float) or not 8 <= size <= 24:
        raise ValueError("terminal_font_size must be between 8 and 24 for Codex")
    generic = {"monospace", "serif", "sans-serif", "system-ui"}
    font = ", ".join([json.dumps(family)] + [f if f in generic else json.dumps(f) for f in fallbacks])
    values = {"desktop.appearanceTheme": config.get("appearanceTheme", "system"),
              "desktop.appearanceLightCodeThemeId": config["lightCodeThemeId"],
              "desktop.appearanceDarkCodeThemeId": config["darkCodeThemeId"],
              "desktop.codeFontSize": size}

    def leaves(value, prefix):
        for key, item in value.items():
            if isinstance(item, dict):
                leaves(item, prefix + "." + key)
            elif item is not None:
                values[prefix + "." + key] = item

    for variant in ("light", "dark"):
        prefix = f"desktop.appearance{variant.title()}ChromeTheme"
        leaves(config[f"{variant}ChromeTheme"], prefix)
        values[prefix + ".fonts.code"] = font
        # A saved selected face can override the family with a bold/italic face.
        values[prefix + ".fonts.codeFace"] = None
    return values


def config_value(config, path):
    for key in path.split("."):
        if not isinstance(config, dict) or key not in config:
            return None
        config = config[key]
    return config


def apply_codex(config: dict[str, Any], args: argparse.Namespace) -> None:
    values = codex_theme_values(config)
    if args.dry_run:
        path = expand_path(os.environ.get("CODEX_HOME", "~/.codex")) / "config.toml"
        info(f"[dry-run] Codex: would update {path} through config/batchWrite:")
        for key, value in values.items():
            info(f"  {key} = {json.dumps(value)}")
        return
    with codex_config_client() as (request, path):
        def read_user_layer():
            result = request("config/read", {"includeLayers": True})
            for layer in result.get("layers") or []:
                name = layer["name"]
                if name["type"] == "user" and Path(name["file"]).resolve() == path.resolve():
                    return result, layer
            raise RuntimeError("Codex did not return the user config layer; no settings were written.")

        result, layer = read_user_layer()
        edits = [{"keyPath": key, "mergeStrategy": "replace", "value": value}
                 for key, value in values.items() if config_value(result["config"], key) != value]
        if not edits:
            info("Codex: theme and shared code font already match; no changes.")
            return
        backup_file(path, False)
        response = request("config/batchWrite", {"edits": edits, "filePath": str(path),
                           "expectedVersion": layer["version"]})
        if response["status"] != "ok":
            raise RuntimeError("Codex settings were saved but are overridden by another config layer.")
        result, layer = read_user_layer()
        if any(config_value(result["config"], key) != value for key, value in values.items()):
            raise RuntimeError("Codex appearance verification failed after writing config.toml.")
    info(f"Codex: applied {config['darkCodeThemeId']} and shared code font to {path}")
    warn("Restart the desktop app if its appearance has not refreshed.")


def apply_iterm(config: dict[str, Any], args: argparse.Namespace) -> None:
    if config.get("installNote"):
        warn(f"iTerm: {config['installNote']}")
        return
    color_file = repo_path(config["colorFile"])
    if not color_file.exists():
        warn(f"iTerm color file not found: {color_file}")
        return
    info(f"iTerm: import {color_file}")
    run_or_log(["open", str(color_file)], args.dry_run)
    warn("iTerm imports the color preset; select it in the active profile if it does not switch automatically.")


def apply_terminal(config: dict[str, Any], args: argparse.Namespace) -> None:
    if config.get("installNote"):
        warn(f"Terminal: {config['installNote']}")
        return
    color_file = repo_path(config["colorFile"])
    if not color_file.exists():
        warn(f"Terminal color file not found: {color_file}")
        return
    info(f"Terminal: import {color_file}")
    run_or_log(["open", str(color_file)], args.dry_run)
    warn("Terminal imports the profile; make it default in Terminal settings if needed.")


def apply_zsh(config: dict[str, Any], args: argparse.Namespace) -> None:
    theme_file = repo_path(config["themeFile"])
    target = expand_path(
        os.environ.get(
            "DOTFILES_ZSH_THEME_TARGET",
            config.get("target", str(state_dir() / "current-theme.zsh")),
        )
    )
    if not theme_file.exists():
        warn(f"zsh theme file not found: {theme_file}")
        return
    info(f"zsh: point {target} to {theme_file}")
    if args.dry_run:
        info(f"[dry-run] Would symlink {target} -> {theme_file}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        target.unlink()
    target.symlink_to(theme_file)


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
    "iterm": apply_iterm,
    "obsidian": apply_obsidian,
    "terminal": apply_terminal,
    "vscode": apply_vscode,
    "zsh": apply_zsh,
}


def apply_theme(args: argparse.Namespace) -> None:
    profile = load_profile(args.theme)
    apps = profile.get("apps", {})
    for app in selected_apps(args, profile):
        info(f"\nApplying {profile['name']} to {app}")
        APPLIERS[app](apps[app], args)

    state_file = expand_path(os.environ.get("DOTFILES_THEME_STATE_FILE", str(state_dir() / "theme-current")))
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
    try:
        args.func(args)
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
