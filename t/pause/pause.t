#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;

use Cwd;

my $class = 'Module::Release';

use_ok( $class );
can_ok( $class, 'new' );

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

my @subs = qw( 
	pause_claim should_upload_to_pause pause_ftp_site 
	set_pause_ftp_site pause_claim_base_url
	pause_claim_content pause_claim_content_type
	);

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check that the subs load at the right time
foreach my $sub ( @subs )
	{
	ok( ! $release->can( $sub ), "$sub not loaded yet" );
	}
	
ok( 
	$release->load_mixin( 'Module::Release::PAUSE' ), 
	"Loaded PAUSE mixin" 
	);

can_ok( $release, @subs );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# A few things just need to return a string
{
my @constant_subs = qw( pause_claim_content_type pause_claim_base_url );

foreach my $sub ( @constant_subs )
	{
	ok( defined $release->$sub(), "method $sub returns something that's defined" );
	}
	
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set and unset the pause_ftp_site for things that should fail
my $site = $release->pause_ftp_site;
ok( $site, "pause_ftp_site returns something true [$site]" );

stderr_like
	{ $release->set_pause_ftp_site }
	qr/does not look like a hostname/,
	"set_pause_ftp_site fails for no argument";

is( $release->pause_ftp_site, $site, 
	"pause_ftp_site stays the same after set failure" );

stderr_like
	{ $release->set_pause_ftp_site( '' ) }
	qr/does not look like a hostname/,
	"set_pause_ftp_site fails for empty string";

is( $release->pause_ftp_site, $site, 
	"pause_ftp_site stays the same after set failure" );

stderr_like
	{ $release->set_pause_ftp_site( 'foo' ) }
	qr/does not look like a hostname/,
	"set_pause_ftp_site fails for 'foo'";

is( $release->pause_ftp_site, $site, 
	"pause_ftp_site stays the same after set failure" );


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set and unset the pause_ftp_site for things that should work

foreach my $site ( qw( foo.bar.com pause.perl.org brian.buster.org ) )
	{
	ok( $release->set_pause_ftp_site( $site ), "Setting $site works" );
	is( $release->pause_ftp_site, $site, "pause_ftp_site returns $site" );
	}

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
# Get the FTP site, either by configuration or default
# First, the default
{
my $site = $release->pause_ftp_site;
ok( defined $site, "pause_ftp_site returns something that is defined" );
ok( length $site, "pause_ftp_site returns something that is long" );
like( $site, qr/[a-z0-9-]+(\.[a-z0-9-]+)+/, 
	"pause_ftp_site returns something that looks like a host name" );
}

# Next, by setting the site first
{
$release->set_pause_ftp_site( 'pause.perl.org' );

my $site = $release->pause_ftp_site;
ok( defined $site, "pause_ftp_site returns something that is defined" );
ok( length $site, "pause_ftp_site returns something that is long" );
like( $site, qr/[a-z0-9-]+(\.[a-z0-9-]+)+/, 
	"pause_ftp_site returns something that looks like a host name" );
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

{
my $release = Module::Release::MockConfig->new;
isa_ok( $release, 'Module::Release::MockConfig' );

$release->remote_file( 'foo.tgz' );
is( $release->remote_file, 'foo.tgz', "Remote file is what I want it to be" );

is( $release->config->cpan_user, 'LOCAL', "CPAN user is what I want it to be" );

my $content = $release->pause_claim_content;
like( $content, qr/LOCAL/, "Has the right PAUSE ID" );
like( $content, qr/foo\.tgz/, "Has the right distro name" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test the reponse to PAUSE claim. Mock the user agent and 
# HTTP::Response. 
BEGIN {
no warnings 'redefine';

package Module::Release::MockClaim;
our @ISA = qw( Module::Release );
sub config    { Module::Release::NullClass->new }
sub web_user_agent_class { 'Module::Release::MockUA' }

package Module::Release::MockUA;
sub new { bless {}, $_[0] }
sub request { Module::Release::NullClass->new }
sub cookie_jar { 1 }
$INC{'Module/Release/MockUA.pm'} = $0;

package Module::Release::NullClass;
sub as_string { 'Query succeeded' }

}

# First, test it when we should not upload because the CPAN user
# isn't set, etc:
{
no warnings 'redefine';
local *Module::Release::NullClass::cpan_user = sub { () };

my $release = Module::Release::MockClaim->new;
isa_ok( $release, 'Module::Release::MockClaim' );

ok( ! $release->should_upload_to_pause, "Shouldn't upload to PAUSE when cpan_user not set" );

ok( ! defined $release->pause_claim, "pause_claim returns nothing when it shouldn't upload" );
}


# Now, test that it works when it sees 'Query succeeded'
{
my $release = Module::Release::MockClaim->new;
isa_ok( $release, 'Module::Release::MockClaim' );

ok( $release->should_upload_to_pause, "Should upload to PAUSE" );

like( Module::Release::NullClass->as_string, qr/Query succeeded/, "Mock as_string looks good" );

stdout_like
	{ $release->pause_claim }
	qr/successful/,
	"pause_claim succeeds when response says 'succeeded'";
}

# Then, test that it fails when it doesn't see 'Query succeeded'
{
no warnings 'redefine';
local *Module::Release::NullClass::as_string = sub { 'foo' };

my $release = Module::Release::MockClaim->new;
isa_ok( $release, 'Module::Release::MockClaim' );

ok( $release->should_upload_to_pause, "Should upload to PAUSE" );

unlike( Module::Release::NullClass->as_string, qr/succeeded/, "Mock as_string looks good" );

stdout_like
	{ $release->pause_claim }
	qr/failed/,
	"pause_claim fails when response does not say 'succeeded'";
}