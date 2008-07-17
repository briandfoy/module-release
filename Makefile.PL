# $Id$
use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.14";

WriteMakefile(
	'NAME'	       => 'Module::Release',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	'ABSTRACT'     => 'Automate software releases',
	'VERSION_FROM' => "lib/Release.pm",
	'LICENSE'      => 'perl',

	'EXE_FILES'    =>  [ 'script/release' ],

	'PREREQ_PM'    => 
		{
		'ConfigReader::Simple' => 0,
		'Net::FTP'             => 0,
		'HTTP::Message'        => 0,
		'IO::Null'             => 0,
		'Crypt::SSLeay'        => 0,
		'File::Temp'           => 0,
		},

	'PM'           => {
		'lib/Release.pm' => '$(INST_LIBDIR)/Release.pm',
		'lib/SVN.pm'     => '$(INST_LIBDIR)/Release/SVN.pm',
		},

	'MAN1PODS'     => {
		'script/release' => '$(INST_MAN1DIR)/release.1',
		},

	'MAN3PODS'     => {
		'lib/Release.pm' => '$(INST_MAN3DIR)/Module::Release.3',
		'lib/SVN.pm'     => '$(INST_MAN3DIR)/Module::Release::SVN.3',
		},

	clean => { FILES => '*.bak release-* Module-*' },
	);
