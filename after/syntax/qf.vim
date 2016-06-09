" Extend quickfix syntax with matched text highlight

exe printf('syn match AgrepConceal "%s" conceal contained', agrep_conceal)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepConceal', agrep_conceal, agrep_conceal, agrep_conceal)

setlocal conceallevel=3 concealcursor=nvic

hi def link AgrepMatch Special
