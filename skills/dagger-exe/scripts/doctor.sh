#!/usr/bin/env bash
set -euo pipefail
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ "${1:-}" != --configured ]]; then
  [[ $# == 1 ]] || { echo "Usage: $0 local|remote|vm" >&2; exit 2; }
  exec "$dir/with-engine.sh" "$1" -- "$dir/doctor.sh" --configured "$1"
fi
[[ $# == 2 ]] || exit 2
mode=$2
printf 'Mode: %s\nContext: %s\nEngine: %s\n' "$mode" "$DOCKER_CONTEXT" "$DAGGER_ENGINE"
"$_EXPERIMENTAL_DAGGER_CLI_BIN" version
docker context inspect "$DOCKER_CONTEXT" --format 'Docker endpoint: {{.Endpoints.docker.Host}}'
docker version --format 'Docker client/server: {{.Client.Version}} / {{.Server.Version}}'
if [[ "$mode" != local ]]; then
  image=$(docker inspect "${DAGGER_ENGINE_CONTAINER:-dagger-shared}" --format '{{.Config.Image}}')
  [[ "$image" == registry.dagger.io/engine:v1.0.0-beta.21 ]] || {
    echo "Unexpected engine image: $image; resolve version drift before running pipelines." >&2
    exit 1
  }
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dagger-skill-doctor.XXXXXX")
# Isolate the image smoke test so it cannot change the project's dagger.lock.
(
cd -- "$scratch"
"$_EXPERIMENTAL_DAGGER_CLI_BIN" --progress=plain api query --no-load-module <<'GRAPHQL'
{ container { from(address: "alpine:3.22") {
  withExec(args: ["echo", "dagger-exe-ok"]) { stdout }
} } }
GRAPHQL
)
echo "PASS: authenticated engine connection and container execution"
