package Module::Release::SourceForge;

=head1 NAME

Module::Release::SourceForge - Work with SourceForge with Module::Release

=head1 SYNOPSIS

All of this is horribly broken because Sourceforge changed everything.
This is the old code.

=cut

use strict;
use vars qw( $VERSION );

use warnings;
no warnings;

$VERSION = '2.00_06';

=head1 DESCRIPTION

=over 4

=item sourceforge_ftp_site

Return the hostname for SourceForge uploads.

=cut

sub sourceforge_ftp_site
	{
	$_[0]->{sourceforge_ftp_site};
	}

=item should_upload_to_sourceforge

Returns true is the object thinks it should upload a distro to SourceForge.

=cut

sub should_upload_to_sourceforge
	{
	$_[0]->{cpan_user} && $_[0]->{cpan_pass}
	}

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

# SourceForge.net seems to know our path through the system
# Hit all the pages, collect the right cookies, etc

=over 4


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
	$cgi->param( 'file_name',       $self->remote_file                     );
	$cgi->param( 'type_id',         $self->config->sf_type_id || 5002      );
	$cgi->param( 'processor_id',    $self->config->sf_processor_id || 8000 );
	$cgi->param( 'release_notes',   $self->get_readme()                    );
	$cgi->param( 'release_changes', $self->get_changes()                   );
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
