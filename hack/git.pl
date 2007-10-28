#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

my $git_update = do { local $/; <DATA> };

my( $branch ) = $git_update =~ /^# On branch (\w+)/g;
print "Branch is [$branch]", "\n-------------\n";

$git_update =~ s/^#\s*[\r\n]+//gm;
print $git_update, "\n-------------\n";

$git_update =~ s/^# On branch.*[\r\n]+//m;
print $git_update, "\n-------------\n";

$git_update =~ s/^#\s//gm; # one space
print $git_update, "\n-------------\n";

$git_update =~ s/^\s*\(.*?\)[\r\n]+//mg;	
print $git_update, "\n-------------\n";


my(undef, %bits ) = split /^(\w.*):[\r\n]+/m, $git_update;


foreach my $key ( keys %bits )
	{
	my @lines = 
		map { my $x = $_; $x =~ s/^\s+//; $x =~ s/\s+$//; $x } 
		split /[\r\n]+/, $bits{ $key };
	
	$" = "\n\t";
	print "$key lines:\n\t@lines\n";
	
	$bits{$key} = [ @lines ];
	}

print Dumper( \%bits );
	
__DATA__
# On branch master
# Changes to be committed:
#   (use "git reset HEAD <file>..." to unstage)
#
#       new file:   README
#
# Changed but not updated:
#   (use "git add <file>..." to update what will be committed)
#
#       modified:   .gitignore
#
# Untracked files:
#   (use "git add <file>..." to include in what will be committed)
#
#       Changes
#       LICENSE
#       MANIFEST.SKIP
#       Makefile.PL
#       examples/
#       lib/
#       t/