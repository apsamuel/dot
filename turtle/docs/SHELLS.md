# Shells

The text in this document primarily comes from the Linux Shells publication by [IBM®](https://developer.ibm.com/tutorials/l-linux-shells/).

## Shells as little languages

Shells are specialized, domain-specific languages ( little languages) that implement a specific use model — in this case, providing an interface to an operating system. In addition to text-based operating system shells, you can find graphical user interface shells as well as shells for languages (such as the Python shell or Ruby's irb). The shell idea has also been applied to Web searching through a web front end called goosh. This shell over Google permits command-line searching with Google using commands such as search, more, and go.

Ken Thompson (of Bell Labs) developed the first shell for UNIX called the V6 shell in 1971. Similar to its predecessor in Multics, this shell (/bin/sh) was an independent user program that executed outside of the kernel. Concepts like globbing (pattern matching for parameter expansion, such as *.txt) were implemented in a separate utility called glob, as was the if command to evaluate conditional expressions.

The shell introduced a compact syntax for redirection (`<` `>` and `>>`) and piping (`|` or `^`) that has survived into modern shells.

You can also find support for invoking sequential commands (with `;`) and asynchronous commands (with `&`).

What the Thompson shell lacked was the ability to script. Its sole purpose was as an interactive shell (command interpreter) to invoke commands and view results.

Here is an example of using redirection, piping, sequential commands, and asynchronous commands in a shell:

```sh
ls > filelist.txt ; cat filelist.txt | grep ".md" &
```

## Bourne Shell

The Bourne shell, created by Stephen Bourne at AT&T Bell Labs for V7 UNIX, remains a useful shell today (in some cases, as the default root shell). The author developed the Bourne shell after working on an ALGOL68 compiler, so you'll find its grammar more similar to the Algorithmic Language (ALGOL) than other shells. The source code itself, although developed in C, even made use of macros to give it an ALGOL68 flavor.

The Bourne shell had two primary goals: serve as a command interpreter to interactively execute commands for the operating system and for scripting (writing reusable scripts that could be invoked through the shell).

Here is an example of a Bourne shell script that finds all executable files in a specified directory:

```sh
#!/bin/sh
#find all executables
count=0
#Test arguments
if [ $# -ne 1 ] ; then
  echo "Usage is $0 <dir>"
  exit 1
fi
#Ensure argument is a directory
if [ ! -d "$1" ] ; then
  echo "$1 is not a directory."
  exit 1
fi
#Iterate the directory, emit executable files
for filename in "$1"/*
do
  if [ -x "$filename" ] ; then
    echo $filename
    count=$((count+1))
  fi
done
echo
echo "$count executable files found."
exit 0
```

## C Shell

The C shell was developed for Berkeley Software Distribution (BSD) UNIX systems by Bill Joy while he was a graduate student at the University of California, Berkeley, in 1978. Five years later, the shell introduced functionality from the Tenex system (popular on DEC PDP systems). Tenex introduced file name and command completion in addition to command-line editing features. The Tenex C shell (tcsh) remains backward-compatible with csh but improved its overall interactive features. The tcsh was developed by Ken Greer at Carnegie Mellon University.

One of the key design objectives for the C shell was to create a scripting language that looked similar to the C language. This was a useful goal, given that C was the primary language in use (in addition to the operating system being developed predominantly in C).

A useful feature introduced by Bill Joy in the C shell was command history. This feature maintained a history of the previously executed commands and allowed the user to review and easily select previous commands to execute. For example, typing the command history would show the previously executed commands. The up and down arrow keys could be used to select a command, or the previous command could be executed using !!. It's also possible to refer to arguments of the prior command; for example, !* refers to all arguments of the prior command, where !$ refers to the last argument of the prior command.

Here is an example of a C shell script that finds all executable files in a specified directory:

```sh
#!/bin/tcsh
#find all executables

set count=0

#Test arguments
if ($#argv != 1) then
  echo "Usage is $0 <dir>"
  exit 1
endif

#Ensure argument is a directory
if (! ‑d  $1) then
  echo "$1 is not a directory."
  exit 1
endif

#Iterate the directory, emit executable files
foreach filename ($1/∗)
  if (‑x $filename) then
    echo $filename
    @ count = $count + 1
  endif
end

echo
echo "$count executable files found."

exit 0
```

## Korn Shell

The Korn shell (ksh), designed by David Korn, was introduced around the same time as the Tenex C shell. One of the most interesting features of the Korn shell was its use as a scripting language in addition to being backward-compatible with the original Bourne shell.

The Korn shell was proprietary software until the year 2000, when it was released as open source (under the Common Public License). In addition to providing strong backward-compatibility with the Bourne shell, the Korn shell includes features from other shells (such as history from csh). The shell also provides several more advanced features found in modern scripting languages like Ruby and Python—for example, associative arrays and floating point arithmetic. The Korn shell is available in a number of operating systems, including IBM® AIX® and HP-UX, and strives to support the Portable Operating System Interface for UNIX (POSIX) shell language standard.

Here is an example of a Korn shell script that finds all executable files in a specified directory:

```sh
#!/usr/bin/ksh
#find all executables

count=0

#Test arguments
if [ $#‑ne 1 ] ; then
  echo "Usage is $0 <dir>"
  exit 1
fi

#Ensure argument is a directory
if [ ! ‑d  "$1" ] ; then
  echo "$1 is not a directory."
  exit 1
fi

#Iterate the directory, emit executable files
for filename in "$1"/∗
do
  if [ ‑x "$filename" ] ; then
    echo $filename
    count=$((count+1))
  fi
done

echo
echo "$count executable files found."

exit 0
```

## Bash

The Bourne-Again Shell, or Bash, is an open source GNU project intended to replace the Bourne shell. Bash was developed by Brian Fox and has become one of the most ubiquitous shells available (appearing in Linux, Darwin, Windows®, Cygwin, Novell, Haiku, and more). As its name implies, Bash is a superset of the Bourne shell, and most Bourne scripts can be executed unchanged.

In addition to supporting backward-compatibility for scripting, Bash has incorporated features from the Korn and C shells. You'll find command history, command-line editing, a directory stack (pushd and popd), many useful environment variables, command completion, and more.

Bash has continued to evolve, with new features, support for regular expressions (similar to Perl), and associative arrays. Although some of these features may not be present in other scripting languages, it's possible to write scripts that are compatible with other languages. To this point, the sample script shown in Listing 3 is identical to the Korn shell script (from Listing 2) except for the shebang difference (/bin/bash).

Here is an example of a Bash script that finds all executable files in a specified directory:

```bash
#!/bin/bash
#find all executables

count=0

#Test arguments
if [ $#‑ne 1 ] ; then
  echo "Usage is $0 <dir>"
  exit 1
fi

#Ensure argument is a directory
if [ ! ‑d  "$1" ] ; then
  echo "$1 is not a directory."
  exit 1
fi

#Iterate the directory, emit executable files
for filename in "$1"/∗
do
  if [ ‑x "$filename" ] ; then
    echo $filename
    count=$((count+1))
  fi
done

echo
echo "$count executable files found."

exit 0
```

### Citations

- This document was adapted from the Linux Shells publication by IBM®.

```bibtex
@misc{ibm_linux_shells,
  author = {IBM Corporation},
  title = {Linux Shells},
  year = {2024},
  publisher = {IBM},
  howpublished = {\url{https://developer.ibm.com/tutorials/l-linux-shells/}},
  note = {Accessed: 2024-06-15}
}
```

- `If you use Turtle in your research, please cite it as:

```bibtex
@misc{turtle_shell,
  author = {Aaron Samuel},
  title = {Turtle: A Modern Shell and Scripting Language},
  year = {2024},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/aaronsamuel/turtle}},
  note = {Accessed: 2024-06-15}
}
```
