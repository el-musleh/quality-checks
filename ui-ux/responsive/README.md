# Responsive Design Audit

**Purpose:** Ensure consistent breakpoint usage across the project and detect responsive design issues like missing viewport meta, inconsistent breakpoints, and horizontal overflow patterns.

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Missing `<meta viewport>` | Error | Page won't scale properly on mobile |
| Non-standard breakpoints | Warning | Media queries using values outside the project's defined set |
| `overflow-x: hidden` on body/html | Warning | Often masks horizontal overflow bugs instead of fixing them |
| `100vw` usage | Info | Can cause horizontal scroll due to scrollbar width |

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/responsive/audit.sh
```

- [ ] All HTML entry points have proper viewport meta
- [ ] Media query breakpoints are consistent across components
- [ ] No `overflow-x: hidden` on body/html masking layout bugs
- [ ] Layout works at 320px, 375px, 768px, 1024px, 1280px (manual check)

---

## Customization

Edit `config.conf`:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html,css,scss,less` | Extensions to check |
| `EXPECTED_BREAKPOINTS` | `480,580,600,640,768,900,1024,1280` | Allowed breakpoint values in px |
