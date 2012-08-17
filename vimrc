"       ____    ___   ___   _________   ________   _    _
"      /  __|  |   \ /   | |____ ____| |____ ___| | |  | |
"     /  /     | |\   /| |     | |         | |    | |  | |
"      \  \    | | | | | |     | |         | |    | |__| |
"       \  \   | | | | | |     | |         | |    |  __  |
"        |  |  | | | | | |     | |         | |    | |  | |
"       _/  /  | | | | | |  ___| |___      | |    | |  | |
"      |___/   |_| |_| |_| |_________|     |_|    |_|  |_|
"
"                           07/02/2012

set autoindent
set expandtab
set hidden
set hlsearch
set incsearch
set nocompatible
set novisualbell
set number
set ruler
set shiftwidth=2
set showmatch
set smartindent
set tabstop=2
set title
set virtualedit=all
set wildmode=list:longest
runtime macros/matchit.vim

call pathogen#infect()

let g:neocomplcache_enable_at_startup = 1
" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

filetype plugin on

nmap <silent> <C-M> :silent noh<CR> :echo "Highlights Cleared! bjoli"<CR>

let mapleader = ','
" http://stevelosh.com/blog/2010/09/coming-home-to-vim/
" ,W = strip all trailing whitespace in the current file
nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>

syntax on
colorscheme solarized
if has('gui_running')
  set background=light
else
  set background=dark
endif
autocmd BufNewFile,BufRead *.json set ft=javascript

"Kill all the trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()
