---
name: exe-dev
description: "Use for exe.dev accounts and VMs: SSH access, VM creation or maintenance, private networking, HTTPS exposure, billing questions, and *.exe.xyz hosts. Read the relevant official docs before acting; verify SSH host identity and get approval for VM or account changes. Use the dagger-exe skill too when operating the shared Dagger VM."
metadata:
  version: "1.0.0"
---

# Working with exe.dev

exe.dev VMs are persistent Linux machines controlled through SSH. Start at
the [official documentation index](https://exe.dev/docs.md), then read the
page for the specific operation. The maintainer's
[upstream agent skill](https://github.com/boldsoftware/exe.dev/blob/main/skill/SKILL.md)
is another reference; this skill is independently written and does not mirror
its text. Never assume an upstream example is authorization to change the
user's account or relax security checks.

## Choose the SSH destination

- `ssh exe.dev help` reaches the management interface; it is not a Linux shell
  and cannot receive scp/sftp uploads. Check command help before changing a VM.
- `ssh <vm>.exe.xyz` reaches that VM. If hostname routing fails, the documented
  explicit form is `ssh vm+<vm>@vm.exe.xyz`. These two destinations serve
  different purposes; see [SSH destinations](https://exe.dev/docs/faq/ssh-destination.md).
- Use the user's existing SSH agent and configured identities. Do not inspect,
  copy, or forward private keys to a VM to make a connection work.

## Verify host identity before connecting

For a host not already trusted on this machine, compare its offered SSH key
fingerprint against an independent trusted source **before** recording it in
`known_hosts`. exe.dev publishes its current SSH fingerprint at
[host-key documentation](https://exe.dev/docs/faq/host-key.md). Investigate a
changed or mismatched key; do not bypass verification with
`StrictHostKeyChecking=no` or accept an unverified key with `accept-new`.
For unattended jobs, provision verified `known_hosts` material first and use
strict host-key checking with batch-mode authentication.

## Respect account, VM, and data boundaries

- Confirm the user's account and exact target VM before any state-changing
  command. Ask before creating, resizing, restarting, deleting or sharing a VM,
  changing billing or integrations, or provisioning account/VM-scoped keys.
  Never treat an agent skill as the user's consent to subscribe or pay.
- Treat VM-scoped SSH credentials as access to the whole VM, not to a single
  repository, service, or Dagger job. Keep account keys out of CI, tracked
  files, tool output, and chat. Prefer one-purpose VM-scoped keys where needed.
- Read [sharing](https://exe.dev/docs/sharing.md) and
  [HTTPS proxy](https://exe.dev/docs/proxy.md) docs before changing exposure.
  Never publish unauthenticated Docker/Dagger TCP endpoints to the Internet.
- Do not restart another project's long-running VM service, prune shared
  caches, or destroy data during diagnosis without explicit authorization.

For the persistent engine on the user's `dagger` VM, load the `dagger-exe`
skill as well. It documents the pinned CLI/engine version and the SSH-backed
Docker context required to reuse that engine's cache. For secrets stored in
`pass`, load the `pass` skill and use its wrappers rather than printing values.

## Upstream change awareness

The weekly, read-only check in this repository compares
[`references/upstream-skill.sha`](references/upstream-skill.sha) with the latest
commit changing the upstream `skill/SKILL.md`. If it changes, review the
upstream diff and official documentation, update this independently authored
skill as appropriate, and change the recorded SHA in a normal PR. No upstream
code or instructions are auto-copied into this repository or auto-executed.
