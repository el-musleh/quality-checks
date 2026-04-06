# Responsive Design Audit

**Purpose:** Ensure consistent breakpoint usage across the project and detect responsive design issues like missing viewport meta, inconsistent breakpoints, horizontal overflow patterns, overlay positioning on mobile, and click-outside handling.

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Missing `<meta viewport>` | Error | Page won't scale properly on mobile |
| Non-standard breakpoints | Warning | Media queries using values outside the project's defined set |
| `overflow-x: hidden` on body/html | Warning | Often masks horizontal overflow bugs instead of fixing them |
| `100vw` usage | Info | Can cause horizontal scroll due to scrollbar width |
| Overlay mobile positioning | Warning | Fixed/absolute positioned elements missing mobile-specific styles |
| Click outside handler missing | Warning | Dialog/overlay elements without click-outside-to-close functionality |
| Mobile touch targets | Warning | Interactive elements smaller than 44px in mobile views |

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/responsive/audit.sh
```

- [ ] All HTML entry points have proper viewport meta
- [ ] Media query breakpoints are consistent across components
- [ ] No `overflow-x: hidden` on body/html masking layout bugs
- [ ] Layout works at 320px, 375px, 768px, 1024px, 1280px (manual check)
- [ ] **All overlays (modals, dropdowns, floating cards) have mobile-specific positioning**
- [ ] **All modals/dropdowns have click-outside-to-close handlers**
- [ ] **Touch targets in mobile view are at least 44x44px**
- [ ] **No horizontal scrolling on any viewport width**

---

## Customization

Edit `config.conf`:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html,css,scss,less` | Extensions to check |
| `EXPECTED_BREAKPOINTS` | `480,580,600,640,768,900,1024,1280` | Allowed breakpoint values in px |
| `MIN_TOUCH_TARGET_MOBILE` | `44` | Minimum touch target size in pixels for mobile |
| `CHECK_OVERLAY_MOBILE` | `true` | Enable overlay mobile positioning checks |
| `CHECK_CLICK_OUTSIDE` | `true` | Enable click-outside handler checks |
