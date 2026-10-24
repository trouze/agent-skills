#!/usr/bin/env python3
"""Install a reviewed OpenCode V2 global config, backing up old files first."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import tempfile


SOURCE = Path(__file__).resolve().parents[1] / "harnesses" / "opencode" / "opencode.jsonc"
SCHEMA_ONLY = {"$schema": "https://opencode.ai/config.json"}
LEGACY = {
    "$schema": "https://opencode.ai/config.json",
    "permission": {
        "bash": {
            "pass": "deny", "pass *": "deny", "pass ls*": "allow",
            "pass find *": "allow", "pass git *": "allow",
            "pass insert *": "allow", "pass generate *": "allow",
            "pass edit *": "allow", "pass rm *": "allow",
            "pass mv *": "allow", "pass cp *": "allow",
            "pass help*": "allow", "pass --version": "allow",
            "passenv *": "allow", "passkeys *": "allow",
        }
    },
}


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (ValueError, UnicodeError) as err:
        raise ValueError(f"Cannot safely parse {path}; review manually: {err}") from err


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="back up and install")
    parser.add_argument("--replace-reviewed", action="store_true", help="replace changed config after review")
    parser.add_argument("--config-dir", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    root = args.config_dir or Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "opencode"
    root = root.expanduser()
    new = root / "opencode.jsonc"
    old = root / "opencode.json"
    plugin = root / "plugin" / "block-pass-secrets.ts"
    desired = read_json(SOURCE)

    for path, allowed in ((new, (SCHEMA_ONLY, desired)), (old, (LEGACY, SCHEMA_ONLY))):
        if path.exists() and read_json(path) not in allowed and not args.replace_reviewed:
            parser.error(f"{path} has unrecognized settings; review and pass --replace-reviewed")
    if new.exists() and read_json(new) == desired and not old.exists() and not plugin.exists():
        print("OpenCode V2 global config is already installed.")
        return

    existing = [path for path in (new, old, plugin) if path.exists()]
    print(f"Install {SOURCE} to {new}; archive {len(existing)} existing file(s).")
    for path in existing:
        print(f"  backup: {path}")
    if not args.apply:
        print("Preview only. Pass --apply to make changes.")
        return

    root.mkdir(parents=True, exist_ok=True)
    backup = root / "backups" / ("agent-skills-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    backup.mkdir(mode=0o700, parents=True)
    for path in existing:
        dest = backup / path.relative_to(root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
    fd, temp = tempfile.mkstemp(dir=root, prefix=".opencode.jsonc.")
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(desired, out, indent=2)
            out.write("\n")
        os.chmod(temp, 0o600)
        os.replace(temp, new)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    for path in (old, plugin):
        if path.exists():
            path.unlink()
    print(f"Installed OpenCode V2 config. Original files backed up at {backup}")
    print("Open a new OpenCode session or reload configuration when ready.")


if __name__ == "__main__":
    main()
