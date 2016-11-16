use strict;
use warnings;

use Cwd;
use File::Spec;
use File::Path;
use Test::More 1;

my $old_dir = cwd;
my $conf    = $^O eq 'MSWin32' ? '.releaserc' : 'releaserc';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Setup a test directory
subtest test_dir => sub {
	my $dir = File::Spec->catfile( qw(t test_dir) );
	mkdir $dir, 0755 unless -d $dir;
	ok( -d $dir, "Test directory is there" );

	ok( chdir( $dir ), "Changed into $dir" );
	END { chdir $old_dir; rmtree [ $dir ], 0, 1; }
	};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create empty configuration file
subtest create_empty_conf => sub {
	my $rc = open my $fh, '>:utf8', $conf;
	my $error = $! unless $rc;

	ok( $rc, "Opened empty $conf" );
	diag( "Error creating $conf! $!" ) unless $rc;
	close $fh;

	ok( -e $conf, "$conf exists" );
	END { unlink $conf }
	};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Clean up

