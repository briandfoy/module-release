use ExtUtils::MakeMaker;
use strict;
use warnings;

require 5.008;

eval "use Test::Manifest 1.21";

my @plugins = qw( SVN PAUSE FTP Kwalitee Prereq MANIFEST);

# The $|++ is there just to let Perl know it's not a hash. I don't know
# how it's deciding to parse that.
my %modules = map { $|++; "lib/$_.pm" => "\$(INST_LIBDIR)/Release/$_.pm" } @plugins;
my %man3    = map { $|++; "lib/$_.pm" => "\$(INST_MAN3DIR)/Module::Release::$_.\$(MAN3EXT)" } @plugins;


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
		%modules,
		},

	(
	$ExtUtils::MakeMaker::VERSION ge '6.48' ? 
		(
		MIN_PERL_VERSION => 5.006,

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

	'MAN3PODS'     => {
		'lib/Release.pm' => '$(INST_MAN3DIR)/Module::Release.$(MAN3EXT)',
		%man3,
		},

	clean => { FILES => '*.bak release-* Module-*' },
	);
