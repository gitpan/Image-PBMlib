#! perl -w
# A PBM/PGM/PPM library.
# Benjamin Elijah Griffin       28 Feb 2003
# elijah@cpan.org
use strict;

package Image::PBMlib;
use vars qw( @ISA @EXPORT %hexraw %decraw );
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw( dectriplettoraw hextriplettoraw
	      readppmheader makeppmheader
	      readpixels_dec readpixels_raw
	    );
#	      %hexraw %decraw

$Image::PBMlib::VERSION = '1.0';

=head1 NAME

Image::PBMlib - Helper functions for PBM/PGM/PPM image file formats

=head1 SYNOPSIS

    use Image::PBMlib;

    ... open(PPM, "< image.ppm")...

    my $ref = readppmheader(\*PPM);

    my @pixels = readpixels_raw(\*PPM, $$ref{type}, 
    				($$ref{width} * $$ref{height}) );

    my @pixels = readpixels_dec(\*PPM, $$ref{type}, 
    				($$ref{width} * $$ref{height}) );

    my @rgb = hextriplettoraw("F00BA4");

    my @rgb = dectriplettoraw("17:34:51");

    my $header = makeppmheader($ref);

=head1 DESCRIPTION

This is primarily a library for reading portable bitmap (PBM), 
portable graymap (PGM), and portable pixmap (PPM) files. These
image formats are only the barest step up from raw data, and
have a very simple format which is the key to be "portable".
Writing out images in these formats is very easy.

Reading images in these formats is also easy, but not quite
"very easy". Proper reading of the file needs to happen one
byte at a time, since there is no fixed header length. Headers
can also contain comments, which must be ignored. Then, once
past the header, there are a total of six different ways that
the data might need to be read: a raw and an ascii encoding of
each image color level.

=cut

BEGIN {
  my $i;
  my $k;
  my $c;
  for ($i = 0; $i < 256; $i ++) {
    $c = chr($i);
    $k = sprintf("%02x", $i);
    $hexraw{$k} = $c;		# 00 to ff
    $k = uc($k);
    $hexraw{$k} = $c;		# 00 to FF
    $decraw{$i} = $c;		# 0 to 255
    $k = sprintf("%03d", $i);
    $decraw{$k} = $c;		# 000 to 255
  }
} # end BEGIN


=head2 makeppmheader($hashref)

Takes a hash reference similar to C<readppmheader()> would return
and makes a PBM, PGM, or PPM header from it. C<makeppmheader>
first looks for a B<type> in the hash and uses that, otherwise it
expects B<bgp> and B<raw> to be set in the hash (and it will
set B<type> for you then). If there is a non-empty B<comments> in
the hash, that will be put in as one or more lines of comments.
There must be sizes for B<width> and B<height>, and if the image
is not a bitmap, there should be one for B<max>. A missing B<max>
will result in C<makeppmheader> guessing 255. A B<max> of more
than 255 cannot be written as a raw file, but C<makeppmheader>
will not check for that.

  my %info = (
     type => 6,					# raw pixmap
     comments => "Made with Image::PBM!",
     width => 100,
     height => 100,
     max => 255
  );
  my $header = makeppmheader(\%info);

Returns undef if there is an error.

=cut

sub makeppmheader($) {
  my $hr = shift; # header hash ref
  my $head = '';

  if (defined($$hr{type}) and $$hr{type} =~ /^[123456]$/) {
    1;

  } elsif(defined($$hr{bgp}) and defined($$hr{raw}) and
          $$hr{bgp} =~ /^[bgp]$/) {
    
    if ($$hr{bgp} eq 'b') {
      $$hr{type} = 1;
    } elsif ($$hr{bgp} eq 'g') {
      $$hr{type} = 2;
    } else {
      $$hr{type} = 3;
    }

    if ($$hr{raw}) {
      $$hr{type} += 3;
    }
  } else {
    return undef;
  }

  $head = "P$$hr{type}\n";

  if(defined($$hr{comments}) and length($$hr{comments})) {
    my $com = $$hr{comments};
    $com =~ s/^/#/gm;
    $com =~ s/([^\n])\Z/$1\n/;
    $head .= $com;
  }

  if(defined($$hr{width})  and $$hr{width} =~ /^\d+$/  and
     defined($$hr{height}) and $$hr{height} =~ /^\d+$/ and
     $$hr{width} and $$hr{height}) {
    $head .= "$$hr{width} $$hr{height}\n";
  } else {
    return undef;
  }

  if(!($$hr{type} == 1 or $$hr{type} == 4)) {
    if(!defined($$hr{max}) or $$hr{max} == 0) {
      $$hr{max} = 255;
    }
    $head .= "$$hr{max}\n";
  }

  return $head;
} # end &makeppmheader


=head2 readppmheader($globref)

Reads byte-by-byte from the glob until a full header has been
found, then parses it and returns a hashref with information
about the file.

  if(open(PPM, "< image.ppm")) {
    my $info_r = readppmheader(\*PPM);
    # Now %{$info_r} will have:
    #
    # $$info_r{error}      undef if no errors, otherwise a problem
    #			   desciption
    # $$info_r{type}       the number part of the magic number of the
    #			   image format:
    #				1  ascii bitmap
    #				2  ascii graymap
    #				3  ascii pixmap
    #				4  raw   bitmap
    #				5  raw   graymap
    #				6  raw   pixmap
    # $$info_r{raw}         boolean, is this a raw format?
    # $$info_r{bgp}         "b" for bitmap, "g" for graymap, "p" for
    #			    pixmap
    # $$info_r{width}	    image width
    # $$info_r{height}	    image height
    # $$info_r{max}	    max color value (1 for bitmap, usually 255
    #			    for others)
    # $$info_r{comments}    comments found in the header (all catinated)
    # $$info_r{fullheader}  the complete, unparsed, header
  }

If there was an error, the B<error> hash element will be set with a
problem description, and the other hash elements may or may not be
set or trustworthy.

=cut

sub readppmheader($) {
  my $gr = shift; # input file glob ref
  my $in = '';
  my $no_comments;
  my %info;
  my $rc;
  $info{error} = undef;
  
  $rc = read($gr, $in, 3);

  if ($rc != 3) {
    $info{error} = 'Read error or EOF';
    return \%info;
  }

  if ($in =~ /^P([123456])\s/) {
    $info{type} = $1;
    if ($info{type} > 3) {
      $info{raw} = 1;
    } else {
      $info{raw} = 0;
    }

    if ($info{type} == 1 or $info{type} == 4) {
      $info{max} = 1;
      $info{bgp} = 'b';
    } elsif ($info{type} == 2 or $info{type} == 5) {
      $info{bgp} = 'g';
    } else {
      $info{bgp} = 'p';
    }

    while(1) {
      $rc = read($gr, $in, 1, length($in));
      if ($rc != 1) {
	$info{error} = 'Read error or EOF';
	return \%info;
      }

      $no_comments = $in;
      $info{comments} = '';
      while ($no_comments =~ /#/) {
        $no_comments =~ s/#(.*\n)/ /;
	$info{comments} .= $1;
      }

      if ($info{bgp} eq 'b') {
        if ($no_comments =~ /^P\d\s+(\d+)\s+(\d+)\s/) {
	  $info{width}  = $1;
	  $info{height} = $2;
          last;
	}
      } else {
        if ($no_comments =~ /^P\d\s+(\d+)\s+(\d+)\s+(\d+)\s/) {
	  $info{width}  = $1;
	  $info{height} = $2;
	  $info{max}    = $3;
          last;
	}
      }
    } # while reading header

    $info{fullheader} = $in;

  } else {
    $info{error} = 'Wrong magic number';
  }

  return \%info;
} # end &readppmheader



=head2 readpixels_dec($globref, $type, $count)

This will attempt to read C<$count> pixels from the GLOB. To know
how to interpret the file, the file type (1 to 6) is required. An
EOF may cause C<readpixels_dec()> to return fewer than C<$count>
pixels. Type 4 (raw bitmap) images can only be read 8 pixels at
a time, so the count will be rounded up to the next multiple of 8.

Returned will be an array of the decimal values of each pixel.
Color images will be returned as an array of arrays of RGB values.

  @pixels = readpixels_dec(\*PPM, $$info_r{type}, 1);
  my ($r, $g, $b) = ( $pixels[0][0], $pixels[0][1], $pixels[0][2] );
  # If it was a blue pixel, $r == 0, $g == 0, $b == 255.
  
Short reads will result in short pixel arrays returned. Invalid
format or nothing to read will result in undef being returned.

=cut

sub readpixels_dec($$$) {
  my $gr = shift; # input file glob ref
  my $t  = shift; # file type [1-6]
  my $n  = shift; # num pixels, will read 8 at a time for type 4 (raw PBM)
  my $rc;
  my $in;
  my @p;	# returned array
  my @p2;	# temp for type 6 (raw PPM) and type 4 (raw PPM) images

  if ($t !~ /^[123456]$/) {
    return undef;
  }

  while($n > 0) {
    $n --;

    if($t == 6) {
      # Color rawbits
      $rc = read($gr, $in, 3);
      if ($rc < 3) {
        if (@p) { return @p } else { return undef }
      }
      @p2 = unpack("C*", $in);
      push(@p, [ $p2[0], $p2[1], $p2[2] ]);

    } elsif($t == 5) {

      # Gray rawbits
      $rc = read($gr, $in, 1);
      if (!$rc) {
        if (@p) { return @p } else { return undef }
      }
      $rc = unpack("C*", $in);
      push(@p, $rc);

    } elsif($t == 4) {

      # B&W rawbits
      $rc = read($gr, $in, 1);
      if (!$rc) {
        if (@p) { return @p } else { return undef }
      }
      $rc = unpack("B*", $in);
      @p2 = $rc =~ /([\d])/g;
      push(@p, @p2);

      $n -= 7; # account for the extra 7 bits we read

    } elsif($t == 3) {

      # Color ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if ($in =~ /(\d+)\s+(\d+)\s+(\d+)$/) {
            push(@p, [ $1, $2, $3 ]);
	    last;
          }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s+(\d+)\s+(\d+)\s/) {
          push(@p, [ $1, $2, $3 ]);
	  last;
	}
      } # while reading $gr

    } elsif($t == 2) {

      # Gray ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if(length($in)) {
            push(@p, $in);
	  }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s/) {
          push(@p, $1);
	  last;
	}
      } # while reading $gr

    } elsif($t == 1) {

      # B&W ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if(length($in)) {
            push(@p, $in);
	  }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s/) {
          push(@p, $1);
	  last;
	}
      } # while reading $gr

    } # end of if t == 6 ... t == 1 if-else chain

  } # while $n

  return @p;
} # end &readpixels_dec




=head2 readpixels_raw($globref, $type, $count)

This will attempt to read C<$count> pixels from the GLOB. To know
how to interpret the file, the file type (1 to 6) is required. An
EOF may cause C<readpixels_dec()> to return fewer than C<$count>
pixels. Type 4 (raw bitmap) images can only be read 8 pixels at
a time, so the count will be rounded up to the next multiple of 8.

Returned will be an array of the raw color values of each pixel.
Color images will be returned as an array of arrays of RGB values.

  @pixels = readpixels_dec(\*PPM, $$info_r{type}, 1);
  my ($r, $g, $b) = ( $pixels[0][0], $pixels[0][1], $pixels[0][2] );
  # If it was a blue pixel, $r == chr(0), $g == chr(0), $b == chr(255).
  
Short reads will result in short pixel arrays returned. Invalid
format or nothing to read will result in undef being returned.

=cut


sub readpixels_raw($$$) {
  my $gr = shift; # input file glob ref
  my $t  = shift; # file type [1-6]
  my $n  = shift; # num pixels, will read 8 at a time for type 4 (raw PBM)
  my $rc;
  my $in;
  my @p;	# returned array
  my @p2;	# temp for type 6 (raw PPM) and type 4 (raw PPM) images

  if ($t !~ /^[123456]$/) {
    return undef;
  }

  while($n > 0) {
    $n --;

    if($t == 6) {
      # Color rawbits
      $rc = read($gr, $in, 3);
      if ($rc < 3) {
        if (@p) { return @p } else { return undef }
      }
      @p2 = $in =~ /(.)/sg;
      push(@p, [ $p2[0], $p2[1], $p2[2] ]);

    } elsif($t == 5) {

      # Gray rawbits
      $rc = read($gr, $in, 1);
      if (!$rc) {
        if (@p) { return @p } else { return undef }
      }
      push(@p, $in);

    } elsif($t == 4) {

      # B&W rawbits
      $rc = read($gr, $in, 1);
      if (!$rc) {
        if (@p) { return @p } else { return undef }
      }
      $rc = unpack("B*", $in);
      $rc =~ tr:01:\00\01:;
      @p2 = $rc =~ /(.)/g;
      push(@p, @p2);

      $n -= 7; # account for the extra 7 bits we read

    } elsif($t == 3) {

      # Color ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if ($in =~ /(\d+)\s+(\d+)\s+(\d+)$/) {
            push(@p, [ $decraw{$1}, $decraw{$2}, $decraw{$3} ]);
	    last;
          }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s+(\d+)\s+(\d+)\s/) {
          push(@p, [ $decraw{$1}, $decraw{$2}, $decraw{$3} ]);
	  last;
	}
      } # while reading $gr

    } elsif($t == 2) {

      # Gray ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if(length($in)) {
            push(@p, $decraw{$in});
	  }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s/) {
          push(@p, $decraw{$1});
	  last;
	}
      } # while reading $gr

    } elsif($t == 1) {

      # B&W ascii
      $in = '';
      while(1) {
        $rc = read($gr, $in, 1, length($in));
	if (!$rc) {
	  if(length($in)) {
            push(@p, $in);
	  }
          if (@p) { return @p } else { return undef }
	}
	if ($in =~ /(\d+)\s/) {
          push(@p, $decraw{$1});
	  last;
	}
      } # while reading $gr

    } # end of if t == 6 ... t == 1 if-else chain

  } # while $n

  return @p;
} # end &readpixels_raw



=head2 hextriplettoraw($string)

Parses a six character hexstring into an R, G, B triplet
and returns an array of the raw bytes.

   @rgb_raw = hextriplettoraw("FF0000"); # red

Returns undef if there is an error.

=cut

sub hextriplettoraw($) {
  my @v = $_[0] =~ /([0-9a-fA-F][0-9a-fA-F])/g;

  if(@v < 3) {
    return undef;
  }

  return ( $hexraw{$v[0]}, $hexraw{$v[1]}, $hexraw{$v[2]} );
} # end &hextriplettoraw



=head2 dectriplettoraw($string)

Parse a colon seperated list into an R, G, B triplet
and returns an array of the raw bytes.

   @rgb_raw = hextriplettoraw("0:255:0"); # green

Returns undef if there is an error.

=cut

sub dectriplettoraw($) {
  my @v = split(/:/, $_[0], 4);

  if(@v < 3) {
    return undef;
  }

  return ( $decraw{$v[0]}, $decraw{$v[1]}, $decraw{$v[2]} );
} # end &dectriplettoraw


=head1 PORTABILITY

This code is pure perl for maximum portability, as befitting the
PBM/PGM/PPM philiosophy.

=head1 BUGS

The maximum color value is never used.

No attempt is made to deal with comments after the header of ascii
formatted files.

Not all PBM/PGM/PPM tools are safe for images from untrusted sources
but this one should be. Be careful what you use this with.

=head1 SEE ALSO

The manual pages for B<pbm>(5),  B<pgm>(5), and B<ppm>(5) define the
various file formats. 

=head1 COPYRIGHT

Copyright 2003 Benjamin Elijah Griffin / Eli the Bearded
E<lt>elijah@cpan.orgE<gt>

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1;
