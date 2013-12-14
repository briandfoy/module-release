package Module::Release::PAUSE;

use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION);

use Carp qw(croak);

our @EXPORT = qw(
	);

$VERSION = '2.06_06';

=encoding utf8

=head1 NAME

Module::Release::PAUSE - Interact with the Perl Authors Upload Server (PAUSE)

=head1 SYNOPSIS

The release script automatically loads this module if it thinks that you
want to upload to PAUSE by noticing the C<cpan_user> configuration
directive.

=head1 DESCRIPTION

=over 4


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
