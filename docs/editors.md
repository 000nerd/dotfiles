# Editor policy

Run `dotfiles editors apply --dry-run`, `dotfiles editors apply`, and
`dotfiles editors check`. Both macOS and Linux are supported. Use `--editor
vscode` or `--editor zed` when only one editor is installed. Python 3 is the only
runtime needed to read, render, and audit configuration; VS Code downloads also
require its `code` CLI (the macOS application CLI is a fallback).

## Sources of truth

- `config/editors/policy.json`: shared font, Vim, privacy, theme pairing, whitespace, and language
  formatter assignments. Edit this to change both editors together.
  `font_family` and `font_fallbacks` also supply Codex's code font when running
  `dotfiles theme apply <theme> --apps codex`. `font_size` controls VS Code/Zed;
  `terminal_font_size` controls Codex's code size (12, matching the current iTerm
  profile). See the [main README](../README.md) for iTerm's profile settings.
- `config/editors/vscode.json` and `config/editors/zed.json`: editor-specific portable preferences, merged before
  the shared policy. Shared policy wins where both declare a preference.
- `config/editors/extensions.json`: every installed non-built-in extension on the source device,
  including its observed version. IDs are installation requirements; recorded
  versions are an optional audit baseline, not pins. Update the manifest when you
  intentionally add/remove required extensions. Removing an extension here stops
  requiring it and does not uninstall it.
- `$XDG_CONFIG_HOME/dotfiles/editors.local.json` (default `~/.config/...`): local
  `vscode` and `zed` objects applied last. `config/editors/local.example.json` shows the shape.
  Supply `--local-overrides PATH` to select a different file.

`render` prints the effective managed settings after local overrides. Applying
merges recursively, preserving unmanaged keys and nested values. Removing a key
from the declarations stops managing it and retains the device's existing value.
The obsolete global VS Code `editor.defaultFormatter` is explicitly removed so
per-language assignments work; an explicit local override can opt back into it.
The command never imports or modifies `.vscode`/`.zed` project settings, authentication,
MCP configuration, or named VS Code profiles. It does not sync snippets or custom
keybinding files. Existing settings files are backed up before semantic changes;
when rewritten, JSONC comments are removed from the active file but preserved in
that original backup. Semantically matching files are not rewritten. Existing
settings symlinks are followed and retained.

New editor preferences should be added here intentionally rather than by copying
entire application state directories. Machine paths such as a JDK installation are
not portable; keep them in the local override. Existing unowned paths remain intact.

## Apply and check behavior

Apply installs missing VS Code extension IDs, verifies the registry afterward,
and sets every Zed extension ID to `true` in `auto_install_extensions`. Zed manages
its own downloads on launch. Pending extensions cause a nonzero result until Zed
has installed them; launch it, then rerun check. `--settings-only` prevents VS Code
installation, but Zed still honors its declared auto-install list when it launches.
No extension is removed or silently enabled. A disabled required VS Code extension
must be enabled in its UI and is reported by check.

Check compares only managed preference leaves and required extension IDs. Additional
extensions and unmanaged preferences are retained. `--exact-versions` also fails on
extension versions differing from the captured manifest; apply does not downgrade
or pin them. Registry errors and malformed configuration are errors, never empty
inventories. The font check uses normalized installed font filenames, not a live
font-rendering test. JDK paths are checked when explicitly configured. This is a
configuration/installation audit, not a live LSP or debugger acceptance test.

Exit status: `0` means the requested operation/check passed, `1` means settings,
extensions, font, or configured machine-path drift remains, and `2` means an
operation or configuration error. Dry-run always avoids writes, backups, and
installation, and exits `0` when it can construct the plan. CLI installation failure
is reported as an error; successfully applied settings are retained with backups.

Paths can be redirected with `DOTFILES_VSCODE_SETTINGS_PATH`,
`DOTFILES_ZED_SETTINGS_PATH`, `DOTFILES_VSCODE_EXTENSIONS_DIR`, and
`DOTFILES_ZED_EXTENSIONS_DIR`. XDG config/data/state directories are honored.
Use these to manage a non-default installation deliberately. The inventory covers
the default local VS Code profile, not remote SSH, containers, WSL, or other profiles.
Do not use the same extension directory concurrently for unrelated installations.

The existing `dotfiles theme` command can change managed appearance keys; check will
report that difference. To persist a shared editor theme, change the policy theme
pairing. The shared `theme` can be `gruvbox`, `gruvbox-material`, or `everforest`.
The installed Zed Gruvbox Material port has one dark variant; its light pairing
uses built-in Gruvbox Light. Applying the editor policy returns to the declared pairing. VS Code Sync
may similarly change managed settings; choose one authority for these values.

## Formatting consistency

The policy preserves current per-language choices: Prettier for web/documents,
Ruff for Python, gopls for Go, SourceKit for Swift, LemMinX for XML, and native Java
servers. Java uses Oracle in VS Code and JDTLS in Zed, so identical Java formatting
is not promised. The installed extensions and auto-downloaded language servers may
use different fallback tool versions across devices. This audit records extension
versions, not every dynamically downloaded tool. For exact formatting, pin the same
tool versions and configuration in each project and use the same formatter in CI.
Keep `.editorconfig`, Prettier plus its lockfile, `pyproject.toml`, and `.swift-format`
with project sources as appropriate.

Settings backups are in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/editors/backups/`.
To restore one, close the editor and copy its backed-up `*.settings.jsonc` contents
back to that editor's settings file. Review future apply plans before replacing
intentional local choices.

References: [Zed auto-install configuration](https://zed.dev/docs/reference/all-settings),
[VS Code Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync).
