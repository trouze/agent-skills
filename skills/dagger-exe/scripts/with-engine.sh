#!/usr/bin/env bash
# Scope engine selection to one command, never changing the global Docker context.
set -euo pipefail
usage() {
  echo "Usage: $0 local|remote|vm DAGGER_ARGUMENTS..." >&2
  echo "       $0 local|remote|vm -- COMMAND [ARGUMENTS...]" >&2
  exit 2
}
[[ $# -ge 2 ]] || usage
mode=$1; shift
version=v1.0.0-beta.21
unset DOCKER_HOST DAGGER_SESSION_PORT DAGGER_SESSION_TOKEN DAGGER_CLOUD_ENGINE
case "$mode" in
  local)
    export DOCKER_CONTEXT=${DAGGER_DOCKER_CONTEXT:-colima}
    export DAGGER_ENGINE="image+docker://registry.dagger.io/engine:$version"
    # Default image provisioning can otherwise remove other versions' engines.
    export DAGGER_LEAVE_OLD_ENGINE=true
    ;;
  remote)
    export DOCKER_CONTEXT=${DAGGER_DOCKER_CONTEXT:-dagger-exe}
    export DAGGER_ENGINE="container+docker://${DAGGER_ENGINE_CONTAINER:-dagger-shared}"
    ;;
  vm)
    export DOCKER_CONTEXT=${DAGGER_DOCKER_CONTEXT:-colima}
    export DAGGER_ENGINE="container+docker://${DAGGER_ENGINE_CONTAINER:-dagger-shared}"
    ;;
  *) usage ;;
esac
cli=$(command -v "${DAGGER_BIN:-dagger}") || { echo "Install Dagger first." >&2; exit 1; }
if [[ "$cli" != /* ]]; then
  cli="$(cd -- "$(dirname -- "$cli")" && pwd)/$(basename -- "$cli")"
fi
actual=$("$cli" version --quiet 2>/dev/null) || {
  echo "Cannot identify CLI; install $version using install-cli.sh." >&2; exit 1;
}
[[ "${actual%%+*}" == "$version" ]] || {
  echo "CLI mismatch: expected $version, got $actual ($cli)." >&2; exit 1;
}
if [[ "$mode" == remote ]]; then
  endpoint=$(docker context inspect "$DOCKER_CONTEXT" --format '{{.Endpoints.docker.Host}}')
  [[ "$endpoint" == ssh://* ]] || {
    echo "Remote mode requires an SSH-backed Docker context, not $endpoint." >&2
    exit 1
  }
fi
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="$DAGGER_ENGINE"
export _EXPERIMENTAL_DAGGER_CLI_BIN="$cli"
if [[ "$1" == -- ]]; then
  shift
  [[ $# -gt 0 ]] || usage
  exec "$@"
fi
exec "$cli" "$@"
