#!/usr/bin/env bash
# Accessibility Audit
# Scans frontend files for common accessibility issues.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/ui-ux/accessibility/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
SCAN_DIR="."
FILE_TYPES="svelte,vue,jsx,tsx,html"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    val=$(echo "$val" | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;;
      FILE_TYPES) FILE_TYPES="$val" ;;
    esac
  done < "$CONF_FILE"
fi

# CLI override
TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then
  SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then
  SCAN_PATH="$TARGET"
else
  echo "Error: '$TARGET' is not a directory." >&2
  exit 1
fi

# Build include flags
IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=()
for ext in "${EXTENSIONS[@]}"; do
  ext=$(echo "$ext" | xargs)
  INCLUDE_FLAGS+=(--include="*.${ext}")
done
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build')

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ISSUES=0

echo ""
echo -e "${BOLD}===== Accessibility Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

# ── Check 1: <img> without alt ──
echo -e "${BOLD}1. Images missing alt attribute${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn '<img\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'alt=' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${RED}ERROR${NC} $file:$lineno — <img> without alt"
  done
  ISSUES=$((ISSUES + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}All images have alt attributes.${NC}"
fi
echo ""

# ── Check 2: <button> without accessible text ──
echo -e "${BOLD}2. Buttons without accessible label${NC}"
echo "────────────────────────────────────────────────────────"
# Find self-closing buttons or buttons with only icon children (no text, no aria-label)
RESULTS=$(grep -rn '<button\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'aria-label' | grep '/>' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${RED}ERROR${NC} $file:$lineno — self-closing <button> without aria-label"
  done
  ISSUES=$((ISSUES + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No obvious unlabeled buttons found.${NC}"
fi
echo ""

# ── Check 3: <input> without label association ──
echo -e "${BOLD}3. Inputs without label or aria-label${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rn '<input\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'aria-label' | grep -v 'type="hidden"' | grep -v 'type="submit"' | grep -v 'placeholder=' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — <input> without aria-label or placeholder"
  done
  ISSUES=$((ISSUES + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}All inputs have labels or placeholders.${NC}"
fi
echo ""

# ── Check 4: Click handlers on non-interactive elements ──
echo -e "${BOLD}4. Click handlers on non-interactive elements without role/tabindex${NC}"
echo "────────────────────────────────────────────────────────"
# Svelte: on:click on div/span; React: onClick on div/span
RESULTS=$(grep -rn -E '(<div|<span)[^>]*(on:click|onClick)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'role=' || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — click handler on <div>/<span> without role attribute"
  done
  ISSUES=$((ISSUES + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No click handlers on non-interactive elements missing role.${NC}"
fi
echo ""

# ── Summary ──
if [ "$ISSUES" -gt 0 ]; then
  echo -e "${BOLD}Summary:${NC} $ISSUES accessibility issue(s) found."
else
  echo -e "${BOLD}Summary:${NC} ${GREEN}No accessibility issues detected.${NC}"
fi
echo ""
