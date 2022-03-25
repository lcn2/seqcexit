# seqcexit
Sequence C exit codes for exiting functions

The following functions calls, with a leading integer argument, are processed by seqcexit:

```c
    exit(99);
    err(100, ...
    errp(101, ...
    errc(102, ...
    errx(103, ...
    verr(104, ...
    verrc(105, ...
    verrx(106, ...
    vfprintf_usage(107, ...
    warn_or_err(108, ...
    warnp_or_errp(109, ...
    usage(110, ...
```

## Command line

```sh
usage: ./seqcexit.pl [-h] [-v lvl] [-b bottom] [-t top] [-n] [-s] [-c] file.c [file2.c ...]

	-h		print this usage message and VERSION stringand exit 0
	-v lvl		verbose / debugging level (def: 0)
	-b bottom	bottom exit code after wrap around (must be >=0 and < bottom and != 127) (def: 10)
			    NOTE: The sequenced exit codes in file.c can start at 0. The bottom  value
				  only applies when the codes exceed top and need to wrap around.
	-t top		top exit code range (must be > bottom  and < 256 and != 127) (def: 249)
	-n		do not change, nor create files
	-s		keep a copy of the original filenmame as filename.orig.c
	-c		continous sequencing across files (def: always reset code on a new file)

	file.c ...	C source file(s) to process

NOTE: Exit 0 can only be used once at the first exit code use: if bottom  == 0.
      Exit codes > 255 are not used: instead the next code will be set to bottom , or set to 1 if bottom  == 0.
      Exit 127 is not used: instead next value is used: usually 128 unless top == 128 in which case bottom  is used.
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
