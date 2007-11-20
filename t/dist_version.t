#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'dist_version_format' );
can_ok( $class, 'dist_version' );

my $mock = bless { remote => 'Foo-1.12_03.tar.gz' }, $class;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# How does the formatting work?
{
my $got = $mock->dist_version_format( 1, 12, "_03" );
is( $got, '1.12_03', 'Development version stays in there' );
}
{
my $got = $mock->dist_version_format( 1, 12 );
is( $got, '1.12', "Without development version it's fine" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# How does the formatting work?
{
my $got = $mock->dist_version;
is( $got, '1.12_03', 'Development version stays in there' );
}
{
my $mock = bless { remote => 'Foo-3.45.tar.gz' }, $class;
my $got = $mock->dist_version;
is( $got, '3.45', "Without development version it's fine" );
}

