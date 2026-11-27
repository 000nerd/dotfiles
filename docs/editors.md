# Shared editor configuration

[Back to README](../README.md)

The editor command applies and checks portable settings for VS Code and Zed on
macOS and Linux. It requires Python 3; VS Code extension installation also needs
its `code` CLI (the installed macOS app CLI is used as a fallback).

## Apply and check

Install the editors and configured font first. The macOS cask declarations
include VS Code, Zed, and BlexMono Nerd Font.

```sh
dotfiles editors apply --dry-run
dotfiles editors apply
# Open Zed to finish any pending extension downloads, then check again.
dotfiles editors check
```

Use `--editor vscode` or `--editor zed` when managing one editor:

```sh
dotfiles editors render --editor vscode
dotfiles editors apply --editor zed --dry-run
dotfiles editors apply --editor vscode --settings-only
dotfiles editors check --exact-versions
```

`render` prints effective declarations without writing settings. Dry-run previews
apply without writes, backups, or extension installation. `--settings-only`
prevents VS Code downloads; Zed's declared auto-install list still takes effect
when Zed launches.

## Configuration and precedence

| Source | Purpose |
| --- | --- |
| [vscode.json](../config/editors/vscode.json), [zed.json](../config/editors/zed.json) | Editor-specific portable settings |
| [policy.json](../config/editors/policy.json) | Shared fonts, themes, Vim mode, privacy, whitespace, and formatter assignments |
| [extensions.json](../config/editors/extensions.json) | Required extension IDs and observed versions |
| `editors.local.json` | Device overrides applied last |

Settings merge in this order: editor-specific declarations, shared policy, then
local overrides. Edit the shared policy to change both editors together.
Removing a declaration stops managing it and retains the existing device value.
Removing an extension from the manifest stops requiring it; it does not uninstall it.

The default local override is
`${XDG_CONFIG_HOME:-~/.config}/dotfiles/editors.local.json`. Create it from
[local.example.json](../config/editors/local.example.json), using paths appropriate
to the device. `--local-overrides PATH` selects another file. Keep machine-specific
JDK paths in this local file.

## Apply behavior

Apply merges managed settings while preserving unrelated keys and settings-file
symlinks/permissions. Changed files are backed up; semantically matching files
keep their contents, comments, and timestamps. Rewritten JSONC becomes formatted
JSON, with original bytes retained in the backup. The obsolete global VS Code
`editor.defaultFormatter` is removed unless explicitly restored by a local override.

Missing VS Code extensions are installed by ID, and the registry is checked
again. Zed extension IDs are declared in `auto_install_extensions`; Zed handles
the downloads on launch. Disabled required VS Code extensions are reported for
manual enablement. Additional extensions remain installed.

Apply runs check afterward. Pending extensions, a missing font, or other drift
can therefore produce a nonzero result even after settings were saved.

## Check behavior and exit codes

Check reads managed preference values and local extension registries. It checks
required extension presence, global VS Code enablement, installed font filenames,
and explicitly configured JDK paths. It does not start an editor or download
extensions. Registry errors and malformed configuration are reported as errors.

| Code | Meaning |
| --- | --- |
| `0` | Operation passed; dry-run could construct its plan |
| `1` | Managed settings, extensions, font, or configured machine paths differ |
| `2` | Configuration or operation error |

Observed extension versions are an audit baseline, not installation pins. Normal
checks accept version differences; `check --exact-versions` treats them as drift.
Apply installs current compatible releases and does not downgrade to recorded versions.

## Themes and formatting

`shared.theme` selects `gruvbox`, `gruvbox-material`, or `everforest`. The policy
contains each editor's light/dark pairings. `dotfiles theme apply` can change
appearance fields separately; editor check reports those differences, and editor
apply restores the policy. Settings Sync can also change managed values.

The shared font policy also supplies Codex's code font; see [themes](themes.md#fonts).
The policy assigns Prettier, Ruff, gopls, SourceKit, LemMinX, and the configured
Java servers to their respective languages. VS Code uses Oracle Java and Zed uses
JDTLS, so matching Java output is not guaranteed. Pin formatter versions and
configuration in each project when identical output matters.

## Backups, paths, and scope

Backups live under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/editors/backups/<run>/` as
`vscode.settings.jsonc` and `zed.settings.jsonc`. To restore one, close the editor
and copy the selected backup contents to its settings file.

Redirect settings/extension locations with `DOTFILES_VSCODE_SETTINGS_PATH`,
`DOTFILES_ZED_SETTINGS_PATH`, `DOTFILES_VSCODE_EXTENSIONS_DIR`, and
`DOTFILES_ZED_EXTENSIONS_DIR`. XDG config/data/state directories are honored by
the editor tool.

The inventory covers the default local editor profile. It does not read or sync
project `.vscode`/`.zed` files, named VS Code profiles, remote/container extensions,
snippets, or custom keybinding files. The bundled declarations contain no
authentication or MCP settings; undeclared settings are preserved. Local overrides
can add managed settings, so review the effective declarations with `render`.
Configuration checks do not establish that a language server, debugger, or
formatter works in a live project; verify those in a scratch project.
