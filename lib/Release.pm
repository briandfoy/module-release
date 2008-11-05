# $Id$
package Module::Release;

=head1 NAME

Module::Release - Automate software releases

=head1 SYNOPSIS

	use Module::Release;

	my $release = Module::Release->new( %params );

	# call methods to automate your release process
	$release->check_cvs;
	...

=cut

use strict;

use warnings;
no warnings;
use vars qw($VERSION);

$VERSION = '2.00_06';

use Carp;
use File::Spec;
use Scalar::Util qw(blessed);

my %Loaded_mixins = ( );

=head1 DESCRIPTION

C<Module::Release> automates your software release process. It started as
a script that automated my release process, so it has bits to
talk to PAUSE (CPAN) and SourceForge, and to use C<Makefile.PL> and
C<CVS>. Other people have extended this in other modules under the same
namespace so you can use C<Module::Build>, C<svn>, and many other things.

The methods represent a step in the release process. Some of them check a
condition (e.g. all tests pass) and die if that doesn't work.
C<Module::Release> doesn't let you continue if something is wrong. Once
you have checked everything, use the upload features to send your files
to the right places.

The included C<release> script is a good starting place. Don't be afraid to
edit it for your own purposes.

=head2 Configuration

C<Module::Release> looks at several sources for configuration information.

=head3 Perl setup

C<Module::Release> looks at C<Config> to get the values it needs for
certain operations.

=over 4

=item make

The name of the program to run for the C<make> steps

=back

=head3 Environment variables

=over 4

=item PERL

Use this value as the perl interpreter, otherwise use the value in C<$^X>.

=item RELEASE_DEBUG

Do you want debugging output? Set this to a true value

=item SF_PASS

Your SourceForge password. If you don't set this and you want to
upload to SourceForge, you should be prompted for it. Failing that,
the module tries to upload anonymously but cannot claim the file for
you.

=item CPAN_PASS

Your CPAN password. If you don't set this and you want to upload to
PAUSE, you should be prompted for it. Failing that, the module tries
to upload anonymously but cannot claim the file for you.

=back

=head3 C<.releaserc>

C<Module::Release> looks for either C<.releaserc> or C<releaserc> in
the current working directory. It reads that with
C<ConfigReader::Simple> to get these values:

=over 4

=item release_subclass (DEPRECATED)

The subclass of C<Module::Release> that you want to use. This allows
you to specify the subclass via a F<.releaserc> file; otherwise you
wouldn't be able to use the C<release> script because the
C<Module::Release> class name is hard-coded there.

=item makefile_PL

The name of the file to run as F<Makefile.PL>.  The default is
C<"Makefile.PL">, but you can set it to C<"Build.PL"> to use a
C<Module::Build>-based system.

=item makefile

The name of the file created by C<makefile_PL> above.  The default is
C<"Makefile">, but you can set it to C<"Build"> for
C<Module::Build>-based systems.

=item cpan_user

Your PAUSE user id.

=item sf_user

Your SourceForge account (i.e. login) name.

=item passive_ftp

Set this to a true value to enable passive FTP.

=back

=head2 Methods

If you don't like what any of these methods do, override them in a subclass.

=over 4

=item new()

Create the bare bones C<Module::Release> object so you can read the
configuration file. If you can read the configuration file, check for
the C<release_subclass> directive. If the C<release_subclass> is there,
C<new> calls the subclass's C<new> and returns the result. Otehrwise,
this C<new> calls C<init> to set up the object.

If you make a subclass, you're responsible for everything, including
reading the configuration and adding it to your object.

=cut

sub new
	{
	my( $class, %params ) = @_;

	my $self = bless {}, $class;

	# NOTE: I have to read the configuration to see if I should
	# call the subclass, but I haven't called init yet.
	# Don't set up anything in _read_configuration!
	my $config = $self->_read_configuration;

	if( $config->release_subclass )
		{
		$self->_die( "release_subclass is the same class! Don't do that!" )
			if $config->release_subclass eq $class;
		my $subclass_self = $self->_handle_subclass(
			$config->release_subclass, %params );

		return $subclass_self;
		}

	$self->init( $config, %params );

	return $self;
	}


=item init()

Set up the C<Module::Release> object.

=cut

sub init
	{	
	my( $self, $config, %params ) = @_;

	$self->_set_defaults( %params );

	# $config comes in as a parameter
	$self->_process_configuration( $config );

	# defer $self->_set_up_web_client;

	1;
	}

sub _select_config_file_name { -e ".releaserc" ? ".releaserc" : "releaserc" }

sub _set_defaults
	{
	require Config;
	require IO::Null;

	my( $self, %params ) = @_;

	my $defaults = {
			'Makefile.PL' => 'Makefile.PL',
			'Makefile'    => 'Makefile',
			make          => $Config::Config{make},
			manifest      => 'MANIFEST',
			debug         => $ENV{RELEASE_DEBUG} || 0,
			local_file    => undef,
			remote_file   => undef,
			output_fh     => *STDOUT{IO},
			debug_fh      => *STDERR{IO},
			null_fh       => IO::Null->new(),
			quiet         => 0,

			%params,
		   };

	foreach my $key ( keys %$defaults )
		{
		$self->{$key} = $defaults->{$key};
		}

	$self->set_perl( $^X );
	$self->add_a_perl( $^X );

	1;
	}

sub _read_configuration
	{
	require ConfigReader::Simple;

	# NOTE: I have to read the configuration to see if I should
	# call the subclass, but I haven't called init yet.
	# Don't set up anything in _read_configuration!
	my $self = shift;

	my $conf_file = $self->_select_config_file_name;

	# Read the configuration
	$self->_die( "Could not find conf file $conf_file\n" )
		unless -e $conf_file;
	my $config = $self->{config} = ConfigReader::Simple->new( $conf_file );
	$self->_die( "Could not get configuration data\n" ) unless ref $config;

	$config;
	}

sub _process_configuration
	{
	my $self = shift;

	# Figure out options
	$self->{cpan} = $self->config->cpan_user eq '<none>' ? 0 : 1;

	$self->{passive_ftp} =
		($self->config->passive_ftp && $self->config->passive_ftp =~ /^y(es)?/) ? 1 : 0;

	my @required = qw(  );

	my $ok = 1;
	for( @required )
		{
		unless( length $self->config->$_() )
			{
			$ok = 0;
			$self->_warn( "Missing configuration data: $_; Aborting!\n" );
			}
		}
	$self->_die( "Missing configuration data" ) unless $ok;


	if( $self->config->perls )
		{
		my @paths = split /:/, $self->config->perls;

		foreach my $path ( @paths )
			{
			$self->add_a_perl( $path );
			}
		}
	}

sub _handle_subclass
	{
	my( $self, $subclass, %params ) = @_;


	# This is a bit tricky. We have to be able to use the subclass, but
	# we don't know if it is defined or not. It might be in a .pm file
	# we haven't loaded, it might be in another file the user already
	# loaded, or the user might have defined it inline inside
	# the script. We'll try loading it if it fails can()
	unless( eval { $subclass->can( 'new' ) } )
		{
		# I don't care if this fails because loading the file
		# might not be the problem
		eval { require File::Spec->catfile( split '::', $subclass ) . '.pm' };
		}

	# If it's not defined by now, we're screwed and we give up
	$self->_die( "$subclass does not have a new()!" )
		unless eval { $subclass->can( 'new' ) };

	my $new_self = eval { $subclass->new( %params ) };
	my $at = $@;

	return $new_self if blessed $new_self;

	$self->_die( "Could not create object with $subclass: $at!" );
	}


=item load_mixin( MODULE )

EXPERIMENTAL!!

Load MODULE through require (so no importing), without caring what it does.
My intent is that MODULE adds methods to the C<Module::Release> namespace
so a release object can see it. This should probably be some sort of
delegation.

Added in 1.21

=cut

sub load_mixin
	{
	my( $self, $module ) = @_;

	return 1 if $self->mixin_loaded( $module );

	no warnings 'redefine';
	
	eval "use $module";

	$self->_die( "Could not load [$module]! $@" ) if $@;

	++$Loaded_mixins{ $module };
	}

=item loaded_mixins

Returns a list of the loaded mixins

Added in 1.21

=cut

sub loaded_mixins { keys %Loaded_mixins }

=item mixin_loaded( MODULE )

Returns true if the mixin class is loaded

=cut

sub mixin_loaded { exists $Loaded_mixins{ $_[1] } }

=back

=head2 Methods for configuation and settings

=over 4

=item config

Get the configuration object. By default this is a C<ConfigReader::Simple>
object;

=cut

sub config { $_[0]->{config} }

=item get_web_user_agent

Get a web user agent that follows the LWP::UserAgent API. The first time
you call this it also sets up the web client by calling C<setup_web_client>.

=cut

sub get_web_user_agent { $_[0]->{web_user_agent} || $_[0]->setup_web_user_agent }

=item setup_web_user_agent( ARGS )

Create a web user agent and store it in the object. Get a reference to it
by saving the result or calling C<get_web_user_agent>. If you call this
method again, it replaces the internal web user agent (and anything you've
done to it since you first set it up). It passes any arguments to the 
constructor of the user agent class.

It calls C<web_user_agent_name> to set the initial agent name, and sets
up an empty, in-memory cookie jar.

=cut

sub setup_web_user_agent 
	{
	my $self = shift;
	
	my $class = $self->web_user_agent_class;
	my $rc = eval { eval "require $class" };
	unless( $rc ) { $self->_die( "Could not load $class: $@" ) };
	
	my $ua = $self->web_user_agent_class->new( 
		agent => $self->web_user_agent_name,
		@_ 
		);

	$ua->cookie_jar( {} );

	$self->{web_user_agent} = $ua;
	}

=item web_user_agent_class

The package name to use to build a web user agent object.

=cut

sub web_user_agent_class { 'LWP::UserAgent' }

=item web_user_agent_name

The user agent name to use with web requests. Let's just call that 
C<Mozilla> for now.

=cut

sub web_user_agent_name { 'Mozilla' }

=item local_file( FILENAME )

Returns or sets the name of the local distribution file. You can use
the literal argument C<undef> to clear the value.

=cut

sub local_file
	{
	$_[0]->{local_file} = $_[1] if @_ > 1;

	$_[0]->{local_file};
	}

=item remote_file

Returns the name of the file on the remote side. You can use the
literal argument C<undef> to clear the value.

=cut

sub remote_file
	{
	$_[0]->{remote_file} = $_[1] if @_ > 1;

	$_[0]->{remote_file};
	}

=back

=head2 Methods for multiple perl testing

=over 4

=item set_perl

Set the current path for the perl binary that C<Module::Release> should
use for general tasks. This is not related to the list of perls used to
test multiple binaries unless you use one of those binaries to set a new
value.

If PATH looks like a perl binary, C<set_perl> uses it as the new setting
for perl and returns the previous value.

Added in 1.21.

=cut

sub set_perl
	{
	my( $self, $path ) = @_;

	unless( my $version = $self->_looks_like_perl( $path ) )
		{
		$self->_die( "Does not look like a perl [$path]" );
		}

	my $old_perl = $self->get_perl;

	$self->{perl} = $path;

	$old_perl;
	}

sub _looks_like_perl
	{
	my( $self, $path ) = @_;


	my $version = `$path -e 'print \$\]' 2>&1`;

	$version =~ m/^\d+\.[\d_]+$/ ? $version : ();
	}

=item get_perl

Returns the current path for the perl binary that C<Module::Release> should
use for general tasks. This is not related to the list of perls used to
test multiple binaries.

Added in 1.21.

=cut

sub get_perl { $_[0]->{perl} }

=item perls

Return the list of perl binaries Module::Release will use to test the
distribution.

Added in 1.21.

=cut

sub perls
	{
	my $self = shift;

	return keys %{ $self->{perls} };
	}

=item add_a_perl( PATH )

Add a perl binary to the list of perls to use for testing. If PATH
is not executable or cannot run C<print $]>, this method returns
nothing and does not add PATH. Otherwise, it returns true. If the
same path was already in the list, it returns true but does not
create a duplicate.

Added in 1.21.

=cut

sub add_a_perl
	{
	my( $self, $path ) = @_;

	return 1 if exists $self->{perls}{$path};

	unless( -x $path )
		{
		$self->_warn( "$path is not executable" );
		return;
		}

	my $version = $self->_looks_like_perl( $path );

	unless( $version )
		{
		$self->_warn( "$path does not appear to be perl!" );
		return;
		}

	return $self->{perls}{$path} = $version;
	}

=item remove_a_perl( PATH )

Delete PATH from the list of perls used for testing

Added in 1.21.

=cut

sub remove_a_perl
	{
	my( $self, $path ) = @_;

	return delete $self->{perls}{$path}
	}

=item reset_perls

Reset the list of perl interpreters to just the one running C<release>.

Added in 1.21.

=cut

sub reset_perls
	{
	my $self = shift;

	$self->{perls} = {};

	return $self->{perls}{$^X} = $];
	}


=item output_fh

If quiet is off, return the value of output_fh. If output_fh is not
set, return STDOUT. If quiet is on, return the value of null_fh.

=cut

sub output_fh  {
	$_[0]->quiet
		?
	$_[0]->null_fh
		:
	( $_[0]->{output_fh} || *STDOUT{IO} )
	}

=item null_fh

Return the null filehandle. So far that's something set up in C<new> and I
haven't provided a way to set it. Any subclass can make their C<null_fh>
return whatever they like.

=cut

sub null_fh  { $_[0]->{null_fh} }

=item quiet

Get the value of queit mode (true or false).

=item turn_quiet_on

Turn on quiet mode

=item turn_quiet_off

Turn off quiet mode

=cut

sub turn_quiet_on  { $_[0]->{quiet} = 1 }
sub turn_quiet_off { $_[0]->{quiet} = 0 }

sub quiet          { $_[0]->{quiet} }

=item debug

Get the value of the debugging flag (true or false).

=item turn_debug_on

Turn on debugging

=item turn_debug_off

Turn off debugging

=item debug_fh

If debugging is on, return the value of debug_fh. If debug_fh is not
set, return STDERR. If debugging is off, return the value of null_fh.

=cut

sub turn_debug_on  { $_[0]->{debug} = 1 }
sub turn_debug_off { $_[0]->{debug} = 0 }

sub debug          { $_[0]->{debug} }

sub debug_fh  {
	$_[0]->debug
		?
	( $_[0]->{debug_fh} || *STDERR{IO} )
		:
	$_[0]->null_fh
	}

=back

=head2 Methods for building

=over 4

=item clean

Run `make realclean`

=cut

sub clean
	{
	my $self = shift;
	$self->_print( "Cleaning directory... " );

	unless( -e $self->{Makefile} )
		{
		$self->_print( " no $self->{Makefile}---skipping\n" );
		return;
		}

	$self->run( "$self->{make} realclean 2>&1" );

	$self->_print( "done\n" );
	}

=item distclean

Run `make distclean`

=cut

sub distclean
	{
	my $self = shift;
	$self->_print( "Cleaning directory... " );

	unless( -e $self->{Makefile} )
		{
		$self->_print( " no $self->{Makefile}---skipping\n" );
		return;
		}

	$self->run( "$self->{make} distclean 2>&1" );

	$self->_print( "done\n" );
	}


=item build_makefile()

Runs `perl Makefile.PL 2>&1`.

This step ensures that we start off fresh and pick up any changes in
C<Makefile.PL>.

=cut

sub build_makefile
	{
	my $self = shift;
	$self->_print( "Recreating make file... " );

	unless( -e $self->{'Makefile.PL'} )
		{
		$self->_print( " no $self->{'Makefile.PL'}---skipping\n" );
		return;
		}

	$self->run( "$self->{perl} $self->{'Makefile.PL'} 2>&1" );

	$self->_print( "done\n" );
	}

=item make()

Run a plain old `make`.

=cut

sub make
	{
	my $self = shift;
	$self->_print( "Running make... " );

	unless( -e $self->{'Makefile'} )
		{
		$self->_print( " no $self->{'Makefile'}---skipping\n" );
		return;
		}

	my $tests = $self->run( "$self->{make} 2>&1" );

	$self->_print( "done\n" );
	}

=item test()

Run `make test`. If any tests fail, it dies.

=cut

sub test
	{
	my $self = shift;
	$self->_print( "Checking make test... " );

	unless( -e $self->{'Makefile'} )
		{
		$self->_print( " no $self->{'Makefile'}---skipping\n" );
		return;
		}

	my $tests = $self->run( "$self->{make} test 2>&1" );

	$self->_die( "\nERROR: Tests failed!\n$tests\n\nAborting release\n" )
		    unless $tests =~ /All tests successful/;

	$self->_print( "all tests pass\n" );
	}

=item dist()

Run `make dist`. As a side effect determines the distribution
name if not set on the command line.

=cut

sub dist
	{
	my $self = shift;
	$self->_print( "Making dist... " );

	unless( -e $self->{'Makefile'} )
		{
		$self->_debug( "no Makefle, so skipping" );
		$self->_print( " no $self->{'Makefile'}---skipping\n" );
		return;
		}

	my $messages = $self->run( "$self->{make} dist 2>&1 < /dev/null" );
	$self->_debug( "messages are [$messages]" );

	# If the distro isn't already set, try to guess it
	unless( $self->local_file )
		{
		$self->_debug( ", guessing local distribution name" );
		my( $guess ) = $messages =~ /^\s*gzip.+?\b'?(\S+\.tar)'?\s*$/m;
		$self->_debug( "guessed [$guess]" );
		$self->local_file( $guess );

		$self->_die( "Couldn't guess distname from dist output\n" )
			unless $self->local_file;

		$self->local_file( $self->local_file() . '.gz' );
		$self->remote_file( $self->local_file );
		}

	# local_file should exist now
	$self->_die( "Local file '$self->{local_file}' does not exist\n" )
		unless -f $self->local_file;

	$self->_print( "done\n" );
	}

=item disttest

Run `make disttest`. If the tests fail, it dies.

=cut

sub disttest
	{
	my $self = shift;

	$self->_print( "Checking make disttest... " );

	unless( -e $self->{'Makefile'} )
		{
		$self->_print( " no $self->{'Makefile'}---skipping\n" );
		return;
		}

	my $tests = $self->run( "$self->{make} disttest 2>&1" );

	$self->_die( "\nERROR: Tests failed!\n$tests\n\nAborting release\n" )
		unless $tests =~ /All tests successful/;

	$self->_print( "all tests pass\n" );
	}

=item dist_test

This was the old name for the method, but was inconsistent with
other method names. It still works, but is deprecated and will
give a warning.

=cut

sub dist_test
	{
	$_[0]->_warn( "dist_test is deprecated. Use disttest instead." );

	goto &disttest;
	}

=item dist_version

Return the distribution version ( set in dist() )

=cut

sub dist_version
	{
	my $self = shift;

	$self->_die( "Can't get dist_version! It's not set (did you run dist first?)" )
		unless defined $self->remote_file;

	no warnings 'uninitialized';
	my( $major, $minor, $dev ) = $self->remote_file
		=~ /(\d+) \. (\d+)(_\d+)? (?:\. tar \. gz)? $/xg;

	$self->dist_version_format( $major, $minor, $dev );
	}

=item dist_version_format

Return the distribution version ( set in dist() )

# XXX make this configurable

=cut

sub dist_version_format
	{
	no warnings 'uninitialized';
	my $self = shift;
	my( $major, $minor, $dev ) = @_;

	sprintf "%d.%02d%s", $major, $minor, $dev;
	}

=item check_manifest

Run `make manifest` and report anything it finds. If it gives output,
die. You should check C<MANIFEST> to ensure it has the things it needs.
If files that shouldn't show up do, put them in MANIFEST.SKIP.

Since `make manifest` takes care of things for you, you might just have
to re-run your release script.

=cut

# _check_output_lines - for command output with one message per line.
# The message hash identifies the first part of the line and serves
# as a category for the message. If a line doesn't matter, don't put
# it's pattern in the message hash.
#
# Prints a summary of what it found. The message is the hash value
# for that output type.
#
# returns the number of interesting things it found, but that's it.
sub _check_output_lines
	{
	my $self = shift;
	my( $message_hash, $message ) = @_;

	my %state;
	foreach my $state ( keys %$message_hash )
		{
		$state{$state} = [ $message =~ /^\Q$state\E\s+(.+)/gm ];
		}

	my $rule = "-" x 50;
	my $count = 0;

	foreach my $key ( sort keys %state )
		{
		my $list = $state{$key};
		next unless @$list;

		$count += @$list;

		local $" = "\n\t";
		$self->_print( "\n\t$message_hash->{$key}\n\t$rule\n\t@$list\n" );
		}


	return $count;
	}

sub check_manifest
	{
	my $self = shift;

	$self->_print( "Checking state of MANIFEST... " );

	my $manifest = $self->run( "$self->{make} manifest 2>&1" );

	my %message    = (
		"Removed from MANIFEST:"  => 'These files were removed from MANIFEST',
		"Added to MANIFEST:"      => 'These files were added to MANIFEST',
		);

	my $count = $self->_check_output_lines( \%message, $manifest );

	$self->_die( "\nERROR: Manifest was not up-to-date ($count files).\n" )
		if $count;

	$self->_print( "MANIFEST up-to-date\n" );
	}

=item manifest_name

Return the name of the manifes file, probably F<MANIFEST>.

=item manifest

This is the old name for manifest_name. It still works but is
deprecated.

=cut

sub manifest_name { 'MANIFEST' }

sub manifest { 
	$_[0]->_warn( "manifest is deprecated. Use manifest_name" );
	&manifest_name 
	}

=item files_in_manifest

Return the filenames in the manifest file as a list.

=cut

sub files_in_manifest
	{
	my $self = shift;
	
	require ExtUtils::Manifest;
	
	# I want to use ExtUtils::Manifest so it automatically
	# follows the right MANIFEST rules, but I have to adapt
	# it's output to my output. Annoying, for sure.
	my $hash = do {
		local $SIG{'__WARN__'} = sub { 
			my $message = shift;
			if( $message =~ m/Debug: (.*)/ )
				{
				$self->_debug( $1 );
				}
			else
				{
				$self->_die( "files_in_manifest: could not open file\n" );
				}
			};
			
		ExtUtils::Manifest::maniread( $self->manifest_name );
		};
	
	sort keys %$hash;
	}

=item check_cvs

=item cvs_tag

=item make_cvs_tag

This is a placeholder method which should be implemented in a mixin
module. Try installing Module::Release::CVS, Module::Release::SVN,
or Module::Release::Git and then loading them in your script. The
default C<release> script does this for you by checking for the
special directories for those source systems.

Previous to version 1.24, these methods were implemented in this
module to support CVS. They are now in Module::Release::CVS as a
separate module.

=cut

sub check_cvs
	{
	$_[0]->_die( "check_cvs must be implemented in a mixin class" );
	}


sub cvs_tag
	{
	$_[0]->_die( "cvs_tag must be implemented in a mixin class" );
	}

sub make_cvs_tag
	{
	$_[0]->_die( "make_cvs_tag must be implemented in a mixin class" );
	}

=item touch( FILES )

Set the modification times of each file in FILES to the current time. It
tries to open the file for writing and immediately closing it, as well as
using utime. It checks that the access and modification times were
updated.

Returns the number of files which it successfully touched.

=cut

sub touch
	{
	my( $self, @files ) = @_;
	
	my $time = time;

	my $count = 0;
	foreach my $file ( @files )
		{
		unless( -f $file )
			{
			$self->_warn( "$file is not a plain file" );
			next;
			}

		open my( $fh ), ">>", $file
			or $self->_warn( "Could not open file [$file] for writing: $!" );
		close $file;

		utime( $time, $time, $file );

		# check that it actually worked
		unless( 2 == grep { $_ == $time } (stat $file)[8,9] )
			{
			$self->_warn( "$file did not set utimes." );
			next;
			}

		$count++;
		}

	$count;
	}

=item touch_all_in_manifest

Runs touch on all of the files in MANIFEST.

=cut

sub touch_all_in_manifest { $_[0]->touch( $_[0]->files_in_manifest ) }

=back

=head2 Methods for uploading

=over 4

=item check_for_passwords

Get passwords for CPAN.

=cut

sub check_for_passwords
	{
	if( my $pass = $_[0]->config->cpan_user && $_[0]->get_env_var( "CPAN_PASS" )  )
		{
		$_[0]->config->set( 'cpan_pass', $pass ); 
		}
		
	$_[0]->_debug( "CPAN pass is " . $_[0]->config->cpan_pass );
	}



=item get_readme()

Read and parse the F<README> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_readme
	{
	open my $fh, '<README' or return '';
	my $data = do {
		local $/;
		<$fh>;
		};

	return $data;
	}

=item get_changes()

Read and parse the F<Changes> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_changes
	{
	open my $fh, '<', 'Changes' or return '';

	my $data = <$fh>;  # get first line

	while( <$fh> )
		{
		last if /^\S/;
		$data .= $_;
		}

	return $data;
	}

=item run

Run a command in the shell.

=item run_error

Returns true if the command ran successfully, and false otherwise. Use
this function in any other method that calls run to figure out what to
do when a command doesn't work. You may want to handle that yourself.

=cut

sub _run_error_reset { $_[0]->{_run_error} = 0 }
sub _run_error_set   { $_[0]->{_run_error} = 1 }
sub run_error        { $_[0]->{_run_error}     }

sub run
	{
	my( $self, $command ) = @_;

	$self->_run_error_reset;

	$self->_debug( "$command\n" );
	$self->_die( "Didn't get a command!" ) unless defined $command;
	
	open my($fh), "$command |" or $self->_die( "Could not open command [$command]: $!" );
	$fh->autoflush;

	my $output = '';
	my $buffer = '';
	local $| = 1;

	my $readlen = $self->debug ? 1 : 256;

	while( read $fh, $buffer, $readlen )
		{
		$output .= $_;
		$self->_debug( $_, $buffer );
		$output .= $buffer;
		}

	$self->_debug( $self->_dashes, "\n" );

	unless( close $fh )
		{
		$self->_run_error_set;
		$self->_warn(  "Command [$command] didn't close cleanly: $?" );
		}

	return $output;
	}

=item get_env_var

Get an environment variable or prompt for it

=cut

sub get_env_var
	{
	my ($self, $field) = @_;

	# Check for an explicit argument passed
	return $self->{lc $field} if defined $self->{lc $field};

	my $pass = $ENV{$field};

	return $pass if defined( $pass ) && length( $pass );

	$self->_print( "$field is not set.  Enter it now: " );
	$pass = <>;
	chomp $pass;

	return $pass if defined( $pass ) && length( $pass );

	$self->_debug( "$field not supplied.  Aborting...\n" );
	}

=back

=head2 Methods for developers

=over

=item _print( LIST )

Send the LIST to whatever is in output_fh, or to STDOUT. If you set
output_fh to a null filehandle, output goes nowhere.

=cut

sub _print { print { $_[0]->output_fh } @_[1..$#_] }

=item _dashes()

Use this for a string representing a line in the output. Since it's a
method you can override it if you like.

=cut

sub _dashes { "-" x 73 }

=item _debug( LIST )

Send the LIST to whatever is in debug_fh, or to STDERR. If you aren't
debugging, debug_fh should return a null filehandle.

=cut

sub _debug { print { $_[0]->debug_fh } @_[1..$#_] }

=item _die( LIST )

=cut

sub _die { croak @_[1..$#_] }

=item _warn( LIST )

=cut

sub _warn { carp @_[1..$#_] unless $_[0]->quiet }

=back

=head1 TO DO

* What happened to my Changes munging?

=head1 CREDITS

Ken Williams turned my initial release(1) script into the present
module form.

Andy Lester handled the maintenance while I was on my Big Camping
Trip. He applied patches from many authors.

Andreas KE<ouml>nig suggested changes to make it work better with PAUSE.

Chris Nandor helped with figuring out the broken SourceForge stuff.

=head1 SOURCE AVAILABILITY

This source is in Github:

	git://github.com/briandfoy/module-release.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2008 brian d foy.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__
