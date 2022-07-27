# seqcexit
Sequence C exit codes for exiting functions

The following functions calls with a leading integer argument, unless removed by -U func, are processed by seqcexit:

```c
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
```

NOTE: With the exception of exit and usage, the above function list are functions
      from the dbg facility were the 1st argument is numberic.  For information on
      the dbg facility, visit the [dbg repo](https://github.com/lcn2/dbg).

## Command line

```sh
./seqcexit [-h] [-v lvl] [-b bottom] [-t top] [-n] [-s] [-c] [[-D func] ...] [[-U func] ...] file [file ...]

	-h		print this usage message and VERSION stringand exit 0
	-v lvl		verbose / debugging level (def: 0)
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
```

## Examples

```c
/*ooo*/
```

For example:

```c
    ...
    exit(0); /*ooo*/
}
```

Use this C comment on a line to indicate the exit code on a given line is
new value tp be sued in sequencing.

```c
/*coo*/
```

For example, this will cause seqcexit to reset the sequence number to 100.

```c
    /*
     * firewall
     */
    if (path == NULL) {
	exit(100); /*coo*/
    }
}
```

The exit code that follows will be assigned to 101.
