"       ____    ___   ___   _________   ________   _    _
"      /  __|  |   \ /   | |____ ____| |____ ___| | |  | |
"     /  /     | |\   /| |     | |         | |    | |  | |
"      \  \    | | | | | |     | |         | |    | |__| |
"       \  \   | | | | | |     | |         | |    |  __  |
"        |  |  | | | | | |     | |         | |    | |  | |
"       _/  /  | | | | | |  ___| |___      | |    | |  | |
"      |___/   |_| |_| |_| |_________|     |_|    |_|  |_|
"

set nocompatible

set autoindent
set expandtab
set hidden
set hlsearch
set incsearch
set novisualbell
set number
set paste
set ruler
set shiftwidth=4
set showmatch
set smartindent
set softtabstop=4
set title
set virtualedit=all
set wildmode=list:longest
set splitbelow
set splitright
runtime macros/matchit.vim

call pathogen#infect()

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
autocmd FileType ruby,eruby set filetype=ruby.eruby.chef

filetype plugin on

nmap <silent> <C-M> :silent noh<CR> :echo "Highlights Cleared! bjoli"<CR>

let mapleader = ','
" http://stevelosh.com/blog/2010/09/coming-home-to-vim/
" ,W = strip all trailing whitespace in the current file
nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>

syntax on
let g:solarized_termcolors=256
colorscheme solarized
if has('gui_running')
  set background=light
else
  set background=dark
endif

autocmd BufNewFile,BufRead *.bbcode set syntax=bbcode
autocmd BufNewFile,BufRead *.gradle set syntax=java
autocmd BufNewFile,BufRead *.json set ft=javascript
autocmd BufNewFile,BufRead BUILD* set syntax=python
autocmd BufNewFile,BufRead kubeconfig* set syntax=yaml

"Kill all the trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" For vim-airline to display
set laststatus=2

silent! if emoji#available()
  let g:gitgutter_sign_added = emoji#for('small_blue_diamond')
  let g:gitgutter_sign_modified = emoji#for('small_orange_diamond')
  let g:gitgutter_sign_removed = emoji#for('small_red_triangle')
  let g:gitgutter_sign_modified_removed = emoji#for('collision')
endif

" Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
"let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:terraform_fmt_on_save = 0

"TODO(jmsmith): Remove on 18.04
let g:go_version_warning = 0

" Our custom hackfmt wrapper doesn't play well with ALE's builtin hackfmt fixer
function! Slackfmt(buffer) abort
    let l:executable ='/Users/jmsmith/workspace/slack-github.com/slack/webapp/bin/hackfmt'
    return {'command': ale#Escape(l:executable) . ' %t -i %s', 'read_temporary_file': 1,}
endfunction
let g:ale_fixers={'hack': ['Slackfmt']}
