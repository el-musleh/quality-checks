#!/usr/bin/env bash
# Run All Quality Checks
# Discovers and executes every audit.sh in the quality-checks directory tree.
#
# Usage:
#   ./quality-checks/run-all.sh              # run all audits
#   ./quality-checks/run-all.sh ui-ux        # run only ui-ux topic audits
#   ./quality-checks/run-all.sh performance  # run only performance audits

set -euo pipefail

QC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Optional topic filter
TOPIC_FILTER="${1:-}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Quality Checks — Run All       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# Find all audit.sh scripts
SEARCH_DIR="$QC_DIR"
if [ -n "$TOPIC_FILTER" ] && [ -d "$QC_DIR/$TOPIC_FILTER" ]; then
  SEARCH_DIR="$QC_DIR/$TOPIC_FILTER"
  echo -e "Filtered to topic: ${CYAN}$TOPIC_FILTER${NC}"
  echo ""
fi

SCRIPTS=$(find "$SEARCH_DIR" -name 'audit.sh' -type f | sort)

if [ -z "$SCRIPTS" ]; then
  echo -e "${RED}No audit scripts found.${NC}"
  exit 1
fi

TOTAL=0
PASSED=0
FAILED=0

while IFS= read -r script; do
  # Derive check name from path: ui-ux/zindex, performance/bundle-size, etc.
  REL_PATH=$(echo "$script" | sed "s|$QC_DIR/||" | sed 's|/audit.sh$||')

  echo -e "${BOLD}┌─── ${CYAN}$REL_PATH${NC} ${BOLD}───${NC}"
  echo ""

  TOTAL=$((TOTAL + 1))

  if bash "$script"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo -e "${RED}Audit exited with error.${NC}"
  fi

  echo -e "${BOLD}└───────────────────────────────────────${NC}"
  echo ""
done <<< "$SCRIPTS"

# ── Summary ──
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║            Final Summary             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total audits run: ${BOLD}$TOTAL${NC}"
echo -e "  Passed:           ${GREEN}$PASSED${NC}"
if [ "$FAILED" -gt 0 ]; then
  echo -e "  Failed:           ${RED}$FAILED${NC}"
fi
echo ""

exit "$FAILED"
