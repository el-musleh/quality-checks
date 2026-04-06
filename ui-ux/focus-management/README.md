# Focus Management Audit

**Purpose:** Ensure all interactive elements have visible focus indicators and that focus is never removed without a replacement, supporting keyboard-only navigation.

**Reference:** [WCAG 2.4.7 Focus Visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html) (Level AA), [WCAG 2.4.11 Focus Not Obscured](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html) (Level AA)

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| `outline: none` / `outline: 0` | Error | Removes focus indicator without replacement (WCAG 2.4.7 violation) |
| `outline: none` with `:focus-visible` nearby | OK | Acceptable if replaced with custom focus style |
| No `:focus-visible` styles in file | Warning | Interactive elements need visible focus for keyboard users |
| `*:focus { outline: none }` global reset | Error | Blanket removal of all focus indicators |

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/focus-management/audit.sh
```

- [ ] No `outline: none` without a `:focus-visible` replacement
- [ ] All interactive elements have visible focus indicators
- [ ] Focus outlines are at least 2px and high-contrast
- [ ] Tab order is logical (manual check)
