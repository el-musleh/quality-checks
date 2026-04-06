#!/usr/bin/env bash
# Reduced Motion Audit
# Checks that animations and transitions respect prefers-reduced-motion.
# WCAG 2.3.3 — Animation from Interactions
#
# Usage: ./quality-checks/ui-ux/reduced-motion/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."; FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"

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
INCLUDE_FLAGS=(); for ext in "${EXTENSIONS[@]}"; do ext=$(echo "$ext" | xargs); INCLUDE_FLAGS+=(--include="*.${ext}"); done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build' --exclude='*.min.css' --exclude='*.min.js')

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Reduced Motion Audit (WCAG 2.3.3) =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_ISSUES=0

# ── 1: Files with @keyframes but no prefers-reduced-motion ──
echo -e "${BOLD}1. Files with @keyframes but no prefers-reduced-motion query${NC}"
echo "────────────────────────────────────────────────────────"
KF_FILES=$(grep -rl '@keyframes' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
KF_MISSING=0
if [ -n "$KF_FILES" ]; then
  while IFS= read -r filepath; do
    if ! grep -q 'prefers-reduced-motion' "$filepath" 2>/dev/null; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      KF_COUNT=$(grep -c '@keyframes' "$filepath" 2>/dev/null || echo "0")
      echo -e "  ${RED}ERROR${NC} $file — $KF_COUNT @keyframes, no reduced-motion query"
      KF_MISSING=$((KF_MISSING + 1))
    fi
  done <<< "$KF_FILES"
fi
if [ "$KF_MISSING" -eq 0 ]; then
  echo -e "  ${GREEN}All files with @keyframes have reduced-motion queries.${NC}"
else
  TOTAL_ISSUES=$((TOTAL_ISSUES + KF_MISSING))
fi
echo ""

# ── 2: Files with animation: but no prefers-reduced-motion ──
echo -e "${BOLD}2. Files with animation: declarations but no reduced-motion query${NC}"
echo "────────────────────────────────────────────────────────"
ANIM_FILES=$(grep -rl -E 'animation\s*:' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v '@keyframes' || true)
# Deduplicate — some files already counted above
ANIM_MISSING=0
if [ -n "$ANIM_FILES" ]; then
  while IFS= read -r filepath; do
    if ! grep -q 'prefers-reduced-motion' "$filepath" 2>/dev/null; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      # Only report if not already reported in section 1
      if [ -n "$KF_FILES" ] && echo "$KF_FILES" | grep -qF "$filepath"; then
        continue
      fi
      echo -e "  ${YELLOW}WARNING${NC} $file — has animation: but no reduced-motion query"
      ANIM_MISSING=$((ANIM_MISSING + 1))
    fi
  done <<< "$ANIM_FILES"
fi
if [ "$ANIM_MISSING" -eq 0 ]; then
  echo -e "  ${GREEN}All files with animations have reduced-motion coverage.${NC}"
else
  TOTAL_ISSUES=$((TOTAL_ISSUES + ANIM_MISSING))
fi
echo ""

# ── 3: Files with long transitions but no reduced-motion ──
echo -e "${BOLD}3. Files with transitions >300ms but no reduced-motion query${NC}"
echo "────────────────────────────────────────────────────────"
TRANS_MISSING=0
TRANS_FILES=$(grep -rl -E 'transition[^:]*:' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$TRANS_FILES" ]; then
  while IFS= read -r filepath; do
    # Skip if already has reduced-motion
    grep -q 'prefers-reduced-motion' "$filepath" 2>/dev/null && continue

    # Check if any transition is >300ms
    HAS_LONG=0
    while IFS= read -r tline; do
      for ms_val in $(echo "$tline" | grep -oP '[0-9]+ms' | grep -oP '[0-9]+'); do
        [ "$ms_val" -gt 300 ] 2>/dev/null && HAS_LONG=1 && break
      done
      [ "$HAS_LONG" -eq 1 ] && break
      for s_val in $(echo "$tline" | grep -oP '[0-9]+\.?[0-9]*s' | grep -v 'ms' | grep -oP '[0-9]+\.?[0-9]*'); do
        ms_equiv=$(echo "$s_val * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")
        [ "${ms_equiv:-0}" -gt 300 ] 2>/dev/null && HAS_LONG=1 && break
      done
      [ "$HAS_LONG" -eq 1 ] && break
    done < <(grep -n -E 'transition[^:]*:' "$filepath" 2>/dev/null || true)

    if [ "$HAS_LONG" -eq 1 ]; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${DIM}INFO${NC} $file — has transitions >300ms without reduced-motion"
      TRANS_MISSING=$((TRANS_MISSING + 1))
    fi
  done <<< "$TRANS_FILES"
fi
if [ "$TRANS_MISSING" -eq 0 ]; then
  echo -e "  ${GREEN}No long transitions missing reduced-motion coverage.${NC}"
fi
echo ""

# ── Summary ──
echo -e "${BOLD}Summary:${NC} $TOTAL_ISSUES issue(s), $TRANS_MISSING info notice(s)."
if [ "$TOTAL_ISSUES" -gt 0 ]; then
  echo -e "Add ${CYAN}@media (prefers-reduced-motion: reduce)${NC} to files with animations."
  echo -e "Or add a global override in your base CSS / design tokens."
fi
echo ""
