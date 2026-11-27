#!/usr/bin/env python3
"""Exercise the current Codex config writer in an isolated CODEX_HOME."""
import argparse
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("dotfiles_theme", ROOT / "scripts/theme.py")
theme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(theme)


class CodexThemeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / "config.toml"
        self.args = argparse.Namespace(dry_run=False)
        self.config = theme.load_profile("gruvbox")["apps"]["codex"]
        self.env = mock.patch.dict(os.environ, {"CODEX_HOME": str(self.home)})
        self.env.start()
        self.addCleanup(self.env.stop)

    def apply(self, config=None):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            theme.apply_codex(config or self.config, self.args)

    def require_cli(self):
        if not shutil.which(os.environ.get("DOTFILES_CODEX_CLI", "codex")):
            self.skipTest("Codex CLI required for native config writer integration")

    def test_profiles_reference_existing_assets_and_supported_targets(self):
        for name in ("gruvbox", "gruvbox-material", "everforest"):
            apps = theme.load_profile(name)["apps"]
            self.assertNotIn("intellij", apps)
            self.assertTrue(set(apps).issubset(theme.APPLIERS))
            for settings in apps.values():
                for key in ("colorFile", "themeFile"):
                    if key in settings:
                        self.assertTrue(theme.repo_path(settings[key]).is_file(), settings[key])

    def test_zsh_theme_and_selection_use_external_state_directory(self):
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(("DOTFILES_", "XDG_"))}
        env.update(HOME=str(self.home), XDG_STATE_HOME=str(self.home / "state with spaces"))
        args = argparse.Namespace(theme="gruvbox", apps="zsh", dry_run=False)
        with mock.patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(io.StringIO()):
            theme.apply_theme(args)
            state = self.home / "state with spaces/dotfiles"
            self.assertEqual((state / "theme-current").read_text().strip(), "gruvbox")
            self.assertEqual((state / "current-theme.zsh").resolve(),
                             ROOT / "config/themes/zsh/gruvbox.zsh-theme")
            self.assertFalse((self.home / ".dotfiles-state").exists())

    def test_shared_policy_wins_over_profile_font(self):
        policy = copy.deepcopy(theme.read_json(ROOT / "config/editors/policy.json"))
        policy["shared"].update(font_family="A different family", terminal_font_size=13)
        self.config["darkChromeTheme"]["fonts"]["code"] = "obsolete profile font"
        with mock.patch.object(theme, "read_json", return_value=policy):
            values = theme.codex_theme_values(self.config)
        for variant in ("Light", "Dark"):
            self.assertTrue(values[f"desktop.appearance{variant}ChromeTheme.fonts.code"].startswith('"A different family",'))
            self.assertIsNone(values[f"desktop.appearance{variant}ChromeTheme.fonts.codeFace"])
            self.assertNotIn(f"desktop.appearance{variant}ChromeTheme.fonts.ui", values)
        self.assertEqual(values["desktop.codeFontSize"], 13)

    def test_dry_run_never_starts_cli_or_creates_files(self):
        self.args.dry_run = True
        with mock.patch.object(theme.subprocess, "Popen", side_effect=AssertionError("started CLI")):
            self.apply()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_cli_is_an_error(self):
        with mock.patch.dict(os.environ, {"DOTFILES_CODEX_CLI": str(self.home / "absent")}):
            with self.assertRaisesRegex(RuntimeError, "CLI not found"):
                self.apply()
        self.assertFalse(self.path.exists())

    def test_native_writer_preserves_settings_and_comments_and_is_idempotent(self):
        self.require_cli()
        before = '''# preserve this comment
model = "gpt-6.1-sol"
[desktop]
appearanceTheme = "dark"
conversationDetailMode = "STEPS_COMMANDS"
[desktop.appearanceDarkChromeTheme.fonts]
ui = "My UI font"
content = "My prose font"
code = "Old code font"
codeFace = { family = "BlexMono Nerd Font Mono", postscriptName = "BlexMonoNFM-Bold", fullName = "BlexMono Nerd Font Mono Bold", style = "Bold" }
[mcp_servers.example]
command = "example-server"
'''
        self.path.write_text(before)
        legacy = self.home / ".codex-global-state.json"
        legacy.write_text('{"unrelated": "preserve this"}\n')
        for name in ("gruvbox", "gruvbox-material", "everforest"):
            config = theme.load_profile(name)["apps"]["codex"]
            self.apply(config)
            text = self.path.read_text()
            self.assertIn("# preserve this comment", text)
            with theme.codex_config_client() as (request, path):
                result = request("config/read", {"includeLayers": True})
            actual = result["config"]
            for key, expected in theme.codex_theme_values(config).items():
                self.assertEqual(theme.config_value(actual, key), expected, key)
            fonts = actual["desktop"]["appearanceDarkChromeTheme"]["fonts"]
            self.assertEqual(fonts["ui"], "My UI font")
            self.assertEqual(fonts["content"], "My prose font")
            self.assertEqual(actual["desktop"]["conversationDetailMode"], "STEPS_COMMANDS")
            self.assertEqual(actual["model"], "gpt-6.1-sol")
            self.assertIn('command = "example-server"', text)
            previous = self.path.stat().st_mtime_ns
            backups = list(self.home.glob("config.toml.bak.*"))
            self.apply(config)
            self.assertEqual(self.path.read_text(), text)
            self.assertEqual(self.path.stat().st_mtime_ns, previous)
            self.assertEqual(list(self.home.glob("config.toml.bak.*")), backups)
        self.assertEqual(legacy.read_text(), '{"unrelated": "preserve this"}\n')
        self.assertIn(before, [p.read_text() for p in self.home.glob("config.toml.bak.*")])

    def test_native_writer_rejects_concurrent_change(self):
        self.require_cli()
        self.path.write_text('[desktop]\nappearanceTheme = "dark"\n')
        with theme.codex_config_client() as (request, path):
            result = request("config/read", {"includeLayers": True})
            layer = next(x for x in result["layers"] if x["name"]["type"] == "user")
            changed = self.path.read_text().replace('"dark"', '"light"')
            self.path.write_text(changed)
            with self.assertRaises(RuntimeError):
                request("config/batchWrite", {"filePath": str(path), "expectedVersion": layer["version"],
                        "edits": [{"keyPath": "desktop.codeFontSize", "value": 12, "mergeStrategy": "replace"}]})
        self.assertEqual(self.path.read_text(), changed)

    def test_native_writer_creates_first_config(self):
        self.require_cli()
        self.apply()
        self.assertTrue(self.path.is_file())
        self.assertEqual(list(self.home.glob("config.toml.bak.*")), [])

    def test_write_failure_does_not_record_success(self):
        self.path.write_text('[desktop]\nappearanceTheme = "dark"\n')
        marker = self.home / "theme-current"
        marker.write_text("previous\n")

        @contextlib.contextmanager
        def client():
            def request(method, params):
                if method == "config/read":
                    return {"config": {}, "layers": [{"name": {"type": "user", "file": str(self.path)},
                                                       "version": "version", "config": {}}]}
                raise RuntimeError("version mismatch")
            yield request, self.path

        with mock.patch.object(theme, "codex_config_client", client), mock.patch.dict(os.environ, {"DOTFILES_THEME_STATE_FILE": str(marker)}):
            args = argparse.Namespace(theme="gruvbox", apps="codex", dry_run=False)
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(RuntimeError, "version mismatch"):
                theme.apply_theme(args)
        self.assertEqual(marker.read_text(), "previous\n")


if __name__ == "__main__":
    unittest.main()
