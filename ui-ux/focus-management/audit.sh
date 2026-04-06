#!/usr/bin/env bash
# Focus Management Audit
# Checks that focus indicators are not removed and :focus-visible is used.
# WCAG 2.4.7 — Focus Visible, WCAG 2.4.11 — Focus Not Obscured
#
# Usage: ./quality-checks/ui-ux/focus-management/audit.sh [scan-dir]

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
echo -e "${BOLD}===== Focus Management Audit (WCAG 2.4.7 / 2.4.11) =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_ISSUES=0

# ── 1: outline: none / outline: 0 without focus-visible replacement ──
echo -e "${BOLD}1. Focus indicator removal (outline: none/0)${NC}"
echo "────────────────────────────────────────────────────────"
OUTLINE_NONE=$(grep -rn -E 'outline:\s*(none|0)\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
ISSUES_FOUND=0
if [ -n "$OUTLINE_NONE" ]; then
  while IFS= read -r line; do
    fullpath=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")

    # Check if the file has :focus-visible styles (acceptable replacement)
    if grep -q ':focus-visible' "$fullpath" 2>/dev/null; then
      echo -e "  ${DIM}OK${NC}    $file:$lineno — outline removed but :focus-visible exists"
    else
      echo -e "  ${RED}ERROR${NC} $file:$lineno — outline removed with no :focus-visible replacement"
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done <<< "$OUTLINE_NONE"
else
  echo -e "  ${GREEN}No outline removal found.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + ISSUES_FOUND))
echo ""

# ── 2: Global focus reset ──
echo -e "${BOLD}2. Global focus resets${NC}"
echo "────────────────────────────────────────────────────────"
GLOBAL_RESET=$(grep -rn -E '\*\s*\{[^}]*outline:\s*(none|0)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
# Also check for *:focus { outline: none }
FOCUS_RESET=$(grep -rn -E ':focus\s*\{[^}]*outline:\s*(none|0)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v ':focus-visible' || true)
COMBINED="${GLOBAL_RESET}${FOCUS_RESET}"
if [ -n "$COMBINED" ]; then
  echo "$COMBINED" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${RED}ERROR${NC} $file:$lineno — global focus indicator removal"
  done
  RESET_COUNT=$(echo "$COMBINED" | grep -cv '^$' || echo "0")
  TOTAL_ISSUES=$((TOTAL_ISSUES + RESET_COUNT))
else
  echo -e "  ${GREEN}No global focus resets found.${NC}"
fi
echo ""

# ── 3: Files with interactive elements but no :focus-visible ──
echo -e "${BOLD}3. Files with interactive elements but no :focus-visible styles${NC}"
echo "────────────────────────────────────────────────────────"
# Find files with buttons/inputs/links
INTERACTIVE_FILES=$(grep -rl -E '<(button|input|a |select|textarea)\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
FV_MISSING=0
if [ -n "$INTERACTIVE_FILES" ]; then
  while IFS= read -r filepath; do
    # Only check component files with <style> sections (not pure HTML without CSS)
    if grep -q '<style' "$filepath" 2>/dev/null || echo "$filepath" | grep -qE '\.(css|scss|less)$'; then
      if ! grep -q ':focus-visible' "$filepath" 2>/dev/null && ! grep -q ':focus' "$filepath" 2>/dev/null; then
        file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
        echo -e "  ${YELLOW}WARNING${NC} $file — has interactive elements but no focus styles"
        FV_MISSING=$((FV_MISSING + 1))
      fi
    fi
  done <<< "$INTERACTIVE_FILES"
fi
if [ "$FV_MISSING" -eq 0 ]; then
  echo -e "  ${GREEN}All component files with interactive elements have focus styles.${NC}"
else
  TOTAL_ISSUES=$((TOTAL_ISSUES + FV_MISSING))
fi
echo ""

# ── Summary ──
echo -e "${BOLD}Summary:${NC} $TOTAL_ISSUES issue(s)."
if [ "$TOTAL_ISSUES" -gt 0 ]; then
  echo -e "Add ${CYAN}:focus-visible${NC} styles to all interactive elements."
  echo -e "Never remove outline without providing a visible alternative."
fi
echo ""
