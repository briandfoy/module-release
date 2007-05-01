# $Id$
use Test::More tests => 1;
eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD" if $@;

pod_coverage_ok(
               "Module::Release",
               { also_private => [ qw/DASHES/ ], },
           );
