#!/usr/bin/env bash
# Format String Injection Audit
# Detects console.log/warn/error calls where user-controlled data is
# interpolated into the format string via template literals or concatenation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load config
CONFIG_FILE="$SCRIPT_DIR/config.conf"
SCAN_DIR="src"
FILE_EXTENSIONS="js,ts,svelte"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Allow CLI override of scan directory
TARGET="${1:-$PROJECT_ROOT/$SCAN_DIR}"

echo "=== Format String Injection Audit ==="
echo "Scanning: $TARGET"
echo ""

ISSUE_COUNT=0

# Build --include flags from FILE_EXTENSIONS
INCLUDE_FLAGS=""
IFS=',' read -ra EXTS <<< "$FILE_EXTENSIONS"
for ext in "${EXTS[@]}"; do
  INCLUDE_FLAGS="$INCLUDE_FLAGS --include=*.${ext}"
done

# Pattern: console.log/warn/error with a template literal containing ${...}
# This catches: console.log(`...${var}...`)
# shellcheck disable=SC2086
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  # Skip minified files and node_modules
  case "$match" in
    *node_modules/*|*.min.js*|*dist/*|*build/*|*src/editor/*.js*) continue ;;
  esac
  echo "WARNING: $match"
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
done < <(grep -rn $INCLUDE_FLAGS -E 'console\.(log|warn|error)\s*\(\s*`[^`]*\$\{' "$TARGET" 2>/dev/null || true)

# Pattern: console.log/warn/error with string concatenation involving variables
# This catches: console.log(variable + "...")  and  console.log("..." + variable)
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  case "$match" in
    *node_modules/*|*.min.js*|*dist/*|*build/*|*src/editor/*.js*) continue ;;
  esac
  echo "WARNING: $match"
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
done < <(grep -rn $INCLUDE_FLAGS -E 'console\.(log|warn|error)\s*\([^)]*\+' "$TARGET" 2>/dev/null || true)

echo ""
if [[ $ISSUE_COUNT -eq 0 ]]; then
  echo "INFO: No format string injection issues found."
else
  echo "Found $ISSUE_COUNT potential format string injection(s)."
  echo "Fix: use %s placeholders and pass data as separate arguments."
fi

exit 0
