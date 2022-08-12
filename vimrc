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
set colorcolumn=100
runtime macros/matchit.vim

filetype plugin on

nmap <silent> <C-M> :silent noh<CR> :echo "Highlights Cleared! bjoli"<CR>

let mapleader = ','
" http://stevelosh.com/blog/2010/09/coming-home-to-vim/
" ,W = strip all trailing whitespace in the current file
nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>

syntax on
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
