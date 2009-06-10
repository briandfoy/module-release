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
