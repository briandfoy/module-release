#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';

my $class = 'Module::Release';

use_ok( $class );

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

my @subs = qw( 
	get_web_user_agent setup_web_user_agent web_user_agent_class 
	);

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );
can_ok( $class, @subs );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# check the user agent name
ok( defined $release->web_user_agent_name, "web user agent name is defined" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# check the user agent class
ok( defined $release->web_user_agent_class, "web user agent class is defined" );

my $loaded_name = loaded_name( $release->web_user_agent_class );

ok( ! exists $INC{ $loaded_name }, "web user agent class is not yet loaded" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# get web user agent
my $ua = $release->get_web_user_agent;
isa_ok( $ua, $release->web_user_agent_class );
ok( exists $INC{ $loaded_name }, "web user agent class is now loaded" );


sub loaded_name { File::Spec->catfile( split /::/, shift ) . ".pm" }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a bad user agent class name
BEGIN {
package Module::Release::MySubclass;
our @ISA = qw( Module::Release );

sub web_user_agent_class { "Foo::Bar::Quuz::NotThere" }
}

{
my $class = 'Module::Release::MySubclass';
my $release = $class->new;
isa_ok( $release, $class );
can_ok( $class, @subs );

is( $release->web_user_agent_class, 'Foo::Bar::Quuz::NotThere', 
	'Fake class name is right' 
	);
	
my $rc = eval { $release->setup_web_user_agent };
my $at = $@;
like( $at, qr/Could not load/, "Could not load fake class (good)" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


