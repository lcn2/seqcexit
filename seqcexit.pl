#!/usr/bin/env perl
#
# seqcexit - sequence C exit codes for special functions that exit
#
# The following functions called, if they have a leading integer
# argument, are sequenced by seqcexit, unless removed by -U func.
#
# See the func hash below for a list of functions.  With -v 3,
# the list of functions that will be processed as debug statements.
#
# With the exception of exit and usage, the function list in func are functions
# from the dbg facility were the 1st argument is numeric.  For information on
# the dbg facility, visit:
#
#	https://github.com/lcn2/dbg
#
# Copyright (c) 2021,2022 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\
#
# Share and enjoy! :-)

# requirements
#
use strict;
use bytes;
use vars qw($opt_v $opt_cap_v $opt_c $opt_h);
use Getopt::Long;
use File::Basename;
use File::Temp qw(tempfile);
use warnings;

# version
#
my $VERSION = "1.11 2022-11-09";

# my vars
#
my $file;	# required argument

# usage and help
#
my $usage = "$0 [-h] [-v lvl] [-V] [-b bottom] [-t top] [-n] [-s] [-c] [[-D func] ...] [[-U func] ...] file [file ...]";
my $help = qq{$usage

	-h		print this usage message and VERSION stringand exit 0
	-v lvl		verbose / debugging level (def: 0)
	-V		print version and exit 0
	-b bottom	bottom exit code after wrap around (must be >=0 and < bottom and != 127) (def: 10)
			    NOTE: The sequenced exit codes in file.c can start at 0.
				  The bottom value only applies when the codes exceed top and need to wrap around.
	-t top		top exit code range (must be > bottom  and < 256 and != 127) (def: 249)
	-n		do not change, nor create files
	-s		keep a copy of the original filenmame as filename.orig.c
	-c		continous sequencing across files (def: always reset code on a new file)

	-D func		Add function func to sequencing list
	-U func		Remove function func to sequencing list
			    NOTE: Multiple -D func and -U func are allowed on the command line.
				  All -D func are added 1st, then all -U func are removed 2nd.

	file ...	source file(s) to process

NOTE: Exit 0 can only be used once at the first exit code use: if bottom == 0.
      Exit codes > 255 are not used: instead the next code will be set to bottom, or set to 1 if bottom == 0.
      Exit 127 is not used: instead next value is used: usually 128 unless top == 128 in which case bottom is used.

The following functions calls with a leading integer argument, unless removed by -U func, are processed by seqcexit:

	exit(100);
	usage(101, ...

	err(102, ...
	verr(103, ...
	ferr(104, ...
	vferr(105, ...

	errp(106, ...
	verrp(107, ...
	ferrp(108, ...
	vferrp(109, ...

	werr(110, ...
	vwerr(111, ...
	fwerr(112, ...
	vfwerr(113, ...
	snwerr(114, ...
	vsnwerr(115, ...

	werrp(116, ...
	vwerrp(117, ...
	fwerrp(118, ...
	vfwerrp(119, ...
	snwerrp(120, ...
	vsnwerrp(121, ...

	warn_or_err(122, ...
	vwarn_or_err(123, ...
	fwarn_or_err(124, ...
	vfwarn_or_err(125, ...

	warnp_or_errp(126, ...
	vwarnp_or_errp(128, ...
	fwarnp_or_errp(129, ...
	vfwarnp_or_errp(130, ...

	printf_usage(131, ...
	vprintf_usage(132, ...
	fprintf_usage(133, ...
	vfprintf_usage(134, ...

NOTE: With the exception of exit and usage, the above function list are functions
      from the dbg facility were the 1st argument is numberic.  For information on
      the dbg facility, visit:

	https://github.com/lcn2/dbg
};
my $bottom  = 10;	# bottom exit code range after wrap around
my $top = 249;		# top exit code range
my $noop = undef;	# change nor create no files
my $save_orig = undef;	# keep the original file as foo.orig.c
my @D_list;		# list of functions referenced by -D func
my @U_list;		# list of functions referenced by -U func
my %optctl = (
    "h" => \$opt_h,
    "v=i" => \$opt_v,
    "V" => \$opt_cap_v,
    "b=i" => \$bottom,
    "t=i" => \$top,
    "n" => \$noop,
    "s" => \$save_orig,
    "c" => \$opt_c,
    "D=s@" => \@D_list,
    "U=s@" => \@U_list,
);

# list of functions to sequence
#
my %func = (
    "exit" => 0,

    "usage" => 0,

    "err" => 0, "verr" => 0, "ferr" => 0, "vferr" => 0,

    "errp" => 0, "verrp" => 0, "ferrp" => 0, "vferrp" => 0,

    "werr" => 0, "vwerr" => 0, "fwerr" => 0, "vfwerr" => 0, "snwerr" => 0, "vsnwerr" => 0,

    "werrp" => 0, "vwerrp" => 0, "fwerrp" => 0, "vfwerrp" => 0, "snwerrp" => 0, "vsnwerrp" => 0,

    "warn_or_err" => 0, "vwarn_or_err" => 0, "fwarn_or_err" => 0, "vfwarn_or_err" => 0,

    "warnp_or_errp" => 0, "vwarnp_or_errp" => 0, "fwarnp_or_errp" => 0, "vfwarnp_or_errp" => 0,

    "printf_usage" => 0, "vprintf_usage" => 0, "fprintf_usage" => 0, "vfprintf_usage" => 0,
);


# function prototypes
#
sub nextexitcode($);
sub error($@);
sub dbg($@);


# setup
#
MAIN: {
    my $ARGV;	# file argument on the command line
    my $line;	# line from open file
    my $tmp_fh;			# temporary file handle
    my $tmp_filename;		# temporary file name
    my $exit_seq = undef;	# exit sequence number

    # setup
    #
    select(STDOUT);
    $| = 1;

    # set the defaults
    #
    $opt_v = 0;

    # parse args
    #
    if (!GetOptions(%optctl)) {
	error(1, "invalid command line\nusage: $help");
    }

    # arg checking
    #
    if (defined $opt_h) {
	error(0, "usage: $help\nVersion: $VERSION");
    }
    if (defined $opt_cap_v) {
	error(0, "$VERSION");
    }
    if ($#ARGV < 0) {
	error(2, "missing required argument\nusage: $help");
    }
    if ($bottom  == 127) {
	error(3, "bottom  cannot be 127\nusage: $help");
    }
    if ($top == 127) {
	error(4, "top cannot be 127\nusage: $help");
    }
    if ($bottom  < 0) {
	error(5, "bottom  must be >= 0\nusage: $help");
    }
    if ($top > 255) {
	error(6, "top must be < 256\nusage: $help");
    }
    if ($bottom  >= $top) {
	error(7, "bottom  must be < top\nusage: $help");
    }

    # Add all -D func first
    #
    foreach my $func_name (@D_list) {
	dbg(5, "# adding function to list: $func_name");
	$func{$func_name} = 0;
    }

    # Remove all -U func second
    #
    foreach my $func_name (@U_list) {
	dbg(5, "# removing function from list: $func_name");
	delete($func{$func_name});
    }

    # print list of sequencing functions if debugging
    #
    foreach my $func_name (sort keys %func) {
	dbg(3, "# will sequence: $func_name");
    }

    # cycle through lines of the argument
    #
    while ($ARGV = shift @ARGV) {

	# process only *.c files
	dbg(1, "# considering $ARGV");

	# open file if possible
	#
	open(FH, $ARGV) or do {
	    dbg(1, "# skipping file, cannot open $ARGV: $!");
	    next;
	};
	dbg(3, "# open $ARGV");

	# open a new temporary file
	#
	if (! defined($noop)) {
	    ($tmp_fh, $tmp_filename) = tempfile("c.tmpfile.XXXXX",
						 DIR => dirname($ARGV),
						 SUFFIX => '.c',
						 EXLOCK => 1);
	    dbg(3, "# forming $tmp_filename");
	}

	# unless -c, reset exit code for the new file
	#
	if (! defined($opt_c)) {
	    $exit_seq = undef;
	}

	# process each line in the file
	#
	while ($line = <FH>) {

	    # do not exit code process lines with /*ooo*/
	    #
	    if ($line !~ /\/\*ooo\*\//) {
		my ($pre, $funcname, $whiteparen, $code, $post);	# parse function line
		my ($prev_exit_seq, $orig_code);

		# look for line of the form: (where 123 can be any integer >= 0)
		#
		#	func(123);
		#	func(123, ...
		#
		# We will ignore lines with whitespace around the exit code.
		#
		#	$1	beginning of line up to the calling function
		#	$2	calling function name
		#	$3	white and ( before the exit code
		#	$4	exit code
		#	$5	text after exit code
		#
		if ($line =~ /^(.*\b)([A-Za-z][A-Za-z0-9_]*)(\s*\()(\d+)(\);.*)$/ ||
		    $line =~ /^(.*\b)([A-Za-z][A-Za-z0-9_]*)(\s*\()(\d+)(,.*)$/) {

		    # save matched expressions
		    #
		    $pre = $1;
		    $funcname = $2;
		    $whiteparen = $3;
		    $code = $4;
		    $post = $5;

		    # process if the function name is listed
		    #
		    if (exists($func{$funcname})) {

			# debug result
			#
			++$func{$funcname};	# count function use
			dbg(9, "possible exit sequenceing call: $funcname$whiteparen$code");
			dbg(9, "possible exit sequenceing line: $pre$funcname$whiteparen$code$post");

			# if first exit number, start with this sequence
			#
			$orig_code = $code;
			$prev_exit_seq = $exit_seq;
			if (! defined($exit_seq)) {
			    $exit_seq = $code;

			# otherwise use the next in the sequence
			#
			} else {
			    $exit_seq = nextexitcode($exit_seq);
			    $code = $exit_seq;
			}

			# skip sequencing if $pre is an open C /* comment
			#			  or in a multi-line * comment
			#			  or in a // comment
			#
			# While not perfect, the regular expression will catch the case
			# where we are in the middle of a comment.
			#
			if ($pre =~ /\/\*[^*\/]*$/ || $pre =~ /\s*\*\s*$/ || $pre =~ /\/\//) {

			    # /* do not alter exit code, nor change exit the sequence */
			    dbg(7, "restoring line, likely open comment found: $pre");
			    $exit_seq = $prev_exit_seq;
			    $code = $orig_code;

			# if we find a /*coo*/ comment, then reset the sequence
			#
			} elsif ($pre =~ /\/\*coo\*\// || $post =~ /\/\*coo\*\//) {

			    # force the exit sequence to change to match current line
			    #
			    dbg(7, "found /*coo*/, reset exit sequence from $exit_seq to $orig_code");
			    $exit_seq = $orig_code;
			    $code = $orig_code;
			}
			if ($code != $orig_code) {
			    dbg(5, "change exit code on line from $orig_code to $code");
			}

			# reform line with sequenced exit code
			#
			$line = $pre . $funcname . $whiteparen . $code . $post . "\n";
		    }
		}
	    }

	    # print the (possibly modified) line to the temp file
	    #
	    if (! defined($noop)) {
		print $tmp_fh $line or die "connot write line to $tmp_filename: $!";
	    }
	}

	# close the temporary file
	#
	if (! defined($noop)) {
	    dbg(3, "# close $tmp_filename");
	    close $tmp_fh or die "cannot close $tmp_filename: $!";
	}

	# close the file
	#
	dbg(3, "# close $ARGV");
	close FH or die "cannot close $ARGV: $!";

	# case: -s
	#
	# Move original file.c to file.orig.c
	#
	if (defined($save_orig)) {
	    my $orig_file = $ARGV;
	    $orig_file =~ s/\.c$/.orig.c/;
	    if (! defined($noop)) {
		dbg(3, "mv -v $ARGV $orig_file");
		rename($ARGV, $orig_file) or die "cannot rename $ARGV to $orig_file: $!";
	    }
	}

	# code: no -s and no -n
	#
	# move temp filename into place, unless -n
	#
	if (! defined($noop)) {
	    dbg(3, "mv -v $tmp_filename $ARGV");
	    rename($tmp_filename, $ARGV) or die "cannot rename $tmp_filename to $ARGV: $!";
	}
    }

    # report on function count use
    #
    foreach my $func_name (sort keys %func) {
	if ($func{$func_name} > 0) {
	    dbg(5, "# function count for $func_name: $func{$func_name}");
	}
    }

    exit(0); # /*ooo*/
}


# nextexitcode - return the next non-zero valid exit code
#
# We select the next exit code beyond $exitcode, which is usually $exitcode+1,
# except when $exitcode >= $top in which case $bottom  is considered.  However
# if $bottom  <= 0, then 1 is used instead.  We will also skip 127 because
# a return value of 127 by system() means the execution of the shell failed.
# Regardless, if the next exit code is >= 256, return to exit code of $bottom .
#
# given:
#	$exitcode	current exit code
#
# returns:
#	next exit code that is within non-zero exit code range
#
sub nextexitcode($)
{
    my $current_code = shift @_;	# get exit code
    my $ret;				# exit code to consider

    # consider next exit code
    #
    $ret = $current_code + 1;

    # do not use 127 - used by system() when shell cannot be invoked
    #
    if ($ret == 127) {
	# skip 127
	$ret = 128;
    }

    # wrap to bottom  if beyond top or beyond 255
    #
    if ($ret > $top || $ret > 255) {
	$ret = $bottom ;
    }

    # do not reuse (due to wrapping) 0, jump to 1 instead
    #
    if ($ret <= 0) {
	$ret = 1;
    }
    return $ret;
}


# error - report an error and exit
#
# given:
#       $exitval	exit code value
#       $msg ...	error message to print
#
sub error($@)
{
    my ($exitval) = shift @_;	# get args
    my $msg;			# error message to print

    # parse args
    #
    if (!defined $exitval) {
	$exitval = 254;
    }
    if ($#_ < 0) {
	$msg = "<<< no message supplied >>>";
    } else {
	$msg = join(' ', @_);
    }
    if ($exitval =~ /\D/) {
	$msg .= "<<< non-numeric exit code: $exitval >>>";
	$exitval = 253;
    }

    # issue the error message
    #
    print STDERR "$0: $msg\n";

    # issue an error message
    #
    exit($exitval);
}


# dbg - print a debug message is debug level is high enough
#
# given:
#       $min_lvl	minimum debug level required to print
#       $msg ...	debug message to print
#
# NOTE: The DEBUG[$min_lvl]: header is printed for $min_lvl >= 0 only.
#
# NOTE: When $min_lvl <= 0, the message is always printed
#
sub dbg($@)
{
    my ($min_lvl) = shift @_;	# get args
    my $msg;			# debug message to print

    # firewall
    #
    if (!defined $min_lvl) {
	error(128, "debug called without a minimum debug level");
    }
    if ($min_lvl !~ /-?\d/) {
	error(129, "debug called with non-numeric debug level: $min_lvl");
    }
    if ($opt_v < $min_lvl) {
	return;
    }
    if ($#_ < 0) {
	$msg = "<<< no message supplied >>>";
    } else {
	$msg = join(' ', @_);
    }

    # issue the debug message
    #
    if ($min_lvl < 0) {
	print STDERR "$msg\n";
    } else {
	print STDERR "DEBUG[$min_lvl]: $msg\n";
    }
}
