#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';
my $file  = ".releaserc";

use_ok( $class );
can_ok( $class, 'new' );

my $old_dir = cwd();

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create object with no parameters
{
my $release = $class->new( quiet => 1 );
isa_ok( $release, $class );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a good release subclass
{
my $mock_class = 'Mock::Release::Good';

eval <<"MOCK";
	package $mock_class; 
	our \@ISA = qw( $class ); 
	sub new { return bless {}, \$_[0] }
MOCK

can_ok( $mock_class, 'new' );

{
ok( 
	open( my($fh), ">", $file ),
	"Opened $file for writing"
  );

print $fh "release_subclass $mock_class\n";
close $fh;
}

{
my $release = $class->new( quiet => 1 );
isa_ok( $release, $mock_class );
isa_ok( $release, $class );
}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a release subclass that doesn't return an object
{
my $mock_class = 'Mock::Release::NoObject';

eval <<"MOCK";
	package $mock_class;
	our \@ISA = qw( $class ); 
	sub new { return '' }
MOCK

can_ok( $mock_class, 'new' );

{
ok( 
	open( my($fh), ">", $file ),
	"Opened $file for writing"
  );

print $fh "release_subclass $mock_class\n";
close $fh;
}

{
my $release = eval { $class->new( quiet => 1 ); 1 };
my $at = $@;

like( $@, qr/Could not create object/, "Subclass that doesn't return object croaks" );
ok( ! defined $release, "Dies when release_subclass is $class" );
}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a release subclass that doesn't have a new() method
# This means it can't inherit from anything with new()!
{
my $mock_class = 'Mock::Release::NoNew';

eval <<"MOCK";
	package $mock_class;
MOCK

ok( ! $mock_class->can( 'new' ), "Mock class $mock_class can't new() (good)" );

{
ok( 
	open( my($fh), ">", $file ),
	"Opened $file for writing"
  );

print $fh "release_subclass $mock_class\n";
close $fh;
}

{
my $release = eval { $class->new; 1 };
my $at = $@;

like( $@, qr/\Qdoes not have a new()/, "Subclass that doesn't return object croaks" );
ok( ! defined $release, "Dies when release_subclass doesn't have new()" );
}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a release subclass that's Module::Release (should fail)
{
ok( 
	open( my($fh), ">", $file ),
	"Opened $file for writing"
  );

print $fh "release_subclass $class\n";
close $fh;
}

{
my $release = eval { $class->new; 1 };
my $at = $@;

like( $@, qr/same class/, "Using the same class as a subclass croaks" );
ok( ! defined $release, "Dies when release_subclass is $class" );
}

