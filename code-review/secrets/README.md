# Hardcoded Secrets Audit

**Purpose:** Ensure hardcoded secrets and API keys are not committed to the repository in plain text. This prevents triggering false-positive alerts in automated scanning tools (like GitHub Secret Scanning) and ensures actual secrets are managed appropriately (e.g. via environment variables).

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Hardcoded Google API Keys (`AIza...`) | Error | Flags contiguous Google API key strings. Public keys should be obfuscated (e.g. split and joined at runtime) to prevent false positives. |

## Pre-Release Checklist

```bash
./quality-checks/code-review/secrets/audit.sh
```

- [ ] No hardcoded API keys exist as contiguous strings in source code.
- [ ] Known public keys are obfuscated (e.g., using `[].join("")`).
- [ ] Real secrets are loaded via environment variables or proper configuration management.

## Customization

Edit `config.conf` to add more patterns or change scanning paths.
