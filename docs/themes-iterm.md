# iTerm color presets

Bundled presets live in `config/themes/iterm/`. Run from the repository root:

```sh
dotfiles theme apply gruvbox --apps iterm
dotfiles theme apply gruvbox-material --apps iterm
dotfiles theme apply everforest --apps iterm
```

The command opens the preset in iTerm. Select the imported preset in the active
profile's Colors settings if iTerm does not select it automatically.

The standalone importer is `scripts/import-iterm-scheme.sh`. It accepts a bundled
preset name or an `.itermcolors` file path:

```sh
bash scripts/import-iterm-scheme.sh gruvbox-dark
bash scripts/import-iterm-scheme.sh config/themes/iterm/gruvbox-light.itermcolors
```

The standalone importer edits iTerm's preferences plist directly; quit iTerm
before using it and reopen afterward. Prefer the theme command for normal use.
