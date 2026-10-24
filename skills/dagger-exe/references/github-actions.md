# GitHub Actions through the persistent exe.dev engine

Use a **GitHub-hosted runner** for checkout and the Dagger CLI; use the existing
exe.dev VM only for the remote engine and its persistent cache. Do not install a
self-hosted Actions runner on this VM by default.

The ready-to-copy workflow is [`../assets/github-actions.yml`](../assets/github-actions.yml).
Adapt the workflow to `.github/workflows/dagger.yml`. It checks out this
public skill repository at a reviewed release's full commit SHA under
`.ci/agent-skills/skills/dagger-exe/`. Replace the placeholder SHA before
enabling it. Commit the workflow and project-specific Dagger module together;
do not vendor the skill into the project. Review its Dagger command first.

## 1. Register a dedicated, VM-scoped CI key

On your trusted local machine, generate a separate key for this repository:

```sh
mkdir -p "$HOME/.ssh"
ssh-keygen -t ed25519 -N '' -f "$HOME/.ssh/dagger-ci-owner-repo" -C 'dagger-ci:OWNER/REPO'
cat "$HOME/.ssh/dagger-ci-owner-repo.pub" | ssh exe.dev ssh-key add --vm=dagger
```

Replace `dagger` with the actual VM name. Do not upload your personal account
private key to GitHub. The VM-scoped key can access this VM, not your other VMs;
it can also sign HTTPS tokens for this VM. It is **not** a restricted
“Dagger-only” or repository-only credential.

Official registration and scope:
<https://exe.dev/docs/vm-scoped-ssh-keys.md>.

Discover the actual SSH destination using your existing trusted account access:

```sh
ssh exe.dev ls --json
```

The workflow defaults to exe.dev's explicitly routed, documented destination:
host **`vm.exe.xyz`**, user **`vm+dagger`**. For another VM name use
`vm+YOUR_VM_NAME`. This username selects the VM; it is not the Linux account
name. The workflow's local SSH alias remains `dagger-exe-vm`.

Alternatively, after verifying your actual API metadata and SSH connection,
use the matching VM's `ssh_host` and, when present, **its exact `ssh_user`**.
Direct `dagger.exe.xyz` with user `exedev` is an option only after verifying
that it works for your VM. `ssh_dest` is the ready-to-use destination; do not
put a combined `user@host` string into the host variable.

Official guaranteed routing form:
<https://exe.dev/docs/faq/ssh-destination.md>.
API field definitions: <https://exe.dev/docs/api.md>.

## 2. Establish trusted host keys locally

First connect from your trusted local machine to the actual destination and
verify its host-key fingerprint using an already trusted source or connection.
For the default route, this means an already verified connection to
`vm+dagger@vm.exe.xyz` and the trusted **`vm.exe.xyz`** host key.
Export the matching entries from your workstation's existing trusted file:

```sh
ssh-keygen -F vm.exe.xyz -f "$HOME/.ssh/known_hosts" |
  sed '/^#/d' > ./dagger-ci-known-hosts
```

Check that this file is nonempty and corresponds to the previously verified
connection, then copy its complete contents into the GitHub secret below.
Preserve hashed entries if your local file uses them. No owner workstation
host key is supplied with this skill; no published fingerprint should be
treated as automatically trusted.

The entries must match the **actual network hostname** used in
`EXE_DAGGER_HOST`, including bracketed host/port notation if applicable—not
merely the workflow's local SSH alias. Recheck entries if the destination or
provider host keys change.

Do not generate trust with an unverified `ssh-keyscan` during CI, and do not
use `StrictHostKeyChecking=no`. A key scan discovers keys; it does not
authenticate them.

## 3. Configure GitHub

Create the repository's GitHub Environment named **`dagger-exe`**. The supplied
workflow selects it. Configure the following environment secrets and variables,
or equivalent repository/organization settings available to that repository:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `EXE_DAGGER_SSH_KEY` | Entire contents of `~/.ssh/dagger-ci-owner-repo`, including its header/footer and newlines. |
| Secret | `EXE_DAGGER_KNOWN_HOSTS` | Previously verified `known_hosts` entries for the actual SSH host. |
| Variable | `EXE_DAGGER_HOST` | Workflow fallback `vm.exe.xyz`; alternatively a verified API `ssh_host`. |
| Variable | `EXE_DAGGER_USER` | Workflow fallback `vm+dagger`; change to `vm+YOUR_VM_NAME` for another VM, or use the exact verified API `ssh_user` for an alternative route. |
| Variable | `EXE_DAGGER_SOCKET` | Remote Colima Docker socket; default `/home/exedev/.config/colima/default/docker.sock`. |

The socket is an absolute path **on the remote VM**, not on the GitHub runner.
Confirm these defaults match your VM name; particularly do not replace a
required routing username with `exedev`. For the default route,
`EXE_DAGGER_KNOWN_HOSTS` must contain the trusted `vm.exe.xyz` entry, not only
an entry for `dagger.exe.xyz`.

For stronger control, configure environment deployment branches to allow only
`main`, and optionally require reviewer approval. Creating an environment
alone does not configure approval or a branch allowlist. A manual dispatch
can otherwise select a different branch; the deployment restriction provides
an additional enforcement boundary.

For multiple repositories:

- Separate repository/environment secrets and a dedicated VM-scoped key per
  repository make revocation and auditing easier.
- Organization secrets/variables can share settings with explicitly selected
  trusted repositories. Sharing one private key expands the compromise and
  rotation scope to every recipient.
- Environment-level settings can override broader settings. Verify what the
  job actually receives, and configure each repository's environment
  protections; an organization secret does not supply those protections.
- Do not commit private keys or publish them with the skill.

GitHub documentation:
<https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>,
<https://docs.github.com/en/actions/reference/workflows-and-actions/variables>,
<https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments>.

## 4. Workflow behavior

The template intentionally uses:

- `push` to `main` and `workflow_dispatch` only—not `pull_request`.
- A GitHub-hosted `ubuntu-24.04` runner and `permissions: contents: read`.
- `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
  (`v7.0.1`), with `persist-credentials: false`.
- The pinned skill checkout's `scripts/install-cli.sh` to install the pinned
  `v1.0.0-beta.21` CLI with checksum verification, rather than an unpinned
  installation action.
- SSH alias `dagger-exe-vm`, the explicit private key, strict host-key checking,
  batch mode, and no SSH agent forwarding.
- Docker context `dagger-exe`, whose remote Docker endpoint is
  `ssh://dagger-exe-vm${EXE_DAGGER_SOCKET}`.
- `scripts/doctor.sh remote` before the project-specific pipeline.
  Use the same wrapper for the actual pipeline; do not silently fall back to a
  fresh local engine.

The wrapper selects the existing `dagger-shared` container through
`DAGGER_ENGINE=container+docker://dagger-shared`, with the legacy
`_EXPERIMENTAL_DAGGER_RUNNER_HOST` set consistently for compatibility. Docker
communicates over SSH to the existing Colima socket. This is **not** the
different `DAGGER_ENGINE=ssh://…` transport, which would require a remote
`buildctl` command.

No public Docker API or Dagger TCP port is required. Cleanup runs even on
failure to remove the temporary private key, SSH material, and Docker context
from the disposable runner. Cleanup does not delete the remote cache or stop
the shared engine.

As verified on October 24, 2026, the official latest checkout release is
`v7.0.1` (published July 20, 2026), and its tag resolves to the immutable commit
above. Revalidate before updating pins; never replace a full commit pin with a
moving major tag.

Primary verification:
<https://github.com/actions/checkout/releases/tag/v7.0.1>,
<https://api.github.com/repos/actions/checkout/releases/latest>,
<https://api.github.com/repos/actions/checkout/git/ref/tags/v7.0.1>.
The official README documents `persist-credentials`:
<https://github.com/actions/checkout/blob/v7.0.1/README.md>.
Docker documents SSH-backed contexts:
<https://docs.docker.com/engine/security/protect-access/>.

## Concurrency and capacity

The VM has only **2 CPUs and 4 GiB RAM**. Keep pipeline resource use modest.
The template's concurrency group coordinates runs **within one repository
only**, with `cancel-in-progress: false`; it avoids deliberately interrupting
the currently running pipeline.

An identical concurrency-group name in another repository does **not**
serialize that repository against this one. This template has no global
VM-side lock. Multiple projects can therefore overlap and exhaust memory or
CPU. Schedule them separately or implement a deliberate shared dispatcher or
whole-session lock if contention becomes a problem. Do not claim that this
workflow globally queues every project. Default GitHub concurrency may also
replace an older pending run rather than preserving an unlimited queue.

Cancelling a client run is not an instruction to restart the shared engine.
Do not add per-job remote engine teardown: other projects may be using it.

Official concurrency semantics:
<https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency>.

## Trust boundary

Treat possession of this SSH credential as **full access to the shared VM**
for security planning. The VM account can reach Docker, and the Dagger engine
is privileged. A persistent engine/cache is not a safe isolation boundary
between mutually untrusted projects.

Only trusted repositories, workflow authors, pipeline code, and dependencies
should execute here. `contents: read` limits the GitHub token, **not** the SSH
key, Docker access, VM integrations, or persistent cache. A malicious workflow
can use the key independently of the intended Dagger command. A compromised
run may affect later jobs or other projects even after that Actions job ends.

Fork pull requests do not receive these keys in the default design. Do not
“fix” that by adding `pull_request_target` and then checking out or executing
the fork's code. Likewise, do not process untrusted artifacts or reusable
workflow callers with these credentials. If you deliberately add a reusable
workflow later, explicitly declare/pass only its required secrets, pin
cross-repository workflow references, and restrict callers to trusted code.

Review workflow and dependency changes before merging. For untrusted PRs,
use an isolated disposable engine/VM without these credentials or caches.
After a suspected compromise, revoke the key, rotate affected credentials,
and rebuild the VM/cache; revoking an SSH key alone does not remove existing
persistence.

Official GitHub security guidance:
<https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>.

## Validation and troubleshooting

This workflow cannot be end-to-end validated until **you register the CI
public key and configure the GitHub secrets/variables**. A working local
engine or successful local SSH session alone does not prove Actions access.

Run `workflow_dispatch` from the trusted `main` branch first. The preflight
should confirm remote Docker access and the existing engine; then run a small
pipeline twice to check reuse. Do not print private keys or enable shell
tracing around secrets.

- **Host-key verification failed:** inspect the actual destination and the
  trusted `known_hosts` entries. Verify changes independently; never bypass
  checking to make the job pass.
- **Permission denied (publickey):** check VM-scoped registration, exact key
  contents, and the API-required routing username.
- **Cannot connect to Docker:** check the remote socket path, Colima status,
  and the remote account's socket access. Do not expose an unauthenticated
  Docker TCP endpoint.
- **Engine missing/unhealthy:** inspect the existing VM services using trusted
  administrative access; do not have every CI job recreate the shared engine.
- **Secrets unavailable:** check environment approval, branch restrictions,
  environment/repository scope, and organization repository allowlists.
- **Out of memory or excessive queuing:** check simultaneous runs from other
  repositories; repository-local concurrency is not a global limiter.
