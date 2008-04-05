#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'perls' );
can_ok( $class, 'add_a_perl' );
can_ok( $class, 'remove_a_perl' );
can_ok( $class, 'reset_perls' );

my $mock = bless { perls => { "$^X" => $] } }, $class;

{
my @perls = $mock->perls;
is( scalar @perls, 1, "There is only one perl" );
}

