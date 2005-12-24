# $Id$

use Test::More tests => 3;

my $file = 'blib/script/release';

print "bail out! Script file is missing!" 
	unless ok( -e $file, "File exists" );

my $output = `$^X -c $file 2>&1`;

print "bail out! Module::Release doesn't compile!" 
	unless use_ok( 'Module::Release' );

print "bail out! Script doesn't compile!" 
	unless like( $output, qr/syntax OK$/, 'script compiles' );

