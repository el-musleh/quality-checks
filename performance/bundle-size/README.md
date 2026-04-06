# Bundle Size Audit

**Purpose:** Track the size of built output files to catch unexpected bloat from new dependencies, unminified code, or accidentally bundled assets.

---

## What It Checks

- Total size of the build output directory
- Individual file sizes sorted by largest first
- Files exceeding the configured size threshold

---

## Pre-Release Checklist

```bash
./quality-checks/performance/bundle-size/audit.sh
```

- [ ] No single file exceeds the size threshold
- [ ] Total bundle size has not grown unexpectedly since last release
- [ ] No source maps or dev-only files in the build output

---

## Customization

Edit `config.conf` to set:

| Key | Default | Description |
|---|---|---|
| `BUILD_DIR` | `dist` | Build output directory (relative to project root) |
| `WARN_FILE_KB` | `500` | Warn if any single file exceeds this size (KB) |
| `WARN_TOTAL_KB` | `2000` | Warn if total bundle exceeds this size (KB) |
| `EXCLUDE_PATTERN` | `*.map` | Glob pattern of files to exclude from size checks |
