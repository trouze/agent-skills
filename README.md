# Agent skills

One source for my reusable agent skills. Each skill lives under `skills/`;
projects keep their own application-specific pipelines and pin the shared
tooling they use in CI.

Available skills:

- [`dagger-exe`](skills/dagger-exe/SKILL.md): Dagger/Dang with local or shared
  exe.dev engine. Its scripts can be checked out by CI at a pinned commit.
- [`pass`](skills/pass/SKILL.md): handling pass-store credentials with the
  `passenv`/`passkeys` helpers. Agent guidance only; no CI dependency.

## Install a skill for local agent use

`gh` 2.90+ supports agent skills without another package manager:

```sh
# Available in all projects on this machine (recommended):
gh skill install trouze/agent-skills dagger-exe --agent opencode --scope user --pin v1.0.1

# Or install into one project instead (a tracked copy; no longer one local copy):
gh skill install trouze/agent-skills dagger-exe --agent opencode --scope project --pin v1.0.1

# Also supported: --agent claude-code, and gh skill update for intentional upgrades.
```

The global install is sufficient for *agent discovery* in every project. You
don't need to copy skills into each project for an agent to find them. Installed
files are local replicas of this Git repo, not another source of truth. A pinned
install won't silently update when a new release is published.

For `pass` on this Mac (one global installation, not one copy per project):

```sh
gh skill install trouze/agent-skills pass --agent opencode --scope user --pin v1.1.0
python3 ~/.config/opencode/skills/pass/scripts/install_helpers.py
```

The second command creates `~/.local/bin/passenv` and `passkeys` launchers.
Unlike scripts installed by `gh skill install`, these have executable bits;
their implementation lives in the installed skill and follows its pinned
version. It refuses to replace existing launchers without `--replace`.

## Use a skill's scripts in GitHub Actions

Local agent installation does not make scripts available on GitHub runners.
Check out **the same Git commit** in each consuming project, rather than
copying the scripts into that project:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    persist-credentials: false

- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    repository: trouze/agent-skills
    ref: <full 40-character commit SHA of reviewed release> # dagger-exe v1.0.1
    path: .ci/agent-skills
    persist-credentials: false
```

Then use `SKILL: .ci/agent-skills/skills/dagger-exe` in the job and invoke
`"$SKILL/scripts/with-engine.sh"`. This public repository needs no additional
checkout token; **never** place SSH keys, `known_hosts` files with private
material, or application credentials in it. Pin the full commit SHA, not `main`
or a movable tag, so a release can't silently change code that runs in CI.
CI must still supply its own secrets and review who may trigger jobs with VM
credentials; see [`skills/dagger-exe/references/github-actions.md`](skills/dagger-exe/references/github-actions.md).

Project-specific `dagger.toml`, `dagger.lock` and `.dagger/modules/` remain in
each project repository, not here.

## Release `dagger-exe`

1. Change `metadata.version` in `skills/dagger-exe/SKILL.md` to the next
   semantic version. Review script changes carefully; this skill handles
   SSH credentials and remote Docker connections. Coordinate Dagger CLI and
   engine version changes separately from the skill's release version.
2. Run `bash -n skills/dagger-exe/scripts/*.sh` and
   `gh skill publish --dry-run` from this repository. Open a PR; CI also checks
   script syntax. Merge it into `main`.
3. From a clean, up-to-date `main`, run:

   ```sh
   VERSION=1.0.1                # substitute the metadata.version above
   gh skill publish --tag "v$VERSION"
   gh release view "v$VERSION"
   git rev-parse HEAD             # full SHA to pin in project workflows
   ```

   `gh skill publish` validates the skill and creates a tag and GitHub release.
   Never move an existing release tag. Review the release and update each
   project's pinned SHA in its own PR; test it before merging.

For new projects, the global agent install above provides instructions and
scripts on your workstation; only add the pinned checkout if CI itself needs
to execute the scripts. See [`skills/dagger-exe/README.md`](skills/dagger-exe/README.md)
for its modes and security assumptions.
