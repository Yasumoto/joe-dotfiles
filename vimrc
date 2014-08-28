"       ____    ___   ___   _________   ________   _    _
"      /  __|  |   \ /   | |____ ____| |____ ___| | |  | |
"     /  /     | |\   /| |     | |         | |    | |  | |
"      \  \    | | | | | |     | |         | |    | |__| |
"       \  \   | | | | | |     | |         | |    |  __  |
"        |  |  | | | | | |     | |         | |    | |  | |
"       _/  /  | | | | | |  ___| |___      | |    | |  | |
"      |___/   |_| |_| |_| |_________|     |_|    |_|  |_|
"
"                           03/14/2014

set nocompatible

set autoindent
set expandtab
set hidden
set hlsearch
set incsearch
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
set splitbelow
set splitright
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

autocmd BufNewFile,BufRead *.alert set syntax=sh
autocmd BufNewFile,BufRead *.aurora set syntax=python
autocmd BufNewFile,BufRead *.confluence set syntax=confluencewiki
autocmd BufNewFile,BufRead *.json set ft=javascript
autocmd BufNewFile,BufRead *.mesos set syntax=python
autocmd BufNewFile,BufRead *.thermos set syntax=python
autocmd BufNewFile,BufRead *.gradle set syntax=java
autocmd BufNewFile,BufRead BUILD set syntax=python
autocmd BufNewFile,BufRead BUILD.twitter set syntax=python

"Kill all the trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" Plugin key-mappings.
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)
" SuperTab like snippets behavior.
imap <expr><TAB> neosnippet#expandable() ? "\<Plug>(neosnippet_expand_or_jump)" : pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable() ? "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
" For snippet_complete marker.
if has('conceal')
  set conceallevel=2 concealcursor=i
endif
let g:neosnippet#snippets_directory='~/.vim/bundle/snipmate-snippets/snippets'

" For vim-airline to display
set laststatus=2
