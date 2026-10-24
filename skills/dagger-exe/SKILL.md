---
name: dagger-exe
description: Configure and run Dagger v1.0.0-beta.21 and native Dang pipelines across projects, using local Colima or a persistent engine on an exe.dev VM. Use when adding Dagger to a project, debugging engine or cache selection, or configuring trusted GitHub Actions jobs to use the shared VM over SSH.
compatibility: Bash, curl, tar, OpenSSH and a Docker CLI; macOS or Linux. Local execution also needs a running Docker-compatible daemon, preferably Colima. Remote execution needs authorized exe.dev SSH access. No public engine port is required.
metadata:
  version: "1.0.0"
  dagger-version: "v1.0.0-beta.21"
---

# Dagger + Colima + exe.dev

## Operating rules

1. Read the project's `AGENTS.md`/`CLAUDE.md`, Dagger configuration, CI and test
   commands before editing. Preserve existing pipelines and version declarations.
2. This skill pins **v1.0.0-beta.21**, not “latest”. CLI, engine and project
   requirements must agree. Do not silently upgrade, migrate, prune, or reset
   caches. Native Dang is available in this beta.
3. Ask which execution mode the user wants: **local**, **remote**, or **vm**.
   Default to local development and remote CI only when authorized. Do not modify
   a user's global Docker context or shell configuration just to run one project.
4. The shared VM is a **trusted personal environment**, not a sandbox for unknown
   contributors. Never send fork PRs, unreviewed branch code, or arbitrary external
   workflows to it. SSH access can control the entire VM, not just one pipeline.
5. Never expose Docker/Dagger TCP ports publicly, disable SSH host checking, copy
   a personal account key into CI, or place credentials in tracked files.
6. Never restart or recreate the shared engine while another project is running.
   Changes to the existing VM require explicit authorization; this skill alone is
   not permission to provision infrastructure or register credentials.

## Select and verify the engine

Paths below are relative to this skill directory; locate it first. A project
workflow can check out the pinned `trouze/agent-skills` commit under `.ci/agent-skills`:

```bash
SKILL="$PWD/.ci/agent-skills/skills/dagger-exe"
"$SKILL/scripts/install-cli.sh"
export PATH="$HOME/.local/bin:$PATH"
```

The installer verifies a pinned SHA-256 before installing. Inspect scripts before
running. Pick exactly one:

| Mode | Where CLI/project live | Where execution/cache live |
|---|---|---|
| `local` | Your workstation | Local Colima's Docker daemon |
| `remote` | Workstation or GitHub-hosted runner | Shared exe.dev VM's Colima |
| `vm` | The exe.dev VM | That VM's Colima |

```bash
"$SKILL/scripts/doctor.sh" local       # or remote / vm
"$SKILL/scripts/with-engine.sh" local check
"$SKILL/scripts/with-engine.sh" remote check
"$SKILL/scripts/with-engine.sh" vm check
```

The wrapper scopes `DOCKER_CONTEXT` and `DAGGER_ENGINE` to its child process.
It does not change `docker context use`. It also sets legacy SDK provisioning
variables and supports arbitrary SDK commands:

```bash
"$SKILL/scripts/with-engine.sh" remote -- python3 ci/main.py
```

For **local**, first follow [local-development.md](references/local-development.md).
For **remote**, first follow [remote-engine.md](references/remote-engine.md); a
remote Docker context and trusted SSH authentication are required.

## Add or maintain a project pipeline

1. Detect `dagger.toml`, `dagger-module.toml`, `dagger.json`, `dagger.lock`, and
   `.dagger/`. Inspect the existing module and run its documented entry point.
   Do not replace an established pipeline with the smoke template.
2. For a new native Dang module, use
   [local-development.md](references/local-development.md) and
   `assets/dang-module/`. Its check is **only a smoke test**, not project coverage.
   Replace/add checks that execute the repository's real tests and linters.
3. Prefer stable image inputs and narrow source includes/excludes. Use secrets
   through Dagger's Secret API, not image layers, source directories or arguments.
   Explicit cache-volume keys should include tool/platform/version as appropriate;
   don't share writable package-cache keys across unrelated trust domains.
4. Run the pipeline locally, then against the intended remote engine. Use
   `scripts/cache-probe.sh MODE` to verify execution-cache reuse across directories
   without restarting the shared engine.
5. Commit project configuration and generated `dagger.lock`; review generated
   changes. Never commit `.env`, SSH private keys, credentials, or build outputs.

## GitHub Actions

Read [github-actions.md](references/github-actions.md) **before** adapting
`assets/github-actions.yml` to `.github/workflows/dagger.yml`.

The template checks out the public `trouze/agent-skills` repository at a
reviewed commit SHA; replace its SHA placeholder before enabling it. The
project's Dagger module and configuration remain in that project's repository.
It uses a GitHub-hosted runner, a VM-scoped SSH key, pinned checkout, strict host
verification, and an explicit remote Colima socket. Default triggers are pushes
to `main` and manual runs restricted to `main`, with a `dagger-exe` environment.
The user must create that environment, restrict deployment branches, and register
the key themselves. No credentials are bundled.

Default target: VM `dagger`, routed as `vm+dagger@vm.exe.xyz`; engine
`dagger-shared`; socket `/home/exedev/.config/colima/default/docker.sock`.
Override documented GitHub variables for other VMs; do not assume a different
machine uses this socket path.

GitHub concurrency groups are repository-scoped. Multiple projects can still
overlap on the VM's 2 CPUs / 4 GiB Colima VM; start with low per-pipeline
parallelism. Do not claim this template globally serializes all projects.

## Troubleshooting and handoff

Use [vm-operations.md](references/vm-operations.md) for cache location, service
checks, version drift, disk pressure and rollback. Do not prune as a diagnostic.
Bare `DAGGER_ENGINE=ssh://HOST` is **not** the connection recipe here: it invokes
host-side `buildctl`, which this VM does not have. Use the Docker SSH context.

Before declaring success, report:

- Selected CLI/engine version and execution mode.
- Real project command tested and cache probe result.
- Files changed and required GitHub environment/secrets/variables.
- What remains untested (especially GitHub-hosted CI without registered keys).
- Risks, version or workspace migrations, and any user-approved VM changes.
