package Slim::Formats::Ogg;

# $Id$

# SlimServer Copyright (c) 2001-2004 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;
use Slim::Utils::Misc;
use Slim::Utils::Unicode;

use Ogg::Vorbis::Header::PurePerl;

my %tagMapping = (
	'TRACKNUMBER'	=> 'TRACKNUM',
	'DISCNUMBER'    => 'DISC',
	'URL'           => 'URLTAG',
	'MUSICBRAINZ_ALBUMARTISTID'	=> 'MUSICBRAINZ_ALBUMARTIST_ID',
	'MUSICBRAINZ_ALBUMID'		=> 'MUSICBRAINZ_ALBUM_ID',
	'MUSICBRAINZ_ALBUMSTATUS'	=> 'MUSICBRAINZ_ALBUM_STATUS',
	'MUSICBRAINZ_ALBUMTYPE'		=> 'MUSICBRAINZ_ALBUM_TYPE',
	'MUSICBRAINZ_ARTISTID'		=> 'MUSICBRAINZ_ARTIST_ID',
	'MUSICBRAINZ_TRACKID'		=> 'MUSICBRAINZ_ID',
	'MUSICBRAINZ_TRMID'		=> 'MUSICBRAINZ_TRM_ID',
);

# Given a file, return a hash of name value pairs,
# where each name is a tag name.
sub getTag {
	my $class = shift;
	my $file  = shift || return {};

	# This hash will map the keys in the tag to their values.
	my $tags = {};
	my $ogg  = undef;

	# some ogg files can blow up - especially if they are invalid.
	eval {
		local $^W = 0;
		$ogg = Ogg::Vorbis::Header::PurePerl->new($file);
	};

	if (!$ogg or $@) {
		$::d_formats && msg("Can't open ogg handle for $file\n");
		return $tags;
	}

	if (!$ogg->info('length')) {
		$::d_formats && msg("Length for Ogg file: $file is 0 - skipping.\n");
		return $tags;
	}

	# Tags can be stacked, in an array.
	foreach my $key ($ogg->comment_tags) {

		my $ucKey  = uc($key);
		my @values = $ogg->comment($key);
		my $count  = scalar @values;

		for my $value (@values) {

			if ($] > 5.007) {
				$value = Slim::Utils::Unicode::utf8decode($value, 'utf8');
			} else {
				$value = Slim::Utils::Unicode::utf8toLatin1($value);
			}

			if ($count == 1) {

				$tags->{$ucKey} = $value;

			} else {

				push @{$tags->{$ucKey}}, $value;
			}
		}
	}

	# Correct ogginfo tags
	while (my ($old,$new) = each %tagMapping) {

		if (exists $tags->{$old}) {

			$tags->{$new} = delete $tags->{$old};
		}
	}

	# Special handling for DATE tags
	# Parse the date down to just the year, for compatibility with other formats
	if (defined $tags->{'DATE'} && !defined $tags->{'YEAR'}) {
		($tags->{'YEAR'} = $tags->{'DATE'}) =~ s/.*(\d\d\d\d).*/$1/;
	}

	# Add additional info
	$tags->{'SIZE'}	    = -s $file;

	$tags->{'SECS'}	    = $ogg->info('length');
	$tags->{'BITRATE'}  = $ogg->info('bitrate_nominal');
	$tags->{'STEREO'}   = $ogg->info('channels') == 2 ? 1 : 0;
	$tags->{'CHANNELS'} = $ogg->info('channels');
	$tags->{'RATE'}	    = $ogg->info('rate');

	if (defined $ogg->info('bitrate_upper') && defined $ogg->info('bitrate_lower')) {

		if ($ogg->info('bitrate_upper') != $ogg->info('bitrate_lower')) {

			$tags->{'VBR_SCALE'} = 1;
		} else {
			$tags->{'VBR_SCALE'} = 0;
		}

	} else {

		$tags->{'VBR_SCALE'} = 0;
	}
	
	$tags->{'OFFSET'}   =  0; # the header is an important part of the file. don't skip it

	return $tags;
}

1;
