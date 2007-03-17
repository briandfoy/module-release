# $Id$

use Test::More 'no_plan';

eval "use Module::Release::Subversion";
plan skip_all => "Module::Release::Subversion required for testing script" if $@;
           
my $file = 'blib/script/release';

print "bail out! Script file is missing!" 
	unless ok( -e $file, "File exists" );

print "bail out! Module::Release doesn't compile!" 
	unless use_ok( 'Module::Release' );

my $output = `$^X -c $file 2>&1`;
		
like( $output, qr/syntax OK$/, 'script compiles' );
