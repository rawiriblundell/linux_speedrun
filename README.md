# linux_speedrun
Tools for a Linux speedrun.

On 11 April, 2020, Rachel Kroll, a veteran sysadmin/engineer, posted [this entry](https://rachelbythebay.com/w/2020/04/11/pengrun/) on her blog.

She gives the scenario of a barebones system with a network connection and documentation, and participants would 'speed run' through getting the system to a point where the system can do something "meaningful (like reading cat pictures on Reddit)"

If you've been under a rock, speed running is something that a select group of video gamers do - the goal being to find any and every way to complete a game in the fastest time possible.  For example, Zelda: Breath of the Wild, a game that took me probably a month of evenings to beat (because I took a more completionist route) can be beaten in about 38 minutes flat.

FWIW, [Sonic the Hedgehog](https://www.youtube.com/watch?v=9kOAdhUlkt0) seems to be one game where this actually makes a lot of sense.

So the challenge is that - take a barebones system and get it to the point of doing something meaningful.  As fast as possible.

For an example of an equally weird challenge, you might want to check out this video of a 
[1930's teletype being used as a Linux terminal.](https://www.youtube.com/watch?v=2XLZ4Z8LpEE)

## Explicit boundaries

>There are no editors and nothing more advanced than 'cat' to read files. You don't have jed, joe, emacs, pico, vi, or ed (eat flaming death). Don't even think about X. telnet, nc, ftp, ncftp, lftp, wget, curl, lynx, links? Luxury! Gone. Perl, Python and Ruby? Nope.

>Assume that documentation is plentiful. You want a copy of the Stevens book so you can figure out how to do a DNS query by banging UDP over the network? Done.

## Implicit boundaries (i.e. assumptions)

* A Linux kernel
* No busybox, no coreutils.
* I don't know if other basic commands like `rm`, `chmod`, `mkdir` etc are present.  I am going to 
  assume that these commands are **not** available.  The only binary we know for sure is present is `cat`.
* Because `cat` is present, that means that we have a shell with which to invoke it :)
* No guarantee of `bash`, however as it's Linux, we can assume *at least* a POSIX compatible shell, be it `bash`, `dash`,
 `ash` or, most likely, `ksh`.  Given that we don't know which, we target for POSIX as the lowest common denominator.  
 I'm going to use `/bin/ksh` for any examples below.

**This means that we're largely bootstrapping from shell builtins.**

## Plan

The first step is to assemble some rudimentary shell based tools to assist with editing files, without writing a full blown editor.  
We will need at least the following in a vague approximate order of preference:

* `cled` - an extremely simple entry-only editor, editing is handled by other tools
* `addln` - add a line to a file
* `addbang` - create a new file with a shebang
* `ls` - list files
* `cp` - copy a file
* `nl` - print a file with linenumbers
* `head` - print the first n lines of a file (default 10)
* `behead` - print the last n lines of a file (default -5)
* `rmln` - remove a line from a file (requires `head` and `behead`)
* `chln` - change a line from a file with corrected content (requires `head` and `behead`)
* `insln` - insert a line into a file at the specified line number
* `grep` - search a file for a string
* `lncount` - possibly a line count could be useful

These tools will necessarily be *extremely* rudimentary and fragile, as they will be built with 
utter primitive approaches, such as individual `echo` calls.  For example, to create an extremely 
basic `cp` command, knowing that we have `cat`:

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

This version of `cp` is obviously a far cry from what you see presented at the end of a `man cp`.

Once we are bootstrapped to a point, we can start creating basic commands in C, like:

* `chmod`
* `mv`
* `rm`

At this point, we also want to consider getting dns responses and figuring out to
search for, download and build various packages.  I would argue that `busybox` be one of the first.

## Log of commands for generating these tools

### `cled`

The first tool I created was `cled`, which simply wraps `cat`.

What's with the name?  "`c`ommand`l`ine `ed`itor".  Because "`s`hell `ed`itor", or "`s`imple `ed`itor" was
taken, and "`sh`ell `i`nput `t`ext" didn't seem appropriate, despite its truthiness :)

**WARNING:** Note that this does not test for existing files, nor does it prompt for overwrites!

```
▓▒░$ cat > cled
#!/bin/ksh
printf -- '%s\n' "Enter one line at a time.  Press ctrl-D to exit." >&2
cat > "${1:?No target specified}"
```

I entered ctrl-D and `cled` was written.  

Next, assuming we don't have `chmod`, to overcome this, we create an alias:

```
▓▒░$ alias cled="/bin/ksh $PWD/cled"
▓▒░$ type cled
cled is an alias for '/bin/ksh /home/rawiri/git/linux_speedrun/cled'
```

From now on, to create a file, you run `cled [target]`

**For the extreme speedrunners, this should be enough, and they're onwards to coding in C**

For a terser version, this could be dealt with as a shell function e.g.

```
cled() { cat > "${1:?}"; }
```

We may add features to `cled` later on...

### `ls`

For a very simple directory listing, we can use shell globbing and `printf`

```
▓▒░$ cled ls
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
printf -- '%s\n' ./.* ./*
```

And we can test it in use:

```
▓▒░$ ksh ls
./.
./..
./.git
./cled
./LICENSE
./ls
./README.md
```

And, if desired, alias it (something we will obviously do from now on):

```
▓▒░$ alias ls="/bin/ksh $PWD/ls"
```

We could make a shell based `ls` that gives more detail by running a battery
of tests against each fs object, for now we just need to know what's in the current dir.
Perhaps the only change worth adding would be a directory test - if it's a dir, append a `/`.
Maybe something to revisit later...

### `addln`

We may want to add a line to a file.  Normally this would be a `echo "content" >> file`, but
as we will be creating other tools like `rmln`, we may as well create this for consistency.

```
▓▒░$ cled addln
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
printf -- '%s\n' "${1:?No content supplied}" >> "${2:?No target specified}"
```

**Note that this MUST be used like** `addln "content here is double quoted" targetfile`

And let's test it:

```
▓▒░$ ksh addln "#this is a testline" ls
▓▒░$ cat ls
#!/bin/ksh
printf -- '%s\n' ./.* ./*
#this is a testline
```

### `cp`

`cp` is a basic enough task:

```
▓▒░$ cled cp
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
cat "${1:?No source specified}" > "${2:?No destination specified}"
```

### `head`

We're going to need a simple `head` variant to enable us to do things like insert
lines at specific line numbers.  This code defaults to 10 lines (stdin), and has 
a pair of loops to cater for reading a file or stdin.  In `bash` we could do 
this with a single loop and read in `< "${2:-/dev/stdin}"`.

Obviously, if a file is specified, then so must the linecount.

```
▓▒░$ cled head
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
▓▒░$ ksh head 2 head
#!/bin/ksh
lines="${1:-10}"
```

### `nl`

Most of our editing functions work on specific line numbers.  For us to know
our target line numbers, we need to see the code printed out with them.

In Linux, `cat` should have the `-n` option that achieves the same thing, if not, 
we can replicate the `nl` tool like this

```
▓▒░$ cled nl
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
count=1
if [ -r "${1}" ]; then
  while IFS='\n' read -r line; do
    printf -- '%04d: %s\n' "${count}" "${line}"
    count=$(( count + 1 ))
  done < "${1}"
else
  while IFS='\n' read -r line; do
    printf -- '%04d: %s\n' "${count}" "${line}"
    count=$(( count + 1 ))
  done
fi
```

And test it like so:

```
▓▒░$ ksh nl cled
0001: #!/bin/ksh
0002: printf -- '%s\n' "Enter one line at a time.  Press ctrl-D to exit." >&2
0003: cat > "${1:?No target specified}"
```

And we can start piping things together:

```
▓▒░$ ksh nl ~/.bashrc | ksh head 8
0001: # shellcheck shell=bash
0002: ################################################################################
0003: # .bashrc
0004: # Please don't copy anything below unless you understand what the code does!
0005: # If you're looking for a licence... WTFPL plus Warranty Clause:
0006: #
0007: # This program is free software. It comes without any warranty, to
0008: #     * the extent permitted by applicable law. You can redistribute it
```

### `behead`

To allow us to change, remove or insert lines in an existing file, we need a 
counterpart for `head`.  This allows us to `head` *n* number of lines from a file,
perform an action, and then `behead` that same number of lines from the same file.

```
▓▒░$ cled behead
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
lines="${1:-5}"
count=0

if [ -r "${2}" ]; then
  while IFS='\n' read -r line; do
    if (( count >= lines )); then
      printf -- '%s\n' "${line}"
    fi
    count=$(( count + 1 ))
  done < "${2}"
else
  while IFS='\n' read -r line; do
    if (( count >= lines )); then
      printf -- '%s\n' "${line}"
    fi
    count=$(( count + 1 ))
  done
fi
```

Okay, so after setting up an `alias`, we can test it:

```
▓▒░$ head 10 LICENSE | nl | behead 9
0010: software to the public domain. We make this dedication for the benefit
```

### `chln`

Now we mash `head` and `behead` together into a command to change a numbered line:

```
▓▒░$ cled chln
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
target_line="${1:?No line specified}"
fs_obj="${2:?No file specified}"
shift 2

head "$(( target_line - 1 ))" "${fs_obj}"
printf -- '%s\n' "${*}"
behead "${target_line}" "${fs_obj}"
```

This did not go as planned.  As the files are not executable yet, PATH didn't help, and aliases don't expand here...

As `cled` currently stands, it overwrites any existing files, which means typing the lot from scratch...
if only... there were some command to... say... change a line...

```
$ cled chln
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
target_line="${1:?No line specified}"
fs_obj="${2:?No file specified}"
shift 2

/bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
printf -- '%s\n' "${*}"
/bin/ksh /home/rawiri/git/linux_speedrun/behead "${target_line}" "${fs_obj}"
```

#### Example

Consider the following file with line numbers shown:

```
0001: A
0002: B
0003: C
0004: D
```

To change the second line would look something like this:

```
+head 1 file
+printf newcontent
+behead 2 file
```

Giving us:

```
0001: A
0002: newcontent
0003: C
0004: D
```

**NOTE: These commands will only print the changes to stdout, they will not make the edits inline.**
You will be responsible for piping this out to another file.  Fortunately, because we're using `alias`
all over the place, we can simply do something like this:

```
chln 4 ls "# This is an extra comment" > ls2
```

Followed by

```
unalias ls
alias ls="/bin/ksh $PWD/ls2
```

Once we get a working implementation of `mv`, we can correct this behaviour.

### `rmln`

Right, so we know that `rmln` is going to be very similar in structure to `chln`, and
because we have `chln` and `cp`, then we may as well use those tools.  This is our
first demonstration of our makeshift numbered-line editing system!

```
▓▒░$ cp chln tmp.rmln

▓▒░$ nl tmp.rmln
0001: #!/bin/ksh
0002: target_line="${1:?No line specified}"
0003: fs_obj="${2:?No file specified}"
0004: shift 2
0005:
0006: /bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
0007: printf -- '%s\n' "${*}"
0008: /bin/ksh /home/rawiri/git/linux_speedrun/behead "${target_line}" "${fs_obj}"

▓▒░$ chln 7 tmp.rmln ''
#!/bin/ksh
target_line="${1:?No line specified}"
fs_obj="${2:?No file specified}"
shift 2

/bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"

/bin/ksh /home/rawiri/git/linux_speedrun/behead "${target_line}" "${fs_obj}"

▓▒░$ chln 7 tmp.rmln '' > rmln
```

So we copy `chln` to `tmp.rmln`, push out a line-numbered copy of `tmp.rmln`, which helps us to
identify that line 7 is the one that needs to go.  We then use `chln` to change
line 7 to a blank line, and test that this output is as we want it.

In retrospect, I could have just done:

```
nl chln
chln 7 chln ''
chln 7 chln '' > rmln
```

#### Example: remove

To remove a line is much the same as changing it, you simply don't insert the change i.e.

```
+head 1 file
+behead 2 file
```

Giving us:

```
0001: A
0002: C
0003: D
```

So let's say we've `nl`'d or `cat -n`'d my example `.bashrc` from above, and we want to delete line number 2:

```
▓▒░$ rmln 2 ~/.bashrc | head 5
# shellcheck shell=bash
# .bashrc
# Please don't copy anything below unless you understand what the code does!
# If you're looking for a licence... WTFPL plus Warranty Clause:
#
```

### `insln`

We may want to insert a line at a numbered point

```
▓▒░$ cp chln tmp.insln

▓▒░$ nl tmp.insln n
0001: #!/bin/ksh
0002: target_line="${1:?No line specified}"
0003: fs_obj="${2:?No file specified}"
0004: shift 2
0005:
0006: /bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
0007: printf -- '%s\n' "${*}"
0008: /bin/ksh /home/rawiri/git/linux_speedrun/behead "${target_line}" "${fs_obj}"

▓▒░$ chln 6 tmp.insln '/bin/ksh /home/rawiri/git/linux_speedrun/head "${target_line}" "${fs_obj}"'
#!/bin/ksh
target_line="${1:?No line specified}"
fs_obj="${2:?No file specified}"
shift 2

/bin/ksh /home/rawiri/git/linux_speedrun/head "${target_line}" "${fs_obj}"
printf -- '%s\n' "${*}"
/bin/ksh /home/rawiri/git/linux_speedrun/behead "${target_line}" "${fs_obj}"

▓▒░$chln 6 tmp.insln '/bin/ksh /home/rawiri/git/linux_speedrun/head "${target_line}" "${fs_obj}"' > insln
```

I realised my mistake, and so I started again:

```
▓▒░$ chln 8 chln '/bin/ksh /home/rawiri/git/linux_speedrun/behead "$(( target_line - 1 ))" "${fs_obj}"' > insln
```

Then we add an alias, because we're traking these in an `aliases` file now.

```
addln 'alias insln="/bin/ksh $PWD/insln"' aliases
```

#### Example

Consider the following file with line numbers shown:

```
0001: A
0002: B
0003: C
0004: D
```

To insert a line between the second and third lines would look something like this:

```
+head 2 file
+printf newcontent
+behead 2 file
```

Giving us:

```
0001: A
0002: B
0003: newcontent
0004: C
0005: D
```

### `lncount`

Having a line count may be useful

```
▓▒░$ cled lncount
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
i=0
while read -r line; do
  i=$(( i + 1 ))
done < "${1:?No target specified}"
printf -- '%s\n' "${i}"
▓▒░$ ksh lncount lncount
6
```

### `grep`

To save us from having to read through scripts, we can simply print numbered
matching lines.  This started out like this, but the keen eye will note the errors:

```
▓▒░$ cled grep
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
needle="${1:?No search term given}"
count=1

if [ -r "${1}" ]; then
  while IFS='\n' read -r line; do
    case "${line}" in
      (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "{line}" ;;
    esac
  done < "${1}"
else
  while IFS='\n' read -r line; do
    case "${line}" in
      (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "{line}" ;;
    esac
  done
fi
```

This resulted in a flurry of `chln`, `insln` and `rmln` calls bouncing back and
forward between `grep` and `tmp.grep`.  Interestingly, the `n` in `then` in line
5 kept disappearing.  Something to investigate...

Finally, I got it settled on this, spot the differences:

```
▓▒░$ cat grep
#!/bin/ksh
needle="${1:?No search term given}"
count=1

if [ -r "${2}" ]; then
  while IFS='\n' read -r line; do
    case "${line}" in
      (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
    esac
    count=$(( count + 1 ))
  done < "${2}"
else
  while IFS='\n' read -r line; do
    case "${line}" in
      (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
    esac
    count=$(( count + 1 ))
  done
fi
```

And we can now show it at work:

```
▓▒░$ grep line grep
0006:   while IFS='\n' read -r line; do
0007:     case "${line}" in
0008:       (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
0013:   while IFS='\n' read -r line; do
0014:     case "${line}" in
0015:       (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
```

### `least`

Potentially we could create a simple paginator, but in all honesty, at this
point we'd just be doing it for the fun of it.  We have sufficient tooling now
to edit and correct code in a higher language...

### `cled` version 0.0.2

Spitballing...

```
#!/bin/ksh
fsobj="${1:?No target specified}"
if [ -e "${fsobj}" ]; then
  if [ -w "${fsobj}" ]; then
    printf -- '%s\n' "File exists, use the *ln tools to edit it" >&2
    exit 1
  else
    printf -- '%s\n' "File is not writeable" >&2
    exit 1
  fi
else
  printf -- '%s\n' "Enter one line at a time, ctrl-D to finish" >&2
  cat > "${fsobj}"
fi
```
