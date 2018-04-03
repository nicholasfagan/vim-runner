" Author: Huang Po-Hsuan <aben20807@gmail.com>
" Filename: runner.vim
" Last Modified: 2018-03-15 11:21:53
" Vim: enc=utf-8

if exists("has_loaded_runner")
    finish
endif
if v:version < 700
    echoerr "Runner: this plugin requires vim >= 7."
    finish
endif
let has_loaded_runner = 1

set shell=/bin/sh
set shellcmdflag=-c


" Function: s:InitVariable() function
" 初始化變數
" Ref: https://github.com/scrooloose/nerdcommenter/blob/master/plugin/NERD_commenter.vim#L26
" Args:
"   -var: the name of the var to be initialised
"   -value: the value to initialise var to
" Returns:
"   1 if the var is set, 0 otherwise
function! s:InitVariable(var, value)
    if !exists(a:var)
        execute 'let ' . a:var . ' = ' . "'" . a:value . "'"
        return 1
    endif
    return 0
endfunction

" Section: variable initialization
call s:InitVariable("g:runner_use_default_mapping", 1)
call s:InitVariable("g:runner_is_save_first", 1)
call s:InitVariable("g:runner_print_timestamp", 1)
call s:InitVariable("g:runner_print_time_usage", 1)
call s:InitVariable("g:runner_show_info", 1)
call s:InitVariable("g:runner_auto_remove_tmp", 0)
call s:InitVariable("g:runner_run_key", "<F5>")
call s:InitVariable("g:runner_tmp_dir", "/tmp/vim-runner/")

" Section: work with other plugins
" w0rp/ale
call s:InitVariable("g:runner_is_with_ale", 0)
" iamcco/markdown-preview.vim
call s:InitVariable("g:runner_is_with_md", 0)

" Section: executable settings
call s:InitVariable("g:runner_c_executable", "gcc")
call s:InitVariable("g:runner_cpp_executable", "g++")
call s:InitVariable("g:runner_rust_executable", "cargo")
call s:InitVariable("g:runner_python_executable", "python3")
call s:InitVariable("g:runner_lisp_executable", "sbcl --script")

" Section: compile options settings
call s:InitVariable("g:runner_c_compile_options", "-std=c11 -Wall")
call s:InitVariable("g:runner_cpp_compile_options", "-std=c++14 -Wall")
call s:InitVariable("g:runner_rust_compile_options", "")

" Section: run options settings
call s:InitVariable("g:runner_c_run_options", "")
call s:InitVariable("g:runner_cpp_run_options", "")
call s:InitVariable("g:runner_rust_run_backtrace", 1)
call s:InitVariable("g:runner_rust_run_options", "")


augroup comment
    autocmd BufEnter,BufRead,BufNewFile * call s:SetUpFiletype(&filetype)
augroup END


" Function: s:SetUpFiletype(filetype) function
" Set up filetype.
" Args:
"   -filetype
function! s:SetUpFiletype(filetype)
    let b:ft = a:filetype
    if b:ft ==# 'rust'
        let l:current_dir = getcwd()
        if filereadable(current_dir . "/../Cargo.toml") ||
                    \ filereadable(current_dir . "/Cargo.toml")
            let g:runner_rust_executable = "cargo"
        else
            let g:runner_rust_executable = "rustc"
        endif
        let b:supported = 1
        return
    endif
    if b:ft ==# 'markdown' && g:runner_is_with_md
        let b:supported = 1
        return
    endif
    if b:ft ==# 'c' || b:ft ==# 'cpp' || b:ft ==# 'python' || b:ft == 'lisp'
        let b:supported = 1
        return
    endif
    let b:supported = 0
endfunction


" Function: s:ShowInfo(str) function
" Use to print info string.
" Args:
"   -str: string need to print.
function! s:ShowInfo(str)
    if g:runner_show_info
        redraw
        echohl WarningMsg
        echo a:str
        echohl NONE
    else
        return
    endif
endfunction


" Function: s:InitTmpDir() function
" Initialize temporary directory for products after compiling.
" Ref: http://vim.wikia.com/wiki/Automatically_create_tmp_or_backup_directories
function! s:InitTmpDir()
    let b:tmp_dir = g:runner_tmp_dir
    if !isdirectory(b:tmp_dir)
        call mkdir(b:tmp_dir)
    endif
endfunction


" Function: s:DoAll() function
" To do all subfunctions.
function! s:DoAll()
    if b:supported
        call s:Before()
        call s:Compile()
        call s:Run()
        call s:After()
    else
        call s:ShowInfo("   ❖  不支援  ❖ ")
    endif
endfunction


" Function: s:Before() function
" To do something before compiling.
function! s:Before()
    call s:InitTmpDir()
    if g:runner_is_save_first
        execute "up"
    endif
    if g:runner_is_with_ale
        let b:runner_ale_status = get(g:, 'ale_enabled', 1)
        let g:ale_enabled = 0
    endif
    if g:runner_print_timestamp && b:ft !=# 'markdown'
        let l:date = strftime("%Y-%m-%d_%T")
        silent execute "!echo -e '\033[31m' "
        silent execute '!printf "<<<< \%s >>>>\n" ' . l:date
        silent execute "!echo -en '\033[0m'"
        if b:ft !=# 'c' && b:ft !=# 'cpp' && b:ft !=# 'rust'
                    \ && b:ft !=# 'python' && b:ft !=# 'lisp'
            execute "!echo -e ''"
        endif
    endif
endfunction


" Function: s:Compile() function
" To do something when compiling.
function! s:Compile()
    let b:tmp_name = strftime("%s")
    if b:ft ==# 'c'
        silent execute "!" . g:runner_c_executable . " " .
                    \ g:runner_c_compile_options .
                    \ " % -o " .
                    \ b:tmp_dir .
                    \ b:tmp_name .
                    \ ".out"
    elseif b:ft ==# 'cpp'
        silent execute "!" . g:runner_cpp_executable . " " .
                    \ g:runner_cpp_compile_options .
                    \ " % -o " .
                    \ b:tmp_dir .
                    \ b:tmp_name .
                    \ ".out"
    elseif b:ft ==# 'rust'
        if g:runner_rust_executable ==# "rustc"
            silent execute "!" . g:runner_rust_executable . " " .
                        \ g:runner_rust_compile_options .
                        \ " % -o " .
                        \ b:tmp_dir .
                        \ b:tmp_name .
                        \ ".out"
        endif
    elseif b:ft ==# 'python'
    elseif b:ft ==# 'lisp'
    endif
endfunction


" Function: s:Run() function
" To do something when running.
function! s:Run()
    if g:runner_print_time_usage
        let l:time = "time"
    else
        let l:time = ""
    endif
    if b:ft ==# 'c'
        execute "!" .
                    \ l:time . " "
                    \ b:tmp_dir .
                    \ b:tmp_name .
                    \ ".out " .
                    \ g:runner_c_run_options
    elseif b:ft ==# 'cpp'
        execute "!" .
                    \ l:time . " " .
                    \ b:tmp_dir .
                    \ b:tmp_name .
                    \ ".out" .
                    \ g:runner_cpp_run_options
    elseif b:ft ==# 'rust'
        if g:runner_rust_run_backtrace
            let l:rust_bt = "RUST_BACKTRACE=1"
        else
            let l:rust_bt = ""
        endif
        if g:runner_rust_executable ==# "rustc"
            execute "!" .
                        \ l:time . " " .
                        \ l:rust_bt . " " .
                        \ b:tmp_dir .
                        \ b:tmp_name .
                        \ ".out " .
                        \ g:runner_rust_run_options
        else
            execute "!" .
                        \ l:time . " " .
                        \ l:rust_bt . " " .
                        \ "cargo run"
        endif
    elseif b:ft ==# 'python'
        execute "!" .
                    \ l:time . " "
                    \ g:runner_python_executable .
                    \ " %"
    elseif b:ft ==# 'lisp'
        execute "!" .
                    \ l:time . " "
                    \ g:runner_lisp_executable .
                    \ " %"
    elseif b:ft ==# 'markdown'
        " markdown preview
        try
            " Stop before starting and handle exception
            execute "MarkdownPreviewStop"
        catch /^Vim:E492:/
            execute "MarkdownPreview"
        endtry
    endif
endfunction


" Function: s:After() function
" To do something after running.
function! s:After()
    if (b:ft ==# 'c' || b:ft ==# 'cpp') && g:runner_auto_remove_tmp
        silent execute "!rm " .
                    \ b:tmp_dir .
                    \ b:tmp_name .
                    \ ".out"
    endif
    if g:runner_is_with_ale
        let g:ale_enabled = b:runner_ale_status
    endif
endfunction


" Section: key map設定
function! s:SetUpKeyMap()
    execute "nnoremap <silent> ".g:runner_run_key." :<C-u>call <SID>DoAll()<CR>"
endfunction
if g:runner_use_default_mapping
    call s:SetUpKeyMap()
endif
