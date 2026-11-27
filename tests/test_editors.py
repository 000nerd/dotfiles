#!/usr/bin/env python3
"""Editor policy tests in disposable homes; no real editors or network needed."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("editors", ROOT / "scripts/editors.py")
editors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(editors)


class EditorsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-editors-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home with spaces"
        self.home.mkdir()
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("DOTFILES_", "XDG_"))}
        self.env["HOME"] = str(self.home)
        self.environ = patch.dict(os.environ, self.env, clear=True)
        self.environ.start()
        self.addCleanup(self.environ.stop)
        self.paths = editors.locations()
        self.policy, self.manifest = editors.load_policy()
        self.expected = editors.render(self.policy, self.manifest, {})
        self.font = self.home / "Library/Fonts/BlexMonoNerdFontMono-Regular.ttf"
        self.font.parent.mkdir(parents=True)
        self.font.write_text("fixture")

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))

    def inventory(self, editor, entries=None):
        entries = entries if entries is not None else self.manifest[editor]
        if editor == "vscode":
            self.write(self.paths["vscode_extensions"] / "extensions.json",
                       [{"identifier": {"id": e["id"]}, "version": e["observed_version"]} for e in entries])
        else:
            self.write(self.paths["zed_extensions"] / "index.json", {
                "extensions": {e["id"]: {"manifest": {"version": e["observed_version"]}} for e in entries}})
            for entry in entries:
                path = self.paths["zed_extensions"] / "installed" / entry["id"] / "extension.toml"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('id = "' + entry["id"] + '"\n')

    def ready(self):
        for editor in editors.EDITORS:
            self.write(self.paths[editor], self.expected[editor])
            self.inventory(editor)

    def invoke(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = editors.main(list(args))
        return status, output.getvalue()

    def test_jsonc_preserves_urls_escaped_quotes_and_comma_bracket_strings(self):
        text = r'''{
          // before a string
          "url": "https://example.test/a//b/*c*/",
          "quoted": "a\"//b",
          "text": ", }", /* after a string */
          "array": [1, 2,],
        }'''
        value = editors.jsonc(text)
        self.assertEqual(value["url"], "https://example.test/a//b/*c*/")
        self.assertEqual(value["quoted"], 'a"//b')
        self.assertEqual(value["text"], ", }")
        self.assertEqual(value["array"], [1, 2])
        with self.assertRaises(ValueError):
            editors.jsonc('{"a": 1, /* unterminated')

    def test_apply_preserves_unmanaged_and_local_values_and_is_idempotent(self):
        original = '// retained in backup\n{"custom.url":"https://example.test", "[python]":{"editor.rulers":[88]}, "editor.defaultFormatter":"bad",}'
        self.paths["vscode"].parent.mkdir(parents=True)
        self.paths["vscode"].write_text(original)
        local = {"vscode": {"jdk.jdkhome": str(self.home)}}
        self.write(self.paths["local"], local)
        self.inventory("vscode")
        self.inventory("zed")
        self.assertEqual(self.invoke("apply")[0], 0)
        actual = editors.read_object(self.paths["vscode"])
        self.assertEqual(actual["custom.url"], "https://example.test")
        self.assertEqual(actual["[python]"]["editor.rulers"], [88])
        self.assertEqual(actual["jdk.jdkhome"], str(self.home))
        self.assertNotIn("editor.defaultFormatter", actual)
        backups = list(self.paths["state"].glob("backups/*/vscode.settings.jsonc"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)
        mtime = self.paths["vscode"].stat().st_mtime_ns
        self.assertEqual(self.invoke("apply")[0], 0)
        self.assertEqual(mtime, self.paths["vscode"].stat().st_mtime_ns)
        self.assertEqual(backups, list(self.paths["state"].glob("backups/*/vscode.settings.jsonc")))
        self.assertEqual(self.invoke("check")[0], 0)

    def test_dry_run_and_check_do_not_create_files_or_launch_cli(self):
        before = sorted(str(p) for p in self.home.rglob("*"))
        with patch.object(editors.subprocess, "run", side_effect=AssertionError("must not launch")):
            self.assertEqual(self.invoke("apply", "--dry-run")[0], 0)
            self.assertEqual(self.invoke("check")[0], 1)
        self.assertEqual(before, sorted(str(p) for p in self.home.rglob("*")))

    def test_all_configs_preflight_before_any_write(self):
        self.write(self.paths["vscode"], {"preserve": True})
        self.paths["zed"].parent.mkdir(parents=True)
        self.paths["zed"].write_text('{"broken":')
        original = self.paths["vscode"].read_bytes()
        with self.assertRaises(ValueError):
            self.invoke("apply")
        self.assertEqual(self.paths["vscode"].read_bytes(), original)
        self.assertFalse(self.paths["state"].exists())

    def test_check_detects_nested_settings_missing_and_disabled_extensions(self):
        self.ready()
        data = editors.read_object(self.paths["zed"])
        data["languages"]["Python"]["formatter"] = "auto"
        self.write(self.paths["zed"], data)
        self.inventory("vscode", self.manifest["vscode"][:-1])
        state = self.paths["vscode"].parent / "globalStorage/state.vscdb"
        state.parent.mkdir()
        with sqlite3.connect(state) as conn:
            conn.execute("CREATE TABLE ItemTable(key TEXT, value TEXT)")
            conn.execute("INSERT INTO ItemTable VALUES (?, ?)", (
                "extensionsIdentifiers/disabled", json.dumps([{"id": "charliermarsh.ruff"}])))
        conn.close()
        code, output = self.invoke("check")
        self.assertEqual(code, 1)
        self.assertIn("languages / Python / formatter", output)
        self.assertIn("missing: vscode extension", output)
        self.assertIn("disabled: vscode extension charliermarsh.ruff", output)

    def test_version_policy_extra_extensions_and_stale_zed_index(self):
        self.ready()
        entries = [dict(entry) for entry in self.manifest["vscode"]]
        entries[0]["observed_version"] = "999.0"
        entries.append({"id": "someone.extra", "observed_version": "1.0"})
        self.inventory("vscode", entries)
        self.assertEqual(self.invoke("check")[0], 0)
        self.assertEqual(self.invoke("check", "--exact-versions")[0], 1)
        manifest = self.paths["zed_extensions"] / "installed/java/extension.toml"
        manifest.unlink()
        self.assertEqual(self.invoke("check")[0], 1)

    def test_single_editor_overrides_and_missing_font(self):
        self.write(self.paths["vscode"], self.expected["vscode"])
        self.inventory("vscode")
        self.assertEqual(self.invoke("check", "--editor", "vscode")[0], 0)
        self.font.unlink()
        self.assertEqual(self.invoke("check", "--editor", "vscode")[0], 1)
        self.write(self.paths["local"], {"wrong-editor": {}})
        with self.assertRaises(ValueError):
            self.invoke("render")

    def test_apply_preserves_existing_symlinks(self):
        target = self.home / "settings source.jsonc"
        target.write_text('{"keep": true}')
        self.paths["vscode"].parent.mkdir(parents=True)
        self.paths["vscode"].symlink_to(target)
        self.inventory("vscode")
        self.assertEqual(self.invoke("apply", "--editor", "vscode")[0], 0)
        self.assertTrue(self.paths["vscode"].is_symlink())
        self.assertTrue(editors.read_object(target)["keep"])

    def test_installer_receives_safe_args_and_registration_is_verified(self):
        self.write(self.paths["vscode"], self.expected["vscode"])
        self.inventory("vscode", self.manifest["vscode"][1:])
        fake = self.home / "fake bin/code"
        fake.parent.mkdir()
        fake.write_text('''#!/usr/bin/env python3
import json, pathlib, sys
args=sys.argv[1:]
registry=pathlib.Path(args[args.index('--extensions-dir')+1])/'extensions.json'
values=json.loads(registry.read_text())
values.append({'identifier': {'id': args[-1]}, 'version': '1.0'})
registry.write_text(json.dumps(values))
''')
        fake.chmod(0o755)
        with patch.object(editors, "code_command", return_value=str(fake)):
            self.assertEqual(self.invoke("apply", "--editor", "vscode")[0], 0)
        self.inventory("vscode", self.manifest["vscode"][1:])
        with patch.object(editors, "code_command", return_value=str(fake)), patch.object(
                editors.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "code")):
            with self.assertRaises(subprocess.CalledProcessError):
                self.invoke("apply", "--editor", "vscode")
        with patch.object(editors, "code_command", return_value=str(fake)), patch.object(editors.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "did not register"):
                self.invoke("apply", "--editor", "vscode")

    def test_manifest_is_complete_and_generated_policy_contains_all_zed_ids(self):
        self.assertIn("charliermarsh.ruff", {e["id"] for e in self.manifest["vscode"]})
        self.assertTrue({"gruvbox-material", "everforest", "swift", "java"}.issubset(
            {e["id"] for e in self.manifest["zed"]}))
        self.assertEqual(set(self.expected["zed"]["auto_install_extensions"]),
                         {entry["id"] for entry in self.manifest["zed"]})
        self.assertNotIn("jdk.jdkhome", self.expected["vscode"])
        self.assertEqual(self.expected["zed"]["theme"]["dark"], "Gruvbox Dark")


if __name__ == "__main__":
    unittest.main()
