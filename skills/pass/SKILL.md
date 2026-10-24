---
name: pass
description: Use this skill when accessing credentials stored in pass, using passenv/passkeys, or preparing authenticated CLI/API commands that need pass-store secrets. Discover only entry and variable names; inject values into a child process with passenv instead of printing passwords or copying them into chat. Applies across projects, not just homelab.
metadata:
  version: "1.0.1"
---

# Credential Handling via pass

For projects using this skill, credentials are stored in the password store (`pass`).

**Cardinal rule: do not put secret values in the chat transcript.** The helpers
read entries internally and export `KEY=VALUE` lines only to their child process.
The child command's output is still your responsibility: avoid debug logging,
environment dumps and commands that echo credentials. Environment variables
are readable by the process and potentially by other processes with sufficient
OS privileges; this is not an isolation boundary.

## Enforcement

Do not run `pass show <entry>`, `pass grep ...`, bare `pass <entry>`, or read
password-store files directly through agent tools: they print credentials.
The wrappers call `pass show` internally but never expose its raw output.
This skill is guidance, **not** an access-control mechanism. The homelab repo
also has OpenCode permission rules and may have agent-specific hooks, but
other projects must configure their own safeguards; don't assume commands
are automatically blocked everywhere.

Use `pass ls`, `pass find` or `pass help` for metadata. **Do not assume**
`pass generate`, `pass insert` or `pass edit` are metadata-only: they can print
or display a credential. Handle store changes in a trusted interactive terminal
with an output plan, not by default in an agent tool transcript.

## Workflow

1. Discover which entries exist (names only — no values):
   ```bash
   pass ls
   ```

2. Discover the variable names inside an entry (names only — no values):
   ```bash
   passkeys <entry>        # e.g. passkeys sa-snowflake  ->  SNOWFLAKE_USER, ...
   ```

3. Run a command with the entry's variables exported (the wrapper does not
   print values; the child command might):
   ```bash
   passenv <entry> -- <command-using-$VARS>
   ```
   Example:
   ```bash
   passenv sa-snowflake -- snow sql -q 'select current_user()'
   ```
   Everything after `--` runs with the entry's `KEY=VALUE` lines exported. The
   variables exist only inside that command's process.

The helpers live in this skill's `scripts/`. After installing the skill globally,
run `python3 ~/.config/opencode/skills/pass/scripts/install_helpers.py` to
create `passenv` and `passkeys` launchers in `~/.local/bin`. It refuses to
overwrite different existing files unless you explicitly pass `--replace`.
Ensure `~/.local/bin` is in your PATH; other agents may install skills elsewhere,
so run `install_helpers.py` from the actual installed skill directory.

## Hard rules

- Reference secrets only as variables (`$SNOWFLAKE_USER`, `${TOKEN}`) — never
  echo, printenv, env-dump, or expand their values.
- Do not write a secret value to a file or a command-line argument; pass it via
  the environment when the receiving program supports that. If it needs a
  file or argv, stop and choose a safer, application-specific method.
- Never ask the user to paste a credential into the conversation.
- Never `cat`/`read` the pass store's internal files (`~/.password-store/…`) —
  same rule as `pass show`, treated as blocked.

## Project convention

Project-specific CLAUDE.md files declare which pass entry to use, e.g.:

```
## Credentials
Secrets are in pass under `env/myproject`. Run authenticated commands with:
  passenv env/myproject -- <command>
```
