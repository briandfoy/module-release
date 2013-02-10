#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

use File::Spec;

my $class = 'Module::Release';
my $file  = ".releaserc";

use_ok( $class );
can_ok( $class, 'new' );

BEGIN {
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create object with no parameters, clean environment
{
local %ENV; # don't react to overall setup
my $method = 'debug';

my $release = $class->new;
isa_ok( $release, $class );

can_ok( $release, $method );
ok( ! $release->$method(), "debug starts off" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create object with no parameters, RELEASE_DEBUG = 1
{
local %ENV; # don't react to overall setup
my $var = "RELEASE_DEBUG";

$ENV{RELEASE_DEBUG} = 1;
my $method = 'debug';

my $release = $class->new;
isa_ok( $release, $class );

can_ok( $release, $method );
is( $release->$method(), $ENV{$var}, 
	"$method matches $var ($ENV{RELEASE_DEBUG})" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create object with no parameters, RELEASE_DEBUG = 0
{
local %ENV; # don't react to overall setup
my $var = "RELEASE_DEBUG";

$ENV{RELEASE_DEBUG} = 0;
my $method = 'debug';

my $release = $class->new;
isa_ok( $release, $class );

can_ok( $release, $method );
is( $release->$method(), $ENV{$var}, 
	"$method matches $var ($ENV{RELEASE_DEBUG})" );
}
