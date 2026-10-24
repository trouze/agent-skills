# Portable Dagger / exe.dev skill

Reusable agent instructions, scripts and templates for:

- Dagger **v1.0.0-beta.21** and native Dang modules.
- Local Colima development.
- One private shared engine/cache on the existing exe.dev VM.
- Trusted GitHub Actions runs through authenticated SSH.

**No private keys or registered credentials are included.** This package does
not register CI access, install a runner on the VM, or change VM services.

## Install for agent use

See the [repository README](../../README.md) for the global, pinned
`gh skill install` command and the CI checkout pattern. The globally installed
skill works from any project on your machine. Do not vendor copies into each
project merely to make the agent discover it. Do **not** commit machine SSH
config or key files.

## Quick start

From your project root:

```bash
export SKILL="$HOME/.config/opencode/skills/dagger-exe" # gh skill install --agent opencode --scope user
"$SKILL/scripts/install-cli.sh"
export PATH="$HOME/.local/bin:$PATH"
```

For local Colima:

```bash
# Install Colima/Lima and Docker's CLI first; review available resources.
colima start --runtime docker --cpus 2 --memory 4 --disk 30
"$SKILL/scripts/doctor.sh" local
"$SKILL/scripts/with-engine.sh" local check
```

For this VM's remote engine, complete
[`references/remote-engine.md`](references/remote-engine.md), then:

```bash
"$SKILL/scripts/create-remote-context.sh"
"$SKILL/scripts/doctor.sh" remote
"$SKILL/scripts/with-engine.sh" remote check
```

You can invoke your agent with:

> Use the dagger-exe skill to inspect this project's existing Dang pipeline,
> run it locally, and add a trusted GitHub Actions workflow using my shared
> exe.dev Dagger engine. Don't change the engine version or run untrusted PRs.

## GitHub Actions

Read [`references/github-actions.md`](references/github-actions.md) first.
Then adapt `assets/github-actions.yml` to `.github/workflows/dagger.yml`.
Replace the pinned SHA placeholder in its second checkout with the full SHA
of a reviewed release. The workflow runs scripts from
`.ci/agent-skills/skills/dagger-exe`; nothing is vendored in the project.

Create and restrict the `dagger-exe` GitHub Environment to your trusted default
branch. Register a **dedicated VM-scoped SSH public key** from your trusted
workstation:

```bash
mkdir -p "$HOME/.ssh"
ssh-keygen -t ed25519 -N '' -f "$HOME/.ssh/dagger-ci-owner-repo" \
  -C 'dagger-ci:OWNER/REPO'
cat "$HOME/.ssh/dagger-ci-owner-repo.pub" | ssh exe.dev ssh-key add --vm=dagger
```

Do not overwrite an existing key. Add environment secrets:

- `EXE_DAGGER_SSH_KEY`: that dedicated CI private key.
- `EXE_DAGGER_KNOWN_HOSTS`: SSH host keys exported from an **already verified**
  connection to the actual host. Do not blindly trust a CI `ssh-keyscan`.

Default variables point to the existing VM:

| Variable | Default |
|---|---|
| `EXE_DAGGER_HOST` | `vm.exe.xyz` |
| `EXE_DAGGER_USER` | `vm+dagger` |
| `EXE_DAGGER_SOCKET` | `/home/exedev/.config/colima/default/docker.sock` |

The username routes to VM `dagger`; commands inside it run as `exedev`.
Copy/adapt the same workflow in each trusted repository, preferably with a
separate per-repository key. Replace `check --parallel 2` with your existing
project's entry point if needed. No public Docker/Dagger port is involved.

## What's bundled

| Path | Purpose |
|---|---|
| `SKILL.md` | Agent entry point, decision process and safety rules |
| `scripts/install-cli.sh` | Checksum-pinned Linux/macOS CLI installer |
| `scripts/with-engine.sh` | Per-command `local`, `remote`, or `vm` mode |
| `scripts/create-remote-context.sh` | Idempotent SSH Docker-context setup |
| `scripts/configure-ci-ssh.sh` | Strict, noninteractive CI SSH setup |
| `scripts/doctor.sh` | Version, connection and container execution checks |
| `scripts/cache-probe.sh` | Non-destructive cross-directory cache probe |
| `assets/github-actions.yml` | Pinned, trusted-main CI workflow template |
| `assets/ssh-config.example` | Laptop SSH alias example |
| `assets/dang-module/` | Minimal native Dang wiring smoke test |
| `references/` | Local development, remote access, CI and VM operations |

## Constraints

- Personal/trusted projects only. A VM-scoped key can control the VM, not just
  one engine. A shared privileged engine/cache is not tenant isolation.
- No fork/unreviewed PR workflows. Don't combine `pull_request_target`, these
  credentials, and untrusted code.
- GitHub concurrency is per repository, not a global multi-project queue.
- Cache GC targets are best-effort; the VM has limited RAM and disk.
- The exact beta is intentionally pinned. Review coordinated CLI/engine/SDK
  upgrades, cache schema changes, installer checksums and Actions pins.
- CI needs your key registration, host trust and GitHub secrets. No package
  can make that account setup automatic without your credentials.

Validation details are in `VALIDATION.md`.
