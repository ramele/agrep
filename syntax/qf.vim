" Extend quickfix syntax with matched text highlight

exe printf('syn match AgrepMarker "%s" conceal contained', agrep_marker)
exe printf('syn match AgrepMatch "%s[^%s]*%s" contains=AgrepMarker', agrep_marker, agrep_marker, agrep_marker)

setlocal conceallevel=3 concealcursor=nvic

hi def link AgrepMatch CursorLine
