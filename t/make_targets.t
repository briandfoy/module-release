#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

use Cwd;

my $class = 'Module::Release';
my $file  = ".releaserc";

use_ok( $class );
can_ok( $class, 'new' );

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Replace run() with a mock. We don't want to actually do anything.
# Just return whatever is in $output
our $output = '';
{
no warnings;
no strict;
*{"${class}::run"} = sub { $output };
}

can_ok( $release, 'run' );
is( $release->run, '', "Mock run starts off as empty string" );
is( $release->run, $output, "Mock run() returns value of \$output" );

$output = 'Hello there!';
is( $release->run, $output, "Mock run() returns value of \$output" );

is( $release->run( qw(a b ) ), $output, "Mock run(a,b) returns value of \$output" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Replace the output filehandle

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# make clean
