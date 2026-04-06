#!/usr/bin/env bash
# Hardcoded Secrets Audit
# Scans frontend files for hardcoded API keys and secrets.
# Portable — configure via config.conf.
#
# Usage: ./quality-checks/code-review/secrets/audit.sh [scan-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config.conf"

# Defaults
SCAN_DIR="."
FILE_TYPES="js,ts,svelte,jsx,tsx,html,json"
GOOGLE_API_KEY_PATTERN="AIza[0-9A-Za-z-_]{35}"

# Load config
if [ -f "$CONF_FILE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    # Remove surrounding quotes from config values
    val=$(echo "$val" | sed -e 's/^"//' -e 's/"$//' | xargs)
    case "$key" in
      SCAN_DIR) SCAN_DIR="$val" ;;
      FILE_TYPES) FILE_TYPES="$val" ;;
      GOOGLE_API_KEY_PATTERN) GOOGLE_API_KEY_PATTERN="$val" ;;
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
EXCLUDE_FLAGS=(--exclude-dir='node_modules' --exclude-dir='.git' --exclude-dir='.claude' --exclude-dir='.factory' --exclude-dir='.windsurf' --exclude-dir='.zencoder' --exclude-dir='.zenflow' --exclude-dir='.gemini' --exclude-dir='dist' --exclude-dir='build')

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ISSUES=0

echo ""
echo -e "${BOLD}===== Hardcoded Secrets Audit =====${NC}"
echo -e "Scanning: ${CYAN}$SCAN_PATH${NC}"
echo ""

# ── Check 1: Google API Keys ──
echo -e "${BOLD}1. Hardcoded Google API Keys${NC}"
echo "────────────────────────────────────────────────────────"
RESULTS=$(grep -rnE "$GOOGLE_API_KEY_PATTERN" "$SCAN_PATH" "${INCLUDE_FLAGS[@]}" "${EXCLUDE_FLAGS[@]}" 2>/dev/null || true)
if [ -n "$RESULTS" ]; then
  echo "$RESULTS" | while IFS= read -r line; do
    file=$(echo "$line" | sed "s|$PROJECT_ROOT/||" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    echo -e "  ${RED}ERROR${NC} $file:$lineno — Hardcoded Google API Key found matching pattern '${GOOGLE_API_KEY_PATTERN}'"
  done
  ISSUES=$((ISSUES + $(echo "$RESULTS" | wc -l)))
else
  echo -e "  ${GREEN}No hardcoded Google API Keys found.${NC}"
fi
echo ""

# ── Summary ──
if [ "$ISSUES" -gt 0 ]; then
  echo -e "${BOLD}Summary:${NC} $ISSUES hardcoded secret issue(s) found."
  echo -e "Please obfuscate known public keys (e.g. splitting the string) to prevent false positives in external scanners."
  echo -e "Real secrets must be managed via environment variables or another secure mechanism."
  exit 1
else
  echo -e "${BOLD}Summary:${NC} ${GREEN}No hardcoded secrets detected.${NC}"
fi
echo ""
exit 0
