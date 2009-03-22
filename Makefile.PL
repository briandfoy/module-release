# $Id$
use ExtUtils::MakeMaker;

require 5.008;

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
		'ConfigReader::Simple'  => 0,
		'Crypt::SSLeay'         => 0,
		'HTTP::Message'         => 0,
		'HTTP::Request'         => 0,
		'IO::Null'              => 0,
		'Net::FTP'              => 0,
		'Test::Output'          => 0,
		'Test::Without::Module' => 0,
		'URI'                   => 0,
		},

	'PM'           => {
		'lib/Release.pm' => '$(INST_LIBDIR)/Release.pm',
		'lib/SVN.pm'     => '$(INST_LIBDIR)/Release/SVN.pm',
		'lib/FTP.pm'     => '$(INST_LIBDIR)/Release/FTP.pm',
		'lib/PAUSE.pm'   => '$(INST_LIBDIR)/Release/PAUSE.pm',
		'lib/Kwalitee.pm'   => '$(INST_LIBDIR)/Release/Kwalitee.pm',
		'lib/Prereq.pm'   => '$(INST_LIBDIR)/Release/Prereq.pm',
		#map { "lib/$_.pm" => "\$(INST_LIBDIR)/Release/$_.pm" } qw( SVN PAUSE FTP ),
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
