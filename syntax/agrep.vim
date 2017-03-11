" Vim syntax file
" Language:	Agrep window
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	AgrepInfo	"^[!-]\d\+[!-]"	conceal nextgroup=AgrepFileName,AgrepPLine,AgrepLineNr
syn match	AgrepFileName	"[^:]\+"	contained
syn match	AgrepPLine	" \+"		contained nextgroup=AgrepLineNr
syn match	AgrepLineNr	"\d\+"		contained
syn match	AgrepTitle	"\%1l.\+"
exe printf('syn match AgrepMarker "%s" conceal contained', agrep_marker)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepMarker', agrep_marker, agrep_marker, agrep_marker)

" The default highlighting.
hi def link AgrepFileName	Identifier
hi def link AgrepLineNr		LineNr
hi def link AgrepMatch		CursorLine
hi def link AgrepCurMatch	IncSearch
hi def AgrepTitle term=underline cterm=underline gui=underline

let b:current_syntax = "Agrep"

" vim: ts=8
