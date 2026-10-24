# Workstation and project setup

This guide is pinned to **Dagger v1.0.0-beta.21**. Run from the project root. Set
`SKILL` to the absolute directory containing this skill's `SKILL.md`.

## 1. Inspect before changing anything

Read repository guidance and existing workflows. Check:

```bash
git status --short
command -v dagger docker colima
dagger version
docker context ls
```

Do not blindly migrate `dagger.json`, replace a module, change SDK versions, or
overwrite an existing CLI. Keep a clean Git checkpoint before migrations.

## 2. Install the CLI

```bash
"$SKILL/scripts/install-cli.sh"
export PATH="$HOME/.local/bin:$PATH"
dagger version
```

The script supports macOS/Linux on arm64/amd64, downloads from Dagger's official
release service, and checks an embedded, version-specific SHA-256. It refuses to
replace a different version already at its destination. Use another `BIN_DIR`
for side-by-side installs or deliberately set `ALLOW_REPLACE_DAGGER=1` after
reviewing the existing installation. `DAGGER_BIN=/absolute/path/to/dagger` can
select a side-by-side CLI for the wrappers.

Do not assume the beta has a GitHub Release asset: this beta is published at
`dl.dagger.io/dagger/releases/1.0.0-beta.21/` (without `v` in the directory).

## 3. Choose local or remote execution

### Local Colima

On macOS, install Docker's CLI and Colima with your normal package manager; for
example `brew install colima docker`. Colima does not require Docker Desktop.
On Linux use official Colima/Lima installation instructions and QEMU/KVM; nested
VM hosts must actually support `/dev/kvm`. Don't install a second daemon just
because a Docker CLI is missing.

Review available resources before starting. A workstation example:

```bash
colima start --runtime docker --cpus 2 --memory 4 --disk 30
"$SKILL/scripts/doctor.sh" local
"$SKILL/scripts/with-engine.sh" local check
```

Do not restart an existing Colima VM with new settings while other work uses it.
Starting a previously created profile may retain or limit existing disk settings.
On a different runtime/context, set `DAGGER_DOCKER_CONTEXT=YOUR_CONTEXT` for the
wrapper instead of globally changing `docker context use`.

In `local` mode Dagger provisions the exact engine image in local Docker and
keeps its normal engine/cache state between runs. The wrapper also sets
`DAGGER_LEAVE_OLD_ENGINE=true` so provisioning cannot automatically remove other
versions' `dagger-engine-*` containers and their cache state. Colima must be running after
a workstation reboot. Stopping Colima preserves its disk; deleting the VM or
pruning cache volumes does not.

### Remote Colima on exe.dev

Follow [remote-engine.md](remote-engine.md) once per workstation. You need a
Docker **client**, SSH, and the exact Dagger CLI, but no running local Docker
daemon or local Colima VM:

```bash
"$SKILL/scripts/doctor.sh" remote
"$SKILL/scripts/with-engine.sh" remote check
```

In `vm` mode, the CLI and checkout are already on the engine's exe.dev VM:

```bash
"$SKILL/scripts/with-engine.sh" vm check
```

The wrapper overrides inherited session/engine variables only for its child
process. It avoids accidentally selecting a local engine when CI needs the
shared cache. Do not persist session tokens/ports in shell profiles.

## 4. Use an existing project

For a beta workspace (`dagger.toml`):

```bash
"$SKILL/scripts/with-engine.sh" local check -l
"$SKILL/scripts/with-engine.sh" local check
"$SKILL/scripts/with-engine.sh" local api functions
"$SKILL/scripts/with-engine.sh" local api call YOUR_FUNCTION
```

For a one-off Dang module not installed into a workspace:

```bash
"$SKILL/scripts/with-engine.sh" local api call \
  --load-module ./.dagger/modules/project-ci YOUR_FUNCTION
```

This beta's direct API commands are `dagger api call` and `dagger api query`.
Examples from v0.21 that use `dagger core`, `dagger call`, or `--no-mod` should
not be copied unchanged. Query without workspace modules with
`dagger api query --no-load-module`. For legacy workspaces, review a migration
with `dagger workspace migrate`, and inspect the diff; don't auto-apply a
migration just to make a sample command pass.

Direct SDK programs can inherit the wrapper's engine/CLI selection:

```bash
"$SKILL/scripts/with-engine.sh" remote -- python3 ci/main.py
"$SKILL/scripts/with-engine.sh" remote -- go run ./ci
```

Use SDK versions compatible with the beta. A project's toolchain wrapper may
select another CLI; confirm what it actually executes.

## 5. Add a native Dang module to a new project

The `dang` runtime is built into the engine. The standalone Dang SDK module is
needed for its scaffolding commands, not to load the small hand-written module
provided here.

Start in a Git repository with no existing module at the destination:

```bash
mkdir -p .dagger/modules/project-ci
cp "$SKILL/assets/dang-module/dagger-module.toml" .dagger/modules/project-ci/
cp "$SKILL/assets/dang-module/main.dang" .dagger/modules/project-ci/
"$SKILL/scripts/with-engine.sh" local module install ./.dagger/modules/project-ci
"$SKILL/scripts/with-engine.sh" local check -l
"$SKILL/scripts/with-engine.sh" local check
git diff
git status --short
```

The template's `engineSmoke` check verifies only engine wiring. It does **not**
test your application. Keep existing tests as the source of truth; replace/add
Dang `@check` functions which run the real tools. Select an appropriate image,
mount/copy a filtered source directory, set a workdir, install dependencies,
then run tests and force evaluation using `.sync` (or return a consumed result).
A successful unconsumed container expression is not evidence tests executed.

Example shape for a Node project, to adapt rather than blindly paste:

```dang
pub test(source: Directory! @defaultPath(path: "/")): Void @check {
  container
    .from("node:22-alpine")
    .withDirectory("/src", source, exclude: ["node_modules", ".git", ".env"])
    .withWorkdir("/src")
    .withMountedCache("/root/.npm", cacheVolume("my-project-node22-npm"))
    .withExec(["npm", "ci"])
    .withExec(["npm", "test"])
    .sync
  null
}
```

Use the project's real Node version and package manager, and exclude all
credential files, not only `.env`. For Go use its module/download/build caches;
for Python key package caches to the appropriate Python/platform/installer.
Avoid putting timestamps/random values into ordinary pipeline inputs, which
deliberately invalidate cache. Prefer lockfiles for deterministic dependencies.
Never put registry tokens, SSH keys, `.npmrc` credentials or secrets in
`withEnvVariable`/build args/source snapshots; use Dagger's Secret API.

Commit `dagger.toml`, module sources/config, and generated `dagger.lock`.
The skill is portable; VM credentials and machine paths do not belong in
application module code.

## 6. Validate the cache

```bash
"$SKILL/scripts/cache-probe.sh" local
"$SKILL/scripts/cache-probe.sh" remote
```

The same randomly keyed operation runs from two directories. Identical random
output shows execution reuse. This does not restart the engine or delete any
entries. The `remote` cache is shared across all authorized projects with
matching inputs; the `local` cache lives on your workstation and is separate.

## Official sources

- Colima installation: https://github.com/abiosoft/colima#installation
- Colima startup/configuration: https://github.com/abiosoft/colima#usage
- Beta CLI install: https://github.com/dagger/dagger/blob/v1.0.0-beta.21/install.sh
- CLI reference: https://github.com/dagger/dagger/blob/v1.0.0-beta.21/docs/current_docs/reference/cli/index.mdx
- Dang reference: https://github.com/dagger/dagger/blob/v1.0.0-beta.21/docs/current_docs/reference/sdks/dang.mdx
