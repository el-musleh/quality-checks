#!/usr/bin/env bash
# Unused CSS Audit
# Runs the project build and captures unused CSS selector warnings.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/ui-ux/unused-css/audit.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
BUILD_CMD="npm run build"
BUILD_DIR="."
PATTERN="Unused CSS selector"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    val=$(echo "$val" | xargs)
    case "$key" in
      BUILD_CMD) BUILD_CMD="$val" ;;
      BUILD_DIR) BUILD_DIR="$val" ;;
      PATTERN) PATTERN="$val" ;;
    esac
  done < "$CONF_FILE"
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}===== Unused CSS Audit =====${NC}"
echo -e "Build command: ${CYAN}${BUILD_CMD}${NC}"
echo -e "Build directory: ${CYAN}${PROJECT_ROOT}/${BUILD_DIR}${NC}"
echo ""

# Run build and capture stderr+stdout
BUILD_OUTPUT=$(cd "$PROJECT_ROOT/$BUILD_DIR" && eval "$BUILD_CMD" 2>&1 || true)

# Extract matching warnings
WARNINGS=$(echo "$BUILD_OUTPUT" | grep -i "$PATTERN" || true)

if [ -z "$WARNINGS" ]; then
  echo -e "${GREEN}No unused CSS selectors found.${NC}"
  echo ""
  exit 0
fi

# Group by file
echo -e "${BOLD}Unused CSS selectors by file:${NC}"
echo "────────────────────────────────────────────────────────"

CURRENT_FILE=""
COUNT=0
echo "$BUILD_OUTPUT" | grep -B1 -i "$PATTERN" | while IFS= read -r line; do
  # Lines with file paths (Svelte/Vue compiler typically prints the filename above the warning)
  if echo "$line" | grep -qE '\.(svelte|vue|jsx|tsx|css|scss|html)$'; then
    FILE=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | xargs)
    if [ "$FILE" != "$CURRENT_FILE" ]; then
      CURRENT_FILE="$FILE"
      echo ""
      echo -e "  ${CYAN}$FILE${NC}"
    fi
  elif echo "$line" | grep -qi "$PATTERN"; then
    SELECTOR=$(echo "$line" | grep -oP '"[^"]*"' | head -1 || echo "$line")
    echo -e "    ${YELLOW}$SELECTOR${NC}"
    COUNT=$((COUNT + 1))
  fi
done

TOTAL=$(echo "$WARNINGS" | wc -l)
echo ""
echo -e "${BOLD}Summary:${NC} $TOTAL unused CSS selector warning(s)."
echo -e "Review each and either remove the selector or add ${CYAN}/* keep: reason */${NC} if intentional."
echo ""
