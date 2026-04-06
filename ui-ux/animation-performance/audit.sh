#!/usr/bin/env bash
# Animation Performance Audit
# Checks that animations use GPU-accelerated properties and sensible durations.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/ui-ux/animation-performance/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."; FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"
MAX_DURATION_MS=500; MIN_DURATION_MS=100

if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;; FILE_TYPES) FILE_TYPES="$val" ;;
      MAX_DURATION_MS) MAX_DURATION_MS="$val" ;; MIN_DURATION_MS) MIN_DURATION_MS="$val" ;;
    esac
  done < "$CONF_FILE"
fi

TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then SCAN_PATH="$TARGET"
else echo "Error: '$TARGET' is not a directory." >&2; exit 1; fi

IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=(); for ext in "${EXTENSIONS[@]}"; do ext=$(echo "$ext" | xargs); INCLUDE_FLAGS+=(--include="*.${ext}"); done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build' --exclude='*.min.css' --exclude='*.min.js')

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Layout-triggering properties that should not be animated
LAYOUT_PROPS="top|left|right|bottom|width|height|margin|padding"

echo ""
echo -e "${BOLD}===== Animation Performance Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_WARNINGS=0

# ── 1: Transitions on layout properties ──
echo -e "${BOLD}1. Transitions on layout-triggering properties${NC}"
echo -e "   ${DIM}(top, left, right, bottom, width, height, margin, padding cause layout recalc)${NC}"
echo "────────────────────────────────────────────────────────"
# Match "transition:" lines that contain layout property names (but not "transform" or "all")
RESULTS=$(grep -rn -E 'transition[^:]*:' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -E "(${LAYOUT_PROPS})" | grep -v 'transition:\s*none' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    prop=$(echo "$line" | grep -oE "(${LAYOUT_PROPS})" | head -1 || echo "?")
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — transition on ${RED}$prop${NC} (use transform instead)"
  done
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No transitions on layout-triggering properties.${NC}"
fi
echo ""

# ── 2: Slow animations (>MAX_DURATION_MS) ──
echo -e "${BOLD}2. Animation durations exceeding ${MAX_DURATION_MS}ms${NC}"
echo "────────────────────────────────────────────────────────"
# Match explicit ms durations in transition/animation properties
SLOW_RESULTS=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # Extract all ms values from the line
  for ms_val in $(echo "$line" | grep -oP '[0-9]+ms' | grep -oP '[0-9]+'); do
    if [ "$ms_val" -gt "$MAX_DURATION_MS" ] 2>/dev/null; then
      SLOW_RESULTS="${SLOW_RESULTS}${line}\n"
      break
    fi
  done
  # Also check "s" durations (e.g. 0.6s = 600ms)
  for s_val in $(echo "$line" | grep -oP '[0-9]+\.?[0-9]*s' | grep -v 'ms' | grep -oP '[0-9]+\.?[0-9]*'); do
    ms_equiv=$(echo "$s_val * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")
    if [ "${ms_equiv:-0}" -gt "$MAX_DURATION_MS" ] 2>/dev/null; then
      SLOW_RESULTS="${SLOW_RESULTS}${line}\n"
      break
    fi
  done
done < <(grep -rn -E '(transition|animation)[^:]*:' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v '@keyframes' | grep -v 'animation-name' || true)

if [ -n "$SLOW_RESULTS" ]; then
  echo -e "$SLOW_RESULTS" | grep -v '^$' | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — animation >${MAX_DURATION_MS}ms (feels sluggish)"
  done
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + $(echo -e "$SLOW_RESULTS" | grep -cv '^$')))
else
  echo -e "  ${GREEN}All animation durations are within ${MAX_DURATION_MS}ms.${NC}"
fi
echo ""

# ── 3: Too-fast animations (<MIN_DURATION_MS) ──
echo -e "${BOLD}3. Animation durations below ${MIN_DURATION_MS}ms${NC}"
echo "────────────────────────────────────────────────────────"
FAST_RESULTS=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  for ms_val in $(echo "$line" | grep -oP '[0-9]+ms' | grep -oP '[0-9]+'); do
    if [ "$ms_val" -gt 0 ] && [ "$ms_val" -lt "$MIN_DURATION_MS" ] 2>/dev/null; then
      FAST_RESULTS="${FAST_RESULTS}${line}\n"
      break
    fi
  done
done < <(grep -rn -E '(transition|animation)[^:]*:' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v '@keyframes' | grep -v 'animation-name' || true)

if [ -n "$FAST_RESULTS" ]; then
  echo -e "$FAST_RESULTS" | grep -v '^$' | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — animation <${MIN_DURATION_MS}ms (imperceptible)"
  done
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + $(echo -e "$FAST_RESULTS" | grep -cv '^$')))
else
  echo -e "  ${GREEN}No too-fast animations found.${NC}"
fi
echo ""

# ── 4: @keyframes animating layout properties ──
echo -e "${BOLD}4. @keyframes animating layout properties (info)${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E "^\s*(${LAYOUT_PROPS}):" "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
# Filter to only lines that are inside @keyframes blocks (heuristic: check if file has @keyframes)
KF_ISSUES=""
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    fullpath=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    # Check if there's a @keyframes within 30 lines above
    START=$((lineno > 30 ? lineno - 30 : 1))
    CONTEXT=$(sed -n "${START},${lineno}p" "$fullpath" 2>/dev/null || true)
    if echo "$CONTEXT" | grep -q '@keyframes'; then
      file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")
      prop=$(echo "$line" | grep -oE "(${LAYOUT_PROPS})" | head -1 || echo "?")
      echo -e "  ${DIM}INFO${NC} $file:$lineno — @keyframes animates ${CYAN}$prop${NC} (prefer transform)"
    fi
  done
fi
echo ""

echo -e "${BOLD}Summary:${NC} $TOTAL_WARNINGS warning(s)."
[ "$TOTAL_WARNINGS" -gt 0 ] && echo -e "Use ${CYAN}transform${NC} and ${CYAN}opacity${NC} for smooth 60fps animations."
echo ""
