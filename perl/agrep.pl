#!/usr/bin/perl

$|++;

$marker = "¬";

$test = `echo 'abc' | grep --color=always abc`;
chop($test);
@cc = split(/abc/, $test);
$color_expr = quotemeta($cc[0]) . "|" . quotemeta($cc[1]);

while (<>) {
    ($file, $lnum, $raw_text) = /^([^:]+):(\d+):(.*)/;
    if ($file ne $cur_file) {
	printf("\n%s%s", $fcount ? "!$fcount!" : "", $lines) if $lines;
	$cur_file = $file;
	$lines = $file ? "$file:\n" : "";
	$fcount = 0;
    }
    if (!$file) {
	$lines .= $_;
	next;
    }
    @s = split(/$color_expr/, $raw_text, -1);
    $text = join($marker, @s);
    $lcount = int((0+@s) / 2);
    $fcount += $lcount;
    $lines .= sprintf("-%d-%6d: %s\n", $lcount, $lnum, $text);
}

printf("\n%s%s", $fcount ? "!$fcount!" : "", $lines) if $lines;
