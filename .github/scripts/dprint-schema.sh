#!/usr/bin/env bash

# Build one schema for every plugin offered by the shared configs.
set -euo pipefail
cd "$(dirname "$0")/../../"

DPRINT="${DPRINT:-kprint}"
TIMEOUT_SECS="${DPRINT_SCHEMA_TIMEOUT:-60}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Schema downloads have no deadline in kprint 0.64.1. Bound each formatter
# invocation and keep its download diagnostics for failures, including hangs.
run_formatter() {
	local stage="$1" start=$SECONDS rc
	shift
	echo "${stage}..." >&2
	if timeout --verbose --kill-after=5s "${TIMEOUT_SECS}s" "$DPRINT" "$@" --log-level debug 2>"$tmp/formatter.log"; then
		# Preserve warnings without flooding successful CI logs with debug output.
		sed '/^\[DEBUG\]/d' "$tmp/formatter.log" >&2
		echo "${stage} completed in $((SECONDS - start))s" >&2
	else
		rc=$?
		cat "$tmp/formatter.log" >&2
		if [[ $rc -eq 124 ]]; then
			echo "::error::${stage} timed out after ${TIMEOUT_SECS}s; the published schema was not replaced." >&2
		else
			echo "::error::${stage} failed (exit ${rc}); the published schema was not replaced." >&2
		fi
		return "$rc"
	fi
}

# Read plugin pins directly from this checkout. Following biome's remote
# extends would also load master and could conceal a plugin update in a PR.
jq -s '{plugins: ([.[] | .plugins[]?] | unique)}' configs/dprint.*.json >"$tmp/config.json"
run_formatter "Generate plugin schemas" schema --config "$tmp/config.json" >"$tmp/generated.json"
jq --arg id 'https://raw.githubusercontent.com/kjanat/kjanat/master/schemas/dprint.schema.json' \
	'. + {"$id": $id}' "$tmp/generated.json" >"$tmp/with-id.json"
run_formatter "Format shared schema" fmt --stdin schemas/dprint.schema.json <"$tmp/with-id.json" >"$tmp/dprint.schema.json"

jq -e '.type == "object" and (.properties | has("plugins")) and (."$defs" | has("pluginTable"))' \
	"$tmp/dprint.schema.json" >/dev/null
mkdir -p schemas
mv "$tmp/dprint.schema.json" schemas/dprint.schema.json
echo "Published schemas/dprint.schema.json"
