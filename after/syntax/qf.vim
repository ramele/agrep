" Extend quickfix syntax with matched text highlight

exe printf('syn match AgrepConceal "%s" conceal contained', agrep_marker)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepConceal', agrep_marker, agrep_marker, agrep_marker)

setlocal conceallevel=3 concealcursor=nvic

hi def link AgrepMatch Special
