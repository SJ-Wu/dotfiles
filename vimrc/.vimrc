" ============================================================
" ~/.vimrc — 系統 vim (9.1) 用，零外掛
"
" 主力編輯器是 Neovim (見 nvim/)。這份是給 sudo vim / ssh 到別台機器 /
" 快速改個檔 用的，鍵位盡量對齊 ideavimrc/ 的肌肉記憶。
"
" 全部只用 vim 內建功能，沒有 plugin manager、沒有 bootstrap，
" 單獨 scp 這一個檔到任何一台機器就能用。
" 檔案最後有「與 IdeaVim 的差異」和「覆蓋掉的 vim 內建鍵」兩份清單。
" ============================================================

set nocompatible
syntax on
filetype plugin indent on

" 內建套件: % 可在 if/endif、開合標籤之間跳躍 (等同 IdeaVim 的 set matchit)
if has('packages')
  silent! packadd! matchit
else
  silent! runtime macros/matchit.vim
endif

" --------------------------------------------
" 編碼
" --------------------------------------------
set encoding=utf-8
set fileencoding=utf-8
" 開舊檔時依序猜測編碼 (big5/gbk 是為了偶爾遇到的舊中文檔)
set fileencodings=ucs-bom,utf-8,big5,gbk,latin1

" --------------------------------------------
" 顯示
" --------------------------------------------
set number
set relativenumber
set scrolloff=5
set sidescrolloff=8
set ruler
set showcmd
set laststatus=2
set display=truncate
set nowrap
set signcolumn=no
" 顯示行尾空白與 nbsp，避免看不見的髒字元 (就是 IdeaVim 那次注音事件的教訓)
set list
set listchars=trail:·,nbsp:␣,extends:›,precedes:‹
set background=dark
silent! colorscheme habamax

" --------------------------------------------
" 搜尋
" --------------------------------------------
set incsearch
set hlsearch
set ignorecase
set smartcase
" 用 ripgrep 當 :grep 後端 (沒裝就維持內建 grep)
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" --------------------------------------------
" 縮排
" --------------------------------------------
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround
set autoindent
set smartindent

" --------------------------------------------
" 行為
" --------------------------------------------
set backspace=indent,eol,start
set hidden
set confirm
set autoread
set mouse=a
set splitbelow
set splitright
set visualbell t_vb=
set ttimeout
set ttimeoutlen=50
" <C-a>/<C-x> 加減數字時不要把 007 當成八進位
set nrformats-=octal
" 系統剪貼簿 (這顆 vim 有 +clipboard)
if has('clipboard')
  set clipboard=unnamed
endif

" 命令列補全: 先補到最長共同前綴再列選單
set wildmenu
set wildmode=longest:full,full
set wildignore+=*/.git/*,*/node_modules/*,*/__pycache__/*,*/.venv/*,*.pyc,*.o,*.class
" :find 可以遞迴搜尋整個專案
set path=.,,**

" --------------------------------------------
" 檔案暫存 (集中放，不要在專案裡拉屎)
" --------------------------------------------
for s:dir in ['undo', 'swap']
  if !isdirectory(expand('~/.vim/' . s:dir))
    silent! call mkdir(expand('~/.vim/' . s:dir), 'p', 0700)
  endif
endfor
set undofile
set undodir=~/.vim/undo//
set directory=~/.vim/swap//
set nobackup
set nowritebackup

" 重開檔案時回到上次離開的位置
augroup vimrc_last_position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
        \ | execute "normal! g`\"" | endif
augroup END

" ============================================================
" 以下鍵位對齊 ideavimrc/
" ============================================================

" Space 當 leader (跟 nvim/lua/config/options.lua 一致)
let mapleader = " "
let maplocalleader = " "
nnoremap <Space> <Nop>

" --------------------------------------------
" 模式切換
" --------------------------------------------
inoremap jj <Esc>
" 不用 Ex 模式，Q 改成格式化
map Q gq
" 清掉搜尋高亮
nnoremap <silent> <leader><CR> :nohlsearch<CR>

" --------------------------------------------
" 游標移動
" --------------------------------------------
nnoremap zh ^
nnoremap hh ^
inoremap zh <Esc>I
nnoremap zl $
nnoremap ll $
inoremap zl <End>

" --------------------------------------------
" 貼上 (使用 register 0，不會被 d/c 洗掉)
" --------------------------------------------
nnoremap ,p "0p
nnoremap ,P "0P
inoremap z,p <Esc>"0pa
inoremap z,P <Esc>"0Pa
" visual 模式貼上後不要把原本的內容吃進 register
xnoremap p "_dP

" --------------------------------------------
" 快速選取 / 修改範圍 (全部是 vim 原生 text object)
" --------------------------------------------
nnoremap z, vi)
nnoremap z) vi)
nnoremap z. vi}
nnoremap z} vi}
nnoremap z> vit
nnoremap c> cit
nnoremap z" vi"
nnoremap z' vi'
nnoremap zxx ci]

" --------------------------------------------
" 編輯操作
" --------------------------------------------
nnoremap <BS> a<BS>
nnoremap hc ^C
nnoremap zb ciw
xnoremap zb <Esc>ciw
inoremap zd <Esc>dd
" 全選 (只在 insert 模式覆蓋，normal 的 <C-a> 保留給「數字加一」)
inoremap <C-a> <Esc>ggVG

" --------------------------------------------
" 行操作
" --------------------------------------------
" 複製當前行 (IdeaVim 是 <C-D>，這裡讓給 vim 的半頁捲動)
nnoremap <leader>d yyp
" 上下移動行並重新縮排 (IdeaVim 是 <C-A-J/K>，終端機收不到這種組合)
nnoremap <silent> <leader>j :move .+1<CR>==
nnoremap <silent> <leader>k :move .-2<CR>==
xnoremap <silent> <leader>j :move '>+1<CR>gv=gv
xnoremap <silent> <leader>k :move '<-2<CR>gv=gv

" --------------------------------------------
" 縮排
" --------------------------------------------
nnoremap <Tab> >>
nnoremap <S-Tab> <<
xnoremap <Tab> >gv
xnoremap <S-Tab> <gv

" --------------------------------------------
" 檔案操作
" --------------------------------------------
nnoremap qq ZQ
nnoremap zq :wq<CR>

" --------------------------------------------
" 導航 (對應 IdeaVim 的 IDE 動作)
" --------------------------------------------
" 上一個 / 下一個游標位置 (IdeaVim: Back / Forward)
nnoremap zk <C-o>
nnoremap zj <C-i>
" 跳到宣告 (IdeaVim: GotoDeclaration) — vim 內建的區域宣告搜尋
nnoremap zf gd
" 下一個 / 上一個 quickfix 項目 (IdeaVim: GotoNextError)
nnoremap <silent> zn :cnext<CR>
nnoremap <silent> zN :cprevious<CR>
" 全域找檔案 (IdeaVim: SearchEverywhere) — 用 :find + wildmenu
nnoremap zrt :find *
" 全文搜尋，結果進 quickfix
nnoremap zrg :grep! 
" 切 buffer
nnoremap ,b :buffer *

" --------------------------------------------
" 格式化
" --------------------------------------------
" 整份重新縮排並回到原位 (IdeaVim: ReformatCode)
nnoremap zra mzgg=G`z

" --------------------------------------------
" 重構近似版
" --------------------------------------------
" 重新命名游標下的字 (IdeaVim: RenameElement)
" 會停在命令列讓你打新名字，確認後每個都問一次
nnoremap zrr :%s/\<<C-r><C-w>\>//gcI<Left><Left><Left><Left>

" --------------------------------------------
" Git (IdeaVim: CheckinProject)
" --------------------------------------------
if executable('lazygit')
  nnoremap <silent> zgc :!lazygit<CR>:redraw!<CR>
endif

" --------------------------------------------
" 複製路徑 (IdeaVim: CopyReference / CopyAbsolutePath)
" --------------------------------------------
nnoremap <silent> zcp :call <SID>CopyText(expand('%:p'))<CR>
nnoremap <silent> zcr :call <SID>CopyText(expand('%:p') . ':' . line('.'))<CR>

" --------------------------------------------
" 檔案結構 (IdeaVim: FileStructurePopup)
" 列出所有定義行與行號，打行號 + G 就能跳過去
" --------------------------------------------
nnoremap <silent> ,m :call <SID>Outline()<CR>

" --------------------------------------------
" 包住選取範圍 (近似 vim-surround 的 S)
" visual 選取後按 <leader> 加符號
" --------------------------------------------
xnoremap <leader>" c"<C-r>""<Esc>
xnoremap <leader>' c'<C-r>"'<Esc>
xnoremap <leader>( c(<C-r>")<Esc>
xnoremap <leader>[ c[<C-r>"]<Esc>
xnoremap <leader>{ c{<C-r>"}<Esc>
xnoremap <leader>` c`<C-r>"`<Esc>

" --------------------------------------------
" 註解切換 (近似 vim-commentary 的 gcc / gc)
" --------------------------------------------
let s:comment_map = {
      \ 'python': '#', 'sh': '#', 'bash': '#', 'zsh': '#', 'ruby': '#',
      \ 'yaml': '#', 'toml': '#', 'conf': '#', 'make': '#', 'perl': '#',
      \ 'dockerfile': '#', 'gitconfig': '#', 'r': '#',
      \ 'vim': '"',
      \ 'c': '//', 'cpp': '//', 'java': '//', 'javascript': '//',
      \ 'typescript': '//', 'javascriptreact': '//', 'typescriptreact': '//',
      \ 'go': '//', 'rust': '//', 'php': '//', 'kotlin': '//', 'scala': '//',
      \ 'swift': '//', 'json': '//', 'jsonc': '//', 'groovy': '//',
      \ 'sql': '--', 'lua': '--', 'haskell': '--',
      \ 'tex': '%', 'matlab': '%',
      \ 'lisp': ';', 'clojure': ';',
      \ }

nnoremap <silent> gcc :call <SID>ToggleComment()<CR>
xnoremap <silent> gc  :call <SID>ToggleComment()<CR>

" ============================================================
" 輔助函式
" ============================================================

function! s:CopyText(text) abort
  let @" = a:text
  if has('clipboard')
    let @+ = a:text
    let @* = a:text
  endif
  echo 'copied: ' . a:text
endfunction

function! s:Outline() abort
  let l:pat = '^\s*\(class\|def\|func\|function\|public\|private\|protected\|'
        \ . 'export\|const\s\+\w\+\s*=\s*(\|async\s\+def\|impl\|type\|struct\)\>'
  try
    execute 'global/' . l:pat . '/#'
  catch /^Vim\%((\a\+)\)\=:E486/
    echohl WarningMsg | echo '這個檔案裡找不到定義' | echohl None
  endtry
endfunction

" 註解切換: 整段一起判斷。只要有任何一行沒被註解，就全部加註解；
" 全部都被註解了才取消。加註解時對齊該段最淺的縮排。
function! s:ToggleComment() range abort
  let l:cs = get(s:comment_map, &filetype, '')
  if empty(l:cs)
    echohl WarningMsg
    echo 'gcc: 沒有定義 ' . (empty(&filetype) ? '(無 filetype)' : &filetype) . ' 的註解符號'
    echohl None
    return
  endif

  let l:len = strlen(l:cs)
  let l:all_commented = 1
  let l:indent = -1

  for l:n in range(a:firstline, a:lastline)
    let l:line = getline(l:n)
    let l:i = match(l:line, '\S')
    if l:i < 0
      continue
    endif
    if strpart(l:line, l:i, l:len) !=# l:cs
      let l:all_commented = 0
    endif
    if l:indent < 0 || l:i < l:indent
      let l:indent = l:i
    endif
  endfor

  " 整段都是空行
  if l:indent < 0
    return
  endif

  for l:n in range(a:firstline, a:lastline)
    let l:line = getline(l:n)
    let l:i = match(l:line, '\S')
    if l:i < 0
      continue
    endif
    if l:all_commented
      let l:rest = strpart(l:line, l:i + l:len)
      if strpart(l:rest, 0, 1) ==# ' '
        let l:rest = strpart(l:rest, 1)
      endif
      call setline(l:n, strpart(l:line, 0, l:i) . l:rest)
    else
      call setline(l:n, strpart(l:line, 0, l:indent) . l:cs . ' ' . strpart(l:line, l:indent))
    endif
  endfor
endfunction

" ============================================================
" 與 IdeaVim 的差異 (純 vim 做不到，或刻意改掉的)
" ============================================================
"   <Space>       IdeaVim 是 AceJump 跳躍；這裡當 leader (跟 nvim 一致)
"                 想快速跳躍就用 / 搜尋，或 f/t/;/,
"   <C-D>         IdeaVim 是複製行；這裡保留 vim 的半頁捲動，複製行改 <leader>d
"   <C-A-J/K>     終端機收不到 Ctrl+Alt 組合，移動行改 <leader>j / <leader>k
"   <A-*> 全系列  終端機下的 Alt 不可靠，一律不用
"   zrf/zrp/zrv   IntroduceField/Parameter/Variable，沒有 IDE 語意分析做不到
"   zrm / M       ExtractMethod，同上
"   zri / zro     Inline / Move，同上
"   zmc/zmr/zms   Run Configuration，vim 這邊請直接用 :! 或終端機
"   <F1>          跳到測試方法，依賴 IDE 索引，略過
"   cs"' / ds"    vim-surround 的改寫/刪除環繞沒有重現;
"                 「新增」環繞用 visual + <leader>" 那組,
"                 「修改內容」直接用內建的 ci" ca( 等即可
"
" ============================================================
" 被覆蓋掉的 vim 內建鍵 (為了對齊 IdeaVim，取捨後放棄的)
" ============================================================
"   zh zl         原本是水平捲動 (只在 nowrap 時有用)
"   zb            原本是「把當前行捲到螢幕底部」(zz / zt 仍保留)
"   zj zk         原本是跳到下/上一個 fold
"   zf            原本是 zf{motion} 建立 fold
"   zc            按單獨的 zc (關閉 fold) 會等待 timeout，因為有 zcp/zcr
"   <Tab>         原本等同 <C-i> 跳到下一個位置 — 該功能已改綁 zj
"   Q             原本進 Ex 模式
