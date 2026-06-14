#!/usr/bin/env bash

# Updates each dprint config's plugins in parallel.
# Each `dprint config update` invocation is killed if it runs longer than
# DPRINT_UPDATE_TIMEOUT seconds and retried up to DPRINT_UPDATE_ATTEMPTS times.

set -uo pipefail

# 1. Move to the project root (2 levels up from .github/scripts/)
# This ensures the relative "configs/" paths work correctly.
cd "$(dirname "$0")/../../" || exit 1

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CONFIGS=(
	"configs/dprint.exec.json"
	"configs/dprint.biome.json"
	"configs/dprint.remote.json"
)

# Per-invocation wall-clock budget and retry count (overridable via env).
TIMEOUT_SECS="${DPRINT_UPDATE_TIMEOUT:-15}"
MAX_ATTEMPTS="${DPRINT_UPDATE_ATTEMPTS:-4}"
KILL_GRACE="5s"

SECONDS=0

update_config() {
	local config="$1"
	local start=$SECONDS
	local attempt rc

	for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
		echo -e "  [${SECONDS}s] Updating: ${config} (attempt ${attempt}/${MAX_ATTEMPTS})..."
		# Capture the exit code directly: a bash `if` whose condition fails (with
		# no else) yields 0, so `$?` after `fi` would not reflect the real code.
		rc=0
		timeout --kill-after="${KILL_GRACE}" "${TIMEOUT_SECS}s" \
			dprint config update --yes -c="${config}" >/dev/null 2>&1 || rc=$?
		if [[ $rc -eq 0 ]]; then
			echo -e "  ${GREEN}[✓] Finished: ${config} ($((SECONDS - start))s, attempt ${attempt}/${MAX_ATTEMPTS})${NC}"
			return 0
		fi
		if [[ $rc -eq 124 || $rc -eq 137 ]]; then
			echo -e "  ${YELLOW}[!] Timed out after ${TIMEOUT_SECS}s: ${config} (attempt ${attempt}/${MAX_ATTEMPTS})${NC}"
		else
			echo -e "  ${YELLOW}[!] Failed (exit ${rc}): ${config} (attempt ${attempt}/${MAX_ATTEMPTS})${NC}"
		fi
		# Brief backoff before retrying, but not after the final attempt.
		((attempt < MAX_ATTEMPTS)) && sleep 1
	done

	echo -e "  ${RED}[✗] Giving up: ${config} after ${MAX_ATTEMPTS} attempts ($((SECONDS - start))s)${NC}"
	return 1
}

echo -e "${CYAN}[0s] Starting dprint configuration updates (timeout ${TIMEOUT_SECS}s, ${MAX_ATTEMPTS} attempts)...${NC}"

pids=()
for config in "${CONFIGS[@]}"; do
	update_config "$config" &
	pids+=("$!")
done

# Wait for every update; surface a non-zero exit if any config ultimately failed.
status=0
for pid in "${pids[@]}"; do
	wait "$pid" || status=1
done

if [[ $status -eq 0 ]]; then
	echo -e "${CYAN}[${SECONDS}s] All parallel updates completed.${NC}"
else
	echo -e "${RED}[${SECONDS}s] One or more updates failed.${NC}"
fi

exit "$status"
