" Vim syntax file
" Language:	Agrep window
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	AgrepFileName	"^[^:]\+"	nextgroup=AgrepSeparator contains=AgrepCurMatch
syn match	AgrepSeparator	":"		nextgroup=AgrepLineNr contained
syn match	AgrepLineNr	"[^:]\+"	contained
syn match	AgrepTitle	"\%1l.\+"
syn match	AgrepCurMatch	"^>"		conceal contained
exe printf('syn match AgrepMarker "%s" conceal contained', agrep_conceal)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepMarker', agrep_conceal, agrep_conceal, agrep_conceal)

" The default highlighting.
hi def link AgrepFileName	Directory
hi def link AgrepLineNr		LineNr
hi def link AgrepMatch		Special
hi def      AgrepUnderlined term=underline cterm=underline gui=underline
hi def link AgrepTitle AgrepUnderlined

setlocal conceallevel=3 concealcursor=nvic

let b:current_syntax = "Agrep"

" vim: ts=8
