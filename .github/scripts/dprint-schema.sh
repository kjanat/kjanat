#!/usr/bin/env bash

# Build one schema for every plugin offered by the shared configs.
set -euo pipefail
cd "$(dirname "$0")/../../"

DPRINT="${DPRINT:-dprint}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Read plugin pins directly from this checkout. Following biome's remote
# extends would also load master and could conceal a plugin update in a PR.
jq -s '{plugins: ([.[].plugins[]] | unique)}' configs/dprint.*.json >"$tmp/config.json"
"$DPRINT" schema --config "$tmp/config.json" \
	| jq --arg id 'https://raw.githubusercontent.com/kjanat/kjanat/master/schemas/dprint.schema.json' \
		'. + {"$id": $id}' \
	| "$DPRINT" fmt --stdin schemas/dprint.schema.json >"$tmp/dprint.schema.json"

jq -e '.type == "object" and (.properties | has("plugins")) and (."$defs" | has("pluginTable"))' \
	"$tmp/dprint.schema.json" >/dev/null
mkdir -p schemas
mv "$tmp/dprint.schema.json" schemas/dprint.schema.json
