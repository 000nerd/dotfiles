# dotfiles

![gruvbox-dark](screenshots/screen-gruvbox-dark.png)

See the screenshots folder for (possibly outdated) screenshots of other themes.

## installation

1. Clone this repo to `~/.dotfiles`
2. Run `./scripts/install.sh`
3. Symlink your dotfiles with `rcup -x README.md -x screenshots -x scripts -x iterm -v`
4. Install your vim and tmux plugins (`:PlugInstall` in vim and `Ctrl-Space I` in tmux)
5. Install a proper [nerdfont](http://nerdfonts.com/)

## rcm

I use [rcm](https://thoughtbot.github.io/rcm/rcm.7.html) to manage my dotfiles. Useful commands are:

```bash
# Dry run
lsrc -x README.md -x screenshots -x scripts -x iterm

# Add new dotfile from homedir to .dotfiles
mkrc ~/.new-dotfile

# Symlink new dotfile from .dotfiles to homedir
rcup new-dotfile
```

## switch themes

1. Import and apply the relevant iterm2 theme from `/iterm`
2. Uncomment the appropriate script in `.zshenv`
3. Restart terminal

## license

[MIT](http://ismay.mit-license.org/)
