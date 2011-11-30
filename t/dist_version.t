#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'dist_version_format' );
can_ok( $class, 'dist_version' );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Should fail if remote is not set
{
my $mock = bless {  }, $class;

my $got = eval { $mock->dist_version };
my $at = $@;

ok( ! defined $got, "Without remote set, dist_version croaks" );
like( $at, qr/\QIt's not set/, "Without remote set, get right error message" );
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# How does the formatting work?
{
my $mock = bless { remote_file => 'Foo-1.12_03.tar.gz' }, $class;

{
my $got = $mock->dist_version_format( 1, 12, "_03" );
is( $got, '1.12_03', 'Development version stays in there' );
}
{
my $got = $mock->dist_version_format( 1, 12 );
is( $got, '1.12', "Without development version it's fine" );
}

{
my $got = $mock->dist_version;
is( $got, '1.12_03', 'Development version stays in there' );
}
{
my $mock = bless { remote_file => 'Foo-3.45.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, '3.45', "Without development version it's fine" );
}
}


# Test three-part version numbers.  Module::Build at least generates
#  them with a leading 'v'
{
my $mock = bless { remote_file => 'Foo-v3.45.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, 'v3.45.0', "Two-part version string with leading 'v'" );
}

{
my $mock = bless { remote_file => 'Foo-v3.45.0.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, 'v3.45.0', "Three-part version string with leading 'v'" );
}

# Ditto, development version
{
my $mock = bless { remote_file => 'Foo-v3.45_1.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, 'v3.45_1', "Three-part development version string with leading 'v'" );
}


# Test three-part version numbers with no leading 'v'.  Not sure if
# this occurs in the wild, but presumably this should result in the
# same as above.
{
my $mock = bless { remote_file => 'Foo-3.45.0.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, 'v3.45.0', "Three-part version string without leading 'v'" );
}

# Test four-part version development numbers with no leading 'v'.
# (Note, four, since the three case must be backward compatible and return
# the same as the earlier test above.)
{
my $mock = bless { remote_file => 'Foo-3.45.0_3.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, 'v3.45.0_3', "Three-part version string without leading 'v'" );
}
