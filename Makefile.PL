use ExtUtils::MakeMaker;

WriteMakefile(
        NAME         => 'Image::PBMlib',
        VERSION_FROM => 'PBMlib.pm',
        'linkext'    => {LINKTYPE => ''},
        'dist'       =>    {COMPRESS=>'gzip', SUFFIX=>'gz'},
        ($] >= 5.005?
	   (ABSTRACT => 'Library for reading PBM, PGM, PPM images',
            AUTHOR   => 'Eli the Bearded <eli+cpan@panix.com>')
         : ()
        ),
);
