package Module::Release::PAUSE;

use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION);

our @EXPORT = qw(
	pause_ftp_site should_upload_to_pause pause_claim set_pause_ftp_site
	pause_claim_base_url pause_claim_content pause_claim_content_type
	);

$VERSION = '2.05';

=head1 NAME

Module::Release::PAUSE - Interact with the Perl Authors Upload Server (PAUSE)

=head1 SYNOPSIS

The release script automatically loads this module if it thinks that you
want to upload to PAUSE by noticing the C<cpan_user> configuration 
directive.

=head1 DESCRIPTION

=over 4

=item set_pause_ftp_site( HOSTNAME )

Set the name of the PAUSE FTP site. If you pass it something that
doesn't look like a host name, it warns and doesn't set anything.

=cut

sub set_pause_ftp_site
	{
	no warnings 'uninitialized';
	unless( $_[1] =~ /^[a-z0-9-]+(\.[a-z0-9-]+)+\z/ )
		{
		$_[0]->_warn( "The argument [$_[0]] does not look like a hostname" );
		return;
		}
		
	$_[0]->{pause_ftp_site} = $_[1];
	}

=item pause_ftp_site

Return the hostname for PAUSE uploads.

=cut

sub pause_ftp_site
	{
	$_[0]->{pause_ftp_site} || 'pause.perl.org';
	}

=item should_upload_to_pause

Returns true is the object thinks it should upload a distro to PAUSE.

=cut

sub should_upload_to_pause
	{
	no warnings 'uninitialized';
	$_[0]->_debug(    "CPAN user: " . $_[0]->config->cpan_user . 
		           " | CPAN pass: " . $_[0]->config->cpan_pass . "\n" );
	$_[0]->config->cpan_user && $_[0]->config->cpan_pass
	}

=item pause_claim

Claim the file in PAUSE

=cut

sub pause_claim
	{
	require HTTP::Request;

	my $self = shift;
	return unless $self->should_upload_to_pause;

	my $ua  = $self->get_web_user_agent;

	my $request = HTTP::Request->new( POST => $self->pause_claim_base_url );
	
	$request->content_type( $self->pause_claim_content_type );

	$request->content( $self->pause_claim_content );

	$request->authorization_basic(
		$self->config->cpan_user, $self->config->cpan_pass );

	my $response = $ua->request( $request );

	$self->_print( "PAUSE upload ",
		$response->as_string =~ /Query succeeded/ ? "successful" : 'failed',
		"\n" );
	}

=item pause_claim_base_url

The base URL to claim something in PAUSE. This is 
C<https://pause.perl.org/pause/authenquery>.

XXX: This should read from pause_ftp_site probably

=cut

sub pause_claim_base_url { 'https://pause.perl.org/pause/authenquery' } 

=item pause_claim_content

Construct the data for the POST request to claim a file in PAUSE.

=cut

sub pause_claim_content
	{
	require CGI; CGI->import( qw(-oldstyle_urls) );
	
	my $cgi = CGI->new();

	$cgi->param( 'HIDDENNAME',                     $_[0]->config->cpan_user     );
	$cgi->param( 'CAN_MULTIPART',                  1                            );
	$cgi->param( 'pause99_add_uri_upload',         $_[0]->remote_file           );
	$cgi->param( 'SUBMIT_pause99_add_uri_upload',  'Upload the checked file'    );
	$cgi->param( 'pause99_add_uri_sub',            'pause99_add_uri_subdirtext' );

	$cgi->query_string;
	}

=item pause_claim_content_type

The content type for the POST request to claim a file in PAUSE. This is 
C<application/x-www-form-urlencoded>.

=cut

sub pause_claim_content_type { 'application/x-www-form-urlencoded' }

=back

=head1 SEE ALSO

L<Module::Release>

=head1 SOURCE AVAILABILITY

This source is in Github:

	git://github.com/briandfoy/module-release.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007-2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
