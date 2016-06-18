#Agrep
###Asynchronous grep plugin for Vim

__Agrep is:__

* Designed for search - Vim's |quickfix| is great, but is not the best choice
  to use for searching. Agrep uses a simpler mechanism to manage the results
  (see below) and makes the list of matches very easy to read and navigate.

* Fully asynchronous - Search is done in the background. There is no need to
  wait for the entire process to finish -the matches are displayed as they are
  found in the Agrep window and you can start exploring them immediately. You
  can keep working in Vim as usual while the search is active.

* Fast and lightweight - Most likely the fastest search tool you can get in
  Vim, or in any other editor. Grep is fast, however, integrating it into other
  tools should be done carefully. Agrep is optimized to preserve the speed of
  grep and to keep Vim fully functional while search is running, even for
  massive searches with thousands of matches.

![Agrep](http://i.imgur.com/gW8q0Kk.gif?1)

__Usage:__  
Agrep takes the same command line arguments as the shell's grep, for example:

`:Agrep -r 'foo.*bar' ~/my_project`

See `:h agrep` for details
