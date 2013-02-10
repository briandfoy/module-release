use ExtUtils::MakeMaker 6.48;
use strict;
use warnings;

require 5.010;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'Module::Release',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	'ABSTRACT'     => 'Automate Perl distribution releases',
	'VERSION_FROM' => "lib/Module/Release.pm",
	'LICENSE'      => 'perl',

	'EXE_FILES'    =>  [ 'script/release' ],

	'PREREQ_PM'    => {
		'CACertOrg::CA'         => '0',
		'ConfigReader::Simple'  => '0',
		'HTTP::Message'         => '0',
		'HTTP::Request'         => '0',
		'IO::Null'              => '0',
		'Mojo::UserAgent'       => '0',
		'Test::Output'          => '0',
		'Test::Without::Module' => '0',
		'URI'                   => '0',
		},

	MIN_PERL_VERSION => 5.010,

	META_MERGE => {
			resources => {
		  		repository => 'git://github.com/briandfoy/module-release.git',
				},
			keywords => ['workflow', 'module', 'distribution', 
				'pause', 'automation', 'testing'],
	  		},

	'MAN1PODS'     => {
		'script/release' => '$(INST_MAN1DIR)/release.$(MAN1EXT)',
		},

	clean => { FILES => '*.bak release-* Module-*' },
	);
