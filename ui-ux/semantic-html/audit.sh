#!/usr/bin/env bash
# Semantic HTML Audit
# Checks heading hierarchy, landmark roles, form labels, and semantic element usage.
# WCAG 1.3.1, 2.4.6
#
# Usage: ./quality-checks/ui-ux/semantic-html/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."; FILE_TYPES="svelte,vue,jsx,tsx,html"

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
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build')

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Semantic HTML Audit (WCAG 1.3.1 / 2.4.6) =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

TOTAL_ISSUES=0

# ── 1: Heading hierarchy ──
echo -e "${BOLD}1. Heading hierarchy (skipped levels)${NC}"
echo "────────────────────────────────────────────────────────"
HEADING_FILES=$(grep -rl -E '<h[1-6]\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
SKIP_ISSUES=0
if [ -n "$HEADING_FILES" ]; then
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    # Extract heading levels in order of appearance
    LEVELS=$(grep -oP '<h\K[1-6]' "$filepath" 2>/dev/null || true)
    [ -z "$LEVELS" ] && continue

    PREV=0
    LINENO_IDX=0
    while IFS= read -r level; do
      LINENO_IDX=$((LINENO_IDX + 1))
      if [ "$PREV" -gt 0 ] && [ "$level" -gt $((PREV + 1)) ]; then
        file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
        echo -e "  ${YELLOW}WARNING${NC} $file — heading jumps from h${PREV} to h${level} (skips h$((PREV + 1)))"
        SKIP_ISSUES=$((SKIP_ISSUES + 1))
        break  # One warning per file
      fi
      PREV=$level
    done <<< "$LEVELS"
  done <<< "$HEADING_FILES"
fi
if [ "$SKIP_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}No skipped heading levels found.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + SKIP_ISSUES))
echo ""

# ── 2: <nav> without aria-label ──
echo -e "${BOLD}2. Navigation elements without aria-label${NC}"
echo "────────────────────────────────────────────────────────"
NAV_RESULTS=$(grep -rn '<nav\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'aria-label' || true)
if [ -n "$NAV_RESULTS" ]; then
  echo "$NAV_RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — <nav> without aria-label"
  done
  NAV_COUNT=$(echo "$NAV_RESULTS" | wc -l)
  TOTAL_ISSUES=$((TOTAL_ISSUES + NAV_COUNT))
else
  echo -e "  ${GREEN}All <nav> elements have aria-labels.${NC}"
fi
echo ""

# ── 3: Missing <main> landmark ──
echo -e "${BOLD}3. HTML entry points missing <main> landmark${NC}"
echo "────────────────────────────────────────────────────────"
HTML_FILES=$(find "$SCAN_PATH" -name '*.html' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)
MAIN_MISSING=0
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    if ! grep -q '<main\b' "$filepath" 2>/dev/null; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${DIM}INFO${NC} $file — no <main> landmark (may be in SPA component)"
    fi
  done <<< "$HTML_FILES"
fi
# Also check component files for <main>
MAIN_EXISTS=$(grep -rl '<main\b' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -z "$MAIN_EXISTS" ]; then
  echo -e "  ${YELLOW}WARNING${NC} No <main> landmark found in any file"
  MAIN_MISSING=1
else
  MAIN_COUNT=$(echo "$MAIN_EXISTS" | wc -l)
  echo -e "  ${GREEN}<main> landmark found in $MAIN_COUNT file(s).${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + MAIN_MISSING))
echo ""

# ── 4: Clickable divs/spans (overlaps with accessibility but semantic focus) ──
echo -e "${BOLD}4. Click handlers on non-semantic elements${NC}"
echo "────────────────────────────────────────────────────────"
CLICK_DIVS=$(grep -rn -E '(<div|<span)[^>]*(on:click|onClick)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v 'role=' || true)
if [ -n "$CLICK_DIVS" ]; then
  COUNT=$(echo "$CLICK_DIVS" | wc -l)
  echo -e "  ${DIM}$COUNT occurrences. Showing first 10:${NC}"
  echo "$CLICK_DIVS" | head -10 | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${DIM}INFO${NC} $file:$lineno — consider <button> instead of clickable <div>/<span>"
  done
  [ "$COUNT" -gt 10 ] && echo -e "  ${DIM}... and $((COUNT - 10)) more${NC}"
else
  echo -e "  ${GREEN}No click handlers on non-semantic elements.${NC}"
fi
echo ""

# ── 5: Multiple <h1> in single files ──
echo -e "${BOLD}5. Multiple <h1> elements in a single file${NC}"
echo "────────────────────────────────────────────────────────"
MULTI_H1=0
if [ -n "$HEADING_FILES" ]; then
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    H1_COUNT=$(grep -c '<h1\b' "$filepath" 2>/dev/null || echo "0")
    if [ "$H1_COUNT" -gt 1 ]; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${YELLOW}WARNING${NC} $file — $H1_COUNT <h1> elements (should be exactly one per page)"
      MULTI_H1=$((MULTI_H1 + 1))
    fi
  done <<< "$HEADING_FILES"
fi
if [ "$MULTI_H1" -eq 0 ]; then
  echo -e "  ${GREEN}No files with multiple <h1> elements.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + MULTI_H1))
echo ""

echo -e "${BOLD}Summary:${NC} $TOTAL_ISSUES issue(s)."
echo ""
