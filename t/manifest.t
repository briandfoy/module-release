#!/usr/bin/perl
use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;

use Cwd;

my $class = 'Module::Release';
my $file  = ".releaserc";

use_ok( $class );
can_ok( $class, 'new' );

BEGIN {
	use File::Spec;
	my $file = File::Spec->catfile( qw(t lib setup_common.pl) );
	require $file;
	}

my @subs = qw(manifest_name files_in_manifest touch_all_in_manifest);

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create test object
my $release = $class->new;
isa_ok( $release, $class );
can_ok( $release, @subs );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 
my $filename = $release->manifest_name;
ok( defined $filename, "manifest_name returns something that is defined" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 
my @files = $release->files_in_manifest;
