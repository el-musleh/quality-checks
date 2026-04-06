#!/usr/bin/env bash
# Responsive Design Audit
# Checks breakpoint consistency, viewport meta, overflow patterns, overlay positioning, and click-outside handling.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/ui-ux/responsive/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

SCAN_DIR="."; FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"
EXPECTED_BREAKPOINTS="480,580,600,640,768,900,1024,1280"
MIN_TOUCH_TARGET_MOBILE=44
CHECK_OVERLAY_MOBILE=true
CHECK_CLICK_OUTSIDE=true

if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in 
      SCAN_DIR) SCAN_DIR="$val" ;; 
      FILE_TYPES) FILE_TYPES="$val" ;; 
      EXPECTED_BREAKPOINTS) EXPECTED_BREAKPOINTS="$val" ;;
      MIN_TOUCH_TARGET_MOBILE) MIN_TOUCH_TARGET_MOBILE="$val" ;;
      CHECK_OVERLAY_MOBILE) CHECK_OVERLAY_MOBILE="$val" ;;
      CHECK_CLICK_OUTSIDE) CHECK_CLICK_OUTSIDE="$val" ;;
    esac
  done < "$CONF_FILE"
fi

TARGET="${1:-$SCAN_DIR}"
if [ -d "$PROJECT_ROOT/$TARGET" ]; then SCAN_PATH="$PROJECT_ROOT/$TARGET"
elif [ -d "$TARGET" ]; then SCAN_PATH="$TARGET"
else echo "Error: '$TARGET' is not a directory." >&2; exit 1; fi

IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=(); for ext in "${EXTENSIONS[@]}"; do ext=$(echo "$ext" | xargs); INCLUDE_FLAGS+=(--include="*.${ext}"); done
INCLUDE_HTML=(--include="*.html")
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build' --exclude='*.min.css' --exclude='*.min.js')

IFS=',' read -ra BP_ARRAY <<< "$EXPECTED_BREAKPOINTS"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Responsive Design Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo -e "Expected breakpoints: ${CYAN}${EXPECTED_BREAKPOINTS}${NC}"
echo ""

TOTAL_ISSUES=0

# ── 1: Viewport meta check ──
echo -e "${BOLD}1. Viewport meta tag in HTML files${NC}"
echo "────────────────────────────────────────────────────────"
HTML_FILES=$(find "$SCAN_PATH" -name '*.html' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)
VP_MISSING=0
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    if ! grep -q 'viewport' "$filepath" 2>/dev/null; then
      file=$(echo "$filepath" | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${RED}ERROR${NC} $file — missing <meta name=\"viewport\">"
      VP_MISSING=$((VP_MISSING + 1))
    fi
  done <<< "$HTML_FILES"
fi
if [ "$VP_MISSING" -eq 0 ]; then
  echo -e "  ${GREEN}All HTML files have viewport meta tags.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + VP_MISSING))
echo ""

# ── 2: Non-standard breakpoints ──
echo -e "${BOLD}2. Non-standard media query breakpoints${NC}"
echo "────────────────────────────────────────────────────────"
# Extract all px values from @media queries
MEDIA_QUERIES=$(grep -rn -oP '@media[^{]*\(\s*(max|min)-width:\s*\K[0-9]+' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | sort -u || true)
BP_ISSUES=0
SEEN_BPS=()
if [ -n "$MEDIA_QUERIES" ]; then
  # Get unique breakpoint values
  while IFS= read -r entry; do
    bp_val=$(echo "$entry" | rev | cut -d: -f1 | rev)
    [ -z "$bp_val" ] && continue

    # Check if this value is in the expected list
    MATCH=0
    for expected in "${BP_ARRAY[@]}"; do
      expected=$(echo "$expected" | xargs)
      [ "$bp_val" -eq "$expected" ] 2>/dev/null && MATCH=1 && break
    done

    if [ "$MATCH" -eq 0 ]; then
      file=$(echo "$entry" | rev | cut -d: -f2- | rev | sed "s|$PROJECT_ROOT/||")
      echo -e "  ${YELLOW}WARNING${NC} $file — breakpoint ${RED}${bp_val}px${NC} not in standard set"
      BP_ISSUES=$((BP_ISSUES + 1))
    fi
  done <<< "$MEDIA_QUERIES"
fi
if [ "$BP_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}All breakpoints match the standard set.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + BP_ISSUES))
echo ""

# ── 3: Breakpoint usage summary ──
echo -e "${BOLD}3. Breakpoint usage summary${NC}"
echo "────────────────────────────────────────────────────────"
ALL_BPS=$(grep -rn -oP '@media[^{]*\(\s*(max|min)-width:\s*\K[0-9]+' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$ALL_BPS" ]; then
  # Count occurrences of each breakpoint (just the number)
  echo "$ALL_BPS" | rev | cut -d: -f1 | rev | sort -n | uniq -c | sort -rn | while read -r count bp; do
    # Check if standard
    IS_STD=0
    for expected in "${BP_ARRAY[@]}"; do
      expected=$(echo "$expected" | xargs)
      [ "$bp" -eq "$expected" ] 2>/dev/null && IS_STD=1 && break
    done
    if [ "$IS_STD" -eq 1 ]; then
      echo -e "  ${GREEN}${bp}px${NC} — used $count time(s)"
    else
      echo -e "  ${YELLOW}${bp}px${NC} — used $count time(s) ${DIM}(non-standard)${NC}"
    fi
  done
else
  echo -e "  ${DIM}No media queries found.${NC}"
fi
echo ""

# ── 4: overflow-x: hidden on body/html ──
echo -e "${BOLD}4. overflow-x: hidden on body/html (may mask layout bugs)${NC}"
echo "────────────────────────────────────────────────────────"
OVERFLOW_RESULTS=$(grep -rn 'overflow-x:\s*hidden' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
OV_ISSUES=0
if [ -n "$OVERFLOW_RESULTS" ]; then
  while IFS= read -r line; do
    if echo "$line" | grep -qiE '(html|body|\:global\(html\)|\:global\(body\))'; then
      file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
      lineno=$(echo "$line" | cut -d: -f2)
      echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — overflow-x: hidden on html/body"
      OV_ISSUES=$((OV_ISSUES + 1))
    fi
  done <<< "$OVERFLOW_RESULTS"
fi
if [ "$OV_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}No overflow-x: hidden on body/html.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + OV_ISSUES))
echo ""

# ── 5: 100vw usage ──
echo -e "${BOLD}5. 100vw usage (may cause horizontal scrollbar)${NC}"
echo "────────────────────────────────────────────────────────"
VW_RESULTS=$(grep -rn '100vw' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null | grep -v '^\s*//' || true)
if [ -n "$VW_RESULTS" ]; then
  echo "$VW_RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${DIM}INFO${NC} $file:$lineno — uses 100vw (includes scrollbar width)"
  done
else
  echo -e "  ${GREEN}No 100vw usage found.${NC}"
fi
echo ""

# ── 6: Overlay mobile positioning ──
if [ "$CHECK_OVERLAY_MOBILE" = "true" ]; then
echo -e "${BOLD}6. Overlay mobile positioning (fixed/absolute elements need mobile styles)${NC}"
echo "────────────────────────────────────────────────────────"
OVERLAY_ISSUES=0
# Find all fixed/absolute positioned elements
OVERLAYS=$(grep -rn -E 'position:\s*(fixed|absolute)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$OVERLAYS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    
    # Check if there's a corresponding @media query for this element (basic check)
    # Look for any @media rules in the same file
    file_path="$PROJECT_ROOT/$file"
    if [ -f "$file_path" ]; then
      has_media_query=$(grep -c '@media' "$file_path" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
      if [ -n "$has_media_query" ] && [ "$has_media_query" -eq 0 ]; then
        echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — fixed/absolute element without any media queries"
        OVERLAY_ISSUES=$((OVERLAY_ISSUES + 1))
      fi
    fi
  done <<< "$OVERLAYS"
fi
if [ "$OVERLAY_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}All overlays have mobile positioning or media queries.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + OVERLAY_ISSUES))
echo ""
fi

# ── 7: Click outside handler ──
if [ "$CHECK_CLICK_OUTSIDE" = "true" ]; then
echo -e "${BOLD}7. Click outside handler for dialogs/modals${NC}"
echo "────────────────────────────────────────────────────────"
CLICK_OUTSIDE_ISSUES=0
# Find elements with role="dialog" or class containing "modal" or "overlay"
DIALOG_ELEMENTS=$(grep -rn -E 'role="dialog"|class=".*modal|class=".*overlay|class=".*dropdown' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$DIALOG_ELEMENTS" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    
    # Check if there's a click handler in the same file that checks for outside clicks
    # Look for patterns like closest(), click-outside, on:click with stopPropagation or handleWindowClick
    file_path="$PROJECT_ROOT/$file"
    if [ -f "$file_path" ]; then
      has_click_outside=$(grep -cE 'closest\(|click-outside|handleWindowClick|stopPropagation.*click' "$file_path" 2>/dev/null | head -1 | awk '{print $1}' || echo "0")
      if [ -n "$has_click_outside" ] && [ "$has_click_outside" -eq 0 ]; then
        echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — dialog/overlay without click-outside handler"
        CLICK_OUTSIDE_ISSUES=$((CLICK_OUTSIDE_ISSUES + 1))
      fi
    fi
  done <<< "$DIALOG_ELEMENTS"
fi
if [ "$CLICK_OUTSIDE_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}All dialogs/overlays have click-outside handlers.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + CLICK_OUTSIDE_ISSUES))
echo ""
fi

# ── 8: Mobile touch targets ──
echo -e "${BOLD}8. Mobile touch targets (min ${MIN_TOUCH_TARGET_MOBILE}px)${NC}"
echo "────────────────────────────────────────────────────────"
TOUCH_ISSUES=0
# Find all height/width declarations in media queries for mobile
MOBILE_STYLES=$(grep -rn -B2 -A2 '@media.*max-width:\s*(480|580|600)' "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$MOBILE_STYLES" ]; then
  # Look for small height/width values in mobile media queries
  SMALL_TARGETS=$(echo "$MOBILE_STYLES" | grep -E 'height:\s*[0-9]+(px)?' | grep -vE 'height:\s*([5-9][0-9]|[1-9][0-9]{2,})' || true)
  if [ -n "$SMALL_TARGETS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
      lineno=$(echo "$line" | cut -d: -f2)
      echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — potentially small touch target in mobile view"
      TOUCH_ISSUES=$((TOUCH_ISSUES + 1))
    done <<< "$SMALL_TARGETS"
  fi
fi
if [ "$TOUCH_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}No obviously small touch targets in mobile views.${NC}"
fi
TOTAL_ISSUES=$((TOTAL_ISSUES + TOUCH_ISSUES))
echo ""

echo -e "${BOLD}Summary:${NC} $TOTAL_ISSUES issue(s)."
echo ""
