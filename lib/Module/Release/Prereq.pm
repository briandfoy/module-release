package Module::Release::Prereq;

use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION);

our @EXPORT = qw( check_prereqs _get_prereq_ignore_list );

$VERSION = '2.06';

=head1 NAME

Module::Release::Prereq - Check  pre-requisites list in build file

=head1 SYNOPSIS

The release script automatically loads this module and checks your
prerequisite declaration against what you actaully used in the
tests.

=head1 DESCRIPTION

=over 4

=item check_prereqs

Run `perl -MTest::Prereq -eprereq_ok`. If it doesn't see "^ok 1"
it dies.

It looks in local_name to get the name of the distribution file.

=cut

sub check_prereqs
	{
	eval "require Test::Prereq; 1 " or
		$_[0]->_die( "You need Test::Prereq to check prereqs" );

	$_[0]->_print( "Checking prereqs... " );

	my $perl = $_[0]->{perl};

	my @ignore = $_[0]->_get_prereq_ignore_list;

	my $messages = $_[0]->run(
		qq|$perl -MTest::Prereq -e "prereq_ok( undef, undef, [ qw(@ignore) ] )"|
		);

	$_[0]->_die( "Prereqs had a problem:\n$messages\n" )
		unless $messages =~ m/^ok 1 - Prereq test/m;

	$_[0]->_print( "done\n" );
	}

sub _get_prereq_ignore_list
	{
	my @ignore = split /\s+/, $_[0]->config->ignore_prereqs || '';
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

Copyright (c) 2007-2011, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
