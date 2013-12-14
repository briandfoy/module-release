package Module::Release::WebUpload::Mojo;

use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION);

use Carp qw(croak);
use Mojo::UserAgent;
use File::Basename qw(basename);

our @EXPORT = qw(
	web_upload
	make_agent
	default_web_hostname
	pause_add_uri
	);

$VERSION = '2.06_06';

=encoding utf8

=head1 NAME

Module::Release::WebUpload::Mojo - Upload through the PAUSE web interface

=head1 SYNOPSIS

The release script automatically loads this module when it's time
to upload a file. It's implemented with C<Mojo::UserAgent>.

=head1 DESCRIPTION

=over 4

=item web_upload( PARAMS )

Upload the file to PAUSE

=cut

sub web_upload {
	my $self = shift;

	my $ua = $self->make_agent;

	$self->_debug( sprintf "Uploading file %s", $self->local_file );

	my $params = {
		HIDDENNAME                    => $self->config->cpan_user,
		CAN_MULTIPART                 => 1,
		pause99_add_uri_subdirtext    => '',
		SUBMIT_pause99_add_uri_httpupload => ' Upload this file from my disk ',
		pause99_add_uri_httpupload    => { file => $self->local_file },
		};

	$self->_print( "File uploading\n" );
	my $tx = $ua->post(
		$self->pause_add_uri( 
		 	$self->config->cpan_user, 
		 	$self->config->cpan_pass,
		 	),
		 form => $params,
		 );
	my $code = $tx->res->code;
	$self->_print( "File uploaded [$code]\n" );
	}

sub make_agent {
	my( $self ) = @_;
	my $agent = Mojo::UserAgent->new( name => 'release' );
	$agent->http_proxy( $self->config->http_proxy ) if $self->config->http_proxy;
	$agent->https_proxy( $self->config->https_proxy ) if $self->config->https_proxy;
	require CACertOrg::CA;
	$agent->cert( CACertOrg::CA::SSL_ca_file() );

	return $agent;
	}

=back

=head2 Default values

Override these methods to change the default values. Remember that
the overridden methods have to show up in the C<Module::Release>
namespace.

=over 4

=item default_web_hostname

pause.perl.org

=item pause_add_uri

http://pause.perl.org/pause/authenquery

=cut

sub default_web_hostname   { "pause.perl.org" }
sub pause_add_uri          {
	my( $self, $user, $pass ) = @_;
	sprintf 'https://%s:%s@pause.perl.org/pause/authenquery', $user, $pass;
	};

=back

=head1 SEE ALSO

L<Module::Release>

=head1 SOURCE AVAILABILITY

This source is in Github:

	https://github.com/briandfoy/module-release

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007-2013, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
