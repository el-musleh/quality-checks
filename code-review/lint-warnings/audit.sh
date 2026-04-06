#!/usr/bin/env bash
# Lint Warnings Audit
# Captures and summarizes linter warnings from the project validation command.
# Portable — configure via config.conf.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
LINT_CMD="npm run validate"
LINT_DIR="playlist-editor" # Specific to this project
PATTERN="Warn:|Error:|a11y-|css-"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs); val=$(echo "$val" | xargs)
    case "$key" in
      LINT_CMD) LINT_CMD="$val" ;;
      LINT_DIR) LINT_DIR="$val" ;;
      PATTERN) PATTERN="$val" ;;
    esac
  done < "$CONF_FILE"
fi

# Colors
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

echo ""
echo -e "${BOLD}===== Lint Warnings Audit =====${NC}"
echo -e "Command: ${CYAN}${LINT_CMD}${NC}"
echo -e "Directory: ${CYAN}${LINT_DIR}${NC}"
echo ""

# Run lint and capture output
LINT_OUTPUT=$(cd "$PROJECT_ROOT/$LINT_DIR" && eval "$LINT_CMD" 2>&1 || true)

# Extract matching issues
WARNINGS=$(echo "$LINT_OUTPUT" | grep -E "$PATTERN" || true)

if [ -z "$WARNINGS" ]; then
  echo -e "  ${GREEN}No linter warnings found.${NC}"
  echo ""
  exit 0
fi

# Group by category
echo -e "${BOLD}Captured Diagnostics:${NC}"
echo "────────────────────────────────────────────────────────"

# Count specific common issues
A11Y_COUNT=$(echo "$WARNINGS" | grep -c "a11y-" || true)
CSS_COUNT=$(echo "$WARNINGS" | grep -c "css-unused-selector" || true)
OTHER_COUNT=$(echo "$WARNINGS" | grep -vE "a11y-|css-unused-selector" | grep -c "." || true)

if [ "$A11Y_COUNT" -ne 0 ]; then
  echo -e "  ${YELLOW}Accessibility:${NC} $A11Y_COUNT issues found"
fi
if [ "$CSS_COUNT" -ne 0 ]; then
  echo -e "  ${YELLOW}CSS Unused:${NC}    $CSS_COUNT selectors found"
fi
if [ "$OTHER_COUNT" -ne 0 ]; then
  echo -e "  ${YELLOW}Other Lint:${NC}    $OTHER_COUNT warnings found"
fi

echo ""
echo -e "${BOLD}Critical details:${NC}"
# Show the actual lines for a11y and css issues
echo "$WARNINGS" | grep -E "a11y-|css-unused-selector" | while IFS= read -r line; do
  echo -e "  ${DIM}•${NC} $line"
done

echo ""
TOTAL=$((A11Y_COUNT + CSS_COUNT + OTHER_COUNT))
echo -e "${BOLD}Summary:${NC} $TOTAL diagnostic warning(s) found."
echo ""
