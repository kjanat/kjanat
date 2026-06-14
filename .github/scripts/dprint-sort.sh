#!/usr/bin/env bash

# Canonicalises the key order of dprint config files:
#   0. "$schema"  (always first; injected if missing)
#   1. global dprint options (useTabs, indentWidth, ...) — original order kept
#   2. kjanat-authored plugin config blocks   — alphabetical
#   3. other plugin config blocks             — alphabetical
#   4. "excludes"
#   5. "plugins"  (always last; entries: kjanat URLs first, then the rest,
#                  each group alphabetical)
#
# Key order and plugin order are set with jq, then the file is re-formatted
# through `dprint fmt` so the result matches dprint's canonical layout (short
# arrays/objects collapsed onto one line). Idempotent. Usage:
#   dprint-sort.sh [config.json ...]   (defaults to the three configs/ files)

set -euo pipefail

cd "$(dirname "$0")/../../" || exit 1

SCHEMA_URL="https://dprint.dev/schemas/v0.json"

GREEN='\033[0;32m'
DIM='\033[0;90m'
NC='\033[0m'

# Derive the config keys of kjanat-authored plugins from a config's own plugin
# list: resolve only the kjanat (URL contains "kjanat") plugins and read back
# their configKeys. dprint owns the URL->configKey mapping, so nothing is
# hardcoded — add a kjanat plugin and its block sorts to the top automatically.
kjanat_config_keys() {
	local f="$1" resolved
	local urls=()
	mapfile -t urls < <(jq -r '(.plugins // [])[] | select(test("kjanat"))' "$f")
	if [[ ${#urls[@]} -eq 0 ]]; then
		printf '[]'
		return 0
	fi
	resolved="$(dprint output-resolved-config --config-discovery=false --plugins "${urls[@]}" </dev/null 2>/dev/null)" ||
		{
			echo "  [!] could not resolve kjanat plugins for $f" >&2
			return 1
		}
	printf '%s' "$resolved" | jq -c 'keys'
}

FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
	FILES=(
		"configs/dprint.exec.json"
		"configs/dprint.biome.json"
		"configs/dprint.remote.json"
	)
fi

REORDER='
  def iskjanat($k): ($kjanat | index($k)) != null;
  . as $c
  | [to_entries[] | select(.key | . != "$schema" and . != "excludes" and . != "plugins")] as $rest
  | [$rest[] | select((.value | type) != "object")] as $globals
  | [$rest[] | select((.value | type) == "object")] as $blocks
  | ([$blocks[] | select(iskjanat(.key))]      | sort_by(.key | ascii_downcase)) as $kjBlocks
  | ([$blocks[] | select(iskjanat(.key) | not)] | sort_by(.key | ascii_downcase)) as $otherBlocks
  | ($c.plugins // []) as $p
  | ( ([$p[] | select(test("kjanat"))]      | sort)
    + ([$p[] | select(test("kjanat") | not)] | sort) ) as $sortedPlugins
  | {"$schema": $schemaUrl}
    + (($globals + $kjBlocks + $otherBlocks) | from_entries)
    + (if ($c | has("excludes")) then {excludes: $c.excludes} else {} end)
    + (if ($c | has("plugins"))  then {plugins:  $sortedPlugins} else {} end)
'

status=0
for f in "${FILES[@]}"; do
	if [[ ! -f "$f" ]]; then
		echo "  [!] skip (not found): $f" >&2
		status=1
		continue
	fi
	kjanat="$(kjanat_config_keys "$f")" || {
		status=1
		continue
	}
	tmp="$(mktemp)"
	jq -c --arg schemaUrl "$SCHEMA_URL" --argjson kjanat "$kjanat" "$REORDER" "$f" |
		dprint fmt --stdin "$f" >"$tmp"
	if cmp -s "$f" "$tmp"; then
		echo -e "  ${DIM}[=] already sorted: ${f}${NC}"
		rm -f "$tmp"
	else
		mv "$tmp" "$f"
		echo -e "  ${GREEN}[✓] sorted: ${f}${NC}"
	fi
done

exit "$status"
