" Agrep - Asynchronous grep plugin for Vim
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

if v:version < 704 || v:version == 704 && !has("patch1907")
    echoerr 'Agrep requires Vim 7.4.1907 or later!'
    fini
endif

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command! -nargs=1 AA         call s:goto_match(<args>)
command!          Anext      call s:goto_match(s:cur_match+1)
command!          Aprev      call s:goto_match(s:cur_match-1)
command!          Agrepsetqf call s:set_qf()
command!          Agrepstop  call s:stop()

" Global options:
if !exists('agrep_win_height')
    let agrep_win_height = 15
endif
if !exists('agrep_use_qf')
    let agrep_use_qf = 0
endif
if !exists('agrep_default_flags')
    let agrep_default_flags = '-I'
endif
if !exists('agrep_conceal')
    let agrep_conceal = nr2char(176)
endif

let s:grep_cmd = 'GREP_COLORS="mt=01:sl=:fn=:ln=:se=" grep --color=always --line-buffered -nH'

func! Agrep_status()
    return '[Agrep] *' . s:agrep_status . '*  ' . s:regexp .
		\ '%=%-14{"' . (s:cur_match . ' of ' . s:n_matches) . '"}%3p%%'
endfunc

func! s:open_agrep_window()
    let base_win = winnr()
    let s:bufnr = bufnr('Agrep')
    if s:bufnr < 0
	exe 'bo' g:agrep_win_height 'new Agrep'
	let s:bufnr = bufnr('%')
	setlocal buftype=nofile bufhidden=hide
	setlocal conceallevel=3 concealcursor=nvic
	setlocal filetype=agrep
	setlocal statusline=%!Agrep_status()

	map <silent> <buffer> <CR>	    :call <SID>goto_match(line('.')-1)<CR>
	map <silent> <buffer> <2-LeftMouse> :call <SID>goto_match(line('.')-1)<CR>
    elseif bufwinnr(s:bufnr) < 0
	exe 'bo sb' s:bufnr
    else
	exe bufwinnr(s:bufnr) 'wincmd w'
    endif
    call clearmatches()
    setlocal modifiable
    silent %d _
    call setline(1, 'grep ' . g:agrep_default_flags . ' ' . s:args .':')
    setlocal nomodifiable
    call cursor(1, col('$')) " avoid scrolling when using out_io buffer
    if winnr() != base_win | wincmd p | endif
endfunc

func! Agrep(args)
    let s:rt = reltime()
    let s:regexp       = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let s:args         = a:args
    let s:agrep_status = 'Active'
    let s:n_matches    = 0
    let s:cur_match    = 0

    if !exists('s:agrep_perl')
	let s:agrep_perl = globpath(&rtp, 'perl/agrep.pl')
    endif

    let grep_cmd = s:grep_cmd . ' ' . g:agrep_default_flags . ' ' . a:args . ' | ' . s:agrep_perl

    if g:agrep_use_qf
	let s:saved_efm = &efm
	set efm=%f:%l\\,%c:%m

	call setqflist([])

	let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		    \ 'out_cb': 'Agrep_cb_qf', 'close_cb': 'Agrep_close_cb'})
    else
	call s:open_agrep_window()

	let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		    \ 'out_io': 'buffer', 'out_buf': s:bufnr, 'out_modifiable': 0,
		    \ 'out_cb': 'Agrep_cb', 'close_cb': 'Agrep_close_cb'})
    endif
endfunc

func! Agrep_cb(channel, msg)
    let s:n_matches += 1
    call setbufvar('Agrep', '&stl', '%!Agrep_status()')
endfunc

func! Agrep_cb_qf(channel, msg)
    let s:n_matches += 1
    cadde a:msg
endfunc

func! Agrep_close_cb(channel)
    " out_cb is still active at this point
    call timer_start(200, 'Agrep_final_close')
endfunc

func! Agrep_final_close(timer)
    if s:agrep_status == 'Active'
	let s:agrep_status = 'Done'
    endif
    if g:agrep_use_qf
	let &efm = s:saved_efm
	redr
	echo 'Done!'
    else
	call setbufvar('Agrep', '&stl', '%!Agrep_status()')
    endif
    echo reltime(s:rt)
endfunc

func! s:goto_match(n)
    if a:n < 1 || a:n > s:n_matches | return | endif
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr 'wincmd w'

	if exists('b:current_syntax')
	    call clearmatches()
	    call matchaddpos('AgrepHeader', [a:n+1])
	endif

	call cursor(a:n+1, col('.'))
	if winnr('$') > 1
	    wincmd p
	else
	    new
	endif
    endif
    let ml = matchlist(getbufline(s:bufnr, a:n+1)[0], '\v^([^:]*):(\d*),(\d*)')
    exe 'e' ml[1]
    call cursor(ml[2], ml[3])
    let s:cur_match = a:n
endfunc

func! s:set_qf()
    let qf = []
    for i in range(1, s:n_matches)
	let ml = matchlist(getbufline(s:bufnr, i+1)[0], '\v^([^:]*):(\d*),(\d*):(.*)')
	call add(qf, {'filename': ml[1], 'lnum': ml[2], 'col': ml[3],
		    \ 'text': substitute(ml[4], g:agrep_conceal, '', 'g')})
    endfor
    call setqflist(qf)
endfunc

func! s:stop()
    if s:agrep_status == 'Active'
	let s:agrep_status = 'Stopped'
	call job_stop(s:agrep_job)
    endif
endfunc
