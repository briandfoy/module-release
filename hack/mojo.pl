use Module::Release;

my $release = Module::Release->new;

$release->local_file( $ARGV[0] );
$release->config->set( cpan_user => 'BDFOY' );
$release->config->set( cpan_pass => 'R$45tear' );

$release->load_mixin( 'Module::Release::WebUpload::Mojo' );
$release->web_upload;
