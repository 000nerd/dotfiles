# vim:ft=zsh ts=2 sw=2 sts=2
#
# Gruvbox Material prompt colors for the local Powerline-style prompt.
# Palette: sainnhe/gruvbox-material dark medium.

CURRENT_BG='NONE'
CURRENT_FG='0'

ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_PROMPT_CONTEXT_BG='237'
ZSH_PROMPT_CONTEXT_FG='223'
ZSH_PROMPT_DIR_BG='109'
ZSH_PROMPT_DIR_FG='237'
ZSH_PROMPT_GIT_CLEAN_BG='142'
ZSH_PROMPT_GIT_DIRTY_BG='214'
ZSH_PROMPT_GIT_FG='237'
ZSH_PROMPT_STATUS_BG='167'
ZSH_PROMPT_STATUS_FG='223'

source "${${(%):-%N}:A:h}/gruvbox.zsh-theme"
