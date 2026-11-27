# Themes

Run these commands from the repository root:

```sh
dotfiles theme list
dotfiles theme apply gruvbox --dry-run
dotfiles theme apply gruvbox --apps vscode,iterm,terminal,zsh
```

Theme declarations are in `config/themes/profiles/`. App-specific assets are in
`config/themes/{iterm,terminal,xcode,zsh}/`. `scripts/theme.py` implements the
command; supported targets are Codex, VS Code, Obsidian, iTerm, Terminal, and Zsh.
IntelliJ integration and its scheme files have been removed.

The shared font policy is `config/editors/policy.json`. See the
[main README](../README.md#matching-the-iterm-font-in-codex) for Codex behavior.
Xcode theme assets remain available for manual import.

The selected theme name and generated Zsh theme link live under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/`. `DOTFILES_THEME_STATE_FILE` and
`DOTFILES_ZSH_THEME_TARGET` override those paths. On another machine, reapply the
Zsh theme after updating the checkout if an old generated link exists.

See [iTerm imports](themes-iterm.md) and the [Zsh theme source notes](themes-zsh.md).
To regenerate the bundled Terminal profiles on macOS, run
`swift scripts/generate-terminal-profiles.swift` from the repository root.
