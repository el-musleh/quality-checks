# Accessibility Audit

**Purpose:** Detect common accessibility issues: missing alt text, unlabeled interactive elements, missing ARIA attributes, and improper semantic HTML.

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Missing `alt` on `<img>` | Error | Screen readers can't describe the image |
| `<button>` without text or `aria-label` | Error | Unlabeled interactive element |
| `<a>` without text or `aria-label` | Error | Unlabeled link |
| `<input>` without `id`+`<label>` or `aria-label` | Warning | Form field not associated with a label |
| Click handlers on non-interactive elements | Warning | `on:click` on `<div>`/`<span>` without `role` and `tabindex` |
| Missing `role` on interactive custom elements | Warning | Custom widgets need explicit ARIA roles |

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/accessibility/audit.sh
```

- [ ] No images missing alt text
- [ ] All buttons and links are labeled
- [ ] All form inputs have associated labels
- [ ] Interactive non-button/link elements have `role` and `tabindex`

---

## Customization

Edit `config.conf` to set:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan (relative to project root) |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html` | File extensions to check |
