#!/usr/bin/perl -w

BEGIN{ 
$ntest = 22;
print "1..$ntest\n";
}

use Image::PBMlib;

sub okay ($$$) {
  my $num = shift;
  my $ok  = shift;
  my $mess = shift;

  print 'not ' unless $ok;
  print "ok $num\n";
  print STDERR $mess."\n" unless $ok;
} # end &okay 

print "ok 1\n";

my ($r, $b, $g);

($r, $b, $g) = hextriplettoraw("414243");

okay(2, ($r eq 'A' and $b eq 'B' and $g eq 'C'),
        "$r eq 'A' and $b eq 'B' and $g eq 'C'" );


($r, $b, $g) = dectriplettoraw("97:98:99");

okay(3, ($r eq 'a' and $b eq 'b' and $g eq 'c'),
    "'$r' eq 'a' and '$b' eq 'b' and '$g' eq 'c'" );

if(open(PPM, "t/2.ppm")) {
  print "ok 4\n";

  my $info_r = readppmheader(\*PPM);

  okay(5, !defined($$info_r{error}), $$info_r{error});

  okay(6, $$info_r{type} == 6, "expected type == 6, got $$info_r{type}");

  okay(7, $$info_r{raw} == 1, "expected raw == 1, got $$info_r{raw}");

  okay(8, $$info_r{bgp} eq 'p', "expected bgp == p, got $$info_r{bgp}");

  okay(9, $$info_r{max} == 255, "expected max == 255, got $$info_r{max}");

  okay(10, $$info_r{width} == 1, "expected width == 1, got $$info_r{width}");

  okay(11, $$info_r{height} == 2,
  		"expected height == 2, got $$info_r{height}");

  okay(12, $$info_r{comments} eq '',
  		"expected comments == '', got $$info_r{comments}");

  my @pix = readpixels_dec(\*PPM, $$info_r{type}, 1);

  if (!@pix) { 
    okay(13, 0, "Undefined pixel array");
  } else {
    okay(13, ($pix[0][0] == 65 and $pix[0][1] == 32 and $pix[0][2] == 127),
       "'$pix[0][0]' == 65 and '$pix[0][1]' == 32 and '$pix[0][2]' == 127");
  }

  @pix = readpixels_raw(\*PPM, $$info_r{type}, 1);

  if (!@pix) { 
    okay(14, 0, "Undefined pixel array");
  } else {
    okay(14, ($pix[0][0] eq ' ' and $pix[0][1] eq '@' and $pix[0][2] eq '~'),
       "'$pix[0][0]' eq ' ' and '$pix[0][1]' eq '\@' and '$pix[0][2]' eq '~'");
  }

  close PPM;
} else {
  print "not ok 4\n";
  print STDERR "Cannot open test image: $!\n";

  my $i;
  for ($i = 5; $i <= 14; $i++) {
    print "ok $i # Skip\n";
  }
}

my %info = (
	type => 6,
	comments => "Made with Image::PBM!",
	width => 10,
	height => 10,
	max => 255
);
my $header = makeppmheader(\%info);

my $expect = "P6
#Made with Image::PBM!
10 10
255
";

okay(15, $header eq $expect, "Header test 1 not as expected");


%info = (
	bgp => "g",
	raw => 1,
	width => 17,
	height => 17,
	max => 255
);
$header = makeppmheader(\%info);

$expect = "P5
17 17
255
";

okay(16, $header eq $expect, "Header test 2 not as expected");


if(open(PPM2, "t/mr-happy.ppm")) {
  print "ok 17\n";

  my $info2_r = readppmheader(\*PPM2);

  okay(18, !defined($$info2_r{error}), $$info2_r{error});
  
  $expect = <<'BIGcomment';
P6
# CREATOR: The GIMP's PNM Filter Version 1.0
# '.' = FFFFFF
# 'X' = CC0000
#
# ....XXXXXXXX....
# ...X........X...
# ...X........X...
# ...X.XX..XX.X...
# ...X........X...
# ..XX...X....XX..
# ..XX...XX...XX..
# ..XX........XX..
# ...X.X....X.X...
# ...X..XXXX..X...
# ...X........X...
# ....XXXXXXXX....
# ......X..X......
# .XXXXXXXXXXXXXX.
# X..............X
# X..X........X..X
16 16
255
BIGcomment
  
  $header = makeppmheader($info2_r);

  okay(19, $header eq $expect, "Big comment header test not as expected");

  close PPM2;
}


# Check for bad filehandle errors
my $bad_r = readppmheader(\*PPM);

if (defined($$bad_r{error}) and $$bad_r{error} =~ /read error/i) {
  print "ok 20\n";
} else {
  print "not ok 20\n";
  if (defined($$bad_r{error})) {
    print STDERR "Wrong error: got $$bad_r{error}\n";
  } else {
    print STDERR "Missing error: expected read error\n";
  }
}

my @bad_p = readpixels_dec(\*PPM, 6, 1);
if(@bad_p) {
  print "ok 21\n";
} else {
  print "not ok 21\n";
  print STDERR "readpixels_dec incorrectly returning pixels\n";
}
@bad_p = readpixels_raw(\*PPM, 6, 1);
if(@bad_p) {
  print "ok 22\n";
} else {
  print "not ok 22\n";
  print STDERR "readpixels_raw incorrectly returning pixels\n";
}
