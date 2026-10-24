#!/usr/bin/env bash
# Requires a preconfigured, strictly verified SSH alias.
set -euo pipefail
[[ $# -le 3 ]] || { echo "Usage: $0 [SSH_ALIAS] [ABSOLUTE_SOCKET] [CONTEXT]" >&2; exit 2; }
alias=${1:-dagger-exe-vm}
socket=${2:-/home/exedev/.config/colima/default/docker.sock}
context=${3:-dagger-exe}
[[ "$alias" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { echo "Invalid SSH alias." >&2; exit 2; }
[[ "$socket" =~ ^/[a-zA-Z0-9_./-]+$ ]] || { echo "Invalid absolute socket path." >&2; exit 2; }
[[ "$context" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { echo "Invalid Docker context name." >&2; exit 2; }
unset DOCKER_HOST DOCKER_CONTEXT
endpoint="ssh://$alias$socket"
if docker context inspect "$context" >/dev/null 2>&1; then
  actual=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')
  [[ "$actual" == "$endpoint" ]] || {
    echo "Existing context $context points at $actual, not $endpoint." >&2
    echo "Review before updating it; this script will not overwrite it." >&2
    exit 1
  }
  echo "Context already configured: $context"
else
  docker context create "$context" --docker "host=$endpoint"
fi
echo "Configured $context without changing your default context."
