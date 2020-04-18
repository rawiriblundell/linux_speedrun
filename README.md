# linux_speedrun
Tools for a Linux speedrun.

On 11 April, 2020, Rachel Kroll, a veteran sysadmin/engineer, posted [this entry](https://rachelbythebay.com/w/2020/04/11/pengrun/) on her blog.

She gives the scenario of a barebones system with a network connection and documentation, and participants would 'speed run' through getting the system to a point where the system can do something "meaningful (like reading cat pictures on Reddit)"

If you've been under a rock, speed running is something that a select group of video gamers do - the goal being to find any and every way to complete a game in the fastest time possible.  For example, Zelda: Breath of the Wild, a game that took me probably a month of evenings to beat (because I took a more completionist route) can be beaten in about 38 minutes flat.

FWIW, [Sonic the Hedgehog](https://www.youtube.com/watch?v=9kOAdhUlkt0) seems to be one game where this actually makes a lot of sense.

So the challenge is that - take a barebones system and get it to the point of doing something meaningful.  As fast as possible.

## Explicit boundaries

>There are no editors and nothing more advanced than 'cat' to read files. You don't have jed, joe, emacs, pico, vi, or ed (eat flaming death). Don't even think about X. telnet, nc, ftp, ncftp, lftp, wget, curl, lynx, links? Luxury! Gone. Perl, Python and Ruby? Nope.

>Assume that documentation is plentiful. You want a copy of the Stevens book so you can figure out how to do a DNS query by banging UDP over the network? Done.

## Implicit boundaries (i.e. assumptions)

* A Linux kernel
* No busybox, no coreutils.
* I don't know if other basic commands like `rm`, `chmod`, `mkdir` etc are present.  The only binary we know for sure is present is `cat`.
* No guarantee of `bash`, however as it's Linux, we can assume a POSIX compatible shell, be it `bash`, `dash`, `ash` or, most likely, `ksh`.  Given that we don't know which, we target for POSIX as the lowest common denominator.  I'm going to use `/bin/ksh` for any examples below.

**This means that we're largely bootstrapping from shell builtins.**

## Plan

The first step is to assemble some rudimentary shell based tools to assist with editing files, without writing a full blown editor.  We will need at least the following:

* `cled` - an extremely simple entry-only editor, editing is handled by other tools
* `addln` - add a line to a file
* `addbang` - create a new file with a shebang
* `ls` - list files
* `cp` - copy a file
* `mv` - move a file, maybe?  Possibly something to save for C?
* `nl` - print a file with linenumbers
* `head` - print the first n lines of a file (default 10)
* `behead` - print the last n lines of a file (default -5)
* `rmln` - remove a line from a file (requires `head` and `behead`)
* `chln` - change a line from a file with corrected content (requires `head` and `behead`)
* `insln` - insert a line into a file at the specified line number
* `grep` - search a file for a string
* `lncount` - possibly a line count could be useful

These tools will necessarily be *extremely* rudimentary and fragile, as they'll be bootstrapped with 
individual `echo` calls.  For example, to create an extremely basic `cp` command, knowing that we have `cat`:

```
echo "#!/bin/ksh" > cp
echo 'cat "${1:?No source specified}" > "${2:?No target specified}"' >> cp
```

Alternatively, a heredoc approach could be used e.g.

```
cat << EOF > cp
#!/bin/ksh
cat "\${1:?No source specified}" > "\${2:?No target specified}"
EOF
```

This is a far cry from what you see presented at the end of a `man cp`.

### Potential approaches

* If tools like `mkdir` and `chmod` are present, then standalone scripts can be made, `$PATH` adjusted etc
* Otherwise, scripts can be made and invoked with an interpreter e.g. `ksh myscript`
* For a completely different option, these could be written as functions into files and then sourced
    * e.g. Save all files with a `.func` extension and then load them with `source *.func`
    * This gives the benefit of not having to call an interpreter, and is a simple bootstrap 
      should you restart your session for whatever reason

## Log of commands

### `cled`

The first tool I created was `cled`, which simply wraps `cat`.

What's with the name?  "`c`ommand`l`ine `ed`itor".  Because "`s`hell `ed`itor", or "`s`imple `ed`itor" was
taken, and "`sh`ell `i`nput `t`ext" didn't seem appropriate, despite its truthiness :)

** WARNING: ** Note that this does not test for existing files, nor does it prompt for overwrites!

```
▓▒░$ cat > cled
#!/bin/ksh
printf -- '%s\n' "Enter one line at a time.  Press ctrl-D to exit." >&2
cat > "${1:?No target specified}"
```

I entered ctrl-D and `cled` was written.  From now on, to create a file, you run `cled [target]`

**For the extreme speedrunners, this should be enough, and they're onwards to coding in C**

For a terser version, this could be dealt with as a shell function e.g.

```
cled() { cat > "${1:?}"; }
```

We may add features to `cled` later on...

### `ls`

For a very simple directory listing, we can use shell globbing and `printf`

```
▓▒░$ ./cled ls
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
printf -- '%s\n' ./.* ./*
```

And we can test it in use:

```
▓▒░$ ./ls
./.
./..
./.git
./cled
./LICENSE
./ls
./README.md
```

### `addln`

We may want to add a line to a file.  Normally this would be a `echo "content" >> file`, but
as we will be creating other tools like `rmln`, we may as well create this for consistency.

```
▓▒░$ ./cled addln
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
printf -- '%s\n' "${1:?No content supplied}" >> "${2:?No target specified}"
```

Note that this MUST be used like `addln "content here is double quoted" targetfile`

And let's test it:

```
▓▒░$ ./addln "#this is a testline" ls
▓▒░$ cat ls
#!/bin/ksh
printf -- '%s\n' ./.* ./*
#this is a testline
```

### `head`

We're going to need a simple `head` variant to enable us to do things like insert
lines at specific line numbers.  This code defaults to 10 lines, and has a pair of
loops to cater for reading a file or stdin.  If a file is specified, so must the linecount.

```
▓▒░$ ./cled head
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
lines="${1:-10}"
count=0

if [ -r "${2}" ]; then
  while IFS='\n' read -r line; do
    printf -- '%s\n' "${line}"
    count=$(( count + 1 ))
    [ "${count}" -eq "${lines}" ] && return 0
  done < "${2}"
else
  while IFS='\n' read -r line; do
    printf -- '%s\n' "${line}"
    count=$(( count + 1 ))
    [ "${count}" -eq "${lines}" ] && return 0
  done
fi
```

And the test:

```
▓▒░$ ./head 2 head
#!/bin/ksh
lines="${1:-10}"
```

### `behead`

### `nl`

We will need to perform line operations on a certain line number.  For us to know
that line number, we need to see the code printed out with a line number.

### `lncount`

Having a line count may be useful

```
▓▒░$ ./cled lncount
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
i=0
while read -r line; do
  i=$(( i + 1 ))
done < "${1:?No target specified}"
printf -- '%s\n' "${i}"
▓▒░$ ./lncount lncount
6
```

### `rmln`

### `chln`

### `insln`

### `cp`

```
▓▒░$ ./cled cp
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
cat "${1:?No source specified}" > "${2:?No destination specified}"
```

### `grep`

### `least`

This is a simple paginator

## Scratchpad


That `head` example gives us a basis for another tool that we could use to identify lines to remove,
in case we have a version of `cat` that doesn't have the `-n` option...

    nl() {
      _count=1
      if [ -r "${1}" ]; then
        while IFS='\n' read -r _line; do
          printf -- '%04d: %s\n' "${_count}" "${_line}"
          _count=$(( _count + 1 ))
        done < "${1}"
      else
        while IFS='\n' read -r _line; do
          printf -- '%04d: %s\n' "${_count}" "${_line}"
          _count=$(( _count + 1 ))
        done
      fi
      unset -v _count
    }

Now we can start piping things together

    $ nl ~/.bashrc | head
    0001: # shellcheck shell=bash
    0002: ################################################################################
    0003: # .bashrc
    0004: # Please don't copy anything below unless you understand what the code does!
    0005: # If you're looking for a licence... WTFPL plus Warranty Clause:
    0006: #
    0007: # This program is free software. It comes without any warranty, to
    0008: #     * the extent permitted by applicable law. You can redistribute it
    0009: #     * and/or modify it under the terms of the Do What The Fuck You Want
    0010: #     * To Public License, Version 2, as published by Sam Hocevar. See

And then we can create another tool to help us:

    # Print all but the first n lines
    behead() {
      _lines="${1:-5}"
      _count=0
    
      if [ -r "${2}" ]; then
        while IFS='\n' read -r _line; do
          if [ "${_count}" -ge "${_lines}" ]; then
            printf -- '%s\n' "${_line}"
          fi
          _count=$(( _count + 1 ))
        done < "${2}"
      else
        while IFS='\n' read -r _line; do
          if [ "${_count}" -ge "${_lines}" ]; then
            printf -- '%s\n' "${_line}"
          fi
          _count=$(( _count + 1 ))
        done
      fi
      unset -v _count _lines _line
    }

Right, so let's plumb `head` and `behead` together, like so:

    # Usage: remove_line [line number] [file]
    remove_line() {
      _target="${1:?No line specified}"
      _fsobj="${2:?No file specified}"
    
      head "$(( _target - 1 ))" "${_fsobj}"
      behead "${_target}" "${_fsobj}"
    
      unset -v _target _fsobj
    }

So let's say we've `nl`'d or `cat -n`'d my example `.bashrc` from above, and we want to delete line number 2:

    $ remove_line 2 ~/.bashrc | head 5
    # shellcheck shell=bash
    # .bashrc
    # Please don't copy anything below unless you understand what the code does!
    # If you're looking for a licence... WTFPL plus Warranty Clause:
    #

So we can then move on to something like this:

    # Usage: replace_line [line number] [file] [new content]
    replace_line() {
      _target="${1:?No line specified}"
      _fsobj="${2:?No file specified}"
      shift 2
    
      head "$(( _target - 1 ))" "${_fsobj}"
      printf -- '%s\n' "${*}"
      behead "${_target}" "${_fsobj}"
    
      unset -v _target _fsobj
    }

Which looks like:

    $ replace_line 2 ~/.bashrc "# Pants are, in my opinion, overrated" | head 5
    # shellcheck shell=bash
    # Pants are, in my opinion, overrated
    # .bashrc
    # Please don't copy anything below unless you understand what the code does!
    # If you're looking for a licence... WTFPL plus Warranty Clause:

Obviously that comes with its own set of headaches, but so far... `sed`, schmed!

From there, assembling C code becomes a lot more tenable.
