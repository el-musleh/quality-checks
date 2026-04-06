# Design Tokens Audit

**Purpose:** Detect hardcoded values (colors, spacing, font sizes, shadows) that should use CSS variables / design tokens for consistent theming and dark mode support.

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Hardcoded hex colors in color/bg | Warning | `#ff0000` instead of `var(--color-*)` |
| Hardcoded `rgb()`/`rgba()` in text/bg | Warning | Inline colors bypassing token system |
| Hardcoded pixel font sizes | Warning | `font-size: 14px` instead of `var(--font-size-*)` |
| Hardcoded box shadows | Info | `box-shadow: 0 2px ...` instead of `var(--shadow-*)` |
| `color:` without `var(--` | Info | Any color property not using a CSS variable |

**Exceptions:** Values inside `rgba()` for shadows/overlays, values in `@keyframes`, and `0` values are intentional and excluded.

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/design-tokens/audit.sh
```

- [ ] No hardcoded colors for `color:` or `background-color:` properties
- [ ] Font sizes use CSS variables or `clamp()` for fluid typography
- [ ] Shadows use token variables from the design system
- [ ] Dark mode renders correctly — no invisible text or missing backgrounds

---

## Customization

Edit `config.conf`:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan (relative to project root) |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html,css,scss,less` | File extensions to check |
| `ALLOWED_HARDCODED` | `white,black,transparent,inherit,currentColor,none` | Color values OK to hardcode |
