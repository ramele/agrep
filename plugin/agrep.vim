" Agrep - Asynchronous grep plugin for Vim
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

if v:version < 704 || v:version == 704 && !has("patch1907")
    echoerr 'Agrep requires Vim 7.4.1907 or later!'
    fini
endif

" global options:
if !exists('agrep_win_sp_mod')
    let agrep_win_sp_mod = 'bo 18'
endif
if !exists('agrep_default_flags')
    let agrep_default_flags = '-I --exclude-dir=.{git,svn}'
endif
if !exists('agrep_marker')
    let agrep_marker = nr2char(172)
endif

command! -nargs=+ -complete=file Agrep call Agrep(<q-args>)
command!          		 Astop call s:stop()

command! -count=1 Anext      call s:goto_match( 1, <count>, 0)
command! -count=1 Aprev      call s:goto_match(-1, <count>, 0)
command! -count=1 Afnext     call s:goto_match( 1, <count>, 1)
command! -count=1 Afprev     call s:goto_match(-1, <count>, 1)
command!          Aquickfix  call s:set_qf()
command!          Aopen      call s:open_window()
command!          Aclose     call s:close_window()
command! -count=1 Aolder     echomsg 'This command is not implemented yet...'
command! -count=1 Anewer     echomsg 'This command is not implemented yet...'

command! -nargs=* -bang Afilter   call s:filer_results(<bang>0, <q-args>, 1)
command! -nargs=* -bang Affilter  call s:filer_results(<bang>0, <q-args>, 0)

let s:grep_cmd = 'GREP_COLORS="mt=01:sl=:fn=:ln=:se=" grep --color=always --line-buffered -nH'

func! Agrep(args)
    " let s:rt        = reltime()
    let s:regexp    = matchstr(a:args, '\v^(-\S+\s*)*\zs(".*"|''.*''|\S*)')
    let s:status    = 'Active'
    let s:n_matches = 0
    let s:n_files   = 0
    let s:current = {'alnum': 1, 'lm': [] , 'lm_i': 0}
    let s:filter    = ''
    call clearmatches()

    if !exists('s:agrep_perl')
	let s:agrep_perl = globpath(&rtp, 'perl/agrep.pl')
    endif

    let grep_cmd = s:grep_cmd . ' ' . g:agrep_default_flags . ' ' . a:args . ' | ' . s:agrep_perl

    call s:set_window('grep ' . g:agrep_default_flags . ' ' . a:args . ':')

    let s:agrep_job = job_start(['/bin/bash', '-c', grep_cmd], {
		\ 'out_io': 'buffer', 'out_buf': s:bufnr, 'out_modifiable': 0,
		\ 'out_cb': function('s:out_cb'), 'close_cb': function('s:close_cb')})
    let s:timer = timer_start(120, function('s:update_stl'), { 'repeat': -1 })
endfunc

func! s:out_cb(channel, msg)
    if a:msg[0] == '!'
	let s:n_matches += matchstr(a:msg, '\v^!\zs\d+')
	let s:n_files += 1
    endif
endfunc

func! s:close_cb(channel)
    " out_cb may still be active at this point
    call timer_start(200, function('s:final_close'))
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
    setlocal modifiable
    silent %d _
    call setline(1, a:title)
    setlocal nomodifiable
    call cursor(1, col('$')) " avoid scrolling when using out_io buffer
    if winnr() != base_win | wincmd p | endif
endfunc

func! s:open_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr 'wincmd w'
    else
	exe g:agrep_win_sp_mod 'sp Agrep'
    endif
endfunc

func! s:close_window()
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	exe winnr . 'close'
    endif
endfunc

func! s:hl_cur_match()
    if !exists('b:current_syntax')
	return
    endif
    call clearmatches()
    call matchaddpos('AgrepCurMatch', [[s:current.alnum, col('.'), s:current.len]])
endfunc

func! s:extract_fline(line)
    let ml = matchlist(a:line, '\v^!(\d*)!(.*):$')
    return {'n_matches': ml[1], 'file': ml[2]}
endfunc

func! s:extract_mline(line)
    let ml = matchlist(a:line, '\v^-(\d*)-\s*(\d+): (.*)')
    return {'n_matches': ml[1], 'lnum': ml[2], 'text': ml[3]}
endfunc

func! s:get_file(lnum)
    let lnum = a:lnum
    let line = getbufline(s:bufnr, lnum)[0]
    while line[0] != '!'
	let  lnum -= 1
	let line = getbufline(s:bufnr, lnum)[0]
    endwhile
    return s:extract_fline(line).file
endfunc

func! s:get_line_matches(line)
    let sp  = split(a:line, g:agrep_marker, 1)
    let ret = []
    let alen = 0
    let m   = 0
    for s in sp
	let len = len(s)
	if m
	    call add(ret, [alen+1, len])
	endif
	let alen += len
	let m = !m
    endfor
    return ret
endfunc

func! s:move_pointer(d)
    let p = s:current
    let p.lm_i += a:d
    if p.lm_i < 0 || p.lm_i >= len(p.lm)
	let p.alnum += a:d
	let bl = getbufline(s:bufnr, p.alnum)
	if bl == [] || p.alnum <= 3 && a:d == -1 " needed for first init...
	    let p.alnum -= a:d
	    let p.lm_i -= a:d
	    return 0
	endif
	if bl[0][0] == '!' || bl[0] == ''
	    let p.alnum += 2 * a:d
	    let bl = getbufline(s:bufnr, p.alnum)
	    let p.file = s:get_file(p.alnum)
	endif
	let p.e_mline = s:extract_mline(bl[0])
	let p.lm = s:get_line_matches(p.e_mline.text)
	let p.lm_i = (a:d == 1 ? 0 : len(p.lm)-1)
	let p.lnum = p.e_mline.lnum
    endif
    let [p.col, p.len] = p.lm[p.lm_i]
    return 1
endfunc

func! s:goto_match(d, count, file)
    if !s:n_matches | return | endif
    let p = s:current
    if a:d " match or file
	let prev_file = get(p, 'file', '')
	let n = a:count
	while n && s:move_pointer(a:d)
	    let n -= (a:file ? (prev_file != p.file) : 1)
	    let prev_file = p.file
	endwhile
    else " go directly (enter)
	let line = getline('.')
	if line[0] != '-'
	    call search('^-')
	endif
	let p.alnum = line('.') - 1
	let p.lm = []
	let p.file = s:get_file(line('.'))
	let col = col('.') - len(matchstr(line, '\v^[^:]*: '))
	call s:move_pointer(1)
	while p.col + p.len - 1 + 2 * (p.lm_i+1) * len(g:agrep_marker) < col
		    \ && p.lm_i + 1 <  len(p.lm)
	    call s:move_pointer(1)
	endwhile
    endif
    let saved_so = &so
    set so=3
    let winnr = bufwinnr(s:bufnr)
    if winnr > 0
	noautocmd exe winnr 'wincmd w'
	call cursor(p.alnum, 1)
	for i in range(0, p.lm_i)
	    call search(printf('%s\zs[^%s]*%s', g:agrep_marker, g:agrep_marker, g:agrep_marker))
	endfor
	call s:hl_cur_match()
	if winnr('$') > 1
	    wincmd p
	else
	    new
	endif
    endif
    exe 'e' p.file
    call cursor(p.lnum, p.col)
    redr
    let &so = saved_so
endfunc

func! s:filer_results(bang, pattern, filter)
    call s:open_window()
    let pattern     = (a:pattern == '' ? @/ : a:pattern)
    let lines       = getline(2,'$')
    let s:n_matches = 0
    let s:n_files   = 0
    let u_lines     = []
    for l in lines
	if l == '' | continue | endif
	let is_file = (l[0] == '!' ? 1 : 0)
	if is_file
	    let fline = l
	    let fadded = 0
	    let fvalid = 1
	    if a:filter == 0
		let el = s:extract_fline(l)
		if el.file =~ pattern && a:bang || el.file !~ pattern && !a:bang
		    let fvalid = 0
		endif
	    endif
	else
	    if !fvalid | continue | endif
	    let em = s:extract_mline(l)
	    if a:filter == 1
		let str = substitute(em.text, g:agrep_marker, '', 'g')
		if str =~ pattern && a:bang || str !~ pattern && !a:bang
		    continue
		endif
	    endif
	    if !fadded
		call add(u_lines, '')
		call add(u_lines, fline)
		let fadded = 1
		let s:n_files += 1
	    endif
	    let s:n_matches += em.n_matches
	    call add(u_lines, l)
	endif
    endfor
    let s:current.alnum = 1
    let s:current.lm = []
    let s:filter = printf('(filter%s: %s)', a:bang ? '(!)' : '', a:pattern)
    call clearmatches()
    setlocal modifiable
    silent 2,$d _
    call setline(2, u_lines)
    setlocal nomodifiable
endfunc

func! s:set_qf()
    let saved_cur = copy(s:current)
    let p         = s:current
    let p.alnum   = 1
    let p.lm      = []
    let qf        = []
    while s:move_pointer(1)
	call add(qf, {'filename': p.file, 'lnum': p.lnum,
		    \ 'col': p.col, 'text': p.e_mline.text})
    endwhile
    let s:current = saved_cur
    call setqflist(qf)
endfunc
