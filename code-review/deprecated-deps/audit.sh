#!/usr/bin/env bash
# Deprecated & Vulnerable Dependencies Audit
# Checks for npm audit vulnerabilities, deprecated packages, and known
# deprecated-to-replacement mappings in the dependency tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load config
CONFIG_FILE="$SCRIPT_DIR/config.conf"
PACKAGE_DIR="playlist-editor"
MIN_SEVERITY="moderate"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

TARGET="${1:-$PROJECT_ROOT/$PACKAGE_DIR}"

echo "=== Deprecated & Vulnerable Dependencies Audit ==="
echo "Scanning: $TARGET"
echo ""

ISSUE_COUNT=0

# --- Check 1: npm audit for known vulnerabilities ---
echo "--- npm audit (severity >= $MIN_SEVERITY) ---"
if [[ -f "$TARGET/package-lock.json" ]]; then
  AUDIT_OUTPUT=$(cd "$TARGET" && npm audit --audit-level="$MIN_SEVERITY" 2>&1) || true
  if echo "$AUDIT_OUTPUT" | grep -qE '[0-9]+ vulnerabilities'; then
    VULN_SUMMARY=$(echo "$AUDIT_OUTPUT" | grep -E '[0-9]+ vulnerabilities' | tail -1)
    echo "ERROR: $VULN_SUMMARY"
    ISSUE_COUNT=$((ISSUE_COUNT + 1))
    # Show individual vulnerability details
    echo "$AUDIT_OUTPUT" | grep -E '(high|critical|moderate)' | head -20
  else
    echo "INFO: No vulnerabilities at or above '$MIN_SEVERITY' severity."
  fi
else
  echo "WARNING: No package-lock.json found in $TARGET — skipping npm audit."
fi

echo ""

# --- Check 2: Deprecated packages ---
echo "--- Deprecated packages ---"
if [[ -f "$TARGET/package-lock.json" ]]; then
  OUTDATED_OUTPUT=$(cd "$TARGET" && npm outdated --json 2>/dev/null) || true
  # Check for deprecated field in package-lock.json directly (faster than npm calls)
  DEPRECATED_COUNT=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "WARNING: Deprecated transitive dependency: $line"
    DEPRECATED_COUNT=$((DEPRECATED_COUNT + 1))
    ISSUE_COUNT=$((ISSUE_COUNT + 1))
  done < <(grep -o '"deprecated": "[^"]*"' "$TARGET/package-lock.json" 2>/dev/null || true)

  if [[ $DEPRECATED_COUNT -eq 0 ]]; then
    echo "INFO: No deprecated packages found in lock file."
  fi
else
  echo "WARNING: No package-lock.json found — skipping deprecated check."
fi

echo ""

# --- Check 3: Known deprecated-to-replacement mappings ---
echo "--- Known deprecated packages in package.json ---"
if [[ -f "$TARGET/package.json" ]]; then
  declare -A KNOWN_DEPRECATED=(
    ["rollup-plugin-terser"]="@rollup/plugin-terser"
    ["rollup-plugin-json"]="@rollup/plugin-json"
    ["rollup-plugin-buble"]="@rollup/plugin-buble"
    ["@babel/polyfill"]="core-js + regenerator-runtime"
    ["node-sass"]="sass (Dart Sass)"
    ["request"]="node-fetch or undici"
    ["uglify-es"]="terser"
    ["tslint"]="eslint with @typescript-eslint"
  )

  for dep in "${!KNOWN_DEPRECATED[@]}"; do
    if grep -q "\"$dep\"" "$TARGET/package.json" 2>/dev/null; then
      echo "WARNING: '$dep' is deprecated — replace with '${KNOWN_DEPRECATED[$dep]}'"
      ISSUE_COUNT=$((ISSUE_COUNT + 1))
    fi
  done

  if [[ $ISSUE_COUNT -eq 0 ]] || ! grep -qE "$(printf '%s|' "${!KNOWN_DEPRECATED[@]}" | sed 's/|$//')" "$TARGET/package.json" 2>/dev/null; then
    echo "INFO: No known deprecated packages found in package.json."
  fi
else
  echo "WARNING: No package.json found in $TARGET."
fi

echo ""
echo "=== Summary ==="
if [[ $ISSUE_COUNT -eq 0 ]]; then
  echo "INFO: No dependency issues found."
else
  echo "Found $ISSUE_COUNT dependency issue(s)."
  echo "Fix: Replace deprecated packages with maintained alternatives. Run 'npm audit fix' for quick patches."
fi

exit 0
