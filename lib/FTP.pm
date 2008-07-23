# $Id$
package Module::Release::FTP;

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT = qw(ftp_upload);

our $VERSION = '0.10_02';

=head1 NAME

Module::Release::FTP - Interact with an FTP server

=head1 SYNOPSIS

The release script automatically loads this module when it's time
to upload a file

=head1 DESCRIPTION

=over 4

=item ftp_upload( PARAMS )

Upload the files to the FTP servers.

	local_file
	remote_file
	upload_dir
	user
	password
	hostname

=cut

sub ftp_upload
	{
	require Net::FTP;

	my( $self, %params ) = @_;

	( $self->{release} ) = $self->remote_file =~ m/^(.*?)(?:\.tar\.gz)?$/g;

	my $config = $self->config;

	$self->_print( "Release name is $self->{release}\n" );
	$self->_debug( "Will use passive FTP transfers\n" ) if $self->passive_ftp;

	my $local_file = $self->local_file;
	my $local_size = -s $local_file;

	foreach my $site ( $params{hostname} )
		{
		$self->_print( "Logging in to $site\n" );
		my $ftp = Net::FTP->new(
			$site,
			Hash    => \*STDOUT,
			Debug   => $self->debug,
			Passive => $self->passive_ftp
			) or $self->_die( "Couldn't open FTP connection to $site: $@" );

		$ftp->login( @params{ qw(user password) } )
			or $self->_die( "Couldn't log in anonymously to $site" );

		$ftp->binary;

		$ftp->cwd( $params{'upload_dir'} )
			or $self->_die( "Couldn't chdir to $params{'upload_dir'}" );

		$self->_print( "Putting $local_file\n" );
		my $remote_file = $ftp->put( $self->local_file, $self->remote_file );
		$self->_die( "PUT failed: " . $ftp->message . "\n" )
			if $remote_file ne $self->remote_file;

		my $remote_size = $ftp->size( $self->remote_file );

		$self->_print( "WARNING: Uploaded file is $remote_size bytes, " .
			"but local file is $local_size bytes" )
				if $remote_size != $local_size;

		$ftp->quit;
		}
	}

=item ftp_passive_on

Turn on passive FTP.

=item ftp_passive_off

Turn off passive FTP.

=item ftp_passive

Get the value of the passive FTP setting

=cut

sub ftp_passive_on  { $_[0]->{ftp_passive} = 1 }

sub ftp_passive_off { $_[0]->{ftp_passive} = 0 }

sub ftp_passive     { $_[0]->{ftp_passive} }

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