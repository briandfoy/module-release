# $Id: load.t 1270 2004-07-04 17:56:42Z comdog $
BEGIN {
	@classes = qw(
		Module::Release 
		Module::Release::Kwalitee
		Module::Release::FTP
		Module::Release::PAUSE
		Module::Release::SVN
		);
	}

use Test::More tests => scalar @classes;

foreach my $class ( @classes )
	{
	print "Bail out! $class did not compile!" unless use_ok( $class );
	}
