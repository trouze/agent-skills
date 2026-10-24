#!/usr/bin/env python3
"""Install thin user-local launchers for the installed pass skill."""

import argparse
import os
from pathlib import Path
import shlex
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replace", action="store_true", help="replace existing launchers")
    args = parser.parse_args()

    source = Path(__file__).resolve().parent
    target = Path.home() / ".local" / "bin"
    target.mkdir(parents=True, exist_ok=True)

    plans = []
    for name in ("passenv", "passkeys"):
        dest = target / name
        script = shlex.quote(str(source / (name + ".py")))
        contents = f"#!/bin/sh\nexec python3 {script} \"$@\"\n"
        if dest.exists() or dest.is_symlink():
            if dest.is_file() and dest.read_text() == contents:
                print(f"Already installed: {dest}")
                continue
            if not args.replace:
                parser.error(f"{dest} exists; review it and pass --replace to overwrite")
        plans.append((name, dest, contents))

    for name, dest, contents in plans:
        fd, tmp = tempfile.mkstemp(dir=target, prefix=f".{name}.")
        try:
            with os.fdopen(fd, "w") as out:
                out.write(contents)
            os.chmod(tmp, 0o755)
            os.replace(tmp, dest)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        print(f"Installed: {dest}")


if __name__ == "__main__":
    main()
