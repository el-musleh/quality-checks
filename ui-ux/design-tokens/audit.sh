#!/usr/bin/env bash
# Design Tokens Audit
# Finds hardcoded colors, font sizes, and shadows that should use CSS variables.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/ui-ux/design-tokens/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
SCAN_DIR="."
FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"
ALLOWED_HARDCODED="white,black,transparent,inherit,currentColor,none"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    val=$(echo "$val" | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;;
      FILE_TYPES) FILE_TYPES="$val" ;;
      ALLOWED_HARDCODED) ALLOWED_HARDCODED="$val" ;;
    esac
  done < "$CONF_FILE"
fi

TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then
  SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then
  SCAN_PATH="$TARGET"
else
  echo "Error: '$TARGET' is not a directory." >&2; exit 1
fi

IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=()
for ext in "${EXTENSIONS[@]}"; do
  ext=$(echo "$ext" | xargs)
  INCLUDE_FLAGS+=(--include="*.${ext}")
done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build' --exclude='*.min.css' --exclude='*.min.js')

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Design Tokens Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_WARNINGS=0

# ── 1: Hardcoded hex colors ──
echo -e "${BOLD}1. Hardcoded hex colors in color/background properties${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E '(^|;|\s)(color|background-color|background|border-color|outline-color):\s*#[0-9a-fA-F]' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'var(--' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    value=$(echo "$line" | grep -oP '#[0-9a-fA-F]{3,8}' | head -1 || echo "?")
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — hardcoded ${CYAN}$value${NC}"
  done
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No hardcoded hex colors found.${NC}"
fi
echo ""

# ── 2: Hardcoded rgb/rgba ──
echo -e "${BOLD}2. Hardcoded rgb()/rgba() in text and background colors${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E '(^|;|\s)(color|background-color):\s*rgba?\(' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'var(--' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — hardcoded rgb/rgba"
  done
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No hardcoded rgb/rgba in text or background colors.${NC}"
fi
echo ""

# ── 3: Hardcoded pixel font sizes ──
echo -e "${BOLD}3. Hardcoded pixel font sizes${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E 'font-size:\s*[0-9]+px' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'var(--' | grep -v 'clamp(' || true)
if [ -n "$RESULTS" ]; then
  COUNT=$(echo "$RESULTS" | wc -l)
  echo -e "  ${DIM}$COUNT occurrences. Showing first 20:${NC}"
  echo "$RESULTS" | head -20 | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    value=$(echo "$line" | grep -oP '[0-9]+px' | head -1 || echo "?")
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — hardcoded ${CYAN}$value${NC}"
  done
  [ "$COUNT" -gt 20 ] && echo -e "  ${DIM}... and $((COUNT - 20)) more${NC}"
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + COUNT))
else
  echo -e "  ${GREEN}All font sizes use CSS variables or clamp().${NC}"
fi
echo ""

# ── 4: Hardcoded box shadows ──
echo -e "${BOLD}4. Hardcoded box-shadow values (info only)${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E 'box-shadow:\s*[0-9]' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'var(--' | grep -v 'box-shadow:\s*none' || true)
INFO_COUNT=0
if [ -n "$RESULTS" ]; then
  INFO_COUNT=$(echo "$RESULTS" | wc -l)
  echo -e "  ${DIM}$INFO_COUNT occurrences. Showing first 10:${NC}"
  echo "$RESULTS" | head -10 | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${DIM}INFO${NC} $file:$lineno"
  done
  [ "$INFO_COUNT" -gt 10 ] && echo -e "  ${DIM}... and $((INFO_COUNT - 10)) more${NC}"
else
  echo -e "  ${GREEN}All box shadows use CSS variables.${NC}"
fi
echo ""

# ── Summary ──
echo -e "${BOLD}Summary:${NC} $TOTAL_WARNINGS warning(s), $INFO_COUNT info occurrence(s)."
[ "$TOTAL_WARNINGS" -gt 0 ] && echo -e "Replace hardcoded values with CSS variables for consistent theming."
echo ""
