# agrep
__Asynchronous grep plugin for Vim__

** This plugin is under development **

__Usage:__ Agrep takes the same command line arguments as the shell's grep, for
example:

:Agrep -r 'foo.*bar' ~/my_project

It uses -nH flags by default so you don't need to specify them explicitly.

Each match is available to Vim as soon as it is discovered. You don't need
to wait for the entire search to complete.

![agrep][1]

The results are displayed in a special window (for now). You can change this
and load the results directly to the quickfix list (agrep_use_qf) but it is
slower for long lists, especially if the quickfix window is opened while it
is being updated. You can load the results to the quickfix list any time by
running :Agrepsetqf. It is useful when you edit the files while exploring
the results.

The following commands can be used to navigate the search results:
- AA [nr]
- Anext
- Aprev
These commands are similar to the corresponding quickfix commands (cc, cn,
cp). Hitting <Enter> or double-clicking the mouse on a match in the Agrep
window will take you to the match location as well.
Use :Agrepstop to kill the search and its grep process.

[1]: http://i.imgur.com/epffEDH.gif
