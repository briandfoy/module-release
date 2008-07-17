use strict;
use warnings;

use Cwd;
use File::Spec;

my $old_dir = cwd;
my $conf    = ".releaserc";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Setup a test directory
{
my $dir = File::Spec->catfile( qw(t test_dir) );
mkdir $dir, 0755 unless -d $dir;
ok( -d $dir, "Test directory is there" );

ok( chdir( $dir ), "Changed into $dir" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create empty configuration file
{

ok( 
	open( my($fh), ">", $conf ),
	"Opened empty $conf"
  );
close $fh;

ok( -e $conf, "$conf exists" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Clean up
END {
	unlink $conf;
	chdir $old_dir;
	}

