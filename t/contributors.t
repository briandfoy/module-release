#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use Capture::Tiny qw( capture_stdout );

use Module::Release;

BEGIN {
    use File::Spec;
    my $file = File::Spec->catfile(qw(. t lib setup_common.pl));
    require $file;
}

my $release = Module::Release->new;

dies_ok(
    sub { $release->get_recent_contributors },
    "Non-subclassed get_recent_contributors dies"
);

{
    no warnings 'redefine';
    local *Module::Release::get_recent_contributors =
      sub { return ('Joe Bloggs <joe@bloggs.com>') };
    is(
        $release->get_recent_contributors,
        ('Joe Bloggs <joe@bloggs.com>'),
        "Can get defined recent contributor list"
    );
}

{
    my $output = capture_stdout { $release->show_recent_contributors };
    is( $output, '',
        "No contributor output without subclassed get_recent_contributors" );
}

{
    no warnings 'redefine';
    local *Module::Release::get_recent_contributors =
      sub { ( 'Jane Smith <jane@smith.com>', 'Joe Bloggs <joe@bloggs.com>' ) };

    my $output = capture_stdout { $release->show_recent_contributors };
    my $expected_output = <<'EOF';
Contributors since last release:
	Jane Smith <jane@smith.com>
	Joe Bloggs <joe@bloggs.com>
EOF
    is( $output, $expected_output,
        "Contributors since last release are shown" );
}

# vim: expandtab shiftwidth=4
