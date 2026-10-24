#!/usr/bin/env python3
"""Load a pass entry's KEY=VALUE lines as environment variables and run a command.

This helper does not print secret values itself. The executed command can still
print them, so inspect its output and avoid environment dumps or debug traces.

Usage:
  passenv <entry>             Print the variable NAMES only (no values).
  passenv <entry> -- cmd...   Run `cmd` with the entry's variables exported.
"""

import os
import re
import subprocess
import sys

KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")


def entry_lines(entry):
    if not entry or entry.startswith("-") or "\n" in entry:
        sys.stderr.write("Invalid pass entry name.\n")
        sys.exit(2)
    proc = subprocess.run(["pass", "show", entry], capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        sys.exit(proc.returncode)
    return proc.stdout.splitlines()


def load_env(entry):
    env = dict(os.environ)
    for line in entry_lines(entry):
        m = KEY_RE.match(line)
        if m:
            env[m.group(1)] = m.group(2)
    return env


def print_names(entry):
    for line in entry_lines(entry):
        m = KEY_RE.fullmatch(line)
        if m:
            print(m.group(1))


def main():
    args = sys.argv[1:]
    if not args:
        sys.stderr.write("Usage: passenv <entry> [-- command...]\n")
        sys.exit(1)

    entry, rest = args[0], args[1:]

    if not rest or rest[0] != "--":
        # Names only — never the values.
        print_names(entry)
        return

    cmd = rest[1:]
    if not cmd:
        sys.stderr.write("Usage: passenv <entry> -- command...\n")
        sys.exit(1)

    os.execvpe(cmd[0], cmd, load_env(entry))


if __name__ == "__main__":
    main()
