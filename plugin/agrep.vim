" Agrep - Asynchronous grep plugin for Vim
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

if v:version < 704 || v:version == 704 && !has("patch1907")
    echoerr 'Agrep requires Vim 7.4.1907 or later!'
    fini
endif

" global options:
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
    let agrep_conceal = '°'
endif

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command!          		 Astop call s:stop()
if !agrep_use_qf
    command! -nargs=1 AA         call s:goto_match(<args>)
    command!          Anext      call s:goto_match(s:cur_match+1)
    command!          Aprev      call s:goto_match(s:cur_match-1)
    command!          Aquickfix  call s:set_qf()
    command!          Aopen      call s:open_agrep_window()
    command!          Aclose     call s:close_agrep_window()
endif

let s:grep_cmd = 'GREP_COLORS="mt=01:sl=:fn=:ln=:se=" grep --color=always --line-buffered -nH'

func! Agrep(args)
    " let s:rt        = reltime()
    let s:regexp    = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let s:args      = a:args
    let s:status    = 'Active'
    let s:n_matches = 0
    let s:cur_match = 0

    if !exists('s:agrep_perl')
	let s:agrep_perl = globpath(&rtp, 'perl/agrep.pl')
    endif

    let grep_cmd = s:grep_cmd . ' ' . g:agrep_default_flags . ' ' . a:args . ' | ' . s:agrep_perl

    if g:agrep_use_qf
	let s:saved_efm = &efm
	set efm=%f:%l\\,%c:%m

	call setqflist([])

	let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		    \ 'out_cb': function('s:qf_cb'), 'close_cb': function('s:close_cb')})
    else
	call s:set_agrep_window()

	let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		    \ 'out_io': 'buffer', 'out_buf': s:bufnr, 'out_modifiable': 0,
		    \ 'out_cb': function('s:agrep_cb'), 'close_cb': function('s:close_cb')})
    endif
endfunc

func! s:qf_cb(channel, msg)
    cadde a:msg
endfunc

func! s:close_cb(channel)
    " out_cb may still be active at this point
    call timer_start(200, function('s:final_close'))
endfunc

func! s:final_close(timer)
    if s:status == 'Active'
	let s:status = 'Done'
    endif
    if g:agrep_use_qf
	let &efm = s:saved_efm
	redr
	echo 'Done!'
    else
	call setbufvar('Agrep', '&stl', '%!Agrep_stl()')
    endif
    " echo reltime(s:rt)
endfunc

func! s:stop()
    if s:status == 'Active'
	let s:status = 'Stopped'
	call job_stop(s:agrep_job)
    endif
endfunc

" Skip the rest (Agrep window functions) if not used:
if agrep_use_qf
    fini
endif

func! s:agrep_cb(channel, msg)
    let s:n_matches += 1
    call setbufvar('Agrep', '&stl', '%!Agrep_stl()')
endfunc

func! Agrep_stl()
    return '[Agrep] *' . s:status . '*  ' . s:regexp .
		\ '%=%-14{"' . (s:cur_match . ' of ' . s:n_matches) . '"}%3p%%'
endfunc

func! s:set_agrep_window()
    let base_win = winnr()
    if bufnr('Agrep') < 0
	exe 'bo' g:agrep_win_height 'new Agrep'
	let s:bufnr = bufnr('%')
	setlocal buftype=nofile bufhidden=hide
	setlocal filetype=agrep
	setlocal statusline=%!Agrep_stl()

	map <silent> <buffer> <CR>	    :call <SID>goto_match(line('.')-1)<CR>
	map <silent> <buffer> <2-LeftMouse> :call <SID>goto_match(line('.')-1)<CR>
    else
	call s:open_agrep_window()
    endif
    call clearmatches()
    setlocal modifiable
    silent %d _
    call setline(1, 'grep ' . g:agrep_default_flags . ' ' . s:args .':')
    setlocal nomodifiable
    call cursor(1, col('$')) " avoid scrolling when using out_io buffer
    if winnr() != base_win | wincmd p | endif
endfunc

func! s:open_agrep_window()
    let saved_swb = &swb
    set swb=useopen
    exe 'bo sb' s:bufnr
    let &swb = saved_swb
endfunc

func! s:close_agrep_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr . 'q'
    endif
endfunc

func! s:update_cur_hl(n)
    if exists('b:current_syntax')
	call clearmatches()
	if a:n
	    call matchaddpos('AgrepUnderline', [a:n+1])
	endif
    endif
endfunc

if !exists('s:autocmd')
    let s:autocmd = 1
    au BufEnter Agrep call s:update_cur_hl(s:cur_match)
    " TODO this won't work if agrep is opened in another tab
    au BufWinLeave Agrep call clearmatches()
endif

func! s:goto_match(n)
    if a:n < 1 || a:n > s:n_matches | return | endif
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	set lz " TODO strange rendering issue. still not perfect though
	noautocmd exe winnr 'wincmd w'
	call s:update_cur_hl(a:n)
	call cursor(a:n+1, col('.'))
	if winnr('$') > 1
	    wincmd p
	else
	    new
	endif
	set nolz
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
	call add(qf, {'filename': ml[1], 'lnum': ml[2], 'col': ml[3], 'text': ml[4]})
    endfor
    call setqflist(qf)
endfunc
