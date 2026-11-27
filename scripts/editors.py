#!/usr/bin/env python3
"""Apply or audit the shared VS Code/Zed policy (Python standard library only)."""

import argparse
import copy
import contextlib
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
EDITORS = ("vscode", "zed")


def jsonc(text):
    """Remove JSONC comments/trailing commas without touching quoted strings."""
    chars = list(text)
    i = 0
    while i < len(chars):
        if chars[i] == '"':
            i += 1
            while i < len(chars):
                if chars[i] == "\\":
                    i += 2
                elif chars[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
        elif text[i:i + 2] in ("//", "/*"):
            start = i
            if text[i:i + 2] == "//":
                i = text.find("\n", i)
                if i < 0:
                    i = len(chars)
            else:
                end = text.find("*/", i + 2)
                if end < 0:
                    raise ValueError("Unterminated JSONC comment")
                i = end + 2
            for n in range(start, i):
                if chars[n] not in "\r\n":
                    chars[n] = " "
        else:
            i += 1
    clean = "".join(chars)
    # Match whole strings first, so comma/bracket text inside strings is intact.
    clean = re.sub(r'"(?:\\.|[^"\\])*"|,(?=\s*[}\]])',
                   lambda m: "" if m.group() == "," else m.group(), clean)
    return json.loads(clean)


def read_object(path):
    if not path.exists():
        return {}
    value = jsonc(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def merge(base, overlay):
    result = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def differences(actual, expected, prefix=()):
    """Audit only owned leaves; preserve all unrelated settings."""
    out = []
    for key, value in expected.items():
        here = prefix + (key,)
        if isinstance(value, dict) and value:
            out.extend(differences(actual.get(key, {}) if isinstance(actual.get(key), dict) else {}, value, here))
        elif key not in actual or type(actual[key]) is not type(value) or actual[key] != value:
            out.append(" / ".join(here))
    return out


def home_path(env, default):
    return Path(os.path.expandvars(os.path.expanduser(os.environ.get(env, default))))


def locations():
    home = Path.home()
    xdg = home_path("XDG_CONFIG_HOME", str(home / ".config"))
    data = home_path("XDG_DATA_HOME", str(home / ".local/share"))
    if sys.platform == "darwin":
        code_user = home / "Library/Application Support/Code/User"
        zed_data = home / "Library/Application Support/Zed"
    else:
        code_user = xdg / "Code/User"
        zed_data = data / "zed"
    return {
        "vscode": home_path("DOTFILES_VSCODE_SETTINGS_PATH", str(code_user / "settings.json")),
        "zed": home_path("DOTFILES_ZED_SETTINGS_PATH", str(xdg / "zed/settings.json")),
        "vscode_extensions": home_path("DOTFILES_VSCODE_EXTENSIONS_DIR", str(home / ".vscode/extensions")),
        "zed_extensions": home_path("DOTFILES_ZED_EXTENSIONS_DIR", str(zed_data / "extensions")),
        "local": xdg / "dotfiles/editors.local.json",
        "state": home_path("XDG_STATE_HOME", str(home / ".local/state")) / "dotfiles/editors",
    }


def load_policy():
    policy = read_object(ROOT / "config/editors/policy.json")
    if policy.get("schema_version") != 1:
        raise ValueError("Unsupported editor policy schema")
    manifest = read_object(ROOT / "config/editors/extensions.json")
    for editor in EDITORS:
        seen = set()
        for entry in manifest[editor]:
            ident = entry["id"]
            pattern = r"[a-z0-9][a-z0-9_.-]*" if editor == "zed" else r"[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9_.-]*"
            if not re.fullmatch(pattern, ident) or ident in seen:
                raise ValueError(f"Invalid/duplicate {editor} extension: {ident}")
            seen.add(ident)
    return policy, manifest


def render(policy, manifest, local):
    unknown = set(local) - set(EDITORS)
    if unknown or any(not isinstance(v, dict) for v in local.values()):
        raise ValueError("Local overrides must contain only vscode/zed objects")
    result = {editor: read_object(ROOT / f"config/editors/{editor}.json") for editor in EDITORS}
    common = policy["shared"]
    vs, zed = result["vscode"], result["zed"]
    font = common["font_family"]
    fallbacks = common["font_fallbacks"]
    vs.update({"editor.fontFamily": ", ".join([f"'{font}'"] + fallbacks),
               "editor.fontSize": common["font_size"],
               "editor.formatOnSave": common["format_on_save"],
               "files.trimTrailingWhitespace": common["trim_trailing_whitespace"],
               "files.insertFinalNewline": common["final_newline"],
               "files.trimFinalNewlines": common["final_newline"],
               "editor.bracketPairColorization.enabled": common["colorize_brackets"],
               "editor.linkedEditing": common["linked_edits"],
               "telemetry.telemetryLevel": "off" if not common["telemetry"] else "all",
               "diffEditor.renderSideBySide": common["diff_style"] == "split"})
    zed.update({"buffer_font_family": font, "buffer_font_fallbacks": fallbacks,
                "buffer_font_size": common["font_size"], "vim_mode": common["vim"],
                "format_on_save": "on" if common["format_on_save"] else "off",
                "remove_trailing_whitespace_on_save": common["trim_trailing_whitespace"],
                "ensure_final_newline_on_save": common["final_newline"],
                "colorize_brackets": common["colorize_brackets"],
                "linked_edits": common["linked_edits"], "diff_view_style": common["diff_style"],
                "telemetry": {"diagnostics": common["telemetry"], "metrics": common["telemetry"]}})
    vs["vim.disableExtension"] = not common["vim"]
    theme = policy["themes"][common["theme"]]
    vs.update({"workbench.colorTheme": theme["vscode"]["dark"],
               "window.autoDetectColorScheme": True,
               "workbench.preferredLightColorTheme": theme["vscode"]["light"],
               "workbench.preferredDarkColorTheme": theme["vscode"]["dark"]})
    zed["theme"] = {"mode": "system", **theme["zed"]}
    for group in policy["formatters"]:
        for lang in group["vscode_languages"]:
            vs.setdefault(f"[{lang}]", {})["editor.defaultFormatter"] = group["vscode_extension"]
        for lang in group["zed_languages"]:
            config = zed.setdefault("languages", {}).setdefault(lang, {})
            config.update({"formatter": "auto" if group["engine"] == "prettier" else {
                "language_server": {"name": group["zed_server"]}},
                "prettier": {"allowed": group["engine"] == "prettier"}})
        if group["vscode_extension"] not in {e["id"] for e in manifest["vscode"]}:
            raise ValueError("Formatter extension missing from manifest: " + group["vscode_extension"])
    trim_md = not common["preserve_markdown_trailing_spaces"]
    vs.setdefault("[markdown]", {})["files.trimTrailingWhitespace"] = trim_md
    zed.setdefault("languages", {}).setdefault("Markdown", {})["remove_trailing_whitespace_on_save"] = trim_md
    zed["auto_install_extensions"] = {entry["id"]: True for entry in manifest["zed"]}
    for editor in EDITORS:
        result[editor] = merge(result[editor], local.get(editor, {}))
    return result


def extension_inventory(editor, paths):
    if editor == "vscode":
        path = paths["vscode_extensions"] / "extensions.json"
        if not path.exists():
            return {}
        entries = json.loads(path.read_text(encoding="utf-8"))
        return {entry["identifier"]["id"].lower(): entry["version"] for entry in entries}
    index = paths["zed_extensions"] / "index.json"
    if not index.exists():
        return {}
    entries = read_object(index).get("extensions", {})
    # Confirm a registered extension also exists on disk, not just a stale index.
    return {ident: value["manifest"]["version"] for ident, value in entries.items()
            if (paths["zed_extensions"] / "installed" / ident / "extension.toml").is_file()}


def disabled_vscode(settings):
    path = settings.parent / "globalStorage/state.vscdb"
    if not path.exists():
        return set()
    with contextlib.closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as conn:
        row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", ("extensionsIdentifiers/disabled",)).fetchone()
    return {entry["id"].lower() for entry in json.loads(row[0])} if row else set()


def atomic_write(path, text):
    # Follow existing symlinks instead of replacing them.
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temp = tempfile.mkstemp(prefix=".editors-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(text)
        os.chmod(temp, mode)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def code_command():
    command = shutil.which("code")
    fallback = Path("/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code")
    if not command and fallback.is_file():
        command = str(fallback)
    return command


def apply_settings(selected, paths, expected, local, dry_run):
    prepared = []
    # Parse every selected file before making any changes.
    for editor in selected:
        path = paths[editor]
        original = path.read_bytes() if path.exists() else None
        actual = read_object(path)
        if editor == "vscode" and "editor.defaultFormatter" not in local.get(editor, {}):
            actual.pop("editor.defaultFormatter", None)
        updated = merge(actual, expected[editor])
        # A removed global formatter is a change even when everything else matches.
        before = jsonc(original.decode("utf-8")) if original is not None else {}
        if updated != before:
            prepared.append((editor, path, original, json.dumps(updated, indent=2) + "\n"))
    if not prepared:
        print("ok: managed settings already match")
        return
    stamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    backup = paths["state"] / "backups" / stamp
    for editor, path, original, text in prepared:
        print(f"{'[dry-run] would update' if dry_run else 'update'}: {editor} {path}")
        if dry_run:
            continue
        current = path.read_bytes() if path.exists() else None
        if current != original:
            raise ValueError(f"Settings changed during apply; retry: {path}")
        if original is not None:
            backup.mkdir(parents=True, exist_ok=True, mode=0o700)
            target = backup / f"{editor}.settings.jsonc"
            target.write_bytes(original)
            target.chmod(0o600)
        atomic_write(path, text)
    if not dry_run and backup.exists():
        print(f"backups: {backup}")


def apply_extensions(selected, paths, manifest, dry_run, settings_only):
    missing_zed = False
    for editor in selected:
        installed = extension_inventory(editor, paths)
        missing = [entry["id"] for entry in manifest[editor] if entry["id"] not in installed]
        for ident in missing:
            if editor == "zed":
                print(f"pending: Zed will auto-install {ident} on its next launch")
                missing_zed = True
            elif dry_run or settings_only:
                print(f"{'[dry-run] would install' if dry_run else 'pending (settings-only)'}: VS Code {ident}")
            else:
                command = code_command()
                if not command:
                    raise ValueError("VS Code CLI not found; install VS Code and its code command first")
                subprocess.run([command, "--extensions-dir", str(paths["vscode_extensions"]),
                                "--install-extension", ident], check=True, timeout=300)
                # Verify instead of treating a zero exit code as proof of installation.
                if ident not in extension_inventory(editor, paths):
                    raise ValueError(f"VS Code did not register installed extension: {ident}")
    return missing_zed


def font_available(font):
    needle = re.sub(r"[^a-z0-9]", "", font.lower())
    home = Path.home()
    dirs = [home / "Library/Fonts", Path("/Library/Fonts"), home / ".fonts",
            home / ".local/share/fonts", Path("/usr/share/fonts"), Path("/usr/local/share/fonts")]
    return any(needle in re.sub(r"[^a-z0-9]", "", p.stem.lower())
               for base in dirs if base.exists() for p in base.rglob("*") if p.is_file())


def check(selected, paths, expected, manifest, local, exact_versions=False):
    failed = False
    for editor in selected:
        path = paths[editor]
        actual = read_object(path)
        drift = differences(actual, expected[editor])
        if editor == "vscode" and "editor.defaultFormatter" in actual and "editor.defaultFormatter" not in local.get(editor, {}):
            drift.append("editor.defaultFormatter (must be absent; choose per language)")
        for key in drift:
            print(f"drift: {editor} {key}")
        if not drift:
            print(f"ok: {editor} managed settings")
        failed |= bool(drift)
        installed = extension_inventory(editor, paths)
        required = {entry["id"]: entry for entry in manifest[editor]}
        disabled = disabled_vscode(path) if editor == "vscode" else set()
        for ident, entry in required.items():
            if ident not in installed:
                print(f"missing: {editor} extension {ident}")
                failed = True
            elif ident in disabled:
                print(f"disabled: {editor} extension {ident}; enable it in the editor")
                failed = True
            elif installed[ident] != entry["observed_version"]:
                label = "version drift" if exact_versions else "note"
                print(f"{label}: {editor} {ident} {installed[ident]} (recorded {entry['observed_version']})")
                failed |= exact_versions
        extras = sorted(set(installed) - set(required))
        if extras:
            print(f"note: {editor} additional extensions retained: {', '.join(extras)}")
        if all(ident in installed and ident not in disabled for ident in required):
            print(f"ok: {editor} all {len(required)} required extensions installed")
        # Validate explicit machine paths without importing them into shared policy.
        jdk = actual.get("jdk.jdkhome") if editor == "vscode" else None
        if jdk and not Path(os.path.expanduser(jdk)).is_dir():
            print("invalid: vscode jdk.jdkhome points to a missing directory")
            failed = True
    fonts = set()
    for editor in selected:
        value = expected[editor].get("buffer_font_family") if editor == "zed" else expected[editor].get("editor.fontFamily", "").split(",")[0].strip("'\" ")
        if value:
            fonts.add(value)
    for font in sorted(fonts):
        found = font_available(font)
        print(f"{'ok' if found else 'missing'}: font {font}")
        failed |= not found
    return 1 if failed else 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="dotfiles editors", description=__doc__)
    parser.add_argument("action", choices=("apply", "check", "render"))
    parser.add_argument("--editor", choices=("all", *EDITORS), default="all")
    parser.add_argument("--local-overrides", type=Path)
    parser.add_argument("--dry-run", action="store_true", help="Preview apply without writes, installs, or backups")
    parser.add_argument("--settings-only", action="store_true", help="Apply settings without installing VS Code extensions")
    parser.add_argument("--exact-versions", action="store_true", help="Make check fail on extension versions different from the recorded inventory")
    args = parser.parse_args(argv)
    if args.action != "apply" and (args.dry_run or args.settings_only):
        parser.error("--dry-run/--settings-only require apply")
    if args.exact_versions and args.action != "check":
        parser.error("--exact-versions requires check")
    paths = locations()
    local = read_object(args.local_overrides or paths["local"])
    policy, manifest = load_policy()
    expected = render(policy, manifest, local)
    selected = EDITORS if args.editor == "all" else (args.editor,)
    if args.action == "render":
        print(json.dumps({editor: expected[editor] for editor in selected}, indent=2))
        return 0
    if args.action == "check":
        return check(selected, paths, expected, manifest, local, args.exact_versions)
    apply_settings(selected, paths, expected, local, args.dry_run)
    apply_extensions(selected, paths, manifest, args.dry_run, args.settings_only)
    if args.dry_run:
        return 0
    return check(selected, paths, expected, manifest, local)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, sqlite3.Error, subprocess.SubprocessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
