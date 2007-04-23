#!/usr/bin/perl -w
# This script was originally based on the script of the same name from
# the KDE SDK (by dfaure@kde.org)
#
# This version is
#   Copyright (C) 2007 Adam D. Barratt
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=head1 NAME

licensecheck - simple license checker for source files

=head1 SYNOPSIS

B<licensecheck> B<--help|--version>

B<licensecheck> [B<--verbose>] [B<-l|--lines=N>] I<list of files to check>

=head1 DESCRIPTION

B<licensecheck> attempts to determine the license that applies to each file
passed to it, by searching the start of the file for text belonging to
various licenses.

=head1 OPTIONS

=over 4

=item B<--verbose> B<--no-verbose>

Specify whether to output the text being processed from each file before
the corresponding license information.

Default is to be quiet.

=item B<-l=N> B<--lines=N>

Specify the number of lines of each file's header which should be parsed 
for license information. (Default is 60).

=back

=head1 CONFIGURATION VARIABLES

The two configuration files F</etc/devscripts.conf> and
F<~/.devscripts> are sourced by a shell in that order to set
configuration variables.  Command line options can be used to override
configuration file settings.  Environment variable settings are
ignored for this purpose.  The currently recognised variables are:

=over 4

=item B<LICENSECHECK_VERBOSE>

If this is set to I<yes>, then it is the same as the --verbose command
line parameter being used. The default is I<no>.

=item B<LICENSECHECK_PARSELINES>

If this is set to a positive number then the specified number of lines
at the start of each file will be read whilst attempting to determine
the license(s) in use.  This is equivalent to the --lines command line
option.

=back

=head1 LICENSE

This code is copyright by Adam D. Barratt <adam@adam-barratt.org.uk>, 
all rights reserved; based on a script of the same name from the KDE 
SDK, which is copyright by <dfaure@kde.org>.
This program comes with ABSOLUTELY NO WARRANTY.
You are free to redistribute this code under the terms of the GNU 
General Public License, version 2 or later.

=head1 AUTHOR

Adam D. Barratt <adam@adam-barratt.org.uk>

=cut

use strict;
use Getopt::Long;
use File::Basename;

sub fatal($);
sub parselicense($);

my $progname = basename($0);

my $modified_conf_msg;

my ($opt_verbose, $opt_lines, $opt_noconf);
my ($opt_help, $opt_version);
my $def_lines = 60;

# Read configuration files and then command line
# This is boilerplate

if (@ARGV and $ARGV[0] =~ /^--no-?conf$/) {
    $modified_conf_msg = "  (no configuration files read)";
    shift;
} else {
    my @config_files = ('/etc/devscripts.conf', '~/.devscripts');
    my %config_vars = (
		       'LICENSECHECK_VERBOSE' => 'no',
		       'LICENSECHECK_PARSELINES' => $def_lines,
		      );
    my %config_default = %config_vars;

    my $shell_cmd;
    # Set defaults
    foreach my $var (keys %config_vars) {
	$shell_cmd .= qq[$var="$config_vars{$var}";\n];
    }
    $shell_cmd .= 'for file in ' . join(" ", @config_files) . "; do\n";
    $shell_cmd .= '[ -f $file ] && . $file; done;' . "\n";
    # Read back values
    foreach my $var (keys %config_vars) { $shell_cmd .= "echo \$$var;\n" }
    my $shell_out = `/bin/bash -c '$shell_cmd'`;
    @config_vars{keys %config_vars} = split /\n/, $shell_out, -1;

    # Check validity
    $config_vars{'LICENSECHECK_VERBOSE'} =~ /^(yes|no)$/
	or $config_vars{'LICENSECHECK_VERBOSE'} = 'no';
    $config_vars{'LICENSECHECK_PARSELINES'} =~ /^[1-9][0-9]*$/
	or $config_vars{'LICENSECHECK_PARSELINES'} = $def_lines;

    foreach my $var (sort keys %config_vars) {
	if ($config_vars{$var} ne $config_default{$var}) {
	    $modified_conf_msg .= "  $var=$config_vars{$var}\n";
	}
    }
    $modified_conf_msg ||= "  (none)\n";
    chomp $modified_conf_msg;

    $opt_verbose = $config_vars{'LICENSECHECK_VERBOSE'} eq 'yes' ? 1 : 0;
    $opt_lines = $config_vars{'LICENSECHECK_PARSELINES'};
}

GetOptions("help|h" => \$opt_help,
	   "version|v" => \$opt_version,
	   "verbose!" => \$opt_verbose,
	   "lines|l=i" => \$opt_lines,
	   "noconf" => \$opt_noconf,
	   "no-conf" => \$opt_noconf,
	   )
    or die "Usage: $progname [options] filelist\nRun $progname --help for more details\n";

$opt_lines =~ /^[1-9][0-9]*$/ or $opt_lines = $def_lines;

if ($opt_noconf) {
    fatal "--no-conf is only acceptable as the first command-line option!";
}
if ($opt_help) { help(); exit 0; }
if ($opt_version) { version(); exit 0; }

die "Usage: $progname [options] filelist\nRun $progname --help for more details\n" unless @ARGV;

$opt_lines = $def_lines if not defined $opt_lines;

while (@ARGV) {
    my $file = shift @ARGV;

    my $content = '';
    open (F, "<$file") or die "Unable to access $file\n";
    while (<F>) {
        last if ($. > $opt_lines);
        $content .= $_;
    }
    close(F);

    print qq(----- $file header -----\n$content----- end header -----\n\n)
	if $opt_verbose;

    $content =~ tr/\t\r\n/ /;
    $content =~ tr% A-Za-z.,@;0-9\(\)\n\r/-%%cd;
    $content =~ tr/ //s;

    print "$file: " . parselicense($content) . "\n";
}

sub help {
   print <<"EOF";
Usage: $progname [options] filename [filename ...]
Valid options are:
   --help, -h             Display this message
   --version, -v          Display version and copyright info
   --verbose              Display the header of each file before its
                            license information
   --lines, -l            Specify how many lines of the file header
                            should be parsed for license information
                            (Default: $def_lines)

Default settings modified by devscripts configuration files:
$modified_conf_msg
EOF
}

sub version {
    print <<"EOF";
This is $progname, from the Debian devscripts package, version ###VERSION###
Copyright (C) 2007 by Adam D. Barratt <adam\@adam-barratt.org.uk>; based 
on a script of the same name from the KDE SDK by <dfaure\@kde.org>.

This program comes with ABSOLUTELY NO WARRANTY.
You are free to redistribute this code under the terms of the
GNU General Public License, version 2, or (at your option) any 
later version.
EOF
}

sub parselicense($) {
    my ($licensetext) = @_;

    my $gplver = "";
    my $extrainfo = "";
    my $license = "";

    if ($licensetext =~ /version ([^ ]+) (?:\(?only\)?.? )?(?:of the GNU General Public License )?as published by the Free Software Foundation/i or
	$licensetext =~ /GNU General Public License as published by the Free Software Foundation; version ([^ ]+) /i) {

	$gplver = " (v$1)";
    }
    elsif ($licensetext =~ /either version ([^ ]+) of the License, or \(at your option\) any later version/) {
	$gplver = " (v$1 or later)";
    }

    if ($licensetext =~ /(?:675 Mass Ave|59 Temple Place|51 Franklin Steet|02139|02111-1307)/i) {
	$extrainfo = " (with incorrect FSF address)$extrainfo";
    }

    if ($licensetext =~ /permission (?:is (also granted|given))? to link (the code of )?this program with (any edition of )?(Qt|the Qt library)/i) {
	$extrainfo = " (with Qt exception)$extrainfo"
    }

    if ($licensetext =~ /(All changes made in this file will be lost|DO NOT (EDIT|delete this file)|Generated by)/i) {
	$license = "GENERATED FILE";
    }

    if ($licensetext =~ /is free software. you can redistribute it and\/or modify it under the terms of the (GNU (Library|Lesser) General Public License|LGPL)/i) {
	$license = "LGPL$gplver$extrainfo $license";
    }

    if ($licensetext =~ /is free software.? you can redistribute it and\/or modify it under the terms of (?:version [^ ]+ (?:\(?only\)? )?of )?the GNU General Public License/i) {
	$license = "GPL$gplver$extrainfo $license";
    }

    if ($licensetext =~ /This file is part of the .*Qt GUI Toolkit. This file may be distributed under the terms of the Q Public License as defined/) {
	$license = "QPL (part of Qt) $license";
    }
    elsif ($licensetext =~ /may be distributed under the terms of the Q Public License as defined/) {
	$license = "QPL $license";
    }

    if ($licensetext =~ /Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files \(the Software\), to deal in the Software/) {
	$license = "MIT/X11 (BSD like) $license";
    }

    if ($licensetext =~ /THIS SOFTWARE IS PROVIDED .*AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY/) {
	$license = "BSD $license";
    }

    if ($licensetext =~ /Mozilla Public License Version ([^ ]+)/) {
	$license = "MPL (v$1) $license";
    }

    if ($licensetext =~ /Released under the terms of the Artistic License ([^ ]+)/) {
	$license = "Artistic (v$1) $license";
    }

    if ($licensetext =~ /This program is free software; you can redistribute it and\/or modify it under the same terms as Perl itself/) {
	$license = "Perl $license";
    }

    if ($licensetext =~ /under the Apache License, Version ([^ ]+) \(the License\)/) {
	$license = "Apache (v$1) $license";
    }

    if ($licensetext =~ /This source file is subject to version ([^ ]+) of the PHP license/) {
	$license = "PHP (v$1) $license";
    }

    if ($licensetext =~ /is in the public domain/i) {
	$license = "Public domain";
    }

    $license = "UNKNOWN" if (!length($license));

    if ($licensetext !~ /copyright/i) {
	$license = "*No copyright* $license";
    }

    return $license;
}

sub fatal($) {
    my ($pack,$file,$line);
    ($pack,$file,$line) = caller();
    (my $msg = "$progname: fatal error at line $line:\n@_\n") =~ tr/\0//d;
    $msg =~ s/\n\n$/\n/;
    die $msg;
}
