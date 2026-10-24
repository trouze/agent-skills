# Existing shared VM: inventory and operations

This is a record of the **existing** personal VM, not a script to install a
second engine in every project. Verify before applying to another machine.

| Item | Current value |
|---|---|
| exe.dev VM | `dagger` |
| Reliable SSH destination | `vm+dagger@vm.exe.xyz` |
| VM login user/home | `exedev`, `/home/exedev` |
| CLI + engine | `v1.0.0-beta.21`, commit `a7a2e64e` |
| Runtime | Colima `v0.10.3`, Lima `v2.2.1`, QEMU/KVM |
| Colima resources | 2 CPUs, 4 GiB RAM, 6 GiB root + 16 GiB data disk |
| Host storage | Approximately 25 GB total; disks are sparse host files |
| Host Docker context | `colima` |
| Host Colima Docker socket | `/home/exedev/.config/colima/default/docker.sock` |
| Running container | `dagger-shared` |
| Image | `registry.dagger.io/engine:v1.0.0-beta.21` |
| Image index digest | `sha256:3444c48e871bedaa95f5b1e57b8c41de929d9e061dd75e9ac6f6deb1f0a74bc3` |
| Persistent cache | Docker volume `dagger-cache-v1-0-0-beta-21`, `/var/lib/dagger` |
| Service/config repository | `/home/exedev/dagger-engine` |
| Autostart | `colima.service` then `dagger-engine.service` |
| Cache GC | 8 GB usage target, 1 GB reserved floor, 3 GB free target |
| Logging | Engine `info`; Docker `json-file` 10 MB × 3 files |

The preinstalled host Docker daemon/socket and host containerd are disabled.
Their **CLI binaries remain available** for connecting to Colima. Don't enable
them to “fix” remote connection issues.

## Read-only checks over authorized SSH

```bash
ssh dagger-exe-vm 'dagger version; systemctl is-active colima dagger-engine'
ssh dagger-exe-vm 'docker --context colima ps'
ssh dagger-exe-vm 'docker --context colima logs --tail 100 dagger-shared'
ssh dagger-exe-vm 'df -h /; colima ssh -- df -h / /var/lib/docker'
ssh dagger-exe-vm 'sudo journalctl -u colima -u dagger-engine -n 100 --no-pager'
```

Read `/home/exedev/dagger-engine/README.md` before making changes. The setup is
tracked in Git. Project-specific pipeline configuration belongs in each project,
not in that infrastructure repository.

## What is safe to share

Multiple trusted projects can connect to the same engine. Matching immutable
operations reuse cached results. Package-manager cache volumes also need stable
explicit keys. These are not project access controls: treat all clients, cached
data, VM filesystem and network credentials as one trusted boundary.

The same GitHub concurrency group in different repos does not serialize them.
Limit expensive checks (`dagger check --parallel 2` or less), avoid overlapping
large builds, and measure contention. If a global queue is required, implement
and test a real coordinator holding a lock for the **entire client session**;
locking only key setup or `docker exec` startup is insufficient. This skill does
not install a queue or promise fairness. A self-hosted Actions runner on the VM
is not needed for remote engine caching.

## Common failures

- **Wrong engine/cache:** inspect `DOCKER_CONTEXT`, `DOCKER_HOST`, `DAGGER_ENGINE`,
  `DAGGER_CLOUD_ENGINE`, `_EXPERIMENTAL_DAGGER_RUNNER_HOST`, and inherited session
  variables. Use `scripts/with-engine.sh` rather than a global shell change.
- **Permission denied (publickey):** verify VM-scoped key registration, selected
  identity, destination routing and revocation status. A VM key is registered
  with exe.dev, not blindly appended to this VM's `authorized_keys`.
- **Host key mismatch:** stop. Verify a provider/key rotation through trusted
  channels. Never automatically delete the entry or set checking to `no`.
- **Cannot find socket / daemon:** verify actual Colima socket path on the VM,
  the Docker SSH URL's absolute path, services and remote Docker CLI PATH.
- **`buildctl: command not found`:** you selected Dagger's bare `ssh://` driver.
  Use the documented Docker SSH context, not a host buildctl bridge.
- **CLI mismatch / module not found:** install the exact beta, fix PATH, inspect
  project requirements and use `dagger api call --load-module PATH` if needed.
- **Project files missing:** Dagger snapshots transfer over the client session;
  direct `docker run -v LOCAL_PATH:...` binds a path on the **remote host**, not
  your laptop/runner. Use Dagger directory/workspace APIs.
- **Disk pressure:** inspect both host `df` and Colima guest `df`; images, logs,
  project checkouts and old caches all compete for storage. GC targets are not
  hard quotas or host-level reservations. Increase host storage before expanding
  sparse guest disks or GC limits. Never prune to diagnose.
- **Cache cold after a version change:** cache metadata schemas can change. Do
  not promise cross-version reuse. This upgrade intentionally used a fresh beta
  volume; stable schema was 17, beta.21 schema is 22.
- **Engine unclean shutdown/OOM:** inspect logs and RAM before restarting.
  Preserve graceful shutdown time; forced kills can discard cache metadata.

## Restarts and configuration changes

Get user approval and coordinate all projects first. These interrupt workloads:

```bash
sudo systemctl restart dagger-engine
# Full runtime restart:
sudo systemctl restart colima
sudo systemctl start dagger-engine
```

Use systemd rather than manually starting/stopping Colima behind the units.
After changing the bind-mounted `engine.json`, the infrastructure README
documents recreating **only the container**, preserving its named cache volume.
Do not remove volumes, `colima delete`, run cache prune, or recreate the VM
without a user-approved data-loss plan.

## Rollback and upgrades

The beta upgrade retained:

- Stopped `dagger-shared-v0-21-11-backup`.
- Cache volume `dagger-cache-v0-21-11`.
- `/usr/local/bin/dagger-v0.21.11`.
- Infrastructure Git tag `pre-beta21`.

The working rollback recipe is in `/home/exedev/dagger-engine/README.md`.
Do not execute the old engine against the beta cache. Any new upgrade must
coordinate engine, CLI, SDK/module versions, skill install checksums, workflow
and documentation. Start with a new cache volume when compatibility is unknown.
Do not silently substitute `latest` or a commit build for a requested version.

## Official sources

- Engine config: https://github.com/dagger/dagger/blob/v1.0.0-beta.21/docs/current_docs/reference/config-files/engine-json.mdx
- Cache schema/import behavior: https://github.com/dagger/dagger/blob/v1.0.0-beta.21/dagql/cache.go
- Colima: https://github.com/abiosoft/colima/tree/v0.10.3
- VM-scoped access: https://exe.dev/docs/vm-scoped-ssh-keys.md
- SSH routing: https://exe.dev/docs/faq/ssh-destination.md
