#!/usr/bin/env bash
# Keyboard Shortcuts Audit
# Flags global keydown listeners to encourage checking against reserved browser shortcuts.
# Portable — configure via config.conf.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."
FILE_TYPES="svelte,vue,jsx,tsx,js,ts"

if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in SCAN_DIR) SCAN_DIR="$val" ;; FILE_TYPES) FILE_TYPES="$val" ;; esac
  done < "$CONF_FILE"
fi

TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then SCAN_PATH="$TARGET"
else echo "Error: '$TARGET' is not a directory." >&2; exit 1; fi

IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=()
for ext in "${EXTENSIONS[@]}"; do
  ext=$(echo "$ext" | xargs)
  INCLUDE_FLAGS+=(--include="*.${ext}")
done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build')

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Keyboard Shortcuts Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_WARNINGS=0

echo -e "${BOLD}1. Global Keydown Listeners (Must protect reserved shortcuts)${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E 'window\.addEventListener\([\'"'"'"]keydown[\'"'"'"]|<svelte:window\s*on:keydown' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)

if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — global ${CYAN}keydown${NC} listener found. Ensure reserved browser shortcuts (e.g. Ctrl+C) are not overridden."
  done
  TOTAL_WARNINGS=$(echo "$RESULTS" | wc -l)
else
  echo -e "  ${GREEN}No global keydown listeners found.${NC}"
fi

echo ""
echo -e "${BOLD}Summary:${NC} $TOTAL_WARNINGS warning(s)."
[ "$TOTAL_WARNINGS" -gt 0 ] && echo -e "Review keydown logic to ensure it checks against an array of reserved native shortcuts."
echo ""
