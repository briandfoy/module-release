#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'ua', 'ua_class_name' );

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

ok( defined $release->ua_class_name, "UA class name is defined" );


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Call it the first time, should load the class
my $loaded_name = loaded_name( $release->ua_class_name );

#print STDERR "Loaded name is $loaded_name\n";

ok( ! exists $INC{ $loaded_name }, "UA class is not yet loaded" );

isa_ok( $release->ua, $release->ua_class_name );

ok( exists $INC{ $loaded_name }, "UA class is now loaded" );


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Call it the second time
isa_ok( $release->ua, $release->ua_class_name );



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub loaded_name { File::Spec->catfile( split /::/, shift ) . ".pm" }