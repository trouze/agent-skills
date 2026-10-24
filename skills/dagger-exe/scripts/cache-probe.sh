#!/usr/bin/env bash
# Safe cache probe: no VM restart, cache prune, or daemon mutation.
set -euo pipefail
[[ $# == 1 ]] || { echo "Usage: $0 local|remote|vm" >&2; exit 2; }
mode=$1
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/dagger-skill-cache.XXXXXX")
mkdir "$work/project-a" "$work/project-b"
nonce="$(date +%s)-$$-$RANDOM"
cat > "$work/query.graphql" <<EOF
{ container { from(address: "alpine:3.22") {
  withEnvVariable(name: "DAGGER_SKILL_PROBE", value: "$nonce") {
    withExec(args: ["sh", "-c", "head -c 32 /dev/urandom | base64"]) { stdout }
  }
} } }
EOF
probe() {
  ( cd -- "$1"
    "$dir/with-engine.sh" "$mode" --progress=plain api query --no-load-module < "$work/query.graphql"
  )
}
probe "$work/project-a" > "$work/first.json"
probe "$work/project-b" > "$work/second.json"
cmp "$work/first.json" "$work/second.json"
echo "PASS: execution cache reused across directories ($mode)"
echo "Probe artifacts retained at $work"
