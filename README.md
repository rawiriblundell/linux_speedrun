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
>
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

```bash
echo "#!/bin/ksh" > cp
echo 'cat "${1:?No source specified}" > "${2:?No target specified}"' >> cp
```

Alternatively, a heredoc approach could be used e.g.

```bash
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

## /dev/stdin check

On Linux, there should be a `/dev/stdin` available.  If so, this makes our tool
creation so much simpler.  We test like so:

```bash
▓▒░$ [ -r /dev/stdin ] && echo $?
0
▓▒░$ while read -r line; do echo $line; done < /dev/stdin
test  # I typed this in and pressed enter
test  # This was echoed back
# [ctrl-D]
```

If this is present and working, that means that for tools that may read either
a file or stdin, we can structure them like this:

```bash
while IFS='\n' read -r line; do
  # Do stuff
done < "${1:/dev/stdin}"
```

If `/dev/stdin` isn't available, then we have to structure those same checks like so:

```bash
if [ -r "${1}" ]; then
  while IFS='\n' read -r line; do
    # Do stuff
  done < "${1}"
else
  while IFS='\n' read -r line; do
    # Do stuff
  done
fi
```

Alternatively, you could structure these tools like this:

```bash
while IFS='\n' read -r line; do
  # Do stuff
done
```

But you must remember to redirect files into your tools e.g.

`mytool < somefile`

## Log of commands for generating these tools

### `cled`

The first tool I created was `cled`, which simply wraps `cat`.

What's with the name?  "`c`ommand`l`ine `ed`itor".  Because "`s`hell `ed`itor", or "`s`imple `ed`itor" was
taken, and "`sh`ell `i`nput `t`ext" didn't seem appropriate, despite its truthiness :)

**WARNING:** Note that this does not test for existing files, nor does it prompt for overwrites!

```bash
▓▒░$ cat > cled
#!/bin/ksh
printf -- '%s\n' "Enter one line at a time.  Press ctrl-D to exit." >&2
cat > "${1:?No target specified}"
```

I entered ctrl-D and `cled` was written.

Next, assuming we don't have `chmod`, to overcome this, we create an alias:

```bash
▓▒░$ alias cled="/bin/ksh $PWD/cled"
▓▒░$ type cled
cled is an alias for '/bin/ksh /home/rawiri/git/linux_speedrun/cled'
```

From now on, to create a file, you run `cled [target]`

**For the extreme speedrunners, this should be enough, and they're onwards to coding in C**

For a terser version, this could be dealt with as a shell function e.g.

```bash
cled() { cat > "${1:?}"; }
```

We may add features to `cled` later on...

### `ls`

For a very simple directory listing, we can use shell globbing and `printf`

```bash
▓▒░$ cled ls
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
printf -- '%s\n' ./.* ./*
```

And we can test it in use:

```bash
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

```bash
▓▒░$ alias ls="/bin/ksh $PWD/ls"
```

We could make a shell based `ls` that gives more detail by running a battery
of tests against each fs object, for now we just need to know what's in the current dir.
Perhaps the only change worth adding would be a directory test - if it's a dir, append a `/`.
Maybe something to revisit later...

### `addln`

We may want to add a line to a file.  Normally this would be a `echo "content" >> file`, but
as we will be creating other tools like `rmln`, we may as well create this for consistency.

```bash
▓▒░$ cled addln
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
target="${1:?No target specified}"
shift 1
printf -- '%s\n' "${*}" >> "${target}"
```

And let's test it:

```bash
▓▒░$ ksh addln ls "#this is a testline"
▓▒░$ cat ls
#!/bin/ksh
printf -- '%s\n' ./.* ./*
#this is a testline
```

### `cp`

`cp` is a basic enough task:

```bash
▓▒░$ cled cp
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
cat "${1:?No source specified}" > "${2:?No destination specified}"
```

### `head`

We're going to need a simple `head` variant to enable us to do things like insert
lines at specific line numbers.  This code defaults to 10 lines (stdin).

Obviously, if a file is specified, then so must the linecount.

```bash
▓▒░$ cled head
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
lines="${1:-10}"
count=0

while IFS='\n' read -r line; do
  printf -- '%s\n' "${line}"
  count=$(( count + 1 ))
  [ "${count}" -eq "${lines}" ] && return 0
done < "${2:-/dev/stdin}"
```

And the test:

```bash
▓▒░$ ksh head 2 head
#!/bin/ksh
lines="${1:-10}"
```

### `nl`

Most of our editing functions work on specific line numbers.  For us to know
our target line numbers, we need to see the code printed out with them.

In Linux, `cat` should have the `-n` option that achieves the same thing, if not,
we can replicate the `nl` tool like this

```bash
▓▒░$ cled nl
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
count=1

while IFS='\n' read -r line; do
  printf -- '%04d: %s\n' "${count}" "${line}"
  count=$(( count + 1 ))
done < "${1:-/dev/stdin}"
```

And test it like so:

```bash
▓▒░$ ksh nl cled
0001: #!/bin/ksh
0002: printf -- '%s\n' "Enter one line at a time.  Press ctrl-D to exit." >&2
0003: cat > "${1:?No target specified}"
```

And we can start piping things together:

```bash
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

```bash
▓▒░$ cled behead
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
lines="${1:-5}"
count=0

while IFS='\n' read -r line; do
  if (( count >= lines )); then
    printf -- '%s\n' "${line}"
  fi
  count=$(( count + 1 ))
done < "${2:-/dev/stdin}"
```

Okay, so after setting up an `alias`, we can test it:

```bash
▓▒░$ head 10 LICENSE | nl | behead 9
0010: software to the public domain. We make this dedication for the benefit
```

### `chln`

Now we mash `head` and `behead` together into a command to change a numbered line:

```bash
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

```bash
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

#### `chln` Example

Consider the following file with line numbers shown:

```bash
0001: A
0002: B
0003: C
0004: D
```

To change the second line would look something like this:

```bash
+head 1 file
+printf newcontent
+behead 2 file
```

Giving us:

```bash
0001: A
0002: newcontent
0003: C
0004: D
```

**NOTE: You will need to escape certain characters.**
**After every change, inspect and read it carefully.**

Example:

```bash
▓▒░$ chln 25 least "  case \"\${_ans}\" in"
```


### `rmln`

Right, so we know that `rmln` is going to be very similar in structure to `chln`, and
because we have `chln` and `cp`, then we may as well use those tools.  This is our
first demonstration of our makeshift numbered-line editing system!

```bash
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

```bash
nl chln
chln 7 chln ''
chln 7 chln '' > rmln
```

#### 'rmln' Example

To remove a line is much the same as changing it, you simply don't insert the change i.e.

Assuming again a simple file like this:

```bash
0001: A
0002: B
0003: C
0004: D
```

Applying essentially the following logic:

```bash
head 1 file
behead 2 file
```

That will give us:

```bash
0001: A
0002: C
0003: D
```

So let's say we've `nl`'d or `cat -n`'d my example `.bashrc` from above, and we want to delete line number 2:

```bash
0001: # shellcheck shell=bash
0002: ################################################################################
0003: # .bashrc
0004: # Please don't copy anything below unless you understand what the code does!
0005: # If you're looking for a licence... WTFPL plus Warranty Clause:
0006: #
```

Becomes:

```bash
▓▒░$ rmln 2 ~/.bashrc | head 5
# shellcheck shell=bash
# .bashrc
# Please don't copy anything below unless you understand what the code does!
# If you're looking for a licence... WTFPL plus Warranty Clause:
#
```

### `insln`

We may want to insert a line at a numbered point

```bash
▓▒░$ cp chln tmp.insln

▓▒░$ nl tmp.insln
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

```bash
▓▒░$ chln 8 chln '/bin/ksh /home/rawiri/git/linux_speedrun/behead "$(( target_line - 1 ))" "${fs_obj}"' > insln
```

Then we add an alias, because we're tracking these in an `aliases` file now.

```bash
addln aliases 'alias insln="/bin/ksh $PWD/insln"'
```

#### 'insln' Example

Consider the following file with line numbers shown:

```bash
0001: A
0002: B
0003: C
0004: D
```

To insert a line between the second and third lines would look something like this:

```bash
+head 2 file
+printf newcontent
+behead 2 file
```

Giving us:

```bash
0001: A
0002: B
0003: newcontent
0004: C
0005: D
```

### `lncount`

Having a line count may be useful

```bash
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

This isn't really a full blown `grep`, it's more of a "does a file contain a string?",
which isn't worthy of the 're' in `grep`.  It's a familiar command name and its
usage, provided it's basic, will also be familiar while serving its purpose.

To save us from having to read through scripts, we can simply print numbered
matching lines.  This started out like this, but the keen eye will note the errors:

```bash
▓▒░$ cled grep
Enter one line at a time.  Press ctrl-D to exit.
#!/bin/ksh
needle="${1:?No search term given}"
count=1

while IFS='\n' read -r line; do
  case "${line}" in
    (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "{line}" ;;
  esac
done < "${1:/dev/stdin}"
```

This resulted in a flurry of `chln`, `insln` and `rmln` calls bouncing back and
forward between `grep` and `tmp.grep`.  Interestingly, the `n` in `then` in line
5 kept disappearing.  Something to investigate...

Finally, I got it settled on this, spot the differences:

```bash
▓▒░$ cat grep
#!/bin/ksh
needle="${1:?No search term given}"
count=1

while IFS='\n' read -r line; do
  case "${line}" in
    (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
  esac
  count=$(( count + 1 ))
done < "${2:-/dev/stdin}"
```

And we can now show it at work:

```bash
▓▒░$ grep line grep
0005: while IFS='\n' read -r line; do
0006:   case "${line}" in
0007:     (*"${needle}"*) printf -- '%04d: %s\n' "${count}" "${line}" ;;
```

### `least`

For larger files, we can create a simple paginator, but in all honesty, at this
point we'd just be doing it for the fun of it.  We have sufficient tooling now
to edit and correct code in a higher language...

What we can do is simply grab the number of available terminal lines and use
`head` and `behead` to fill them, with a pause that waits for a keypress.  After
an evening of half-hearted shell wrangling between
[Nickolas](https://www.youtube.com/watch?v=l_Vqp1dPuPo)
[Means](https://www.youtube.com/watch?v=NLXys9vgWiY)
[talks](https://www.youtube.com/watch?v=hMk6rF4Tzsg),
I came up with this:

```bash
#!/bin/ksh

if stty size >/dev/null 2>&1; then
  read -r lines columns < <(stty size)
elif [ -n "${COLUMNS}" ]; then
  columns="${COLUMNS}"
  lines="${LINES}"
fi

columns="${columns:-80}"
lines="${lines:-20}"

# We halve the number of lines to allow for line wrapping etc
lines=$(( lines / 2 ))
linesread=0

#Start infinite loop
while true; do
  /bin/ksh /home/rawiri/git/linux_speedrun/nl < "${1:-/dev/stdin}" |
    /bin/ksh /home/rawiri/git/linux_speedrun/behead "${linesread}" |
    /bin/ksh /home/rawiri/git/linux_speedrun/head "${lines}"
  linesread=$(( linesread + lines ))
  printf -- '\t%s' "Press q, then [Enter] to quit, or [Enter] to continue" >&2
  read -r _ans
  case "${_ans}" in
    (q*|Q*) exit 0 ;;
    (''|*) continue ;;
  esac
done
```

### `cled` version 0.0.2

Spitballing...

```bash
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

## Upgrades

So while working on `least`, I got annoyed at the amount of times I had to
manually go back and forward between a temp file and a main file e.g.

```bash
insln 10 least something > tmp.insln
cp tmp.insln insln
```

Rinse and repeat that for every line insertion, change or deletion.

So I invested a small amount of time upgrading these tools to automatically do
this.  Here's how, using `insln` as an example

```bash
▓▒░$ nl insln
0001: #!/bin/ksh
0002: target_line="${1:?No line specified}"
0003: fs_obj="${2:?No file specified}"
0004: shift 2
0005:
0006: /bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
0007: printf -- '%s\n' "${*}"
0008: /bin/ksh /home/rawiri/git/linux_speedrun/behead "$(( target_line - 1 ))" "${fs_obj}"
▓▒░$ insln 4 insln 'tmp_obj=".tmp.${fs_obj}"' > .tmp.insln
▓▒░$ cp .tmp.insln insln
▓▒░$ nl insln
0001: #!/bin/ksh
0002: target_line="${1:?No line specified}"
0003: fs_obj="${2:?No file specified}"
0004: tmp_obj=".tmp.${fs_obj}"
0005: shift 2
0006:
0007: /bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
0008: printf -- '%s\n' "${*}"
0009: /bin/ksh /home/rawiri/git/linux_speedrun/behead "$(( target_line - 1 ))" "${fs_obj}"
▓▒░$ insln 7 insln '{' > .tmp.insln
▓▒░$ cp .tmp.insln insln
▓▒░$ addln insln '} > "${tmp_obj}"'
▓▒░$ addln insln 'cp "${tmp_obj}" "${fs_obj}"'
▓▒░$ cat insln
#!/bin/ksh
target_line="${1:?No line specified}"
fs_obj="${2:?No file specified}"
tmp_obj=".tmp.${fs_obj}"
shift 2

{
/bin/ksh /home/rawiri/git/linux_speedrun/head "$(( target_line - 1 ))" "${fs_obj}"
printf -- '%s\n' "${*}"
/bin/ksh /home/rawiri/git/linux_speedrun/behead "$(( target_line - 1 ))" "${fs_obj}"
} > "${tmp_obj}"
cp "${tmp_obj}" "${fs_obj}"
```

Now let's test it:

```bash
▓▒░$ nl testabet
0001: A
0002: B
0003: C
0004: D
0005: E
0006: F
0007: G
▓▒░$ insln 5 testabet pants
▓▒░$ cat testabet
A
B
C
D
pants
E
F
G
```

So good.

Obviously, this does now mean that these tools need to be used with extra care.
