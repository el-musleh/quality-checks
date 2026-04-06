#!/usr/bin/env bash
# TODO/FIXME Audit
# Finds and reports all TODO, FIXME, HACK, and BUG comments in the codebase.
# Portable — configure via config.conf.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
SCAN_DIR="."
FILE_TYPES="svelte,vue,jsx,tsx,ts,js,html,css,scss,less"
KEYWORDS="TODO|FIXME|HACK|BUG|OPTIMIZE"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;;
      FILE_TYPES) FILE_TYPES="$val" ;;
      KEYWORDS) KEYWORDS="$val" ;;
    esac
  done < "$CONF_FILE"
fi

TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then SCAN_PATH="$TARGET"
else echo "Error: '$TARGET' is not a directory." >&2; exit 1; fi

IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=(); for ext in "${EXTENSIONS[@]}"; do ext=$(echo "$ext" | xargs); INCLUDE_FLAGS+=(--include="*.${ext}"); done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build')

# Colors
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== TODO / FIXME Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo -e "Keywords: ${CYAN}${KEYWORDS}${NC}"
echo ""

# Find matches
RESULTS=$(grep -rnE "(${KEYWORDS})" "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)

if [ -z "$RESULTS" ]; then
  echo -e "  ${GREEN}No TODO or FIXME comments found.${NC}"
  echo ""
  exit 0
fi

# Summary counts
TODO_COUNT=$(echo "$RESULTS" | grep -c "TODO" || true)
FIXME_COUNT=$(echo "$RESULTS" | grep -c "FIXME" || true)
HACK_COUNT=$(echo "$RESULTS" | grep -c "HACK" || true)
BUG_COUNT=$(echo "$RESULTS" | grep -c "BUG" || true)

echo -e "${BOLD}Technical Debt Summary:${NC}"
echo "────────────────────────────────────────────────────────"
[ "$TODO_COUNT" -ne 0 ] && echo -e "  ${CYAN}TODOs:${NC}   $TODO_COUNT"
[ "$FIXME_COUNT" -ne 0 ] && echo -e "  ${RED}FIXMEs:${NC}  $FIXME_COUNT"
[ "$HACK_COUNT" -ne 0 ] && echo -e "  ${YELLOW}HACKs:${NC}   $HACK_COUNT"
[ "$BUG_COUNT" -ne 0 ] && echo -e "  ${RED}BUGs:${NC}    $BUG_COUNT"

echo ""
echo -e "${BOLD}Findings:${NC}"
echo "$RESULTS" | while IFS= read -r line; do
  file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  comment=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
  
  # Highlight the keyword
  formatted_comment=$(echo "$comment" | sed -E "s/(${KEYWORDS})/\x1b[1m\1\x1b[0m/g")
  
  echo -e "  ${DIM}$file:$lineno${NC}"
  echo -e "    $formatted_comment"
done

echo ""
TOTAL=$((TODO_COUNT + FIXME_COUNT + HACK_COUNT + BUG_COUNT))
echo -e "${BOLD}Summary:${NC} $TOTAL comments found."
echo ""
