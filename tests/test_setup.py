#!/usr/bin/env python3
"""Regression tests run entirely in temporary homes/repositories; no installs."""

import copy
import contextlib
import io
import importlib.util
import hashlib
import json
import os
import plistlib
from pathlib import Path
import shutil
import sys
import shlex
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


state = load("setup_state", ROOT / "scripts/setup-state.py")
prefs = load("preferences", ROOT / "scripts/preferences.py")
store = load("appstore_test", ROOT / "scripts/appstore.py")
exporter = load("export_source", ROOT / "tests/smoke/export-source.py")


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-regression-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.env = {**os.environ, "HOME": str(self.home)}
        for name in list(self.env):
            if name.startswith("DOTFILES_") or name in ("BASH_ENV", "ENV", "NVM_DIR"):
                self.env.pop(name)
        self.env["XDG_CACHE_HOME"] = str(self.base / "cache")
        self.env["XDG_STATE_HOME"] = str(self.base / "state")

    def file(self, relative, value="fixture\n", executable=False):
        path = self.base / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
        if executable:
            path.chmod(0o755)
        return path

    def command(self, *args, env=None):
        return subprocess.run(args, env=env or self.env, capture_output=True, text=True, timeout=30)

    def fixture_repo(self):
        repo = self.base / "repo with spaces"
        repo.mkdir()
        for name in ("install.sh", "install/symlinks.sh", "install/backup.sh", "install/links.sh", "install/links.tsv", "install/profiles/personal.env", "bin/dotfiles"):
            dest = repo / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, dest)
        for name in ("config/zsh/zshrc", "config/zsh/zprofile", "config/git/gitconfig", "config/git/ignore", "config/ssh/config", "config/example/settings"):
            self.file(str(repo.relative_to(self.base) / name))
        with (repo / "install/links.tsv").open("a") as manifest:
            manifest.write("config/example\t.config/example\n")
        return repo

    def test_restore_preserves_unrelated_files_and_handles_broken_links(self):
        self.file("home/.ssh/id_ed25519", "FAKE KEY")
        self.file("home/.config/unrelated/settings", "preserve")
        self.file("backup/.ssh/config", "restored ssh")
        self.file("backup/.config/example/settings", "restored config")
        self.file("backup/.zshrc", "restored shell")
        (self.home / ".zshrc").symlink_to("missing-target")
        result = self.command("python3", str(ROOT / "install/restore.py"), "--backup-dir", str(self.base / "backup"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".ssh/id_ed25519").read_text(), "FAKE KEY")
        self.assertEqual((self.home / ".config/unrelated/settings").read_text(), "preserve")
        self.assertEqual((self.home / ".zshrc").read_text(), "restored shell")
        self.assertFalse((self.home / ".zshrc").is_symlink())

    def test_restore_dry_run_and_destination_symlink(self):
        external = self.file("external/example/settings", "keep external")
        (self.home / ".config").symlink_to(external.parents[1], target_is_directory=True)
        self.file("backup/.config/example/settings", "restore")
        args = ("python3", str(ROOT / "install/restore.py"), "--backup-dir", str(self.base / "backup"))
        self.assertEqual(self.command(*args, "--dry-run").returncode, 0)
        self.assertTrue((self.home / ".config").is_symlink())
        self.assertEqual(external.read_text(), "keep external")
        self.assertEqual(self.command(*args).returncode, 0)
        self.assertFalse((self.home / ".config").is_symlink())
        self.assertEqual(external.read_text(), "keep external")
        self.assertEqual((self.home / ".config/example/settings").read_text(), "restore")

    def test_symlink_conflicts_spaces_idempotency_and_doctor(self):
        repo = self.fixture_repo()
        self.file("home/.ssh/id_ed25519", "FAKE KEY")
        self.file("home/.ssh/config", "original ssh")
        self.file("home/.zshrc", "original shell")
        self.file("home/.config/example/settings", "original config")
        backup = self.command("bash", str(repo / "install/backup.sh"))
        self.assertEqual(backup.returncode, 0, backup.stderr)
        self.assertEqual((self.home / "dotfiles-backup/.config/example/settings").read_text(), "original config")
        self.assertEqual((self.home / ".ssh/config").read_text(), "original ssh")
        args = (str(repo / "install.sh"), "--only", "symlinks")
        first = self.command(*args)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual((self.home / "dotfiles-backup/.ssh/config").read_text(), "original ssh")
        self.assertEqual((self.home / ".ssh/id_ed25519").read_text(), "FAKE KEY")
        second = self.command(*args)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertNotIn("Backing up", second.stdout)
        doctor = (str(repo / "bin/dotfiles"), "doctor", "run")
        self.file("fake-bin/zsh", "#!/bin/sh\nexit 0\n", True)
        doctor_env = {**self.env, "PATH": str(self.base / "fake-bin") + ":" + self.env["PATH"]}
        self.assertFalse((repo / "bins").exists())
        self.assertEqual(self.command(*doctor, env=doctor_env).returncode, 0)
        link = self.home / ".ssh/config"
        link.unlink()
        self.assertNotEqual(self.command(*doctor, env=doctor_env).returncode, 0)
        link.symlink_to(repo / "config/git/gitconfig")
        self.assertNotEqual(self.command(*doctor, env=doctor_env).returncode, 0)
        link.unlink()
        link.symlink_to(repo / "missing")
        self.assertNotEqual(self.command(*doctor, env=doctor_env).returncode, 0)

    def test_installer_rejects_bad_step_lists_and_missing_values(self):
        for flags in (("--only", "symlink"), ("--skip", "bad"), ("--only", "brew,,java"),
                      ("--only",), ("--skip",), ("--profile",), ("--only=",), ("--profile", "../x"),
                      ("--only", "--dry-run")):
            with self.subTest(flags=flags):
                result = self.command(str(ROOT / "install.sh"), "--dry-run", *flags)
                self.assertNotEqual(result.returncode, 0)

    def test_install_and_inventory_use_only_explicit_links(self):
        repo = self.fixture_repo()
        shutil.rmtree(repo / "config/example")
        manifest = repo / "install/links.tsv"
        manifest.write_text(manifest.read_text().replace("config/example\t.config/example\n", ""))
        self.file(str(repo.relative_to(self.base) / "config/editors/policy.json"), "{}")
        self.file(str(repo.relative_to(self.base) / "config/themes/profiles/example.json"), "{}")
        result = self.command(str(repo / "install.sh"), "--only", "symlinks")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".zshrc").is_symlink())
        with patch.object(state, "ROOT", repo), patch.object(state, "HOME", self.home):
            links = state.link_inventory()
        self.assertTrue(all(item["state"] == "correct" for item in links.values()))
        self.assertFalse(any(name.startswith(".config/") for name in links))
        self.assertFalse((self.home / ".config/editors").exists())
        self.assertFalse((self.home / ".config/themes").exists())

    def test_moved_links_replace_old_targets_and_keep_install_idempotent(self):
        repo = self.fixture_repo()
        (self.home / ".zshrc").symlink_to(repo / "zsh/zshrc.symlink")
        result = self.command(str(repo / "install.sh"), "--only", "symlinks")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".zshrc").resolve(), (repo / "config/zsh/zshrc").resolve())
        self.assertEqual(os.readlink(self.home / "dotfiles-backup/.zshrc"), str(repo / "zsh/zshrc.symlink"))
        with patch.object(state, "ROOT", repo), patch.object(state, "HOME", self.home):
            self.assertTrue(all(item["state"] == "correct" for item in state.link_inventory().values()))
        repeat = self.command(str(repo / "install.sh"), "--only", "symlinks")
        self.assertEqual(repeat.returncode, 0, repeat.stderr)
        self.assertNotIn("Backing up", repeat.stdout)

    def test_missing_declared_source_does_not_replace_existing_file(self):
        repo = self.fixture_repo()
        (repo / "config/zsh/zshrc").unlink()
        existing = self.file("home/.zshrc", "keep shell settings")
        result = self.command(str(repo / "install.sh"), "--only", "symlinks")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Symlink source not found", result.stderr)
        self.assertEqual(existing.read_text(), "keep shell settings")

    def test_canonical_bin_is_exported_despite_global_ignore(self):
        result = self.command("git", "-C", str(ROOT), "check-ignore", "--no-index", "bin/dotfiles")
        # Exported VM source has no Git checkout; the standalone export test
        # below exercises filtering there using a disposable Git repository.
        if (ROOT / ".git").exists():
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue((ROOT / "bin/dotfiles").is_file())
        self.assertFalse((ROOT / "bins").exists())

    def test_emptytrash_requires_explicit_run_and_uses_only_finder(self):
        self.file("fake-bin/uname", "#!/bin/sh\necho Darwin\n", True)
        self.file("fake-bin/osascript", '#!/bin/sh\necho "$*" >> "$CALL_LOG"\n', True)
        env = {**self.env, "PATH": str(self.base / "fake-bin") + ":/usr/bin:/bin", "CALL_LOG": str(self.base / "calls")}
        for args in ((), ("--dry-run",), ("--help",)):
            result = self.command(str(ROOT / "bin/emptytrash"), *args, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((self.base / "calls").exists())
        self.assertNotEqual(self.command(str(ROOT / "bin/emptytrash"), "--invalid", env=env).returncode, 0)
        result = self.command(str(ROOT / "bin/emptytrash"), "--run", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.base / "calls").read_text().strip(), '-e tell application "Finder" to empty the trash')

    def update_env(self):
        self.file("fake-bin/uname", "#!/bin/sh\necho Darwin\n", True)
        self.file("fake-bin/brew", '''#!/bin/sh
if [ "$1" = --prefix ]; then echo "$FAKE_PREFIX"; exit 0; fi
echo brew >> "$CALL_LOG"
[ "$FAIL_STEP" != brew ]
''', True)
        for name in ("sudo", "npm"):
            self.file("fake-bin/" + name, '#!/bin/sh\necho ' + name + ' >> "$CALL_LOG"\n[ "$FAIL_STEP" != ' + name + ' ]\n', True)
        self.file("prefix/opt/nvm/nvm.sh", '''nvm() {
    echo "nvm-$1" >> "$CALL_LOG"
    [ "$FAIL_STEP" != "nvm-$1" ]
}
''')
        return {**self.env, "PATH": str(self.base / "fake-bin") + ":/usr/bin:/bin", "FAKE_PREFIX": str(self.base / "prefix"), "CALL_LOG": str(self.base / "calls"), "FAIL_STEP": ""}

    def test_update_loads_nvm_and_propagates_every_failure(self):
        env = self.update_env()
        for step in ("sudo", "brew", "nvm-install", "nvm-alias", "nvm-use", "npm"):
            with self.subTest(step=step):
                result = self.command(str(ROOT / "bin/dotfiles"), "update", "run", env={**env, "FAIL_STEP": step})
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("Success!", result.stdout)
        (self.base / "calls").unlink()
        result = self.command(str(ROOT / "bin/dotfiles"), "update", "run", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.base / "calls").read_text().splitlines(), ["sudo", "brew", "nvm-install", "nvm-alias", "nvm-use", "npm"])
        (self.base / "prefix/opt/nvm/nvm.sh").unlink()
        self.assertNotEqual(self.command(str(ROOT / "bin/dotfiles"), "update", "run", env=env).returncode, 0)

    def test_export_excludes_ignored_files_and_distinguishes_head(self):
        repo = self.base / "git-repo"
        repo.mkdir()
        def git(*args):
            result = self.command("git", "-C", str(repo), *args)
            self.assertEqual(result.returncode, 0, result.stderr)
        git("init")
        self.file("git-repo/.gitignore", "bins/\nprivate.env\n")
        tracked = self.file("git-repo/tracked", "committed")
        deleted = self.file("git-repo/deleted", "present in HEAD")
        self.file("git-repo/executable", "#!/bin/sh\n", True)
        git("add", ".gitignore", "tracked", "deleted", "executable")
        git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-c", "core.hooksPath=/dev/null", "commit", "-m", "fixture")
        tracked.write_text("proposed")
        deleted.unlink()
        self.file("git-repo/proposed.py")
        self.file("git-repo/bins/dotfiles", "ignored old command")
        self.file("git-repo/private.env", "FAKE SECRET")
        working, head = self.base / "working", self.base / "head"
        exporter.export(repo, working, "working")
        exporter.export(repo, head, "head")
        self.assertEqual((working / "tracked").read_text(), "proposed")
        self.assertEqual((head / "tracked").read_text(), "committed")
        self.assertTrue((head / "deleted").exists())
        self.assertFalse((working / "deleted").exists())
        self.assertTrue((working / "proposed.py").exists())
        self.assertFalse((head / "proposed.py").exists())
        for output in (working, head):
            self.assertFalse((output / "bins").exists())
            self.assertFalse((output / "private.env").exists())
            self.assertTrue(os.access(output / "executable", os.X_OK))
            self.assertTrue((output / ".dotfiles-source.json").exists())
        external = self.file("external.txt", "DO NOT COPY")
        (repo / "outside-link").symlink_to(external)
        with self.assertRaises(ValueError):
            exporter.export(repo, self.base / "unsafe-export", "working")

    def sample(self):
        empty = {"status": "ok", "items": {}}
        return {"schema_version": 1, "platform": {}, "brew": {"formula": copy.deepcopy(empty), "cask": copy.deepcopy(empty)},
                "runtimes": {"node": {"status": "ok", "version": "v22.17.0"}}, "global_tools": {"npm": copy.deepcopy(empty), "uv-tool": copy.deepcopy(empty)},
                "applications": copy.deepcopy(empty), "vscode_extensions": copy.deepcopy(empty), "links": {}, "preferences": copy.deepcopy(empty)}

    def test_comparison_versions_drift_and_unknowns(self):
        before = self.sample()
        after = copy.deepcopy(before)
        self.assertEqual(state.compare(before, after)["status"], "matched")
        before["brew"]["formula"]["items"]["git"] = ["1"]
        after["brew"]["formula"]["items"]["git"] = ["2"]
        self.assertEqual(state.compare(before, after)["status"], "matched")
        self.assertEqual(state.compare(before, after, True)["status"], "different")
        after["brew"]["formula"]["items"] = {}
        self.assertEqual(state.compare(before, after)["status"], "different")
        before = self.sample()
        before["preferences"]["items"]["user|domain|key"] = {"status": "missing-or-unreadable", "observed": None}
        report = state.compare(before, before)
        self.assertEqual(report["status"], "partial")
        self.assertEqual(report["unverified"], ["preference.user|domain|key"])

    def test_extension_capture_uses_only_allowlisted_fields(self):
        self.file("home/.vscode/extensions/extensions.json", json.dumps([{"identifier": {"id": "example.extension"}, "version": "1.2.3", "secret": "DO NOT EXPORT"}]))
        with patch.object(state, "HOME", self.home):
            data = state.extensions()
        self.assertEqual(data, {"status": "ok", "items": {"example.extension": "1.2.3"}})

    def test_complete_package_verification_includes_globals(self):
        declared = state.package_manifest()
        globals_ = {kind: {"status": "ok", "items": {item["name"]: "1" for item in declared if item["kind"] == kind}} for kind in ("npm", "uv-tool")}
        with contextlib.redirect_stdout(io.StringIO()), patch.object(state, "package_manifest", return_value=declared), patch.object(state, "run", return_value=object()), patch.object(state, "global_tools", return_value=globals_), patch.object(state, "app_store_installed", return_value=True):
            self.assertEqual(state.verify(["brew", "javascript", "java", "python"], True), 0)
            globals_["npm"]["items"].pop(next(iter(globals_["npm"]["items"])))
            self.assertEqual(state.verify(["javascript"], True), 1)
            globals_["npm"]["status"] = "unavailable"
            self.assertEqual(state.verify(["javascript"], True), 2)

    def test_node_versions_are_configurable_and_failures_stop_install(self):
        env = self.update_env()
        self.file("fake-bin/sleep", "#!/bin/sh\nexit 0\n", True)
        self.file("prefix/opt/nvm/nvm.sh", '''nvm() {
    echo "$*" >> "$CALL_LOG"
    [ "$FAIL_STEP" != "nvm-$1" ]
}
''')
        env.update(DOTFILES_NODE_VERSIONS="22.17.0 24", DOTFILES_NODE_DEFAULT="22.17.0")
        command = ("bash", str(ROOT / "install/languages/javascript.sh"))
        result = self.command(*command, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.base / "calls").read_text().splitlines()
        self.assertIn("install 22.17.0", calls)
        self.assertIn("install 24", calls)
        self.assertIn("alias default 22.17.0", calls)
        self.assertFalse(any(line in ("install 18", "install 20") for line in calls))
        result = self.command(*command, env={**env, "FAIL_STEP": "nvm-install"})
        self.assertNotEqual(result.returncode, 0)
        (self.base / "calls").unlink()
        env.pop("DOTFILES_NODE_VERSIONS")
        env.pop("DOTFILES_NODE_DEFAULT")
        result = self.command(*command, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.base / "calls").read_text().splitlines()
        self.assertIn("install --lts", calls)
        self.assertIn("alias default lts/*", calls)

    def test_python_tool_failure_stops_install(self):
        env = self.update_env()
        self.file("fake-bin/uv", "#!/bin/sh\nexit 23\n", True)
        result = self.command("bash", str(ROOT / "install/languages/python.sh"), env=env)
        self.assertEqual(result.returncode, 23, result.stderr)

    def test_java_repeat_install_handles_export_hook_in_noninteractive_bash(self):
        env = self.update_env()
        env.pop("PROMPT_COMMAND", None)
        env["JENV_TEST_STATE"] = str(self.base / "jenv-export-enabled")
        self.file("fake-bin/jenv", '''#!/bin/sh
case "$1" in
    init)
        if [ -f "$JENV_TEST_STATE" ]; then
            echo 'if [ -z "$PROMPT_COMMAND" ]; then PROMPT_COMMAND="jenv refresh"; fi'
        fi
        ;;
    enable-plugin) touch "$JENV_TEST_STATE" ;;
esac
exit 0
''', True)
        for attempt in (1, 2):
            with self.subTest(attempt=attempt):
                result = self.command("bash", str(ROOT / "install/languages/java.sh"), env=env)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_stale_cask_does_not_erase_inventory(self):
        def query(args):
            output = None
            if args == ["brew", "list", "--formula", "--versions"]:
                output = "git 2.50.0\n"
            elif args == ["brew", "list", "--cask", "-1"]:
                output = "codex-app\niterm2\n"
            elif args == ["brew", "list", "--cask", "--versions", "iterm2"]:
                output = "iterm2 3.6.0\n"
            elif args == ["brew", "services", "list", "--json"]:
                output = "[]"
            return subprocess.CompletedProcess(args, 0, output, "") if output is not None else None
        with patch.object(state, "run", side_effect=query):
            data = state.brew_inventory()
        self.assertEqual(data["cask"]["status"], "partial")
        self.assertEqual(data["cask"]["items"], {"codex-app": None, "iterm2": ["3.6.0"]})
        self.assertEqual(data["cask"]["unavailable_versions"], ["codex-app"])

    def test_compare_cli_preserves_partial_exit_and_private_report(self):
        data = self.sample()
        data["runtimes"]["java"] = {"status": "unavailable", "version": None}
        baseline = self.file("baseline.json", json.dumps(data))
        report = self.base / "report.json"
        result = self.command("python3", str(ROOT / "scripts/setup-state.py"), "compare", str(baseline), str(baseline), "--output", str(report))
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(json.loads(report.read_text())["status"], "partial")
        self.assertEqual(report.stat().st_mode & 0o777, 0o600)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is needed to exercise plugin startup")
    def test_piped_shell_registers_and_bootstraps_plugins_without_missing_cache(self):
        self.file("brew/opt/zplug/init.zsh", '''zplug() {
    case "$1" in
        check) [[ -f "$ZPLUG_HOME/installed" ]] ;;
        install) [[ -n "${TERM:-}" && "$TERM" != dumb ]] || return 44; mkdir -p "$ZPLUG_HOME"; touch "$ZPLUG_HOME/installed"; echo install >> "$CALL_LOG" ;;
        load) [[ -f "$ZPLUG_HOME/installed" ]] || return 42; echo load >> "$CALL_LOG" ;;
        *) [[ ! -p /dev/stdin ]] || return 43; echo "register:$1" >> "$CALL_LOG" ;;
    esac
}
''')
        env = {**self.env, "TERM": "dumb", "ZPLUG_HOME": str(self.home / ".zplug"), "CALL_LOG": str(self.base / "calls")}
        command = ["zsh", "-f", "-c", 'BREW_PREFIX="$1"; source "$2"', "_", str(self.base / "brew"), str(ROOT / "config/zsh/plugins")]
        # capture_output + input gives the shell exactly the pipe stdin used by SSH.
        result = subprocess.run(command, env=env, input="", capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.base / "calls").read_text().splitlines()
        self.assertEqual(len([line for line in calls if line.startswith("register:")]), 8)
        self.assertNotIn("load", calls)
        result = subprocess.run(command, env={**env, "DOTFILES_INSTALL_ZSH_PLUGINS": "true"}, input="", capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / ".zplug/installed").exists())
        self.assertEqual((self.base / "calls").read_text().splitlines()[-2:], ["install", "load"])

    def test_vlc_fallback_accepts_only_pinned_official_artifacts(self):
        asset = self.file("mirror.dmg", "fixture artifact")
        checksum = hashlib.sha256(asset.read_bytes()).hexdigest()
        metadata = self.file("metadata.json", json.dumps({"casks": [{"url": "https://get.videolan.org/vlc/3.0.24/macosx/vlc-arm64.dmg", "sha256": checksum}]}))
        cache = self.base / "cache/vlc.dmg"
        self.file("fake-bin/brew", '''#!/bin/sh
if [ "$1" = info ]; then /bin/cat "$METADATA"; else echo "$CACHE_FILE"; fi
''', True)
        self.file("fake-bin/curl", '''#!/bin/sh
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then shift; /bin/cp "$MIRROR_ASSET" "$1"; exit $?; fi
    shift
done
exit 1
''', True)
        env = {**self.env, "PATH": str(self.base / "fake-bin") + ":" + self.env["PATH"], "METADATA": str(metadata), "CACHE_FILE": str(cache), "MIRROR_ASSET": str(asset)}
        command = ["bash", "-c", 'source "$1"; dotfiles_cache_vlc_from_official_mirror', "_", str(ROOT / "install/macos/downloads.sh")]
        result = self.command(*command, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(cache.read_bytes(), asset.read_bytes())
        cache.unlink()
        data = json.loads(metadata.read_text())
        data["casks"][0]["sha256"] = "0" * 64
        metadata.write_text(json.dumps(data))
        result = self.command(*command, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(cache.exists())
        data["casks"][0].update(url="https://untrusted.invalid/vlc.dmg", sha256=checksum)
        metadata.write_text(json.dumps(data))
        self.assertNotEqual(self.command(*command, env=env).returncode, 0)
        self.assertFalse(cache.exists())

    @unittest.skipUnless(shutil.which("zsh"), "zsh is needed to exercise Python PATH")
    def test_python_command_uses_python3_and_preserves_active_environments(self):
        binary = self.base / "brew/opt/python/libexec/bin/python"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\nexec " + shlex.quote(sys.executable) + " \"$@\"\n")
        binary.chmod(0o755)
        env = {**self.env, "HOMEBREW_PREFIX": str(self.base / "brew"), "PATH": "/usr/bin:/bin"}
        env.pop("VIRTUAL_ENV", None)
        command = ["zsh", "-f", "-c", 'source "$1"; command -v python; python -c "import sys; assert sys.version_info.major == 3"', "_", str(ROOT / "config/zsh/python-path")]
        result = self.command(*command, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(binary))
        active = self.file("venv/bin/python", "#!/bin/sh\necho active-environment\n", True)
        command[3] = 'source "$1"; command -v python'
        for setting in ("VIRTUAL_ENV",):
            result = self.command(*command, env={**env, setting: str(self.base / "venv"), "PATH": str(active.parent) + ":" + env["PATH"]})
            self.assertEqual(result.stdout.strip(), str(active))

    def test_smb_name_uses_network_name_instead_of_display_spaces(self):
        result = self.command("bash", "-c", 'DOTFILES_DEFAULTS_MODE=list; DOTFILES_DEFAULTS_PROFILE=common; DOTFILES_COMPUTER_NAME_VALUE="Dotfiles Smoke"; source "$1"; dotfiles_defaults_run_registry', "_", str(ROOT / "install/macos/defaults/registry.sh"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("NetBIOSName\tDotfiles-Smoke\t", result.stdout)

    def test_preference_capture_filters_private_keys_and_opaque_values(self):
        directory = self.base / "preferences"
        directory.mkdir()
        policy = {"domains": [{"target": "user", "domain": "example.ui", "restart": "none", "keys": ["Enabled", "Location", "Opaque"]}]}
        data = {"Enabled": True, "Location": str(self.home / "Screenshots"), "Opaque": b"opaque", "AccountToken": "DO NOT EXPORT", "RecentDocuments": ["private"]}
        (directory / prefs.domain_filename("user", "example.ui")).write_bytes(plistlib.dumps(data))
        report = prefs.capture(policy, directory, self.home)
        self.assertEqual([entry["key"] for entry in report["entries"]], ["Enabled", "Location"])
        self.assertEqual(report["entries"][1]["value"], "__DOTFILES_HOME__/Screenshots")
        self.assertNotIn("DO NOT EXPORT", json.dumps(report))
        self.assertNotIn("RecentDocuments", json.dumps(report))

    def test_preference_reference_distinguishes_equal_different_and_unknown(self):
        entries = [{"target": "user", "domain": "ui", "restart": "none", "kind": "int", "key": key, "value": value} for key, value in (("Same", 1), ("Different", 2), ("Unknown", 3))]
        current = {"macos": "15.8.2", "captured_at": "fixture", "entries": entries}
        reference = {"macos": "15.7.7", "entries": [{**entries[0]}, {**entries[1], "value": 0}]}
        policy = {"domains": [{"target": "user", "domain": "ui", "keys": ["Same", "Different", "Unknown"]}]}
        snapshot = prefs.build(current, reference, policy)
        self.assertFalse(snapshot["same_os_version"])
        self.assertEqual([entry["comparison"] for entry in snapshot["entries"]], ["same-as-reference", "different-from-reference", "reference-missing; factory-default-unknown"])
        self.assertTrue(all(entry["default_confidence"] == "provisional" for entry in snapshot["entries"]))
        self.assertTrue(all(entry['apply'] is False for entry in snapshot['entries']))
        self.assertNotIn('dotfiles_default_int ', prefs.render(snapshot))
        verified = prefs.build(current, {**reference, 'macos': current['macos'], 'factory_defaults_verified': True}, policy)
        self.assertEqual([entry['key'] for entry in verified['entries'] if entry['apply']], ['Different'])
        rendered = prefs.render(verified)
        self.assertIn(' Different ', rendered)
        self.assertNotIn(' Same ', rendered)
        self.assertNotIn(' Unknown ', rendered)
        with self.assertRaises(ValueError):
            prefs.build({**current, "entries": [{**entries[0], "key": "AccountToken"}]}, reference, policy)

    def test_generated_preferences_quote_values_without_executing_them(self):
        sentinel = self.base / "must-not-exist"
        entry = {"target": "user", "domain": "example.ui", "restart": "none", "kind": "string", "key": "Value", "value": "$(touch " + str(sentinel) + ")", "apply": True}
        generated = self.file("generated.sh", prefs.render({"entries": [entry]}))
        result = self.command("bash", "-c", 'dotfiles_default_string() { printf "%s" "$5"; }; source "$1"', "_", str(generated))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, entry["value"])
        self.assertFalse(sentinel.exists())
        with self.assertRaises(ValueError):
            prefs.render({"entries": [{**entry, "kind": "unexpected; command"}]})

    def test_appstore_auth_failure_is_pending_and_does_not_store_credentials(self):
        app = {"id": "6745342698", "name": "uBlock Origin Lite.app", "bundle_id": "net.raymondhill.uBlock-Origin-Lite"}
        result = subprocess.CompletedProcess(["mas"], 1, "", "DO NOT RECORD AUTHENTICATION DETAILS")
        with patch.object(store, "installed", return_value=False), patch.object(store.subprocess, "run", return_value=result):
            report = store.install([app])
        self.assertEqual(report["status"], "pending")
        self.assertNotIn("DO NOT RECORD", json.dumps(report))
        with patch.object(store, "installed", return_value=True), patch.object(store.subprocess, "run") as runner:
            self.assertEqual(store.install([app])["status"], "installed")
            runner.assert_not_called()

    def test_float_preference_audit_accepts_equivalent_numeric_format(self):
        result = self.command("bash", "-c", 'source "$1"; dotfiles_defaults_reset; defaults() { echo 64; }; dotfiles_defaults_audit_float user domain key 64.0; test "$DOTFILES_DEFAULTS_MATCHED" -eq 1', "_", str(ROOT / "install/macos/defaults/lib.sh"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_reference_capture_visits_every_domain_without_ssh_draining_input(self):
        repo = self.base / "reference-repo"
        for name in ("tests/smoke/capture-reference.sh", "scripts/preferences.py", "install/macos/defaults/capture-policy.json"):
            dest = repo / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, dest)
        self.file("mock-bin/tart", '#!/bin/bash\ncase "$1" in list) echo "Source Name State"; echo "local dotfiles-default-reference stopped";; ip) echo 192.0.2.1;; esac\n', executable=True)
        self.file("mock-bin/sshpass", '#!' + sys.executable + '\n' + '''import sys, plistlib
command = sys.argv[-1]
if command.startswith('defaults '):
    if '-n' not in sys.argv:
        sys.stdin.read()
    sys.stdout.buffer.write(plistlib.dumps({'ShowPathbar': True, 'tilesize': 64.0}))
elif command == 'sw_vers -productVersion':
    print('15.7.7')
''', executable=True)
        result = self.command("bash", str(repo / "tests/smoke/capture-reference.sh"), env={**self.env, "PATH": str(self.base / "mock-bin") + os.pathsep + self.env["PATH"]})
        self.assertEqual(result.returncode, 0, result.stderr)
        policy = json.loads((repo / "install/macos/defaults/capture-policy.json").read_text())
        output = self.base / "cache/dotfiles/defaults-reference"
        self.assertFalse((repo / "tmp").exists())
        raw = output / "raw"
        self.assertEqual(len(list(raw.glob("*.plist"))), len(policy["domains"]))
        snapshot = json.loads((output / "reference.json").read_text())
        self.assertIn('ShowPathbar', {entry['key'] for entry in snapshot['entries']})
        self.assertIn('tilesize', {entry['key'] for entry in snapshot['entries']})


if __name__ == "__main__":
    unittest.main(verbosity=2)
