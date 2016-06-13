#Agrep
###Asynchronous grep plugin for Vim

__Features:__

- Probably the fastest search you can get, in Vim or in any other editor.
- Run grep at the background and get the live stream of results into Vim.  The
  results will be displayed in a special window as soon as they are found, you
  can keep working or start exploring the list immediately.
- Jump to the exact location of a match (line and column. Also for multiple
  matches in a line).
- Highlighting the matching text.

![Agrep](http://i.imgur.com/gW8q0Kk.gif?1)

__Usage:__  
Agrep takes the same command line arguments as the shell's grep, for example:

:Agrep -r 'foo.*bar' ~/my_project

It uses -nH flags by default so you don't need to specify them explicitly.

The following standard commands are available:

Anext, Aprev, Afnext, Afprev, Aopen, Aclose

These commands are similar to the corresponding quickfix commands (cn, cp,
etc.).  Hitting Enter or double-clicking the mouse on a match in the Agrep
window will take you to the match location as well.

Additional commands:

Astop     - kill the search and its grep process.
Aquickfix - Create a quickfix list contains all the search results.

Filter commands:

Afilter[!] {pattern} - filter the results, keep only the results matching the
pattern.  When ! is used, keep only the non-matching results. When {pattern} is
omitted, it uses the last search pattern.

Affilter[!] {pattern} - like Afilter but work on the file names.
