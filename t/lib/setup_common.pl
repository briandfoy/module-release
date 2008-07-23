use strict;
use warnings;

use Cwd;
use File::Spec;
use File::Path;

my $old_dir = cwd;
my $conf    = ".releaserc";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Setup a test directory
{
my $dir = File::Spec->catfile( qw(t test_dir) );
mkdir $dir, 0755 unless -d $dir;
ok( -d $dir, "Test directory is there" );

ok( chdir( $dir ), "Changed into $dir" );
END { chdir $old_dir; rmtree [ $dir ], 0, 1; }
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

