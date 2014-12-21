#!/usr/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

# The rules:
# A ring of 13 positions.  Choose 4 such that there exists a chosen pair
# distance 'X' apart for X = 1..13.
# Also for 21 positions, 5 points.
# Note that (3+2+1)*2 = 13-1
# and     (4+3+2+1)*2 = 21-1
# Find the possible arrangements.

my $c = 4;
my $l = 13;

# We represent the possible solution as a series of numbers adding up to the
# length of the ring; i.e. the gaps between successive points.
# Without loss of generality we can say that the first such gap is always 1.
# So given a solution it might be (1,x,y,z,...)

my @solutions;

solve([], [ (undef)x$l ], [ undef, (0)x$l ], $l);

sub solve
{
	my ($raIndexes, $raSlots, $raUsedGaps, $iToGo) = @_;

	if (not $iToGo)
	{
		push @solutions, $raIndexes;
		return;
	}

	my @aiPossiblePos;
	if (not @$raIndexes)
	{
		@aiPossiblePos = (0);
	} else {
		@aiPossiblePos = grep { not defined $raSlots->[$_] } 0..$l-1;
	}

	for my $iInsert (@aiPossiblePos)
	{
	}
}
