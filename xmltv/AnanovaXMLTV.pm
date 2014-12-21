#!/usr/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

package AnanovaXMLTV;

use constant TV_HTML_PAGE => "http://www.ananova.com/tv/frontpage.html";
use constant XMLTV_URL => "http://www.ananova.com/tv_listings/_xmltv.php";
use constant CACHE_ROOT => '/home/rachel/cvs/local/misc-dev/xmltv/.cache';

use Storable qw( freeze thaw );
use Cache::File;
my $cache = do {
	# Suppress this: Name "Cache::RemovalStrategy::LRU::FIELDS" used only once
	local $^W;
	Cache::File->new(
		cache_root => CACHE_ROOT,
		default_expires => '7 days',
	);
};

sub get_cached
{
	my ($class, $url) = @_;
	my $key = $url;

	my $c = $cache->get($key);
	return $c if $c;

	use LWP::Simple;
	print "Requesting ".$url;
	$c = get($url);
	print "\n";

	$cache->set($key, $c, "7 days");
	$c;
}

################################################################################
# Channel List
################################################################################

sub find_first_node(&$)
{
	my ($sub, $tree) = @_;
	my @q = $tree;
	while (@q)
	{
		my $e = shift @q;
		return $e if &$sub($e);
		unshift @q, $e->content_list
			if ref $e;
	}
	undef;
}

sub fetch_regions
{
	my $class = shift;

	my $content = $class->get_cached(TV_HTML_PAGE);

	use HTML::TreeBuilder;
	my $tree = HTML::TreeBuilder->new; # empty tree
	$tree->parse($content);

	my $select = find_first_node {
		my $e = shift;
		ref($e) or return;
		$e->tag eq "select" or return;
		$e->attr("name") eq "tvregion" or return;
		return 1;
	} $tree;

	$select or die;

	my @regions;
	for my $option ($select->content_list)
	{
		ref($option) or next;
		$option->tag eq "option" or next;
		my $v = $option->attr("value")
			or next;
		my $name = join "", $option->content_list;
		$name =~ s/\A\s*(.*?)\s*\z/$1/;
		push @regions, [ $v, $name ];
	}

	$tree->delete;

	@regions;
}

sub regions
{
	my $class = shift;

	my $c = $cache->get("regions");
	if (defined $c)
	{
		$c = thaw($c);
	} else {
		my @regions = $class->fetch_regions();
		$cache->set("regions", freeze(\@regions), "30 days");
		$c = \@regions;
	}
	@$c;
}

sub fetch_channels
{
	my ($class, $region) = @_;

	my $url = TV_HTML_PAGE . ($region ? "?tvregion=$region" : "");
	my $content = $class->get_cached($url);

	use HTML::TreeBuilder;
	my $tree = HTML::TreeBuilder->new; # empty tree
	$tree->parse($content);

	my $select = find_first_node {
		my $e = shift;
		ref($e) or return;
		$e->tag eq "select" or return;
		$e->attr("name") eq "c" or return;
		return 1;
	} $tree;

	$select or die;

	my @channels;
	for my $option ($select->content_list)
	{
		ref($option) or next;
		$option->tag eq "option" or next;
		my $v = $option->attr("value")
			or next;
		my $name = join "", $option->content_list;
		$name =~ s/\A\s*(.*?)\s*\z/$1/;
		push @channels, [ $v, $name ];
	}

	$tree->delete;

	@channels;
}

sub channels
{
	my ($class, $region) = @_;
	my $key = "channels" . ($region ? "-r$region" : "");
	
	my $c = $cache->get($key);
	if (defined $c)
	{
		$c = thaw($c);
	} else {
		my @channels = $class->fetch_channels($region);
		$cache->set($key, freeze(\@channels), "7 days");
		$c = \@channels;
	}
	@$c;
}

################################################################################
# Channel Day Listing
################################################################################

sub fetch_channel_day_listing
{
	my ($class, $channelid, $daycode) = @_;

	my $url = XMLTV_URL . "?c=$channelid&day=$daycode";
	my $content = $class->get_cached($url);

	$content;
}

sub channel_day_listing
{
	my ($class, $channelid, $y, $m, $d) = @_;
	$channelid =~ /^\d+$/ or die;

	use Date::Calc qw( Today Delta_Days check_date );
	check_date($y, $m, $d) or die;

	my @today = Today;
	my $offset = Delta_Days(@today, $y, $m, $d);
	($offset >= -1 and $offset <= 2)
		or die "Date out of range";

	my $date = sprintf "%04d-%02d-%02d", $y, $m, $d;
	my $key = "xml-$channelid-$date";
	my $content = $cache->get($key);
	if (not defined $content)
	{
		$content = $class->fetch_channel_day_listing($channelid, "day".($offset+1));
		# TODO check correct day fetched (might be wrong if near date
		# boundary)
		$cache->set($key, $content, "7 days");
	}

	$content;
}

sub xml_channel_day_listing
{
	my $self = shift;
	my $content = $self->channel_day_listing(@_);

	require XML::LibXML;
	my $x = XML::LibXML->new;
	my $doc = eval { $x->parse_string($content) };

	unless ($doc)
	{
		my $err = $@;
		open(my $fh, ">failed-xml-parse.log");
		use Data::Dumper;
		print $fh Data::Dumper->Dump([ \@_ ],[ '*_' ]);
		print $fh "The error was: [$err]\n";
		print $fh "The content follows.\n";
		print $fh $content;
		die "Failed to parse XML - saved to failed-xml-parse.log\n";
	}

	$doc;
}

1;
# eof AnanovaXMLTV.pm
