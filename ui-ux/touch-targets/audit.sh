#!/usr/bin/env bash
# Touch Targets Audit
# Flags interactive elements with explicit sizes below the minimum threshold.
# WCAG 2.5.5 (44px enhanced) / WCAG 2.5.8 (24px minimum)
#
# Usage: ./quality-checks/ui-ux/touch-targets/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."; FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"; MIN_TARGET_PX=44

if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in SCAN_DIR) SCAN_DIR="$val" ;; FILE_TYPES) FILE_TYPES="$val" ;; MIN_TARGET_PX) MIN_TARGET_PX="$val" ;; esac
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

echo ""
echo -e "${BOLD}===== Touch Targets Audit (WCAG 2.5.5 / 2.5.8) =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo -e "Minimum target size: ${CYAN}${MIN_TARGET_PX}px${NC}"
echo ""

TOTAL_WARNINGS=0

# ── 1: Explicit small height on interactive-looking selectors ──
echo -e "${BOLD}1. Small explicit heights on interactive elements${NC}"
echo "────────────────────────────────────────────────────────"
# Find height: Npx declarations where N < MIN_TARGET_PX
RESULTS=$(grep -rn -E 'height:\s*[0-9]+px' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
SMALL_H=0
if [ -n "$RESULTS" ]; then
  while IFS= read -r line; do
    value=$(echo "$line" | grep -oP 'height:\s*\K[0-9]+' | head -1 || echo "999")
    [ "$value" -ge "$MIN_TARGET_PX" ] 2>/dev/null && continue
    [ "$value" -le 2 ] 2>/dev/null && continue  # border/line heights

    fullpath=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)

    # Heuristic: check if this is near a button/input/link selector (within 10 lines above)
    START=$((lineno > 10 ? lineno - 10 : 1))
    CONTEXT=$(sed -n "${START},${lineno}p" "$fullpath" 2>/dev/null || true)
    if echo "$CONTEXT" | grep -qiE '(button|btn|input|\.action|\.icon-btn|\.avatar|a\b|link|click|toggle)'; then
      file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — height: ${RED}${value}px${NC} (below ${MIN_TARGET_PX}px)"
      SMALL_H=$((SMALL_H + 1))
    fi
  done <<< "$RESULTS"
fi
if [ "$SMALL_H" -eq 0 ]; then
  echo -e "  ${GREEN}No small interactive element heights found.${NC}"
fi
TOTAL_WARNINGS=$((TOTAL_WARNINGS + SMALL_H))
echo ""

# ── 2: Explicit small width on interactive-looking selectors ──
echo -e "${BOLD}2. Small explicit widths on interactive elements${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn -E '^\s*width:\s*[0-9]+px' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
SMALL_W=0
if [ -n "$RESULTS" ]; then
  while IFS= read -r line; do
    value=$(echo "$line" | grep -oP 'width:\s*\K[0-9]+' | head -1 || echo "999")
    [ "$value" -ge "$MIN_TARGET_PX" ] 2>/dev/null && continue
    [ "$value" -le 2 ] 2>/dev/null && continue

    fullpath=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)

    START=$((lineno > 10 ? lineno - 10 : 1))
    CONTEXT=$(sed -n "${START},${lineno}p" "$fullpath" 2>/dev/null || true)
    if echo "$CONTEXT" | grep -qiE '(button|btn|input|\.action|\.icon-btn|\.avatar|a\b|link|click|toggle)'; then
      file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — width: ${RED}${value}px${NC} (below ${MIN_TARGET_PX}px)"
      SMALL_W=$((SMALL_W + 1))
    fi
  done <<< "$RESULTS"
fi
if [ "$SMALL_W" -eq 0 ]; then
  echo -e "  ${GREEN}No small interactive element widths found.${NC}"
fi
TOTAL_WARNINGS=$((TOTAL_WARNINGS + SMALL_W))
echo ""

# ── 3: Interactive elements sized in mobile breakpoints ──
echo -e "${BOLD}3. Interactive elements resized in mobile breakpoints (info)${NC}"
echo "────────────────────────────────────────────────────────"
# Heuristic: find @media blocks with max-width that contain small height/width on interactive selectors
RESULTS=$(grep -rn -A5 '@media.*max-width' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -E '(height|width):\s*[0-9]+px' || true)
MOBILE_SMALL=0
if [ -n "$RESULTS" ]; then
  while IFS= read -r line; do
    value=$(echo "$line" | grep -oP '(height|width):\s*\K[0-9]+' | head -1 || echo "999")
    [ "$value" -ge "$MIN_TARGET_PX" ] 2>/dev/null && continue
    [ "$value" -le 2 ] 2>/dev/null && continue

    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1 | cut -d- -f1)
    echo -e "  ${DIM}INFO${NC} $file — mobile breakpoint sets size to ${value}px"
    MOBILE_SMALL=$((MOBILE_SMALL + 1))
  done <<< "$RESULTS"
fi
if [ "$MOBILE_SMALL" -eq 0 ]; then
  echo -e "  ${GREEN}No mobile breakpoint size reductions found.${NC}"
fi
echo ""

echo -e "${BOLD}Summary:${NC} $TOTAL_WARNINGS warning(s), $MOBILE_SMALL info notice(s)."
[ "$TOTAL_WARNINGS" -gt 0 ] && echo -e "Ensure touch targets are at least ${CYAN}${MIN_TARGET_PX}x${MIN_TARGET_PX}px${NC} for comfortable interaction."
echo ""
