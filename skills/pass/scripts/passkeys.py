#!/usr/bin/env python3
"""List variable names from one pass entry; never print raw entry lines."""

import sys

# Avoid creating __pycache__ inside the globally installed skill at runtime.
sys.dont_write_bytecode = True

from passenv import print_names


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: passkeys <entry>\n")
        sys.exit(2)
    print_names(sys.argv[1])
