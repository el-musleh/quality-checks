#!/usr/bin/env bash
# Bundle Size Audit
# Reports file sizes in the build output directory and flags oversized files.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/performance/bundle-size/audit.sh [build-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
BUILD_DIR="dist"
WARN_FILE_KB=500
WARN_TOTAL_KB=2000
EXCLUDE_PATTERN="*.map"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    val=$(echo "$val" | xargs)
    case "$key" in
      BUILD_DIR) BUILD_DIR="$val" ;;
      WARN_FILE_KB) WARN_FILE_KB="$val" ;;
      WARN_TOTAL_KB) WARN_TOTAL_KB="$val" ;;
      EXCLUDE_PATTERN) EXCLUDE_PATTERN="$val" ;;
    esac
  done < "$CONF_FILE"
fi

# CLI override
TARGET="${1:-$BUILD_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then
  BUILD_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then
  BUILD_PATH="$TARGET"
else
  echo "Error: Build directory '$TARGET' not found." >&2
  echo "Hint: Run your build command first, or set BUILD_DIR in config.conf." >&2
  exit 1
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}===== Bundle Size Audit =====${NC}"
echo -e "Build directory: ${CYAN}$BUILD_PATH${NC}"
echo -e "Thresholds: file=${CYAN}${WARN_FILE_KB}KB${NC}, total=${CYAN}${WARN_TOTAL_KB}KB${NC}"
echo ""

# ── List files sorted by size ──
echo -e "${BOLD}Files by size (largest first):${NC}"
echo "────────────────────────────────────────────────────────"

TOTAL_BYTES=0
OVERSIZED=0

while IFS= read -r line; do
  SIZE_BYTES=$(echo "$line" | awk '{print $1}')
  FILE=$(echo "$line" | awk '{print $2}')
  REL_FILE=$(echo "$FILE" | sed "s|$PROJECT_ROOT/||")
  BASENAME=$(basename "$FILE")

  # Skip excluded patterns
  if [[ "$BASENAME" == $EXCLUDE_PATTERN ]]; then
    continue
  fi

  SIZE_KB=$((SIZE_BYTES / 1024))
  TOTAL_BYTES=$((TOTAL_BYTES + SIZE_BYTES))

  if [ "$SIZE_KB" -ge "$WARN_FILE_KB" ]; then
    echo -e "  ${RED}${SIZE_KB}KB${NC}  $REL_FILE  ${RED}(exceeds ${WARN_FILE_KB}KB)${NC}"
    OVERSIZED=$((OVERSIZED + 1))
  elif [ "$SIZE_KB" -ge $((WARN_FILE_KB / 2)) ]; then
    echo -e "  ${YELLOW}${SIZE_KB}KB${NC}  $REL_FILE"
  else
    echo -e "  ${GREEN}${SIZE_KB}KB${NC}  $REL_FILE"
  fi
done < <(find "$BUILD_PATH" -type f ! -name "$EXCLUDE_PATTERN" -printf '%s %p\n' 2>/dev/null | sort -rn)

echo ""

# ── Total ──
TOTAL_KB=$((TOTAL_BYTES / 1024))
echo -e "${BOLD}Total bundle size:${NC} ${TOTAL_KB}KB"

if [ "$TOTAL_KB" -ge "$WARN_TOTAL_KB" ]; then
  echo -e "  ${RED}Exceeds total threshold of ${WARN_TOTAL_KB}KB${NC}"
elif [ "$TOTAL_KB" -ge $((WARN_TOTAL_KB * 3 / 4)) ]; then
  echo -e "  ${YELLOW}Approaching total threshold of ${WARN_TOTAL_KB}KB${NC}"
else
  echo -e "  ${GREEN}Within total threshold of ${WARN_TOTAL_KB}KB${NC}"
fi

echo ""

# ── Summary ──
if [ "$OVERSIZED" -gt 0 ]; then
  echo -e "${BOLD}Summary:${NC} $OVERSIZED file(s) exceed the ${WARN_FILE_KB}KB threshold."
else
  echo -e "${BOLD}Summary:${NC} ${GREEN}All files within size thresholds.${NC}"
fi
echo ""
