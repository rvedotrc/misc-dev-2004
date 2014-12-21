#!/usr/bin/perl -w

no warnings qw( portable );
use strict;
use Parser;

my $last_type = "";
my $title = "";
my $p;
my ($baseURI, $artist, $album, $index, $sortname, $track, $tracknum);
my ($artistid, $cdindex, $albumid, $trackid, $trm, $i, $trackURI);

$p = Parser->new();
$p->Parse(join "", <>)
	or die "parse error: " . $p->{error};

for($index = 1;; $index++)
{
    $baseURI = $p->FindNodeByType('http://musicbrainz.org/mm/mm-2.1#Album', $index);
    last if not defined $baseURI;

    if (defined $baseURI)
    {
       #------------------------------------
       # Extract artist info
       #------------------------------------
       $artist = $p->Extract($baseURI, 0, 
                         "http://purl.org/dc/elements/1.1/creator " .
                         "http://purl.org/dc/elements/1.1/title");
       $sortname = $p->Extract($baseURI, 0, 
                         "http://purl.org/dc/elements/1.1/creator " .
                         "http://musicbrainz.org/mm/mm-2.0#sortName");
       $artistid = $p->Extract($baseURI, 0, 
                         "http://purl.org/dc/elements/1.1/creator");
       $artistid =~ s/^.*\/(.*)$/$1/;

       #------------------------------------
       # Extract album info
       #------------------------------------
       $album = $p->Extract($baseURI, 0, 
                         "http://purl.org/dc/elements/1.1/title");
       $albumid = $baseURI;
       $albumid =~ s/^.*\/(.*)$/$1/;
       $cdindex = $p->Extract($baseURI, 0, 
                         "http://musicbrainz.org/mm/mm-2.0#cdindexId");

       #------------------------------------
       # Debug output 
       #------------------------------------
       print " BaseURI: $baseURI\n\n";                            
       print "  Artist: $artist\n";
       print "Sortname: $sortname\n";
       print "ArtistId: $artistid\n\n";
       print "   Album: $album\n";
       print " AlbumId: $albumid\n";                            
       print "CD Index: $cdindex\n" if (defined $cdindex);
       print "\n";                            

       #------------------------------------
       # Extract track info
       #------------------------------------
       for($i = 1;; $i++)
       {
            $trackURI = $p->Extract($baseURI, 0, 
                         "http://musicbrainz.org/mm/mm-2.0#trackList ".
                         "http://www.w3.org/1999/02/22-rdf-syntax-ns#_$i");
            last if (not defined $trackURI);

            $trackid = $trackURI;
            $trackid =~ s/^.*\/(.*)$/$1/;

            $track = $p->Extract($trackURI, 0, "http://purl.org/dc/elements/1.1/title");
            $tracknum = $p->Extract($trackURI, 0, 
                              "http://musicbrainz.org/mm/mm-2.0#trackNum");

            #------------------------------------
            # Debug output 
            #------------------------------------
            $tracknum = "?" if (not defined $tracknum);
            print "TrackNum: $tracknum\n" if (defined $tracknum);
            $track = "<unknown>" if (not defined $track);
            print "   Track: $track\n";
            print " TrackId: $trackid\n\n";
       }
    }
}
