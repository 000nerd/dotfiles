Installation
Download iTerm2 Gruvbox Color Scheme and import into iTerm. iTerm2 Preferences -> Profiles -> Colors -> Color Preset
Download and install a Nerd Font.
Download gruvbox.zsh-theme and put it in ~/.oh-my-zsh/custom/themes/.
curl -L https://raw.githubusercontent.com/sbugzu/gruvbox-zsh/master/gruvbox.zsh-theme > ~/.oh-my-zsh/custom/themes/gruvbox.zsh-theme
Enable the theme, add the following to your ~/.zshrc or ~/.oh-my-zsh/custom/custom.zsh file
ZSH_THEME="gruvbox"
SOLARIZED_THEME="dark"

Add above to your dotfiles https://github.com/sbugzu/gruvbox-zsh