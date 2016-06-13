#!/usr/bin/perl

$|++;
$marker = "¬";

while (<>) {
    next unless /^([^:]*):(\d*):(.*)/;
    ($file, $lnum) = ($1, $2);
    if ($file ne $prev_file) {
	print "\n!$fcount!$prev_file:\n$lines" if $prev_file;
	$prev_file = $file;
	$lines = "";
	$fcount = 0;
    }
    @s = split(/\e\[(?:01)?m\e\[K/, $3, -1);
    $text = join($marker, @s);
    $lcount = int((0+@s) / 2);
    $fcount += $lcount;
    $lines .= sprintf("-%d-%6d: %s\n", $lcount, $lnum, $text);
}

print "\n!$fcount!$prev_file:\n$lines" if $prev_file;
