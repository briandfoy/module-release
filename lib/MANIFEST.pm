package Module::Release::MANIFEST;

use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION);

our @EXPORT = qw( check_MANIFEST );

$VERSION = '2.05';

=head1 NAME

Module::Release::MANIFEST - Check Perl's MANIFEST to ensure you've updated it

=head1 SYNOPSIS

The release script automatically loads this module and checks your
MANIFEST file. It runs C<{make|Build} manifest> and dies if the 
output contains any lines that start with C<added> or C<removed>.

If it dies, you have to start the release process again after 
verifying F<MANIFEST> (and F<MANIFEST.SKIP>).

=head1 DESCRIPTION

=over 4

=item check_MANIFEST

Runs C<{make|Build} manifest>. If it sees output
starting with C<added> or C<removed>, it dies.

It looks in local_name to get the name of the distribution file.

=cut

sub check_MANIFEST
	{
	$_[0]->_print( "Checking MANIFEST... " );
	
	my $perl = $_[0]->{perl};
	
	my @ignore = $_[0]->_get_prereq_ignore_list;
	
	my $output = $_[0]->run( "$_[0]->{make} test 2>&1" );

	$_[0]->_die( "\nERROR: MANIFEST is dirty! Update MANIFEST or MANIFEST.SKIP!\n$output\n\nAborting release\n" )
		    if $output =~ /^(added|removed)/mi;
	
	$_[0]->_print( "done\n" );
	}

=back

=head1 SEE ALSO

L<Module::Release>

=head1 SOURCE AVAILABILITY

This source is in Github:

	git://github.com/briandfoy/module-release.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
