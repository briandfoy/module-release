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
use vars qw( $VERSION );

$VERSION = '1.17_10';

use Carp;
use CGI qw(-oldstyle_urls);
use Config;
use ConfigReader::Simple;
use File::Spec;
use File::Temp;
use HTTP::Cookies;
use HTTP::Request;
use IO::Null;
use LWP::UserAgent;
use Net::FTP;

use constant DASHES => "-" x 73;

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

Use this value as the perl interpreter, otherwise use the value in C<$^X>

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

=item release_subclass

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

=item sf_group_id

The Group ID of your SourceForge project. This is a numeric ID given to
the project usually, and you can see it in the URLs when you browse
the SourceForge files area.

=item sf_package_id

The Package ID of your SourceForge package. This is a numeric ID given to
a particular file release, and you can see it in the URLs when you browse
the SourceForge files area.

=item sf_release_match

This is a regular expression. Given the file release name that
C<Module::Release> picks (e.g. "Foo-Bar-1.15.tgz"), you can run a
substitution on it. The replacement string is in C<sf_release_replace>.

=item sf_release_replace

This is a regular expression. Given the file release name that
C<Module::Release> picks (e.g. "Foo-Bar-1.15.tgz"), you can run a
substitution on it. The regex portion is in C<sf_release_match>.

=item sf_type_id 5002

The distribution type (e.g. "gzipped source") of the package, by numeric
ID that you have to look up on your own from the SourceForge form. The
default is 5002 (".gz source").

=item sf_processor_id

The processor type (e.g. Intel Pentium) of the package, by numeric
ID that you have to look up on your own from the SourceForge form.
The default is 8000 ("Any").

=back

=head2 Methods

If you don't like what any of these methods do, override them in a subclass.

=over 4

=item new()

Create a Module::Release object.  Any arguments passed are assumed to
be key-value pairs that override the default values.


=cut

sub new
	{
	my ($class, %params) = @_;

	my $conf = -e ".releaserc" ? ".releaserc" : "releaserc";

	my $self = {
			'Makefile.PL' => 'Makefile.PL',
			'Makefile'    => 'Makefile',
			make          => $Config{make},
			perl          => $ENV{PERL} || $^X,
			conf          => $conf,
			debug         => $ENV{RELEASE_DEBUG} || 0,
			'local'       => undef,
			remote        => undef,
			stdout_fh     => \*STDOUT,
			debug_fh      => \*STDERR,
			null_fh       => IO::Null->new(),
			%params,
		   };

	# Read the configuration
	$self->_die( "Could not find conf file $self->{conf}\n" )
		unless -e $self->{conf};
	my $config = $self->{config} = ConfigReader::Simple->new( $self->{conf} );
	$self->_die( "Could not get configuration data\n" ) unless ref $config;

	# See whether we should be using a subclass
	if( my $subclass = $config->release_subclass )
		{
		unless( eval { $subclass->can( 'new' ) } )
			{
			require File::Spec->catfile( split '::', $subclass ) . '.pm';
			}

		return $subclass->new(@_) unless $subclass eq $class;
		}
	bless $self, $class;

	# Figure out options
	$self->{cpan} = $config->cpan_user eq '<none>' ? 0 : 1;
	$self->{sf}   = $config->sf_user   eq '<none>' ? 0 : 1;
	$self->{sf}   = defined $config->sf_user ? 1 : 0;

	$self->{passive_ftp} =
		($config->passive_ftp && $config->passive_ftp =~ /^y(es)?/) ? 1 : 0;

	my @required = qw( cpan_user );
	push( @required, qw( sf_user sf_group_id sf_package_id ) ) if $self->{sf};

	my $ok = 1;
	for( @required )
		{
		unless( length $config->$_() )
			{
			$ok = 0;
			$self->_print( "Missing configuration data: $_; Aborting!\n" );
			}
		}
	die "Missing configuration data" unless $ok;

	if( !$self->{cpan} && !$self->{sf} )
		{
		$self->_die( "Must upload to the CPAN or SourceForge.net; Aborting!\n" );
		}
	elsif( !$self->{cpan} )
		{
		$self->_print( "Uploading to SourceForge.net only\n" );
		}
	elsif( !$self->{sf} )
		{
		$self->_print( "Uploading to the CPAN only\n" );
		}


	# Set up the browser
	$self->{ua}      = LWP::UserAgent->new( agent => 'Mozilla/4.5' );

	my $fh = File::Temp->new( UNLINK => 1 );
	
	$self->{cookie_fh} = $fh;  # to keep it around until we're done
	$self->{cookies} = HTTP::Cookies->new(
					    file           => $fh->filename,
					    hide_cookie2   => 1,
					    autosave       => 1,
					    );
	$self->{cookies}->clear;

	return $self;
	}

=item config

Get the configuration object. By default this is a C<ConfigReader::Simple>
object;

=cut

sub config { $_[0]->{config} }

=item output_fh

Return the output filehandle, or the null filehandle if we're running in
quiet mode. What's quiet mode? I don't know yet. It's a future feature.
It's STDOUT or nothing 

=cut

sub output_fh  { $_[0]->_quiet ? $_[0]->null_fh : $_[0]->output_fh }

sub _quiet  { 0 }

=item debug

Get the value of the debugging flag.

=item debug_on

Turn on debugging

=item debug_off

Turn off debugging

=item debug_fh

If debugging, return the debugging filehandle, otherwise the null filehandle.
I haven't created a way to set the debugging filehandle just yet. It's STDERR
or nothing.

=cut

sub debug_on  { $_[0]->{debug} = 1 }
sub debug_off { $_[0]->{debug} = 0 }

sub debug     { $_[0]->{debug} }

sub debug_fh  { $_[0]->debug ? $_[0]->{debug_fh} : $_[0]->{null_fh} }

=item ua

Get the value of the web user agent.

=cut

sub ua { $_[0]->{ua} }

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

=item test()

Run `make test`. If any tests fail, it dies.

=cut

sub test
	{
	my $self = shift;
	$self->_print( "Checking make test... " );

	unless( -e $self->{'Makefile.PL'} )
		{
		$self->_print( " no $self->{'Makefile.PL'}---skipping\n" );
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

	unless( -e $self->{'Makefile.PL'} )
		{
		$self->_print( " no $self->{'Makefile.PL'}---skipping\n" );
		return;
		}

	my $messages = $self->run( "$self->{make} dist 2>&1 < /dev/null" );

	unless( $self->{local} )
		{
		$self->_print( ", guessing local distribution name" ) if $self->debug;
		($self->{local}) = $messages =~ /^\s*gzip.+?\b'?(\S+\.tar)'?\s*$/m;
		$self->{local} .= '.gz';
		$self->{remote} = $self->{local};
		}

	$self->_die( "Couldn't guess distname from dist output\n" )
		unless $self->{local};
	$self->_die( "Local file '$self->{local}' does not exist\n" )
		unless -f $self->{local};

	$self->_print( "done\n" );
	}

=item check_kwalitee()

Run `cpants_lints.pl distname.tgz`. If it doesn't see "a 'perfect' distribution"
it dies. 

=cut

sub check_kwalitee
	{
	my $self = shift;
	$self->_print( "Making dist... " );

	unless( -e $self->{'Makefile.PL'} )
		{
		$self->_print( " no $self->{'Makefile.PL'}---skipping\n" );
		return;
		}

	# XXX: what if it's not .tar.gz?
	my $messages = $self->run( "cpants_lint.pl *.tar.gz" );

	$self->_die( "Kwalitee is less than perfect:\n$messages\n" )
		unless $messages =~ m/a 'perfect' distribution!/;
	
	$self->_print( "done\n" );
	}
	
=item dist_test

Run `make disttest`. If the tests fail, it dies.

=cut

sub dist_test
	{
	my $self = shift;

	$self->_print( "Checking disttest... " );

	unless( -e $self->{'Makefile.PL'} )
		{
		$self->_print( " no $self->{'Makefile.PL'}---skipping\n" );
		return;
		}

	my $tests = $self->run( "$self->{make} disttest 2>&1" );

	$self->_die( "\nERROR: Tests failed!\n$tests\n\nAborting release\n" )
		unless $tests =~ /All tests successful/;

	$self->_print( "all tests pass\n" );
	}

=item dist_version

Return the distribution version ( set in dist() )

=cut

sub dist_version
	{
	my $self = shift;

	$self->_die( "Can't get dist_version! It's not set (did you run dist first?)" )
		unless defined $self->{remote};

	my( $major, $minor ) = $self->{remote}
		=~ /(\d+) \. (\d+(?:_\d+)?) (?:\. tar \. gz)? $/xg;

	$self->dist_version_format( $major, $minor );
	}

=item dist_version_format

Return the distribution version ( set in dist() )

# XXX make this configurable

=cut

sub dist_version_format
	{
	my $self = shift;
	my( $major, $minor ) = @_;

	sprintf "%d.%02d", $major, $minor;
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

	my $manifest = $self->run( "make manifest 2>&1" );

	my %message    = (
		"Removed from MANIFEST:"  => 'These files were removed from MANIFEST',
		"Added to MANIFEST:"      => 'These files were added to MANIFEST',
		);

	my $count = $self->_check_output_lines( \%message, $manifest );

	$self->_die( "\nERROR: Manifest was not up-to-date ($count files): Won't release.\n" )
		if $count;

	$self->_print( "MANIFEST up-to-date\n" );
	}


=item check_cvs

Run `cvs update` and report the state of the repository. If something
isn't checked in or imported, die.

=cut

sub check_cvs
	{
	my $self = shift;
	return unless -d 'CVS';

	$self->_print( "Checking state of CVS... " );

	my $cvs_update = $self->run( "cvs -n update 2>&1" );

	if( $? )
		{
		$self->_die( sprintf("\nERROR: cvs failed with non-zero exit status: %d\n\n" .
			"Aborting release\n", $? >> 8) );
		}

	my %message    = (
		C   => 'These files have conflicts',
		M   => 'These files have not been checked in',
		U   => 'These files need to be updated',
		P   => 'These files need to be patched',
		A   => 'These files were added but not checked in',
		'?' => q|I don't know about these files|,
		);

	my $count = $self->_check_output_lines( \%message, $cvs_update );

	$self->_die( "\nERROR: CVS is not up-to-date ($count files): Can't release files!\n" )
		if $count;

	$self->_print( "CVS up-to-date\n" );
	}

=item check_for_passwords

Get passwords for CPAN or SourceForge.

=cut

sub check_for_passwords
	{
	my $self = shift;

	$self->{cpan_pass} = $self->getpass( "CPAN_PASS" ) if $self->{cpan};
	$self->{sf_pass}   = $self->getpass( "SF_PASS" )   if $self->{sf};
	}

=item ftp_upload

Upload the files to the FTP servers

=cut

sub ftp_upload
	{
	my $self = shift;
	my @Sites;
	push @Sites, 'pause.perl.org' if $self->{cpan};
	push @Sites, 'upload.sourceforge.net' if $self->{sf};

	( $self->{release} ) = $self->{remote} =~ m/^(.*?)(?:\.tar\.gz)?$/g;

	my $config = $self->config;
	# set your own release name if you want to ...
	if( $config->sf_release_match && $config->sf_release_replace )
		{
		my $match   = $config->sf_release_match;
		my $replace = $config->sf_release_replace;
		$self->{release} =~ s/$match/$replace/ee;
		}

	$self->_print( "Release name is $self->{release}\n" );
	$self->_print( "Will use passive FTP transfers\n" )
		if $self->{passive_ftp} && $self->debug;

	my $local_file = $self->{local};
	my $local_size = -s $local_file;

	foreach my $site ( @Sites )
		{
		$self->_print( "Logging in to $site\n" );
		my $ftp = Net::FTP->new(
			$site,
			Hash    => \*STDOUT,
			Debug   => $self->debug,
			Passive => $self->{passive_ftp}
			) or $self->_die( "Couldn't open FTP connection to $site: $@" );

		my $email = ($config->cpan_user || "anonymous") . '@cpan.org';
		$ftp->login( "anonymous", $email )
			or $self->_die( "Couldn't log in anonymously to $site" );

		$ftp->binary;

		$ftp->cwd( "/incoming" )
			or $self->_die( "Couldn't chdir to /incoming" );

		$self->_print( "Putting $local_file\n" );
		my $remote_file = $ftp->put( $self->{local}, $self->{remote} );
		$self->_die( "PUT failed: " . $ftp->message . "\n" )
			if $remote_file ne $self->{remote};

		my $remote_size = $ftp->size( $self->{remote} );

		$self->_print( "WARNING: Uploaded file is $remote_size bytes, " .
			"but local file is $local_size bytes" )
				if $remote_size != $local_size;

		$ftp->quit;
		}
	}

=item pause_claim

Claim the file in PAUSE

=cut

sub pause_claim
	{
	my $self = shift;
	return unless $self->{cpan};

	my $cgi = CGI->new();
	my $ua  = LWP::UserAgent->new();

	my $request = HTTP::Request->new( POST =>
		   'https://pause.perl.org/pause/authenquery' );

	$cgi->param( 'HIDDENNAME', $self->config->cpan_user );
	$cgi->param( 'CAN_MULTIPART', 1 );
	$cgi->param( 'pause99_add_uri_upload', $self->{remote} );
	$cgi->param( 'SUBMIT_pause99_add_uri_upload', 'Upload the checked file' );
	$cgi->param( 'pause99_add_uri_sub', 'pause99_add_uri_subdirtext' );

	$request->content_type('application/x-www-form-urlencoded');

 	$request->content( $cgi->query_string );

 	$request->authorization_basic(
		$self->config->cpan_user, $self->{cpan_pass} );

	my $response = $ua->request( $request );

	$self->_print( "PAUSE upload ",
		$response->as_string =~ /Query succeeded/ ? "successful" : 'failed',
		"\n" );
	}

=item cvs_tag

Tag the release in local CVS. The tag name comes from C<make_cvs_tag>.

=cut

sub cvs_tag
	{
	my $self = shift;
	return unless -d 'CVS';

	my $tag = $self->make_cvs_tag;
	$self->_print( "Tagging release with $tag\n" );

	system 'cvs', 'tag', $tag;

	if ( $? )
		{ # already uploaded, so warn, don't die
		$self->_print( sprintf(
			"\nWARNING: cvs failed with non-zero exit status: %d\n",
			$? >> 8
		    ) );
		}

	}

=item make_cvs_tag

By default, examines the name of the remote file
(i.e. F<Foo-Bar-0.04.tar.gz>) and constructs a CVS tag like
C<RELEASE_0_04> from it.  Override this method if you want to use a
different tagging scheme.

=cut

sub make_cvs_tag
	{
	my $self = shift;
	my( $major, $minor ) = $self->{remote}
		=~ /(\d+) \. (\d+(?:_\d+)?) (?:\. tar \. gz)? $/xg;

	return "RELEASE_${major}_${minor}";
	}

# SourceForge.net seems to know our path through the system
# Hit all the pages, collect the right cookies, etc

=item sf_user( [ SF_USER ] )

Set or GET the SourceForge user name

=cut

sub sf_user
	{
	my $self = shift;
	my $user = shift;

	$self->config->set( 'sf_user', $user ) if defined $user;

	return $self->config->sf_user;
	}

=item sf_login

Authenticate with Sourceforge

=cut

sub sf_login
	{
	my $self = shift;
	return unless $self->{sf};

	$self->_print("Logging in to SourceForge.net... " );

	my $cgi = CGI->new();
	my $request = HTTP::Request->new( POST =>
		'https://sourceforge.net/account/login.php' );
	$self->{cookies}->add_cookie_header( $request );

	$cgi->param( 'return_to',      ''                     );
	$cgi->param( 'form_loginname', $self->config->sf_user );
	$cgi->param( 'form_pw',        $self->{sf_pass}       );
	$cgi->param( 'persistent_login',    1                      );
	$cgi->param( 'login',          'Login'       );

	$request->content_type('application/x-www-form-urlencoded');
	$request->content( $cgi->query_string );

	$request->header( "Referer", "http://sourceforge.net/account/login.php" );

	$self->_debug( $request->as_string, DASHES, "\n" );

	my $response = $self->ua->request( $request );
	$self->{cookies}->extract_cookies( $response );

	$self->_debug( $response->headers_as_string, DASHES, "\n" );

	REDIRECT: {
	if( $response->code == 302 )
		{
		my $location = $response->header('Location');
		$self->_debug( "Location is $location\n" );

 		my $request = HTTP::Request->new( POST => $location );
		$request->content_type('application/x-www-form-urlencoded');
		$request->content( $cgi->query_string );
		$self->{cookies}->add_cookie_header( $request );

		$self->_debug( $request->as_string, DASHES, "\n" );
		$response = $self->ua->request( $request );

		$self->_debug( $response->headers_as_string, DASHES, "\n" );
		$self->{cookies}->extract_cookies( $response );

		redo REDIRECT;
		}
	}

	my $content = $response->content;
	$content =~ s|.*<!-- begin SF.net content -->||s;
	$content =~ s|Register New Project.*||s;

	$self->_debug( $content );

	my $sf_user = $self->config->sf_user;

	if( $content =~ m/welcome.*$sf_user/i )
		{
		$self->_print( "Logged in!\n" );
		return 1;
		}
	else
		{
		$self->_print( "Not logged in! Aborting\n" );
		#return 0;
		exit;
		}
	}

=item sf_qrs()

Visit the Quick Release System form

=cut

sub sf_qrs
	{
	my $self = shift;
	return unless $self->{sf};

	my $request = HTTP::Request->new( GET =>
		'https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=' .
		$self->config->sf_group_id
		);

	$self->{cookies}->add_cookie_header( $request );
	$self->_debug( $request->as_string, DASHES, "\n" );

	my $response = $self->{ua}->request( $request );

	$self->_debug( $response->headers_as_string,  DASHES, "\n" );
	$self->{cookies}->extract_cookies( $response );
	}

=item sf_release()

Release the file to Sourceforge

=cut

sub sf_release
	{
	my $self = shift;
	return unless $self->{sf};

	my @time = localtime();
	my $date = sprintf "%04d-%02d-%02d",
		$time[5] + 1900, $time[4] + 1, $time[3];

	$self->_print( "Connecting to SourceForge.net QRS... " );
	my $cgi = CGI->new();
	my $request = HTTP::Request->new(
		POST => 'https://sourceforge.net/project/admin/qrs.php' );

	$self->{cookies}->add_cookie_header( $request );

	$cgi->param( 'MAX_FILE_SIZE',   1_000_000                              );
	$cgi->param( 'package_id',      $self->config->sf_package_id           );
	$cgi->param( 'release_name',    $self->{release}                       );
	$cgi->param( 'release_date',    $date                                  );
	$cgi->param( 'status_id',       1                                      );
	$cgi->param( 'file_name',       $self->{remote}                        );
	$cgi->param( 'type_id',         $self->config->sf_type_id || 5002      );
	$cgi->param( 'processor_id',    $self->config->sf_processor_id || 8000 );
	$cgi->param( 'release_notes',   get_readme()                           );
	$cgi->param( 'release_changes', get_changes()                          );
	$cgi->param( 'group_id',        $self->config->sf_group_id             );
	$cgi->param( 'preformatted',    1                                      );
	$cgi->param( 'submit',         'Release File'                          );

	$request->content_type('application/x-www-form-urlencoded');
	$request->content( $cgi->query_string );

	$request->header( "Referer",
		"https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=" .
		$self->config->sf_group_id
		);
	$self->_debug( $request->as_string, "\n", DASHES, "\n" );

	my $response = $self->{ua}->request( $request );
	$self->_debug( $response->headers_as_string, "\n", DASHES, "\n" );

	my $content = $response->content;
	$content =~ s|.*Database Admin.*?<H3><FONT.*?>\s*||s;
	$content =~ s|\s*</FONT></H3>.*||s;

	$self->_print( "$content\n" ) if $self->debug;
	$self->_print( "File Released\n" );
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

	$self->_print( "$command\n" ) if $self->debug;
	
	open my($fh), "$command |" or die $!;
	$fh->autoflush;
	
	my $output = '';
	my $buffer = '';
	local $| = 1;

	my $readlen = $self->{debug} ? 1 : 256;

	while (read $fh, $buffer, $readlen)
		{
		$output .= $_;
		$self->_debug( $_, $buffer );
		$output .= $buffer;
		}

	print DASHES, "\n" if $self->debug;

	unless( close $fh )
		{
		$self->_run_error_set;
		carp "Command [$command] had problems" if $self->debug;
		}

	return $output;
	}

=item getpass

Get a password from the user if it isn't found.

=cut

sub getpass
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

sub _print
	{
	my $self = shift;
		
	print { $self->output_fh || *STDOUT } @_;
	}

=item _debug( LIST )

Send the LIST to whatever is in debug_fh, or to STDERR. If you are
debugging, debug_fh should return a null filehandle, 

=cut

sub _debug
	{
	my $self = shift;
	
	print { $self->debug_fh || *STDERR } @_
	}

=item _debug

=cut
	
sub _die
	{
	my $self = shift;
	
	die @_;
	}
	
=back

=head1 TO DO

* What happened to my Changes munging?

=head1 CREDITS

Ken Williams turned my initial release(1) script into the present
module form.

Andy Lester handled the maintenance while I was on my Big Camping
Trip. He applied patches from many authors.

Andreas Koenig suggested changes to make it work better with PAUSE.

Chris Nandor helped with figuring out the broken SourceForge stuff.

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in SVN, as well as all of the previous releases. This
source now lives in the "Module/Release" section of the repository,
and older sources live in the "release" section.

	http://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2007 brian d foy.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__
