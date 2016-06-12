#!/usr/bin/perl

$|++;
while (<>) {
    next unless /^([^:]*):(\d*):(.*)/;
    ($file, $lnum) = ($1, $2);
    @s = split(/\e\[(?:01)?m\e\[K/, $3, -1);
    $col = 1; $m = 0;
    $text = join('°', @s);
    $text =~ s/^\s+//;
    foreach (@s) {
	print "$file:$lnum,$col: $text\n" if $m;
	$col += length($_);
	$m = !$m;
    }
}
