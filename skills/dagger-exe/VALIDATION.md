# Validation

Validated on **October 24, 2026**, against the installed Dagger
**v1.0.0-beta.21+a7a2e64e**, Colima v0.10.3, and Docker CLI v29.1.3 on Linux
amd64.

## Passed

- 17 offline helper tests: engine modes, version mismatch rejection, inherited
  session cleanup, scoped environment, preservation of old local engines,
  remote-context endpoint validation/idempotence/conflict refusal, CI-only SSH
  setup, hostname injection rejection, known-host selection, key permissions,
  configuration precedence, installer idempotence and checksum mismatch refusal.
- ShellCheck 0.9.0 for every helper and runtime-smoke test.
- actionlint 1.7.12 for the supplied Actions workflow.
- Real official CLI download, pinned SHA-256 verification and repeat install.
- Existing-VM mode: Docker/engine preflight, cross-directory execution-cache
  reuse, installation of the bundled Dang module into a fresh Git workspace,
  listing and successfully executing its `@check`.
- Remote mode: a real, encrypted SSH session with strict host verification to a
  **temporary loopback-only sshd**, throwaway client/host keys, and isolated
  Docker configuration. Docker's SSH context reached the explicit Colima socket;
  the same preflight, cache and native Dang workflow tests passed.
- Local mode: real image-based engine provisioning on Colima, cache probe and
  Dang workspace checks. The temporary auto-provisioned test engine was removed
  afterward; the shared engine and its volume were not stopped or pruned.

The SSH test did not register any exe.dev account keys, change permanent SSH
configuration, publish a port, or install an Actions runner. Test keys were
temporary and are not included in this package.

## Still requires owner validation

- **Actual GitHub-hosted Actions end to end.** The owner must register a
  VM-scoped public key, establish trusted exe.dev host keys, configure GitHub
  environment restrictions/secrets and dispatch the workflow. Loopback SSH does
  not prove exe.dev edge authorization or GitHub secret availability.
- macOS/arm64 execution. Artifact checksums are pinned from the official release
  manifest, but only Linux amd64 was executed here.
- A project's actual tests. The supplied Dang module is explicitly a wiring
  smoke test, not coverage for any application.
- Cross-repository load/fairness. GitHub concurrency is not a global queue.

## Validate this published skill

```bash
bash -n skills/dagger-exe/scripts/*.sh
gh skill publish --dry-run
# Optional tools, if installed:
shellcheck skills/dagger-exe/scripts/*.sh
actionlint skills/dagger-exe/assets/github-actions.yml
```

The original offline test harness used for the historical validation above
was not part of this skill bundle and is not included in this repository.
Do not treat this syntax/spec check as a rerun of the 17 offline tests.
To test an authorized, running engine, use `scripts/doctor.sh` and the project's
real `dagger check`; these do not alter the shared VM configuration.

Runtime helpers retain small temporary workspace/probe artifacts for inspection.
They do not restart VM services. Do not run integration tests against an engine
you are not authorized to use.
