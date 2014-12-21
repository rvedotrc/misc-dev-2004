#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use strict;
use warnings;

require 5.8.0;

use Encode;

# Encodings

my @enc = Encode->encodings;
use Data::Dumper;
print Data::Dumper->Dump([ \@enc ],[ '*enc' ]);

my @all_encodings = Encode->encodings(":all");
print Data::Dumper->Dump([ \@all_encodings ],[ '*allenc' ]);

# Validation, testing

use charnames ':full';

my %s;
$s{"A"} = chr(65);
$s{"GAMMA"} = chr(0x0194);
$s{"L_POUND"} = chr(163);
$s{"U_POUND"} = "\N{POUND SIGN}";
$s{"DOUBLEENC"} = "\N{LATIN CAPITAL LETTER A WITH CIRCUMFLEX}\N{POUND SIGN}";

for (sort keys %s)
{
	use Data::Dumper;
	print Data::Dumper->Dump([ $s{$_} ],[ $_ ]);
	use Encode 'is_utf8';
	printf " %s utf-8\n", (is_utf8($s{$_}) ? "is":"isn't");

	use Devel::Peek;
	Dump($s{$_});

	for my $enc ("latin-1", "utf-8", "big5")
	{
		my $octets = encode($enc, $s{$_});
		print "  as $enc : ";
		print unpack("H*", $octets);
		print "\n";
	}
}

# eof 
