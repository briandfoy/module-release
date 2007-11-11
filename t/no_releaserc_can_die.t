#!/usr/bin/perl

=pod

I had the bless() after a method call to _die. In older versions I called
Perl's die() so the location of the bless() didn't matter. Now it does.

Reported by Sagar Shah.

=cut

use Test::More 'no_plan';

chdir( 't' );

ok( ! (-e '.releaserc'), 'The releaserc file is missing (good)' );

my $class = 'Module::Release';

use_ok( $class );

ok( ! eval{ $class->new() }, 'new() does not die (good)' );
like( $@, qr/Could not find conf file releaserc/, 
	'Die with the right error message' );