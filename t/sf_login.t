use Test::More 'no_plan';

use_ok( "Module::Release" );

#$ENV{RELEASE_DEBUG} = 1;
my $release = Module::Release->new();
isa_ok( $release, "Module::Release" );

can_ok( $release, 'sf_login' );

is( $release->sf_user( 'comdog' ), 'comdog' );


ok( defined $ENV{SF_PASS} );
$release->{sf_pass} = $ENV{SF_PASS};

ok( defined $release->{sf_pass} );

ok( $release->sf_login() );
