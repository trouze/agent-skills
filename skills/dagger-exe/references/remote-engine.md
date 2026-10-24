# Remote engine over authenticated SSH

This recipe keeps the engine private. The Dagger CLI runs on your laptop or
GitHub-hosted runner, while execution and cache live in the existing engine on
the exe.dev VM. Do not publish an engine TCP port or change exe.dev HTTP sharing.

## Verified target

These values describe the existing installation, not generic Colima defaults:

| Setting | Value |
| --- | --- |
| VM | `dagger` / `dagger.exe.xyz` |
| Linux user inside the VM | `exedev` |
| CLI and engine version | `v1.0.0-beta.21` |
| Docker context **inside the VM** | `colima` |
| Docker socket **inside the VM** | `/home/exedev/.config/colima/default/docker.sock` |
| Existing engine container | `dagger-shared` |
| SSH alias **on each client** | `dagger-exe-vm` |
| Docker context **on each client** | `dagger-exe` |

For a different VM or Colima installation, obtain its actual socket with:

```sh
# Run inside that VM; inspection only.
docker context inspect colima --format '{{.Endpoints.docker.Host}}'
```

Do not assume `/var/run/docker.sock` or `~/.colima/default/docker.sock`. Here the
host Docker daemon is disabled; the explicit Colima socket is essential.

## Credential scope and owner setup

Use a **dedicated VM-scoped SSH key per repository**, not an exe.dev account key.
exe.dev documents this registration command, run from a trusted owner machine
using the owner's existing account authentication:

```sh
cat /path/to/repository-ci-key.pub | ssh exe.dev ssh-key add --vm=dagger
```

The dedicated private key belongs in that repository's GitHub Actions secret,
for example `EXE_DAGGER_SSH_KEY`. The owner's account private key must never
be uploaded to CI, copied to the VM, or included in this skill. Public-key
registration is an owner action; do not assume an agent running inside the VM
has the owner's external SSH identity.

VM-scoped is the smallest documented exe.dev SSH scope here, **not** an
engine-only or repository-only authorization. A holder can SSH to this VM and
sign HTTPS tokens for it. Treat the key as full VM/root-like access: the VM
login has access to a privileged shared engine and potentially other VM files,
services, and credentials. Per-repository keys make rotation and attribution
easier, but do not isolate repositories sharing the same VM and engine.

For a laptop, prefer a separate passphrase-protected key loaded into your local
SSH agent. For unattended CI, a dedicated noninteractive key must be protected
by GitHub secret/environment access controls. Never disable host verification
or turn on SSH agent forwarding to make authentication work.

### Rotation and revocation

Create and register a replacement dedicated key, update the repository secret,
test it, and revoke the old registered key through the owner's exe.dev account.
Deleting a GitHub secret alone does not revoke the corresponding exe.dev key.
Do not remove unrelated account keys or the owner's access.

The public VM-scoped-key page documents `ssh-key add` but not the exact
listing/removal syntax. Discover the current supported commands from the owner
machine instead of guessing a revocation command:

```sh
ssh exe.dev help
# Follow its SSH-key help to list keys and remove the precise old key.
```

An unauthenticated VM shell cannot verify account-management help. If the agent
cannot authenticate as the owner, ask the owner to perform this step.

## Establish host trust once, outside CI

Start from the owner's **already-verified** local SSH host-key records.
The alias below uses exe.dev's documented explicit VM-routing destination,
`vm+dagger@vm.exe.xyz`. It avoids relying on reverse-DNS routing for
`dagger.exe.xyz`; both forms reach the same VM and run commands as `exedev`.
The routing username `vm+dagger` is not a Linux account to create.

Before using this destination, the owner must have verified its host key using
an independent trusted source. exe.dev publishes its SSH fingerprint at:

<https://exe.dev/docs/faq/host-key.md>

At the time this recipe was researched, the published RSA fingerprint was:

```text
SHA256:JJOP/lwiBGOMilfONPWZCXUrfK154cnJFXcqlsi6lPo
```

An unauthenticated, pre-login check found the same RSA fingerprint at
`exe.dev` and `vm.exe.xyz`. That observation is a consistency check, **not**
the source of trust. Verify against the current official documentation and
your established trusted records; investigate any change instead of accepting
a replacement automatically.

For CI, export the relevant entry from that already-verified local
`known_hosts` file:

```sh
ssh-keygen -F vm.exe.xyz -f "$HOME/.ssh/known_hosts" > dagger-exe-known-hosts
test -s dagger-exe-known-hosts
ssh-keygen -lf dagger-exe-known-hosts -E sha256
```

If the lookup fails, stop and establish trust interactively on the trusted
owner machine first. Do not invent a host-key entry. Preserve a hashed entry
as-is: SSH can match it to `vm.exe.xyz`.

Store the exported contents as the workflow's `EXE_DAGGER_KNOWN_HOSTS`
secret, or as a reviewed file in a trusted repository. It is public key
material, not a private credential, but its integrity matters. CI must install
these trusted contents before any connection. Do **not** bootstrap CI trust by
blindly appending `ssh-keyscan` output, using `StrictHostKeyChecking=no`, or
using `accept-new`.

## Configure a laptop

Add this to `~/.ssh/config`, substituting the dedicated private-key path:

```sshconfig
Host dagger-exe-vm
    HostName vm.exe.xyz
    User vm+dagger
    IdentityFile ~/.ssh/dagger-exe-laptop
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts
    ForwardAgent no
    RequestTTY no
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Keep this file and private keys private (`~/.ssh` mode `700`, private keys mode
`600`). The matching trusted host-key entry is for `vm.exe.xyz`, the configured
`HostName`, not the local alias. Use a local agent for a passphrase-protected
key; do not put its passphrase in the Docker URL.

Inspect the resolved alias and test it:

```sh
ssh -G dagger-exe-vm
ssh -o BatchMode=yes dagger-exe-vm \
  'id -un; docker --host unix:///home/exedev/.config/colima/default/docker.sock inspect --format "{{.State.Running}} {{.Config.Image}}" dagger-shared'
```

Expect `exedev` and a running engine with the pinned beta.21 image. A key
prompt or authentication failure must be fixed at the SSH layer first.

## Configure Docker and Dagger on the client

Install the pinned Dagger CLI with the skill's `scripts/install-cli.sh`.
A Docker **client** and OpenSSH client are also required; a local Docker daemon
is not required. Use the skill's `scripts/create-remote-context.sh`, or create
the context manually:

```sh
unset DOCKER_HOST
docker context create dagger-exe \
  --description 'Private Dagger engine on exe.dev via SSH' \
  --docker 'host=ssh://dagger-exe-vm/home/exedev/.config/colima/default/docker.sock'

export DOCKER_CONTEXT=dagger-exe
export DAGGER_ENGINE=container+docker://dagger-shared
export _EXPERIMENTAL_DAGGER_RUNNER_HOST=container+docker://dagger-shared
```

The Docker SSH URL's path is the **remote Docker socket**. Docker invokes the
equivalent of this remote command through the SSH alias:

```sh
docker --host unix:///home/exedev/.config/colima/default/docker.sock system dial-stdio
```

Dagger's container driver then uses the remote Docker API to execute
`buildctl dial-stdio` **inside** `dagger-shared`. No engine listener needs to be
published. The remote command does not depend on the remote shell loading
`env.sh`, selecting the `colima` context, or sourcing an interactive profile.
Use a Docker CLI version with SSH URL socket-path support; this behavior is
explicit in Docker's v28.3.0 connection-helper source and works with the
installed v29.1.3 client.

Do not set the client context to `colima`: that name belongs to the VM's Docker
configuration, not the runner's. Do not add `?context=colima` to a Dagger URL.
Unset an inherited `DOCKER_HOST` rather than depending on context/environment
precedence. If the client context already exists, inspect it before using it:

```sh
docker context inspect dagger-exe
docker version
docker inspect --format '{{.State.Running}} {{.Config.Image}}' dagger-shared
dagger version
dagger --progress=plain api query --no-load-module <<'GRAPHQL'
{
  container {
    from(address: "alpine:3.22") {
      withExec(args: ["echo", "remote-engine-ok"]) {
        stdout
      }
    }
  }
}
GRAPHQL
```

The GraphQL smoke test, unlike `dagger version`, proves an actual engine
session. It pulls/executes a container if the result is not already cached.
Then run this project's normal `dagger check` or `dagger api call ...` through
`scripts/with-engine.sh`. The selected existing container must already be
running; this recipe is not an engine provisioning or restart mechanism.

## GitHub-hosted runners

Use `assets/github-actions.yml` as the starting point and adapt only the
project's Dagger command. Provision the two repository/environment secrets
described above:

- `EXE_DAGGER_SSH_KEY`: the dedicated VM-scoped private key.
- `EXE_DAGGER_KNOWN_HOSTS`: host entries exported from trusted local SSH.

The runner must install the private key and trusted host entries in files
with restrictive permissions, configure the **same alias and URL**, and add
`BatchMode yes` to the CI SSH configuration. Preserve
`StrictHostKeyChecking yes`, `IdentitiesOnly yes`, and `ForwardAgent no`.
Do not print secrets or enable shell tracing around key installation.
Remove temporary key material in an `always()` cleanup step. For persistent
self-hosted runners, use isolated temporary SSH and Docker configuration
directories and remove any SSH control sockets too.

Limit the credential-bearing workflow to trusted pushes to the protected
default branch or an explicitly approved environment/manual run. Use minimum
GitHub token permissions, review/pin third-party actions, and enforce branch
protection. Never hand these credentials to untrusted pull-request code.
In particular, do not combine `pull_request_target`, secrets, and checkout or
execution of a pull request's code. Fork secret withholding is not a complete
trust policy: same-repository PRs and dependency/build scripts also need review.

All projects using this VM share its engine/cache trust boundary. Separate
VMs/engines and credentials are needed for mutually untrusted projects. Scope
and authenticate any services the build accesses as carefully as SSH itself.

## Workspace and path behavior

Keep the repository checkout **on the client/runner**. The local Dagger CLI and
SDK session transfer the workspace files and requested directories to the
remote engine. Do not clone every project into the VM just to use this engine.
Use the repository's normal module/workspace paths and keep versions aligned
with beta.21.

This is different from direct `docker run -v /path:/path`: Docker bind-mount
source paths refer to the **remote daemon's filesystem** (here inside Colima),
not the GitHub runner's checkout. Do not attempt to share runner files by
passing their host paths to remote Docker bind mounts.

## Why not `DAGGER_ENGINE=ssh://...`?

In beta.21, Dagger's native SSH driver runs:

```text
ssh [user/port options] HOST buildctl [--addr unix://PATH] dial-stdio
```

It requires `buildctl` in the **remote host's PATH** and access to a host-visible
engine socket. A URL path selects that engine socket; it is not a command,
Docker socket, container name, or script path. The driver explicitly rejects
URL query strings and fragments, so there is no supported query parameter for
a Docker context, engine container, or custom remote command.

This VM has no host `buildctl`; the engine lives inside the Colima container.
Therefore neither bare `ssh://dagger.exe.xyz` nor a native SSH URL pointing at
the Colima **Docker** socket is correct. Use the SSH-backed Docker context
above. A host wrapper/custom transport would be a separate, deliberately
managed implementation, not this beta's native URL feature.

## What can be verified from inside the VM?

Without the owner's external key, an agent can inspect the current engine,
Docker context/socket, pinned CLI, driver source, and public host fingerprint;
it can run a local Dagger engine smoke test. None proves that a GitHub runner
can authenticate with the newly registered key. The owner/CI must test
`ssh -o BatchMode=yes dagger-exe-vm ...` and the remote GraphQL smoke test.
Do not claim end-to-end runner verification based only on a local session.

The packaged helpers were additionally tested through real, strictly verified
SSH to a temporary loopback-only sshd, including Docker's explicit-socket
transport and the native Dang module. This validates the transport wiring, not
exe.dev account authorization or GitHub secret availability. See
[`../VALIDATION.md`](../VALIDATION.md).

## Primary sources

- exe.dev VM-scoped keys and their SSH/token capabilities:
  <https://exe.dev/docs/vm-scoped-ssh-keys.md>
- exe.dev explicit VM routing and identity selection:
  <https://exe.dev/docs/faq/ssh-destination.md>
  <https://exe.dev/docs/faq/ssh-key.md>
- exe.dev host-key fingerprint and SSH account-management API:
  <https://exe.dev/docs/faq/host-key.md>
  <https://exe.dev/docs/api.md>
- Docker SSH contexts and daemon access:
  <https://docs.docker.com/engine/security/protect-access/>
- Docker v28.3.0 SSH connection helper, including the socket URL path:
  <https://github.com/docker/cli/blob/v28.3.0/cli/connhelper/connhelper.go>
  <https://github.com/docker/cli/blob/v28.3.0/cli/connhelper/ssh/ssh.go>
- Dagger beta.21 native SSH behavior and query rejection:
  <https://github.com/dagger/dagger/blob/v1.0.0-beta.21/engine/client/drivers/dial.go>
  <https://github.com/dagger/dagger/blob/v1.0.0-beta.21/internal/buildkit/client/connhelper/ssh/ssh.go>
- Dagger beta.21 existing-container and Docker exec transports:
  <https://github.com/dagger/dagger/blob/v1.0.0-beta.21/engine/client/drivers/container.go>
  <https://github.com/dagger/dagger/blob/v1.0.0-beta.21/engine/client/drivers/docker.go>
- GitHub Actions secrets and workflow security:
  <https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions>
  <https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions>
- Docker bind mounts refer to the daemon host:
  <https://docs.docker.com/engine/storage/bind-mounts/>
