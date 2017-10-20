#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;
use Sub::Override;
use Capture::Tiny qw( capture );

use Module::Release;

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(. t lib setup_common.pl) );
	require $file;
	}

my $release = Module::Release->new;
$release->{'preset_field'} = 'preset';
is( $release->get_env_var('PRESET_FIELD'),
    'preset', 'Preset field value returned' );

$ENV{'MOO'} = 'baa';
is( $release->get_env_var('MOO'),
    'baa', 'Preset environment variable value returned' );

{
    my $terminal_input =
      Sub::Override->new( 'Module::Release::_slurp' => sub { "baa\n" } );
    $ENV{'MOO'} = '';
    my ( $stdout, $stderr, @result ) = capture { $release->get_env_var('MOO') };
    is(
        $stdout,
        'MOO is not set.  Enter it now: ',
        'Empty environment variable prompts for value'
    );
    is( $result[0], 'baa', 'Variable read from input' );
}

{
    my $terminal_input =
      Sub::Override->new( 'Module::Release::_slurp' => sub { "\n" } );
    $ENV{'MOO'} = undef;
    $release->turn_debug_on;
    my ( $stdout, $stderr, @result ) = capture { $release->get_env_var('MOO') };
    is(
        $stdout,
        'MOO is not set.  Enter it now: ',
        'Undef environment variable prompts for value'
    );
    is(
        $stderr,
        "MOO not supplied.  Aborting...\n",
        "Error message about missing variable shown in debug mode"
    );
}

# vim: expandtab shiftwidth=4
