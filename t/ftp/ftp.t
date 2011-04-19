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

my @subs = qw( 
	ftp_upload ftp_passive_on ftp_passive_off ftp_passive 
	ftp_class_name get_ftp_object 
	default_ftp_hostname default_ftp_user 
	default_ftp_password default_ftp_upload_dir
	);
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
foreach my $sub ( @subs )
	{
	ok( ! $release->can( $sub ), "$sub not loaded yet" );
	}

ok( 
	$release->load_mixin( 'Module::Release::FTP' ), 
	"Loaded Kwalitee mixin" 
	);

can_ok( $release, @subs );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test constant subs
foreach my $sub ( 'ftp_class_name', grep /default/, @subs )
	{
	ok( $release->$sub(), "$sub returns something that is true" );
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Test passive setting
$release->ftp_passive_off;
ok( ! $release->ftp_passive, "Passive FTP turned off" );

$release->ftp_passive_on;
ok( $release->ftp_passive, "Passive FTP turned on" );

$release->ftp_passive_off;
ok( ! $release->ftp_passive, "Passive FTP turned off again" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Mock the FTP object with a missing class
{
my $mock_class = 'Module::Release::MockFTPMissing';
my $loaded_name = loaded_name( $mock_class );

no warnings 'redefine';
no warnings 'once';
*Module::Release::ftp_class_name = sub { $mock_class };
is( $release->ftp_class_name, $mock_class, 'Mock FTP class is right' );

{
my $test_site = 'ftp.example.com';
my $ftp = eval { $release->get_ftp_object( $test_site ) };
my $at = $@;
like( $at, qr/Couldn't/, "With missing FTP class, get_ftp_object dies" );
}

{
my $rc = eval { $release->ftp_upload };
my $at = $@;
like( $at, qr/Couldn't/, "With undef FTP class, ftp_upload dies" );
}

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Mock the FTP object with a loadable class where new returns nothing
BEGIN {
package Module::Release::MockFTPUndef;

sub new { () }
}

{
my $mock_class = 'Module::Release::MockFTPUndef';
my $loaded_name = loaded_name( $mock_class );
local $INC{$loaded_name} = $0;

no warnings 'redefine';
no warnings 'once';
*Module::Release::ftp_class_name = sub { $mock_class };
is( $release->ftp_class_name, $mock_class, 'Mock FTP class is right' );

{
my $test_site = 'ftp.example.com';
my $ftp = eval { $release->get_ftp_object( $test_site ) };
my $at = $@;
like( $at, qr/Couldn't open/, "With undef FTP class, get_ftp_object dies" );
}

{
my $ftp = eval { $release->ftp_upload };
my $at = $@;
like( $at, qr/Couldn't open/, "With undef FTP class, ftp_upload dies" );
}

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Mock the FTP object with a loadable class
BEGIN {
package Module::Release::MockFTP;

sub new 
	{
	my $class = shift;
	
	unshift @_, "Site";
	
	bless { @_ }, $class 
	}
	
sub login   { 1 }
sub cwd     { 1 }
sub binary  { 1 }
sub put     { 'Foo.tgz' }
sub size    { 4 }
sub message { "Permission denied" }
sub quit    { 1 }
}

{
my $mock_class = 'Module::Release::MockFTP';
my $loaded_name = loaded_name( $mock_class );
local $INC{$loaded_name} = $0;

no warnings 'redefine';
no warnings 'once';
local *Module::Release::ftp_class_name = sub { $mock_class };
is( $release->ftp_class_name, $mock_class, 'Mock FTP class is right' );

my $test_site = 'ftp.example.com';
my $ftp = $release->get_ftp_object( $test_site );
isa_ok( $ftp, $mock_class );

# this is peeking. Don't do that in real code!
is( $ftp->{Passive}, $release->ftp_passive, "Passive FTP setting is right" );
is( $ftp->{Site},    $test_site,            "Test site setting is right" );

# create the files we'll need
$release->local_file(  Module::Release::MockFTP->put );
$release->remote_file( Module::Release::MockFTP->put );

open my($fh), ">", Module::Release::MockFTP->put;
print $fh 'a' x Module::Release::MockFTP->size;
close $fh;

is( -s Module::Release::MockFTP->put, Module::Release::MockFTP->size,
	"test distro has the right size" );
	
# now test it to the end with passive on
$release->ftp_passive_on;
stdout_like
	{ $release->ftp_upload }
	qr/uploaded/,
	"ftp_upload gets to the end";

# now test it to the end with passive off
$release->ftp_passive_off;
stdout_like
	{ $release->ftp_upload }
	qr/uploaded/,
	"ftp_upload gets to the end";
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Everything else uses MockFTP from here on out
my $mock_class = 'Module::Release::MockFTP';
my $loaded_name = loaded_name( $mock_class );
local $INC{$loaded_name} = $0;

{
no warnings 'redefine';
*Module::Release::ftp_class_name = sub { $mock_class };
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with the default hostname
{
my $site = $release->default_ftp_hostname;

stdout_like
	{ $release->ftp_upload }
	qr/logging in to $site/i,
	"Gets the right hostname when it gets no arguments";
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it with a specified hostname
{
my $site = 'ftp.example.com';

stdout_like
	{ $release->ftp_upload( hostname => $site ) }
	qr/logging in to $site/i,
	"Gets the right hostname when it gets an arguments";
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it when login fails
{
no warnings 'redefine';
no warnings 'once';
local *Module::Release::MockFTP::login = sub { 0 };

{
my $ftp = eval { $release->ftp_upload };
my $at = $@;
like( $at, qr/Couldn't log in/, "When login fails, ftp_upload dies" );
}

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it when cwd fails
{
no warnings 'redefine';
no warnings 'once';
local *Module::Release::MockFTP::cwd = sub { 0 };

{
my $ftp = eval { $release->ftp_upload };
my $at = $@;
like( $at, qr/Couldn't chdir/, "When cwd fails, ftp_upload dies" );
}

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it when put fails
{
no warnings 'redefine';
no warnings 'once';
local *Module::Release::MockFTP::put = sub { 0 };

{
my $ftp = eval { $release->ftp_upload };
my $at = $@;
like( $at, qr/PUT failed/, "When put fails, ftp_upload dies" );
}

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Try it when size returns the wrong size
{
no warnings 'redefine';
no warnings 'once';
local *Module::Release::MockFTP::size = sub { -3 };

stdout_like
	{ $release->ftp_upload }
	qr/but local file is/,
	"When size returns wrong number, ftp_upload warns";

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub loaded_name { File::Spec->catfile( split /::/, shift ) . ".pm" }
