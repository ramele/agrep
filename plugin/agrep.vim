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
    let agrep_default_flags = '-I --exclude-dir=.{git,svn}'
endif
if !exists('agrep_conceal')
    let agrep_conceal = '°'
endif

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command!          		 Astop call s:stop()

if !agrep_use_qf
    command! -count=0 AA         call s:goto_match(<count> ? <count> : s:cur_match)
    command! -count=1 Anext      call s:goto_match(s:cur_match + <count>)
    command! -count=1 Aprev      call s:goto_match(s:cur_match - <count>)
    command! -count=1 Afnext     call s:goto_file_match(<count>, 1)
    command! -count=1 Afprev     call s:goto_file_match(<count>, -1)
    command!          Aquickfix  call s:set_qf()
    command!          Aopen      call s:open_window()
    command!          Aclose     call s:close_window()

    command! -nargs=* -bang Afilter   call s:filer_results(<bang>0, <q-args>, 1)
    command! -nargs=* -bang Affilter  call s:filer_results(<bang>0, <q-args>, 0)
endif

let s:grep_cmd = 'GREP_COLORS="mt=01:sl=:fn=:ln=:se=" grep --color=always --line-buffered -nH'

func! Agrep(args)
    " let s:rt        = reltime()
    let s:regexp    = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let s:status    = 'Active'
    let s:n_matches = 0
    let s:cur_match = 0
    let s:last_hl   = 0
    let s:filter    = ''

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
	call s:set_agrep_window('grep ' . g:agrep_default_flags . ' ' . a:args . ':')

	let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		    \ 'out_io': 'buffer', 'out_buf': s:bufnr, 'out_modifiable': 0,
		    \ 'out_cb': function('s:agrep_cb'), 'close_cb': function('s:close_cb')})
	let s:timer = timer_start(120, function('s:update_stl'), { 'repeat': -1 })
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
	call timer_stop(s:timer)
	call s:update_stl(0)
    endif
    " echo reltimestr(reltime(s:rt))
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
endfunc

func! s:update_stl(timer)
    call setbufvar('Agrep', '&stl', '%!Agrep_stl()')
endfunc

func! Agrep_stl()
    return '[Agrep] *' . s:status . '*  ' . s:regexp . '  ' . s:filter .
		\ '%=%-14{"' . (s:cur_match . ' of ' . s:n_matches) . '"}%4p%%'
endfunc

func! s:set_agrep_window(title)
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
	call s:open_window()
    endif
    setlocal modifiable
    silent %d _
    call setline(1, a:title)
    setlocal nomodifiable
    call cursor(1, col('$')) " avoid scrolling when using out_io buffer
    if winnr() != base_win | wincmd p | endif
endfunc

func! s:open_window()
    let saved_swb = &swb
    set swb=useopen
    exe 'bo sb' s:bufnr
    let &swb = saved_swb
endfunc

func! s:close_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr . 'close'
    endif
endfunc

func! s:hl_cur_match()
    if !exists('w:agrep_matchid') && exists('b:current_syntax')
	let w:agrep_matchid = matchadd('AgrepUnderlined', '^>.*', '-1')
    endif
    if s:cur_match == s:last_hl | return | endif
    setlocal modifiable
    if s:cur_match
	call setline(s:cur_match+1, '>' . getline(s:cur_match+1))
    endif
    if s:last_hl
	call setline(s:last_hl+1, getline(s:last_hl+1)[1:])
    endif
    setlocal nomodifiable
    let s:last_hl = s:cur_match
endfunc

func! s:get_match(arg)
    let line = (type(a:arg) == type(0) ? getbufline(s:bufnr, a:arg+1)[0] : a:arg)
    let ml = matchlist(line, '\v^\>?([^:]*):(\d*),(\d*): (.*)')
    return {'filename': ml[1], 'lnum': ml[2], 'col': ml[3], 'text': ml[4]}
endfunc

func! s:goto_match(n)
    if a:n < 1 || a:n > s:n_matches | return | endif
    let s:cur_match = a:n
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	noautocmd exe winnr 'wincmd w'
	call s:hl_cur_match()
	call cursor(a:n+1, col('.'))
	if winnr('$') > 1
	    wincmd p
	else
	    new
	endif
    endif
    let m = s:get_match(a:n)
    exe 'e' m.filename
    call cursor(m.lnum, m.col)
endfunc

func! s:goto_file_match(n, d)
    let fn = s:get_match(s:cur_match).filename
    let i = s:cur_match
    let n = a:n

    while n
	let i += a:d
	while i && i <= s:n_matches && s:get_match(i).filename == fn
	    let i += a:d
	endwhile
	if !i || i > s:n_matches
	    break
	else
	    let n -= 1
	    let fn = s:get_match(i).filename
	endif
    endwhile

    if !n 
	call s:goto_match(i)
    endif
endfunc

func! s:filer_results(bang, pattern, filter)
    call s:open_window()
    let pattern = (a:pattern == '' ? @/ : a:pattern)
    let lines = getline(2,'$')
    let n_lines = []
    for l in lines
	if a:filter == 0 " filter file names
	    let str = substitute(s:get_match(l).filename, '^>', '', '')
	else
	    let str = substitute(s:get_match(l).text, g:agrep_conceal, '', 'g')
	endif
	if str =~ pattern && !a:bang || str !~ pattern && a:bang
	    call add(n_lines, l[0] != '>' ? l : l[1:])
	endif
    endfor
    let s:n_matches = len(n_lines)
    let s:cur_match = 0
    let s:last_hl   = 0
    let s:filter    = printf('(filter%s: %s)', a:bang ? '(!)' : '', a:pattern)
    setlocal modifiable
    silent 2,$d _
    call setline(2, n_lines)
    setlocal nomodifiable
endfunc

func! s:set_qf()
    let qf = []
    for i in range(1, s:n_matches)
	call add(qf, s:get_match(i))
    endfor
    call setqflist(qf)
endfunc
