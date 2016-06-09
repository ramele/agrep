" Vim syntax file
" Language:	Agrep window
" Maintainer:	Ramel Eshed <ramelo1@gmail.com>
" Last Change:	2016 Apr 29

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	AgrepFileName	"^[^:]\+"	nextgroup=AgrepSeparator
syn match	AgrepSeparator	":"		nextgroup=AgrepLineNr contained
syn match	AgrepLineNr	"[^:]\+"	contained
syn match	AgrepHeader	"\%1l.\+"
exe printf('syn match AgrepConceal "%s" conceal contained', agrep_conceal)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepConceal', agrep_conceal, agrep_conceal, agrep_conceal)

" The default highlighting.
hi def link AgrepFileName	Directory
hi def link AgrepLineNr		LineNr
hi def link AgrepMatch		Special
hi def AgrepUnderline term=underline cterm=underline gui=underline
hi link AgrepHeader AgrepUnderline

setlocal conceallevel=3 concealcursor=nvic

let b:current_syntax = "Agrep"

" vim: ts=8
