# Themes

[Back to README](../README.md)

Bundled profiles are `gruvbox`, `gruvbox-material`, and `everforest`. Their
declarations live in [config/themes/profiles](../config/themes/profiles/), with
app-specific assets alongside them.

## Choose a profile

```sh
dotfiles theme list
dotfiles theme current
dotfiles theme apply gruvbox --apps vscode,zsh --dry-run
dotfiles theme apply gruvbox --apps vscode,zsh
```

Without `--apps`, apply visits every target declared in the selected profile.
Use an explicit list to select the applications you want to configure.
`--dry-run` prints the intended changes without writing files, importing presets,
or installing extensions.

| Target | Behavior |
| --- | --- |
| `codex` | Write appearance/code-font settings through the native Codex config writer |
| `vscode` | Update the user color theme and report required extensions |
| `obsidian` | Update configured vault appearance settings |
| `iterm` | Open the bundled iTerm color preset for import on macOS |
| `terminal` | Open the bundled Terminal profile for import on macOS |
| `zsh` | Select the bundled shell prompt through a generated link |

Xcode assets remain in [config/themes/xcode](../config/themes/xcode/) for manual
import; Xcode is not an apply target. Zed appearance is managed by
[editor policy](editors.md#themes-and-formatting).

For VS Code, `--install-missing` requests missing theme extensions through `code`.
Without it, missing extensions are reported. For Obsidian, set vaults in the
profile or use `DOTFILES_OBSIDIAN_VAULTS` (separated by the platform path separator).
The CSS theme must already be installed; `--force` bypasses that presence check.

## Fonts

[config/editors/policy.json](../config/editors/policy.json) supplies the shared
font family, fallbacks, editor size, and terminal size. Its declarations use
BlexMono Nerd Font Mono, editor size 15, and terminal size 12.

The editor command applies `shared.font_size` to VS Code/Zed. The Codex theme
adapter uses `shared.terminal_font_size` and the shared font family/fallbacks,
clearing a selected code-face override. It preserves UI/prose font choices.

The iTerm target imports colors only. Set its font manually in the profile's
Text settings to match the policy if desired; no live iTerm profile is managed
by the font policy. Numeric font sizes can render differently between apps.

## Codex adapter

```sh
dotfiles theme apply gruvbox --apps codex --dry-run
dotfiles theme apply gruvbox --apps codex
```

The repository adapter requires `codex` on `PATH`, or `DOTFILES_CODEX_CLI` pointing
to another executable. `CODEX_HOME` selects the configuration home; the default
is `~/.codex`. The adapter targets appearance keys under `[desktop]` in
`config.toml`, using native `config/read` and `config/batchWrite` calls.

It backs up changed configuration as `config.toml.bak.<timestamp>`, checks the
configuration version, and verifies effective values after writing. Matching
values are left alone. Errors return nonzero and do not record a successful
theme selection. Dry-run does not start the CLI. Restart the desktop app if its
appearance has not refreshed after apply.

## Zsh prompts and theme state

```sh
dotfiles theme apply everforest --apps zsh
exec zsh -l
```

Zsh loads the selected prompt from
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/current-theme.zsh`, falling back to
`config/zsh/prompt` when no selected prompt exists. Selectable prompts share
`config/zsh/git-prompt` for Git dirty-state detection. No Oh My Zsh theme download
or `ZSH_THEME` setting is needed for this setup.

The last applied profile name is stored beside the prompt link as `theme-current`.
`theme current` reads that marker; it does not audit every application's live
appearance. `DOTFILES_THEME_STATE_FILE` and `DOTFILES_ZSH_THEME_TARGET` override
the writer's paths. Zsh startup reads the default state-directory link; a custom
theme target requires a corresponding shell customization.

## iTerm and Terminal imports

```sh
dotfiles theme apply gruvbox-material --apps iterm,terminal
```

These targets open their bundled files. Select the imported preset/profile in
the application if it does not become active automatically.

The standalone iTerm importer accepts bundled preset names and `.itermcolors`
paths. It requires Python 3 and edits the preferences plist directly; quit iTerm
before using it and reopen afterward.

```sh
bash scripts/import-iterm-scheme.sh gruvbox-dark
bash scripts/import-iterm-scheme.sh config/themes/iterm/gruvbox-light.itermcolors
```

It parses plist data, validates preset names, escapes external names/paths for
display, preserves unrelated preferences and the existing plist format, and
backs up changes. Missing preferences start with an empty preset collection.

Regenerate the bundled Terminal profiles on macOS from the repository root:

```sh
swift scripts/generate-terminal-profiles.swift
```

## Backups and source notes

Theme-written JSON settings preserve existing file modes and symlinks, with
sibling `.bak.<timestamp>` copies before writes. Use the corresponding application's
settings path to select a backup for restoration. Editor-policy backups have a
separate location described in [editors](editors.md#backups-paths-and-scope).

The bundled Gruvbox prompt derives from Agnoster's Powerline-style prompt; the
Material and Everforest variants share its implementation with different palette
settings. Upstream attribution remains in the theme source comments. See the
[repository license](../LICENSE).
