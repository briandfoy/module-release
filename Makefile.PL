use ExtUtils::MakeMaker;
use strict;
use warnings;

require 5.008;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'Module::Release',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	'ABSTRACT'     => 'Automate software releases',
	'VERSION_FROM' => "lib/Module/Release.pm",
	'LICENSE'      => 'perl',

	'EXE_FILES'    =>  [ 'script/release' ],

	'PREREQ_PM'    => 
		{
		'ConfigReader::Simple'  => 0,
		'Crypt::SSLeay'         => 0,
		'HTTP::Message'         => 0,
		'HTTP::Request'         => 0,
		'IO::Null'              => 0,
		'LWP::UserAgent'        => 0,
		'Net::FTP'              => 0,
		'Test::Output'          => 0,
		'Test::Without::Module' => 0,
		'URI'                   => 0,
		},


	(
	$ExtUtils::MakeMaker::VERSION ge '6.48' ? 
		(
		MIN_PERL_VERSION => 5.008,

		META_MERGE       => {
			resources => {
		  		repository => 'git://github.com/briandfoy/module-release.git',
				},
			keywords => ['workflow', 'module', 'distribution', 'pause', 'automation', 'testing'],
	  		},
	 	) 
	 	: 
	 	()
	 ),

	'MAN1PODS'     => {
		'script/release' => '$(INST_MAN1DIR)/release.$(MAN1EXT)',
		},

	clean => { FILES => '*.bak release-* Module-*' },
	);
