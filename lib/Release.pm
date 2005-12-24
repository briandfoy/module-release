# $Id$
package Module::Release;

=head1 NAME

Module::Release - Methods for releasing packages to CPAN and SourceForge.

=head1 SYNOPSIS

Right now, there are no user-servicable parts inside.  However, this
has been split out like this so that there can be in the future.

=cut

our $VERSION = '1.02';

use strict;
use Config;
use CGI qw(-oldstyle_urls);
use ConfigReader::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Net::FTP;
use File::Spec;

use constant DASHES => "-" x 73;

=head2 C<new()>

Create a Module::Release object.  Any arguments passed are assumed to
be key-value pairs that override the default values.

At this point, the C<new()> method is not overridable via the
C<release_subclass> config file entry.  It would be nice to fix this
sometime.

=cut

sub new {
    my ($class, %params) = @_;
    
    my $conf = -e ".releaserc" ? ".releaserc" : "releaserc";
    
    my $self = {
			make => $Config{make},
			perl => $ENV{PERL} || $^X,
			conf => $conf,
			debug => $ENV{RELEASE_DEBUG} || 0,
			local => undef,
			remote => undef,
			%params,
	       };

    # Read the configuration
    die "Could not find conf file $self->{conf}\n" unless -e $self->{conf};
    my $config = $self->{config} = ConfigReader::Simple->new( $self->{conf} );
    die "Could not get configuration data\n" unless ref $config;

    # See whether we should be using a subclass
    if (my $subclass = $config->release_subclass) {
	unless (UNIVERSAL::can($subclass, 'new')) {
	    require File::Spec->catfile( split '::', $subclass ) . '.pm';
	}
	bless $self, $subclass;
    } else {
	bless $self, $class;
    }

    # Figure out options
    $self->{cpan} = $config->cpan_user eq '<none>' ? 0 : 1;
    $self->{sf}   = $config->sf_user   eq '<none>' ? 0 : 1;
    $self->{passive_ftp} = ($config->passive_ftp && $config->passive_ftp =~ /^y(es)?/) ? 1 : 0;

    my @required = qw( sf_user cpan_user );
    push( @required, qw( sf_group_id sf_package_id ) ) if $self->{sf};

    my $ok = 1;
    for( @required ) {
	unless ( length $config->$_() ) {
	    $ok = 0;  
	    print "Missing configuration data: $_; Aborting!\n";
	}
    }
    die "Missing configuration data" unless $ok;
  
    if( !$self->{cpan} && !$self->{sf} ) {
	die "Must upload to the CPAN or SourceForge.net; Aborting!\n";
    }
    elsif( !$self->{cpan} ) {
	print "Uploading to SourceForge.net only\n";
    }
    elsif( !$self->{sf} ) {
	print "Uploading to the CPAN only\n";
    }
  

    # Set up the browser
    $self->{ua}      = LWP::UserAgent->new( agent => 'Mozilla/4.5' );
    $self->{cookies} = HTTP::Cookies->new(
					    file           => ".lwpcookies",
					    hide_cookie2   => 1,
					    autosave       => 1 );
    $self->{cookies}->clear;

    return $self;
}

=head2 clean()

Clean up the directory to get rid of old versions

=cut

sub clean {
    my $self = shift;
    print "Cleaning directory... ";
    
    unless( -e 'Makefile' ) {
        print " no Makefile---skipping\n";
        return;
    }

    $self->run( "$self->{make} realclean 2>&1" );

    print "done\n";

} # clean

=head2 C<build_makefile()>

Builds the makefile from Makefile.PL

=cut

sub build_makefile {
    my $self = shift;
    print "Recreating make file... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    $self->run( "$self->{perl} Makefile.PL 2>&1" );

    print "done\n";
} # perl

=head2 C<test()>

Check the tests, which must all pass

=cut

sub test {
    my $self = shift;
    print "Checking make test... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $tests = $self->run( "$self->{make} test 2>&1" );

    die "\nERROR: Tests failed!\n$tests\n\nAborting release\n"
            unless $tests =~ /All tests successful/;

    print "all tests pass\n";
} # test

=head2 C<dist()>

Make the distribution. As a side effect determines the distribution
name if not set on the command line.

=cut

sub dist {
    my $self = shift;
    print "Making dist... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $messages = $self->run( "$self->{make} dist 2>&1" );

    unless( $self->{local} ){
        print ", guessing local distribution name" if $self->{debug};
        ($self->{local}) = $messages =~ /^\s*gzip.+?\b'?(\S+\.tar)'?\s*$/m;
        $self->{local} .= '.gz';
        $self->{remote} = $self->{local};
    }

    die "Couldn't guess distname from dist output\n" unless $self->{local};
    die "Local file '$self->{local}' does not exist\n" unless -f $self->{local};

    print "done\n";
} # dist

=head2 C<dist_test()>

Check the distribution test

=cut

sub dist_test {
    my $self = shift;
    print "Checking disttest... ";

    unless( -e 'Makefile.PL' ) {
        print " no Makefile.PL---skipping\n";
        return;
    }

    my $tests = $self->run( "$self->{make} disttest 2>&1" );

    die "\nERROR: Tests failed!\n$tests\n\nAborting release\n"
            unless $tests =~ /All tests successful/;

    print "all tests pass\n";
} # dist_test

=head2 C<check_cvs()>

Check the state of the CVS repository

=cut

sub check_cvs {
    my $self = shift;
    return unless -d 'CVS';

    print "Checking state of CVS... ";

    my $cvs_update = $self->run( "cvs -n update 2>&1" );

    if( $? )
            {
            die sprintf("\nERROR: cvs failed with non-zero exit status: %d\n\n" .
                    "Aborting release\n", $? >> 8);
            }

    my %message    = (
            C   => 'These files have conflicts',
            M   => 'These files have not been checked in',
            U   => 'These files need to be updated',
            P   => 'These files need to be patched',
            A   => 'These files were added but not checked in',
            '?' => q|I don't know about these files|,
            );
    my @cvs_states = keys %message;

    my %cvs_state;
    foreach my $state ( @cvs_states ) {
        $cvs_state{$state} = [ $cvs_update =~ /^\Q$state\E (.+)/gm ];
    }

    my $rule = "-" x 50;
    my $count;
    my $question_count;

    foreach my $key ( sort keys %cvs_state ) {
            my $list = $cvs_state{$key};
            next unless @$list;
            $count += @$list unless $key eq '?';
            $question_count += @$list if $key eq '?';

	    local $" = "\n\t";
            print "\n\t$message{$key}\n\t$rule\n\t@$list\n";
            }

    die "\nERROR: CVS is not up-to-date ($count files): Can't release files\n"
            if $count;

    if( $question_count ) {
            print "\nWARNING: CVS is not up-to-date ($question_count files unknown); ",
                    "continue anwyay? [Ny] " ;
            die "Exiting\n" unless <> =~ /^[yY]/;
    }

    print "CVS up-to-date\n";
} # cvs

=head2 C<check_for_passwords()>

Makes sure that C<cpan_pass> and C<sf_pass> members are populated,
as appropriate.  This function must die if the calling program is
not able to continue.

=cut

sub check_for_passwords {
    my $self = shift;

    if ( $self->{cpan} ) {
	$self->{cpan_pass} = $self->getpass( "CPAN_PASS" );
    }
    if ( $self->{sf} ) {
	$self->{sf_pass} = $self->getpass( "SF_PASS" );
    }
}

=head2 C<ftp_upload()>

Upload the files to the FTP servers

=cut

sub ftp_upload {
    my $self = shift;
    my @Sites;
    push @Sites, 'pause.perl.org' if $self->{cpan};
    push @Sites, 'upload.sourceforge.net' if $self->{sf};
    
    ( $self->{release} ) = $self->{remote} =~ m/^(.*?)(?:\.tar\.gz)?$/g;
    
    my $config = $self->{config};
    # set your own release name if you want to ...
    if( $config->sf_release_match && $config->sf_release_replace ) {
        my $match   = $config->sf_release_match;
        my $replace = $config->sf_release_replace;
        $self->{release} =~ s/$match/$replace/ee;
    }
    
    print "Release name is $self->{release}\n";
    print "Will use passive FTP transfers\n" if $self->{passive_ftp} && $self->{debug};


    my $local_file = $self->{local};
    my $local_size = -s $local_file;
    foreach my $site ( @Sites ) {
        print "Logging in to $site\n";
        my $ftp = Net::FTP->new( $site, Hash => \*STDOUT, Debug => $self->{debug}, Passive => $self->{passive_ftp} )
	    or die "Couldn't open FTP connection to $site: $@";

	my $email = ($config->cpan_user || "anonymous") . '@cpan.org';
        $ftp->login( "anonymous", $email )
	    or die "Couldn't log in anonymously to $site";

        $ftp->pasv if $self->{passive_ftp};
        $ftp->binary;

        $ftp->cwd( "/incoming" )
	    or die "Couldn't chdir to /incoming";

	print "Putting $local_file\n";
        my $remote_file = $ftp->put( $self->{local}, $self->{remote} );
	die "PUT failed: $@\n" if $remote_file ne $self->{remote};

	my $remote_size = $ftp->size( $self->{remote} );
	if ( $remote_size != $local_size ) {
	    warn "WARNING: Uploaded file is $remote_size bytes, but local file is $local_size bytes";
	}

        $ftp->quit;
    }
} # ftp_upload

=head2 C<pause_claim()>

Claim the file in PAUSE

=cut

sub pause_claim {
    my $self = shift;
    return unless $self->{cpan};

    my $cgi = CGI->new();
    my $ua  = LWP::UserAgent->new();

    my $request = HTTP::Request->new( POST =>
            'https://pause.perl.org/pause/authenquery' );

    $cgi->param( 'HIDDENNAME', $self->{config}->cpan_user );
    $cgi->param( 'CAN_MULTIPART', 1 );
    $cgi->param( 'pause99_add_uri_upload', $self->{remote} );
    $cgi->param( 'SUBMIT_pause99_add_uri_upload', 'Upload the checked file' );
    $cgi->param( 'pause99_add_uri_sub', 'pause99_add_uri_subdirtext' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->authorization_basic( $self->{config}->cpan_user, $self->{cpan_pass} );
    $request->content( $cgi->query_string );

    my $response = $ua->request( $request );

    print "PAUSE upload ",
            $response->as_string =~ /Query succeeded/ ? "successful" : 'failed',
            "\n";
} # pause_claim

=head2 C<cvs_tag()>

Tag the release in local CVS

=cut

sub cvs_tag {
    my $self = shift;
    return unless -d 'CVS';

    my $tag = $self->make_cvs_tag;
    print "Tagging release with $tag\n";

    system 'cvs', 'tag', $tag;

    if ( $? ) {
            # already uploaded, and tagging is not (?) essential, so warn, don't die
            warn sprintf(
                    "\nWARNING: cvs failed with non-zero exit status: %d\n",
                    $? >> 8
            );
    }

} # cvs_tag

=head2 C<make_cvs_tag()>

By default, examines the name of the remote file
(i.e. F<Foo-Bar-0.04.tar.gz>) and constructs a CVS tag like
C<RELEASE_0_04> from it.  Override this method if you want to use a
different tagging scheme.

=cut

sub make_cvs_tag {
    my $self = shift;
    my( $major, $minor ) = $self->{remote} =~ /(\d+) \. (\d+(?:_\d+)?) (?:\. tar \. gz)? $/xg;
    return "RELEASE_${major}_${minor}";
}

# SourceForge.net seems to know our path through the system
# Hit all the pages, collect the right cookies, etc

=head2 C<sf_login()>

Authenticate with Sourceforge

=cut

sub sf_login {
    my $self = shift;
    return unless $self->{sf};

    print "Logging in to SourceForge.net... ";

    my $cgi = CGI->new();
    my $request = HTTP::Request->new( POST =>
        'https://sourceforge.net/account/login.php' );
    $self->{cookies}->add_cookie_header( $request );

    $cgi->param( 'return_to', '' );
    $cgi->param( 'form_loginname', $self->{config}->sf_user );
    $cgi->param( 'form_pw', $self->{sf_pass} );
    $cgi->param( 'stay_in_ssl', 1 );
    $cgi->param( 'login', 'Login With SSL' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->content( $cgi->query_string );

    $request->header( "Referer", "http://sourceforge.net/account/login.php" );

    print $request->as_string, DASHES, "\n" if $self->{debug};

    my $ua = $self->{ua};
    my $response = $ua->request( $request );
    $self->{cookies}->extract_cookies( $response );

    print $response->headers_as_string, DASHES, "\n" if $self->{debug};

    if( $response->code == 302 ) {
        my $location = $response->header('Location');
        print "Location is $location\n" if $self->{debug};
        my $request = HTTP::Request->new( GET => $location );
        $self->{cookies}->add_cookie_header( $request );
        print $request->as_string, DASHES, "\n" if $self->{debug};
        $response = $ua->request( $request );
        print $response->headers_as_string, DASHES, "\n" if $self->{debug};
        $self->{cookies}->extract_cookies( $response );
    }

    my $content = $response->content;
    $content =~ s|.*<!-- begin SF.net content -->||s;
    $content =~ s|Register New Project.*||s;

    print $content if $self->{debug};

    my $sf_user = $self->{config}->sf_user;
    if( $content =~ m/welcome.*$sf_user/i ) {
        print "Logged in!\n";
    } else {
        print "Not logged in! Aborting\n";
        exit;
    }
} # sf_login

=head2 C<sf_qrs()>

Visit the Quick Release System form

=cut

sub sf_qrs {
    my $self = shift;
    return unless $self->{sf};

    my $request = HTTP::Request->new( GET =>
        'https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=' . $self->{config}->sf_group_id
    );
    $self->{cookies}->add_cookie_header( $request );
    print $request->as_string, DASHES, "\n" if $self->{debug};
    my $response = $self->{ua}->request( $request );
    print $response->headers_as_string,  DASHES, "\n" if $self->{debug};
    $self->{cookies}->extract_cookies( $response );
} # sf_qrs

=head2 C<sf_release()>

Release the file

=cut

sub sf_release {
    my $self = shift;
    return unless $self->{sf};

    my @time = localtime();
    my $date = sprintf "%04d-%02d-%02d", $time[5] + 1900, $time[4] + 1, $time[3];

    print "Connecting to SourceForge.net QRS... ";
    my $cgi = CGI->new();
    my $request = HTTP::Request->new( POST => 'https://sourceforge.net/project/admin/qrs.php' );
    $self->{cookies}->add_cookie_header( $request );

    $cgi->param( 'MAX_FILE_SIZE', 1000000 );
    $cgi->param( 'package_id', $self->{config}->sf_package_id  );
    $cgi->param( 'release_name', $self->{release} );
    $cgi->param( 'release_date',  $date );
    $cgi->param( 'status_id', 1 );
    $cgi->param( 'file_name',  $self->{remote} );
    $cgi->param( 'type_id', $self->{config}->sf_type_id || 5002 );
    $cgi->param( 'processor_id', $self->{config}->sf_processor_id || 8000 );
    $cgi->param( 'release_notes', get_readme() );
    $cgi->param( 'release_changes', get_changes() );
    $cgi->param( 'group_id', $self->{config}->sf_group_id );
    $cgi->param( 'preformatted', 1 );
    $cgi->param( 'submit', 'Release File' );

    $request->content_type('application/x-www-form-urlencoded');
    $request->content( $cgi->query_string );

    $request->header( "Referer",
        "https://sourceforge.net/project/admin/qrs.php?package_id=&group_id=" . $self->{config}->sf_group_id
    );
    print $request->as_string, "\n", DASHES, "\n" if $self->{debug};

    my $response = $self->{ua}->request( $request );
    print $response->headers_as_string, "\n", DASHES, "\n" if $self->{debug};

    my $content = $response->content;
    $content =~ s|.*Database Admin.*?<H3><FONT.*?>\s*||s;
    $content =~ s|\s*</FONT></H3>.*||s;

    print "$content\n" if $self->{debug};
    print "File Released\n";
} # sf_release

=head2 C<get_readme()>

Read and parse the F<README> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_readme {
        open my $fh, '<README' or return '';
        my $data = do {
                local $/;
                <$fh>;
        };
        return $data;
}

=head2 C<get_changes()>

Read and parse the F<Changes> file.  This is pretty specific, so
you may well want to overload it.

=cut

sub get_changes {
        open my $fh, '<Changes' or return '';
        my $data = <$fh>;  # get first line
        while (<$fh>) {
                if (/^\S/) { # next line beginning with non-whitespace is end ... YMMV
                        last;
                }
                $data .= $_;
        }
        return $data;
}

=head2 C<run()>

Run a command in the shell.

=cut

sub run {
    my ($self, $command) = @_;
    print "$command\n" if $self->{debug};
    open my($fh), "$command |" or die $!;
    my $output = '';
    local $| = 1;
    
    while (<$fh>) {
        $output .= $_;
        print if $self->{debug};
    }
    print DASHES, "\n" if $self->{debug};
    
	close $fh or die "Could not run '$command' successfully, got '$output'";

    return $output;
};

=head2 C<getpass()>

Get a password from the user if it isn't found.

=cut

sub getpass {
    my ($self, $field) = @_;

    my $pass = $ENV{$field};
    
    return $pass if defined( $pass ) && length( $pass );

    print "$field is not set.  Enter it now: ";
    $pass = <>;
    chomp $pass;

    return $pass if defined( $pass ) && length( $pass );

    die "$field not supplied.  Aborting...\n";
}

=head1 CREDITS

Ken Williams turned my initial release(1) script into the present
module form.

Andy Lester helped with the maintenance.

Andreas Koenig suggested changes to make it work better with PAUSE.

Chris Nandor helped with figuring out the broken SourceForge stuff.

=head1 AUTHOR

Copyright 2005 brian d foy, C<< <bdfoy@cpan.org> >>

=cut

1;

__END__
