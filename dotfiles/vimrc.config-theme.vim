" ==================================================================================================
" Theme settings
" ==================================================================================================

if $VIM_THEME == 'gruvbox-dark'
  if has_key(g:plugs, 'gruvbox')
    let g:gruvbox_italic = 1
    colorscheme gruvbox
    exe 'highlight StatusLine guifg=' . $VIM_STATUS_BAR_FG 'guibg=' . $VIM_STATUS_BAR_BG
  endif

  if has_key(g:plugs, 'vim-airline')
    let g:airline_theme='gruvbox'
  endif

  if has_key(g:plugs, 'ale')
    exe 'highlight ALEErrorSign guifg=' . $VIM_ALE_ERROR_FG 'guibg=' . $VIM_ALE_ERROR_BG
    exe 'highlight ALEWarningSign guifg=' . $VIM_ALE_WARNING_FG 'guibg=' . $VIM_ALE_WARNING_BG
  endif
endif

if $VIM_THEME == 'onehalf-dark'
  if has_key(g:plugs, 'onehalf')
    colorscheme onehalfdark
  endif

  if has_key(g:plugs, 'vim-airline')
    let g:airline_theme='onehalfdark'
  endif
endif

if $VIM_THEME == 'gotham'
  if has_key(g:plugs, 'vim-gotham')
    colorscheme gotham
  endif
endif

if $VIM_THEME == 'iceberg'
  if has_key(g:plugs, 'iceberg.vim')
    colorscheme iceberg
  endif

  if has_key(g:plugs, 'ale')
    exe 'highlight ALEErrorSign guifg=' . $VIM_ALE_ERROR_FG 'guibg=' . $VIM_ALE_ERROR_BG
    exe 'highlight ALEWarningSign guifg=' . $VIM_ALE_WARNING_FG 'guibg=' . $VIM_ALE_WARNING_BG
  endif
endif
