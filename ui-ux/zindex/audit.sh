#!/usr/bin/env bash
# Z-Index Audit Script
# Scans frontend source files for z-index declarations and flags layering issues.
# Portable — works in any project. Configure via config.conf or CLI args.
#
# Usage:
#   ./quality-checks/ui-ux/zindex/audit.sh              # scan from project root
#   ./quality-checks/ui-ux/zindex/audit.sh src/          # scan a specific directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# ── Defaults ──
SCAN_DIR="."
FILE_TYPES="svelte,vue,jsx,tsx,html,css,scss,less"
VALID_ZINDEX="1,10,90,99,1000,2000,9999,10000"
HEADER_PATTERN="header"

# ── Load config if present ──
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    # Skip comments and blank lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    val=$(echo "$val" | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;;
      FILE_TYPES) FILE_TYPES="$val" ;;
      VALID_ZINDEX) VALID_ZINDEX="$val" ;;
      HEADER_PATTERN) HEADER_PATTERN="$val" ;;
    esac
  done < "$CONF_FILE"
fi

# ── Parse valid values into array ──
IFS=',' read -ra VALID_VALUES <<< "$VALID_ZINDEX"

# ── Build --include flags from FILE_TYPES ──
IFS=',' read -ra EXTENSIONS <<< "$FILE_TYPES"
INCLUDE_FLAGS=()
for ext in "${EXTENSIONS[@]}"; do
  ext=$(echo "$ext" | xargs)
  INCLUDE_FLAGS+=(--include="*.${ext}")
done

# ── Determine scan directories (CLI args override config) ──
SCAN_DIRS=()
if [ $# -gt 0 ]; then
  for arg in "$@"; do
    if [ -d "$PROJECT_ROOT/$arg" ]; then
      SCAN_DIRS+=("$PROJECT_ROOT/$arg")
    elif [ -d "$arg" ]; then
      SCAN_DIRS+=("$arg")
    else
      echo "Warning: '$arg' is not a directory, skipping." >&2
    fi
  done
else
  SCAN_DIRS=("$PROJECT_ROOT/$SCAN_DIR")
fi

if [ ${#SCAN_DIRS[@]} -eq 0 ]; then
  echo "Error: No valid directories to scan." >&2
  exit 1
fi

# ── Colors ──
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}===== Z-Index Audit =====${NC}"
for d in "${SCAN_DIRS[@]}"; do
  echo -e "Scanning: ${CYAN}$d${NC}"
done
echo -e "File types: ${CYAN}${FILE_TYPES}${NC}"
echo ""

# ── Collect all z-index declarations ──
FINDINGS=""
for d in "${SCAN_DIRS[@]}"; do
  RESULT=$(grep -rn 'z-index:' "$d" "${INCLUDE_FLAGS[@]}" --exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='dist' --exclude-dir='build' --exclude='*.min.css' --exclude='*.min.js' 2>/dev/null | grep -v '^\s*//' | grep -v 'var(--' || true)
  if [ -n "$RESULT" ]; then
    FINDINGS="${FINDINGS}${FINDINGS:+$'\n'}${RESULT}"
  fi
done

if [ -z "$FINDINGS" ]; then
  echo -e "${GREEN}No hardcoded z-index values found.${NC}"
  exit 0
fi

# ── Section 1: Full inventory ──
echo -e "${BOLD}1. All z-index declarations${NC}"
echo "────────────────────────────────────────────────────────"
echo "$FINDINGS" | while IFS= read -r line; do
  file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  value=$(echo "$line" | grep -oP 'z-index:\s*\K[0-9]+' || echo "?")
  printf "  %-55s line %-5s z-index: %s\n" "$file" "$lineno" "$value"
done
echo ""

# ── Section 2: Off-scale values ──
echo -e "${BOLD}2. Values outside the defined scale${NC}"
echo -e "   Valid scale: ${CYAN}${VALID_VALUES[*]}${NC}"
echo "────────────────────────────────────────────────────────"
OFF_SCALE=0
echo "$FINDINGS" | while IFS= read -r line; do
  value=$(echo "$line" | grep -oP 'z-index:\s*\K[0-9]+' || echo "")
  [ -z "$value" ] && continue
  MATCH=0
  for v in "${VALID_VALUES[@]}"; do
    v=$(echo "$v" | xargs)
    [ "$value" -eq "$v" ] 2>/dev/null && MATCH=1 && break
  done
  if [ "$MATCH" -eq 0 ]; then
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — z-index: $value (not in scale)"
    OFF_SCALE=1
  fi
done
if [ "$OFF_SCALE" -eq 0 ]; then
  echo -e "  ${GREEN}All values match the defined scale.${NC}"
fi
echo ""

# ── Section 3: Sticky elements with high z-index ──
echo -e "${BOLD}3. Sticky elements with z-index >= 1000 (potential header conflicts)${NC}"
echo "────────────────────────────────────────────────────────"
STICKY_ISSUES=0
echo "$FINDINGS" | while IFS= read -r line; do
  value=$(echo "$line" | grep -oP 'z-index:\s*\K[0-9]+' || echo "0")
  [ "$value" -lt 1000 ] 2>/dev/null && continue

  fullpath=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")

  # Check for "sticky" within 10 lines above the z-index line
  START=$((lineno > 10 ? lineno - 10 : 1))
  CONTEXT=$(sed -n "${START},${lineno}p" "$fullpath" 2>/dev/null || true)

  if echo "$CONTEXT" | grep -q 'position:\s*sticky'; then
    BASENAME=$(basename "$file" | tr '[:upper:]' '[:lower:]')
    # Skip files matching the header pattern (they're allowed high z-index)
    if ! echo "$BASENAME" | grep -qi "$HEADER_PATTERN"; then
      echo -e "  ${RED}ISSUE${NC} $file:$lineno — sticky element with z-index: $value (will overlap header)"
      STICKY_ISSUES=1
    fi
  fi
done
if [ "$STICKY_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}No sticky elements conflicting with header.${NC}"
fi
echo ""

# ── Section 4: Fixed-position elements with low z-index ──
echo -e "${BOLD}4. Fixed-position elements with z-index < 1000 (may be hidden behind sticky bars)${NC}"
echo "────────────────────────────────────────────────────────"
FIXED_ISSUES=0
echo "$FINDINGS" | while IFS= read -r line; do
  value=$(echo "$line" | grep -oP 'z-index:\s*\K[0-9]+' || echo "0")
  [ "$value" -gt 99 ] 2>/dev/null && continue

  fullpath=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  file=$(echo "$fullpath" | sed "s|$PROJECT_ROOT/||")

  START=$((lineno > 10 ? lineno - 10 : 1))
  CONTEXT=$(sed -n "${START},${lineno}p" "$fullpath" 2>/dev/null || true)

  if echo "$CONTEXT" | grep -q 'position:\s*fixed'; then
    echo -e "  ${YELLOW}WARNING${NC} $file:$lineno — fixed element with z-index: $value (may be hidden behind sticky bars)"
    FIXED_ISSUES=1
  fi
done
if [ "$FIXED_ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}No low-z fixed elements found.${NC}"
fi
echo ""

# ── Summary ──
TOTAL=$(echo "$FINDINGS" | wc -l)
echo -e "${BOLD}Summary:${NC} $TOTAL z-index declarations found."
echo -e "Review ${CYAN}quality-checks/ui-ux/zindex/README.md${NC} for layering rules and manual checklist."
echo ""
