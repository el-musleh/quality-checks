# Unused CSS Audit

**Purpose:** Detect unused CSS selectors that add dead weight to the bundle and make maintenance harder.

---

## How It Works

The audit script runs the project's build command and captures CSS warnings emitted by the compiler (Svelte, Vue, PostCSS, etc.). It groups warnings by file and reports a summary.

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/unused-css/audit.sh
```

- [ ] No unused CSS selectors reported by the compiler
- [ ] Any intentionally unused selectors are documented with a `/* keep: reason */` comment

---

## Customization

Edit `config.conf` to set:

| Key | Default | Description |
|---|---|---|
| `BUILD_CMD` | `npm run build` | The build command that emits CSS warnings |
| `BUILD_DIR` | `.` | Directory to run the build command from |
| `PATTERN` | `Unused CSS selector` | Grep pattern to match compiler warnings |
