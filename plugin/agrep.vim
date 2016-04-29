" Agrep - Asynchronous grep plugin for Vim
" Last Change:	2016 Apr 29
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>
"
" ** This plugin is under development **
"
" Usage: Agrep takes the same command line arguments as the shell's grep, for
" example:
" :Agrep -r 'foo.*bar' ~/my_project
" 
" It uses -nH flags by default so you don't need to specify them explicitly.
"
" Each match is available to Vim as soon as it is discovered. You don't need
" to wait for the entire search to complete.
"
" The results are displayed in a special window (for now). You can change this
" and load the results directly to the quickfix list (agrep_use_qf) but it is
" slower for long lists, especially if the quickfix window is opened while it
" is being updated. You can load the results to the quickfix list any time by
" running :Agrepsetqf. It is useful when you edit the files while exploring
" the results.
" 
" The following commands can be used to navigate the search results:
" - AA [nr]
" - Anext
" - Aprev
" These commands are similar to the corresponding quickfix commands (cc, cn,
" cp). Hitting <Enter> or double-clicking the mouse on a match in the Agrep
" window will take you to the match location as well.
" Use :Agrepstop to kill the search and its grep process.

" TODO:
" - Handle tab switching while searching
" - Add filter results command
"
if v:version < 704 || v:version == 704 && !has("patch1750")
    echoerr 'Agrep requires Vim 7.4.1750 or later!'
    fini
endif

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command! -nargs=1 AA         call <SID>goto_match(<args>)
command!          Anext      call <SID>goto_match(s:cur_match+1)
command!          Aprev      call <SID>goto_match(s:cur_match-1)
command!          Agrepsetqf call s:set_qf()
command!          Agrepstop  call s:stop()

" global options:
if !exists('agrep_win_highet')
    let agrep_win_highet = 15
endif
if !exists('agrep_use_qf')
    let agrep_use_qf = 0
endif
if !exists('agrep_default_flags')
    let agrep_default_flags = '-I'
endif
if !exists('agrep_conceal')
    let agrep_conceal = nr2char(30)
endif

let s:grep_cmd = 'GREP_COLORS="mt=01:sl=:fn=:ln=:se=" grep --color=always --line-buffered -nH'

func! s:move_to_buf(bufnr)
    let s:saved_ei = &eventignore
    set eventignore=all
    let s:base_win = winnr()
    let s:buf_win = bufwinnr(a:bufnr)
    if s:base_win != s:buf_win
	exe s:buf_win 'wincmd w'
    endif
    setlocal modifiable
endfunc

func! s:back_from_buf()
    setlocal nomodifiable
    if s:base_win != s:buf_win
	exe s:base_win 'wincmd w'
    endif
    let &eventignore = s:saved_ei
endfunc

func! Agrep_status()
    return '[Agrep] *'.(g:agrep_active ? 'Active' : 'Done').'*  '.s:regexp.
		\ '%=%-14{"'.(s:cur_match ? s:cur_match.' of ' : '').s:n_matches.'"}%3p%%'
endfunc

func! s:open_agrep_window()
    let base_win = winnr()
    let s:bufnr = bufnr('Agrep')
    if s:bufnr < 0
	exe 'bo' g:agrep_win_highet 'new Agrep'
	let s:bufnr = bufnr('%')
	setlocal buftype=nofile bufhidden=hide
	setlocal conceallevel=3 concealcursor=nvic
	setlocal filetype=agrep
	setlocal statusline=%!Agrep_status()

	map <silent> <buffer> <CR>		:call <SID>goto_match(line('.')-1)<CR>
	map <silent> <buffer> <2-LeftMouse>	:call <SID>goto_match(line('.')-1)<CR>
    elseif bufwinnr(s:bufnr) < 0
	exe 'bo sb' s:bufnr
    else
	exe bufwinnr(s:bufnr) 'wincmd w'
    endif
    setlocal modifiable
    silent %d _
    call setline(1, 'Searching...')
    setlocal nomodifiable
    if winnr() != base_win | wincmd p | endif
endfunc

func! Agrep(args)
    let s:regexp = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let [g:agrep_active, s:n_matches, s:cur_match, s:columns] = [1, 0, 0, []]

    let grep_cmd = s:grep_cmd . ' ' . g:agrep_default_flags . ' ' . a:args

    if g:agrep_use_qf
	call setqflist([])
    else
	call s:open_agrep_window()
    endif

    let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		\ 'out_cb': 'Agrep_cb', 'close_cb': 'Agrep_close_cb'})
endfunc

func! Agrep_cb(channel, msg)
    let ml = matchlist(a:msg, '\v^([^:]*):(\d*):(.*)')
    if !len(ml) | return | endif

    let sp = split(ml[3], '\V\e[\(01\)\?m\e[K', 1)
    let len = 0
    let is_match = 0
    for s in sp
	if is_match
	    let s:n_matches += 1
	    if g:agrep_use_qf
		call setqflist([{'filename': ml[1], 'lnum': ml[2], 'col': len+1,
			    \ 'text': substitute(join(sp, ''), '^\s\+', '', '')}], 'a')
	    else
		call add(s:columns, len+1)
		call s:move_to_buf(s:bufnr)
		call setline(s:n_matches+1, printf('%s:%d: %s', ml[1], ml[2],
			    \ substitute(join(sp, g:agrep_conceal), '^\s\+', '', '')))
		call setline(1, printf('Searching... %d results:', s:n_matches))
		call s:back_from_buf()
	    endif
	endif
	let len += len(s)
	let is_match = !is_match
    endfor
endfunc

func! Agrep_close_cb(channel)
    " out_cb is still active at this point
    call timer_start(200, 'Agrep_final_close')
endfunc

func! Agrep_final_close(timer)
    if g:agrep_use_qf
	redr
	echo 'Done!'
    else
	call s:move_to_buf(s:bufnr)
	call setline(1, printf('Done. %d results:', s:n_matches))
	call s:back_from_buf()
    endif
    let g:agrep_active = 0
endfunc

func! <SID>goto_match(n)
    if a:n < 1 || a:n > s:n_matches | return | endif
    if bufwinnr(s:bufnr) > 0
	call s:move_to_buf(s:bufnr)
	if exists('b:current_syntax')
	    call clearmatches()
	    call matchaddpos('AgrepHeader', [a:n+1])
	endif
	call cursor(a:n+1, col('.'))
	call s:back_from_buf()
	if bufnr('%') == s:bufnr
	    if winnr('$') > 1
		wincmd p
	    else
		new
	    endif
	endif
    endif
    let ml = matchlist(getbufline(s:bufnr, a:n+1)[0], '\v^([^:]*):(\d*)')
    exe 'e' ml[1]
    call cursor(ml[2], s:columns[a:n-1])
    let s:cur_match = a:n
endfunc

func! s:set_qf()
    let qf = []
    for i in range(1, s:n_matches)
	let ml = matchlist(getbufline(s:bufnr, i+1)[0], '\v^([^:]*):(\d*):(.*)')
	call add(qf, {'filename': ml[1], 'lnum': ml[2], 'col': s:columns[i-1],
		    \ 'text': substitute(ml[3], g:agrep_conceal, '', 'g')})
    endfor
    call setqflist(qf)
endfunc

func! s:stop()
    call job_stop(s:agrep_job)
endfunc
