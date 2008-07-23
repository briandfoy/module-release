# $Id$
package Module::Release::PAUSE;

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT = qw(pause_ftp_site should_upload_to_pause pause_claim);

our $VERSION = '0.10_02';

=head1 NAME

Module::Release::PAUSE - Interact with the Perl Authors Upload Server (PAUSE)

=head1 SYNOPSIS

The release script automatically loads this module if it thinks that you
want to upload to PAUSE by noticing the C<cpan_user> configuration 
directive.

=head1 DESCRIPTION

=over 4

=item pause_ftp_site

Return the hostname for PAUSE uploads.

=cut

sub pause_ftp_site
	{
	$_[0]->{pause_ftp_site};
	}

=item should_upload_to_pause

Returns true is the object thinks it should upload a distro to PAUSE.

=cut

sub should_upload_to_pause
	{
	$_[0]->{cpan_user} && $_[0]->{cpan_pass}
	}
	
=item pause_claim

Claim the file in PAUSE

=cut

sub pause_claim
	{
	require HTTP::Request;
	require CGI; CGI->import( qw(-oldstyle_urls) );

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


=back

=head1 SEE ALSO

L<Module::Release>

=head1 SOURCE AVAILABILITY

So far this is in a private git repository. It's only private because I'm
lazy. I can send it to you if you like, and I promise to set up something
public Real Soon Now.

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007-2008, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;