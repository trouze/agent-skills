# OpenCode V2 global configuration

`opencode.jsonc` is a portable, credential-free V2 policy baseline. Installing
it globally protects every OpenCode project on the machine; `gh skill install`
alone does **not** install harness configuration.

The ordered `policies` deny direct `pass` execution, then lift the denial only
for metadata commands (`ls`, `find`, `help`, `--version`). These global policy
denials override project permissions and saved approvals. `passenv` prompts
before use; `passkeys` lists variable names only. The older `pass generate`,
`insert` and `edit` allowances are intentionally removed because they can
display passwords. Use a trusted terminal to manage the password store.

## Install or update

Review a pinned `trouze/agent-skills` release and check it out locally. From
that checkout:

```sh
python3 scripts/install-opencode.py          # preview and check for conflicts
python3 scripts/install-opencode.py --apply  # backup first, then install
```

The installer preserves a backup of existing global configs and the old
`plugin/block-pass-secrets.ts` in `~/.config/opencode/backups/`. It refuses
unrecognized or hand-edited config instead of silently discarding it; use
`--replace-reviewed` only after inspecting the diff and backup. It never
changes a project config, CLI preferences (`cli.json`), service credentials, or
the V1 `@opencode-ai/plugin` package. Open a **new** OpenCode session or reload
configuration when ready; do not restart a running service just to install a
file. To roll back, restore the dated backup's files to their original paths.

The retired plugin checked for a V1 `bash` tool ID and allowed secret-displaying
commands such as `pass generate`. V2 policies replace its intended direct
command protection without a regex that mistakes documentation strings for
shell execution. This is **not** a complete sandbox: an arbitrary Python/shell
program, or a child launched by `passenv`, can still print secrets. Review the
command and its output before granting access.
