#!/usr/bin/perl
use strict;
use warnings;

use Test::More 1.0 'no_plan';
use Test::Output;

use Cwd;

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'new' );

BEGIN {
	use File::Spec::Functions qw(rel2abs catfile);
	my $file = rel2abs( catfile( qw( t lib setup_common.pl) ) );
	require $file;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check that we should upload to PAUSE
# First, set both CPAN user and password
{
$release->config->set( 'cpan_user', 'Buster' );
$release->config->set( 'cpan_pass', 'Foo'    );
ok( $release->config->cpan_user, "cpan_user is true" );
ok( $release->config->cpan_pass, "cpan_pass is true" );

ok( $release->should_upload_to_pause, "Should upload to PAUSE" );
}

# Next, unset both CPAN user and password
{
$release->config->set( 'cpan_user', undef );
$release->config->set( 'cpan_pass', undef );
ok( ! defined $release->config->cpan_user, "cpan_user is undefined" );
ok( ! defined $release->config->cpan_pass, "cpan_pass is undefined" );

ok( ! $release->should_upload_to_pause, "Shouldn't upload to PAUSE when neither user nor password set" );
}

# Then, set just CPAN password
{
$release->config->set( 'cpan_user', undef );
$release->config->set( 'cpan_pass', 'Foo' );
ok( ! defined $release->config->cpan_user, "cpan_user is undefined" );
ok(           $release->config->cpan_pass, "cpan_pass is true" );

ok( ! $release->should_upload_to_pause, "Shouldn't upload to PAUSE when user not set" );
}


# Finally, set CPAN user but unset CPAN password
{
$release->config->set( 'cpan_user', 'Buster' );
$release->config->set( 'cpan_pass', undef );
ok(           $release->config->cpan_user, "cpan_user is true" );
ok( ! defined $release->config->cpan_pass, "cpan_pass is undefined" );

ok( ! $release->should_upload_to_pause, "Shouldn't upload to PAUSE when password not set" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test the content for the claim request. It needs to know the remote
# file name and the PAUSE user. Mock the config data
BEGIN {
package Module::Release::MockConfig;
our @ISA = qw( Module::Release );

sub config    { Module::Release::NullClass->new }

package Module::Release::NullClass;
sub new { bless {}, $_[0] }
sub AUTOLOAD  { 1 }
sub perls     { () }
sub cpan_user { 'LOCAL' }
sub cpan_pass { 'BUSTER' }
}
