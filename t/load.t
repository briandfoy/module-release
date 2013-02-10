BEGIN {
	@classes = qw(
		Module::Release 
		Module::Release::Kwalitee
		Module::Release::WebUpload::Mojo
		Module::Release::PAUSE
		Module::Release::SVN
		Module::Release::MANIFEST
		);
	}

use Test::More tests => scalar @classes;

foreach my $class ( @classes )
	{
	print "Bail out! $class did not compile!" unless use_ok( $class );
	}
