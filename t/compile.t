# $Id$

use Test::More tests => 2;

my $file = 'blib/script/release';

print "bail out! Script file is missing!" unless ok( -e $file, "File exists" );

my $output = `$^X -c $file 2>&1`;

like( $output, qr/syntax OK$/, 'script compiles' );
