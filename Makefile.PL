# $Id$
use ExtUtils::MakeMaker;

eval "use Test::Manifest 1.14";
	   
WriteMakefile(
	'NAME'	       => 'Module::Release',
	'VERSION_FROM' => "lib/Release.pm",
	'LICENSE'       => 'perl',
	
	'EXE_FILES'    =>  [ 'script/release' ],
	    	
	'PREREQ_PM'    => 
		{
 		'ConfigReader::Simple' => 0,
		'Net::FTP'             => 0,
		'HTTP::Message'        => 0,
		'Crypt::SSLeay'        => 0,
		'File::Temp'           => 0,
		},

	'PM'           => {
        'lib/Release.pm' => '$(INST_LIBDIR)/Release.pm',
		},

	'MAN1PODS'     => {
		'script/release' => '$(INST_MAN1DIR)/release.1',
		},
		
	clean => { FILES => '*.bak release-*' },
	);
