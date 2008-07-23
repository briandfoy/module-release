#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;

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

my @subs = qw( check_kwalitee cpants_lint cpants_pass_regex );

my $test_tar = 'foo.tar.gz';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
ok( ! $release->can( 'check_kwalitee' ), 'check_kwalitee not loaded yet' );

ok( 
	$release->load_mixin( 'Module::Release::Kwalitee' ), 
	"Loaded Kwalitee mixin" 
	);

can_ok( $release, @subs );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
ok( defined $release->cpants_lint, "cpants_lint returns a defined value" );
isa_ok( $release->cpants_pass_regex, ref qr//, "cpants_pass_regex returns a regex" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Replace run() with a mock. We don't want to actually do anything.
# Just return whatever is in $output
our $run_output = '';
{
no warnings;
no strict;
*{"${class}::run"} = sub { $run_output };
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check without distro file
{
$release->turn_quiet_on;
my $rc = eval { $release->check_kwalitee; 1 };
my $at = $@;
ok( defined $at, "check_kwalitee dies with no distro file" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check with the distro file
{
open my( $fh ), ">", $test_tar;
close $fh;
ok( -e $test_tar, "Created test distribution" );
}

__END__
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run returns nothing, should die


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run returns "a 'prefect' distribution"
{
local $run_output = "a 'perfect' distribution";
ok( -e $test_tar, "$test_tar file exists" );
$release->local_file( $test_tar );
is( $release->local_file, $test_tar, "Local file was set to $test_tar" );

stdout_like
	{ $release->check_kwalitee }
	qr/done/,
	"kwalitee passes and we reach 'done'"

}