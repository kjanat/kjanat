#!/usr/bin/env bash

# 1. Move to the project root (2 levels up from .github/scripts/)
# This ensures the relative "configs/" paths work correctly.
cd "$(dirname "$0")/../../" || exit 1

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CONFIGS=(
	"configs/dprint.exec.json"
	"configs/dprint.biome.json"
	"configs/dprint.remote.json"
)

SECONDS=0

echo -e "${CYAN}[0s] Starting dprint configuration updates...${NC}"

for config in "${CONFIGS[@]}"; do
	(
		start=$SECONDS
		echo -e "  [${start}s] Updating: ${config}..."
		if dprint config update -c="${config}" >/dev/null 2>&1; then
			echo -e "  ${GREEN}[✓] Finished: ${config} ($((SECONDS - start))s)${NC}"
		else
			echo -e "  ${RED}[✗] Failed: ${config} ($((SECONDS - start))s)${NC}"
		fi
	) &
done

wait

echo -e "${CYAN}[${SECONDS}s] All parallel updates completed.${NC}"
