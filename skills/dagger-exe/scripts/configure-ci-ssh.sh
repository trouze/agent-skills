#!/usr/bin/env bash
# For an ephemeral GitHub-hosted runner, not a developer's permanent SSH config.
# Consumes secrets via environment; never prints their contents.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && -n "${RUNNER_TEMP:-}" ]] || {
  echo "This script is only for ephemeral GitHub Actions runners." >&2
  exit 1
}
: "${EXE_DAGGER_SSH_KEY:?Set the VM-scoped private-key secret}"
: "${EXE_DAGGER_KNOWN_HOSTS:?Set trusted, independently verified known_hosts entries}"
host=${EXE_DAGGER_HOST:-vm.exe.xyz}
user=${EXE_DAGGER_USER:-vm+dagger}
[[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo "Invalid SSH hostname." >&2; exit 2; }
[[ "$user" =~ ^[a-zA-Z0-9_+.-]+$ ]] || { echo "Invalid SSH username." >&2; exit 2; }
umask 077
sshdir="$RUNNER_TEMP/dagger-exe-ssh"
mkdir -p "$sshdir" "$HOME/.ssh"
chmod 700 "$sshdir" "$HOME/.ssh"
if [[ -e "$HOME/.ssh/config" ]] && grep -Eq '^[[:space:]]*Host[[:space:]]+dagger-exe-vm([[:space:]]|$)' "$HOME/.ssh/config"; then
  echo "SSH alias dagger-exe-vm already exists; refusing to append a conflicting definition." >&2
  exit 1
fi
printf '%s\n' "$EXE_DAGGER_SSH_KEY" | tr -d '\r' > "$sshdir/id_ed25519"
printf '%s\n' "$EXE_DAGGER_KNOWN_HOSTS" | tr -d '\r' > "$sshdir/known_hosts"
chmod 600 "$sshdir/id_ed25519" "$sshdir/known_hosts"
ssh-keygen -y -P '' -f "$sshdir/id_ed25519" >/dev/null 2>&1 || {
  echo "CI requires a valid, unencrypted private key. Use a dedicated VM-scoped key." >&2
  exit 1
}
ssh-keygen -F "$host" -f "$sshdir/known_hosts" >/dev/null || {
  echo "Trusted known_hosts has no entry for $host; verify it on your workstation first." >&2
  exit 1
}
cat > "$sshdir/ssh_config" <<EOF

Host dagger-exe-vm
  HostName $host
  User $user
  IdentityFile "$sshdir/id_ed25519"
  IdentityAgent none
  IdentitiesOnly yes
  BatchMode yes
  ForwardAgent no
  StrictHostKeyChecking yes
  UserKnownHostsFile "$sshdir/known_hosts"
  GlobalKnownHostsFile /dev/null
  UpdateHostKeys no
  ConnectTimeout 20
  ServerAliveInterval 30
  ServerAliveCountMax 3
  RequestTTY no

Host *
EOF
if [[ -f "$HOME/.ssh/config" ]]; then
  cat "$HOME/.ssh/config" >> "$sshdir/ssh_config"
fi
install -m 600 "$sshdir/ssh_config" "$HOME/.ssh/config"
echo "Configured strict SSH alias dagger-exe-vm; no network key discovery performed."
