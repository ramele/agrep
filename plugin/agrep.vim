" Agrep - Asynchronous grep plugin for Vim
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

if v:version < 704 || v:version == 704 && !has("patch1906")
    echoerr 'Agrep requires Vim 7.4.1906 or later!'
    fini
endif

" global options:
if !exists('agrep_win_sp_mod')
    let agrep_win_sp_mod = 'bo 18'
endif
if !exists('agrep_default_flags')
    let agrep_default_flags = '-I --exclude-dir=.{git,svn}'
endif
if !exists('agrep_history')
    let agrep_history = 5
endif

let agrep_marker = '¬'

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command!          		 Astop call s:stop()

command! -count=1 Anext      call s:goto_match( 1, <count>, 0)
command! -count=1 Aprev      call s:goto_match(-1, <count>, 0)
command! -count=1 Anfile     call s:goto_match( 1, <count>, 1)
command! -count=1 Apfile     call s:goto_match(-1, <count>, 1)
command!          Aquickfix  call s:set_qf()
command!          Aopen      call s:open_window()
command!          Aclose     call s:close_window()

command! -nargs=* -bang Afilter   call s:filer_results(<bang>0, <q-args>, 0)
command! -nargs=* -bang Affilter  call s:filer_results(<bang>0, <q-args>, 1)

command! -count=1 Anewer  call s:history_get( 1, <count>)
command! -count=1 Aolder  call s:history_get(-1, <count>)

let s:grep_cmd = 'export GREP_COLORS="mt=01:sl=:fn=:ln=:se="; grep --color=always --line-buffered -nH'

let s:status = ''
let s:history = []

func! Agrep(args)
    if s:status == 'Active'
	call s:stop()
	let s:args = a:args
	call timer_start(400, function('s:delayed_run'))
	return
    endif
    if s:status != ''
	call s:history_set()
    endif
    let s:hist_ptr = -1
    " let s:rt      = reltime()
    let s:regexp    = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let s:status    = 'Active'
    let s:n_matches = 0
    let s:n_files   = 0
    let s:filter    = ''
    let s:cwd       = getcwd()
    let s:m_lnum    = 1
    let s:m_ptr     = 0

    if !exists('s:agrep_perl')
	let s:agrep_perl = globpath(&rtp, 'perl/agrep.pl')
    endif

    let grep_cmd = s:grep_cmd . ' ' . g:agrep_default_flags . ' ' . a:args . ' |& ' . s:agrep_perl

    call s:set_window('grep ' . g:agrep_default_flags . ' ' . a:args . ':')

    let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		\ 'out_io': 'buffer', 'out_buf': s:bufnr, 'out_modifiable': 0,
		\ 'out_cb': function('s:out_cb'), 'close_cb': function('s:close_cb')})
    let s:timer = timer_start(120, function('s:update_stl'), { 'repeat': -1 })
endfunc

func! s:delayed_run(timer)
    call Agrep(s:args)
endfunc

func! s:out_cb(channel, msg)
    if a:msg[0] == '!'
	let s:n_matches += matchstr(a:msg, '^!\zs\d\+')
	let s:n_files += 1
    endif
endfunc

func! s:close_cb(channel)
    " out_cb may still be active at this point
    call timer_start(100, function('s:final_close'))
endfunc

func! s:final_close(timer)
    if s:status == 'Active'
	let s:status = 'Done'
    endif
    call timer_stop(s:timer)
    call s:update_stl(0)
    " echo reltimestr(reltime(s:rt))
endfunc

func! s:stop()
    if s:status == 'Active'
	let s:status = 'Stopped'
	call job_stop(s:agrep_job)
    endif
endfunc

func! s:update_stl(timer)
    call setbufvar('Agrep', '&stl', '%!Agrep_stl()')
endfunc

func! Agrep_stl()
    return '[Agrep] *' . s:status . '*  ' . s:regexp . '  ' . s:filter .
		\ '%=%-14{"' . (s:n_matches . ' / ' . s:n_files) . '"}%4p%%'
endfunc

func! s:set_window(title)
    let base_win = winnr()
    if bufnr('Agrep') < 0
	exe g:agrep_win_sp_mod 'new Agrep'
	let s:bufnr = bufnr('%')
	setlocal buftype=nofile bufhidden=hide noswapfile
	setlocal filetype=agrep
	setlocal statusline=%!Agrep_stl()

	map <silent> <buffer> <CR>	    :call <SID>goto_match(0, 1, 0)<CR>
	map <silent> <buffer> <2-LeftMouse> :call <SID>goto_match(0, 1, 0)<CR>
    else
	call s:open_window()
    endif
    call clearmatches()
    setlocal modifiable
    silent %d _
    call setline(1, a:title)
    setlocal nomodifiable
    call cursor(1, col('$')) " avoid scrolling
    if winnr() != base_win | wincmd p | endif
endfunc

func! s:open_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr 'wincmd w'
    else
	exe g:agrep_win_sp_mod 'new +' . s:bufnr . 'b'
    endif
endfunc

func! s:close_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr . 'close'
    endif
endfunc

func! s:hl_cur_match(lnum, col, len)
    if !exists('b:current_syntax')
	return
    endif
    call clearmatches()
    call matchaddpos('AgrepCurMatch', [[a:lnum, a:col, a:len]])
endfunc

func! s:get_match()
    let m = len(g:agrep_marker)
    let lnum = str2nr(matchstr(s:m_line[0], '\d\+\ze:'))
    let s0 = matchend(s:m_line[0], ': ')
    let s = match(s:m_line[0], g:agrep_marker, s0, s:m_ptr*2-1)
    let e = matchend(s:m_line[0], g:agrep_marker, s0, s:m_ptr*2)
    return { 'm_col': s+m+1, 'len': e-s-2*m,
	    \ 'lnum': lnum, 'col': s+m-s0+1-(s:m_ptr*2-1)*m }
endfunc

func! s:get_count()
    return str2nr(matchstr(s:m_line[0], '^[-!]\zs\d\+'))
endfunc

func! s:goto_symbol(s, d)
    while 1
	let s:m_lnum += a:d
	let s:m_line = getbufline(s:bufnr, s:m_lnum)
	if s:m_line == [] || s:m_line[0][0] == a:s
	    break
	endif
    endwhile
    return s:m_line != []
endfunc

func! s:get_file()
    let lnum = s:m_lnum - 1
    while getbufline(s:bufnr, lnum)[0][0] != '!'
	let lnum -= 1
    endwhile
    return matchstr(getbufline(s:bufnr, lnum)[0], '^!\d\+!\zs.*\ze:$')
endfunc

func! s:goto_match(d, count, file)
    let s:m_lnum -= 1
    if !s:goto_symbol('-', 1)
	return
    endif

    if a:d " relative location
	let a_count = a:count
	if a:file
	    while a_count && s:goto_symbol('!', a:d)
		let a_count -= 1
	    endwhile
	    if a_count
		call s:goto_symbol('!', a:d * -1)
	    endif
	    let a_count = 1
	    let m_count = 0
	else
	    let m_count = (a:d == 1) ? s:get_count() - s:m_ptr
			\ : s:m_ptr - 1
	endif

	while a_count > m_count && s:goto_symbol('-', a:d)
	    let m_count += s:get_count()
	endwhile
	if a_count > m_count
	    call s:goto_symbol('-', a:d * -1)
	    let s:m_ptr = (a:d == 1) ? s:get_count() : 1
	else
	    let s:m_ptr = (a:d == 1) ? s:get_count() - m_count + a_count 
			\ : m_count - a_count + 1
	endif
	let match = s:get_match()
    else " go directly (enter)
	let s:m_lnum = line('.') -1
	call s:goto_symbol('-', 1)
	let max = s:get_count()
	for s:m_ptr in range(1, max)
	    let match = s:get_match()
	    if col('.') < match.m_col + match.len
		break
	    endif
	endfor
    endif

    let reset_so = 0
    if !&so
	set so=4
	let reset_so = 1
    endif
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	noautocmd exe winnr 'wincmd w'
	if a:d
	    call cursor(s:m_lnum, match.m_col)
	endif
	call s:hl_cur_match(s:m_lnum, match.m_col, match.len)
	if winnr('$') > 1
	    wincmd p
	else
	    exe g:agrep_win_sp_mod 'new'
	endif
    endif
    let file = s:get_file()
    let file = (file[0] == '/' ? file : s:cwd . '/' . file)
    if simplify(file) != simplify(expand('%'))
	exe 'e' file
    endif
    call cursor(match.lnum, match.col)
    redr
    if reset_so
	set so=0
    endif
endfunc

func! s:filer_results(bang, pattern, ffilter)
    call s:history_set()
    call s:open_window()
    let pattern     = (a:pattern == '' ? @/ : a:pattern)
    let lines       = getline(2,'$')
    call add(lines, '')
    let s:n_matches = 0
    let s:n_files   = 0
    let f_lines     = []

    if a:ffilter == 1
	for l in lines
	    if l == ''
		continue
	    elseif l[0] == '!'
		let file = matchstr(l, '^!\d\+!\zs.*\ze:$')
		let valid = 0
		if file =~ pattern && !a:bang || file !~ pattern && a:bang
		    let valid = 1
		    let s:n_files += 1
		    let s:n_matches += matchstr(l, '^!\zs\d\+')
		    call add(f_lines, '')
		    call add(f_lines, l)
		endif
	    elseif l[0] == '-' && valid
		call add(f_lines, l)
	    endif
	endfor
    else
	let file_ptr = 0
	for l in lines
	    if l == ''
		if file_ptr
		    let f_lines[file_ptr] = '!' . fcount . '!' . file
		    let s:n_matches += fcount
		    let s:n_files += 1
		    let file_ptr = 0
		endif
	    elseif l[0] == '!'
		let file = matchstr(l, '^!\d\+!\zs.*')
	    elseif l[0] == '-'
		let line = matchstr(l, ': \zs.*')
		let line = substitute(line, g:agrep_marker, '', 'g')
		if line =~ pattern && !a:bang || line !~ pattern && a:bang
		    if !file_ptr
			call add(f_lines, '')
			call add(f_lines, '')
			let file_ptr = len(f_lines) - 1
			let fcount = 0
		    endif
		    let fcount += matchstr(l, '^-\zs\d\+')
		    call add(f_lines, l)
		endif
	    endif
	endfor
    endif

    let s:m_lnum = 1
    let s:m_ptr  = 0
    let s:filter = printf('(filter%s: %s)', a:bang ? '(!)' : '', a:pattern)
    let s:hist_ptr = -1
    call clearmatches()
    setlocal modifiable
    silent 2,$d _
    call setline(2, f_lines)
    setlocal nomodifiable
endfunc

func! s:set_qf()
    let lines = getbufline(s:bufnr, 2, '$')
    let qf    = []
    for l in lines
	if l == ''
	    continue
	elseif l[0] == '!'
	    let file = matchstr(l, '^!\d\+!\zs.*\ze:$')
	elseif l[0] == '-'
	    call add(qf, {'filename': file,
			\ 'lnum': matchstr(l, '\d\+\ze:'),
			\ 'text': matchstr(l, ': \zs.*')})
	endif
    endfor
    call setqflist(qf)
endfunc

func! s:history_set()
    if s:hist_ptr > -1 | return | endif
    if len(s:history) == g:agrep_history
	let s:history = s:history[1:]
    endif
    let hist_entry = { 'lines' : getbufline(s:bufnr, 1, '$'),
		\ 'context' : [s:regexp, s:status, s:n_matches, s:n_files,
		\ s:filter, s:cwd, s:m_lnum, s:m_ptr] }
    call add(s:history, hist_entry)
    let s:hist_ptr = len(s:history) - 1
endfunc

func! s:history_get(d, count)
    call s:history_set()
    let s:hist_ptr += a:count * a:d
    if s:hist_ptr >= len(s:history) | let s:hist_ptr = len(s:history) - 1 | endif
    if s:hist_ptr < 0 | let s:hist_ptr = 0 | endif
    call s:open_window()
    call clearmatches()
    setlocal modifiable
    silent %d _
    let f_lines = s:history[s:hist_ptr].lines
    let [s:regexp, s:status, s:n_matches, s:n_files, s:filter,
		\ s:cwd, s:m_lnum, s:m_ptr] = s:history[s:hist_ptr].context
    call setline(1, f_lines)
    setlocal nomodifiable
endfunc
