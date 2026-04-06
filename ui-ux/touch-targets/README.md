# Touch Targets Audit

**Purpose:** Ensure interactive elements (buttons, links, inputs) meet minimum size requirements for touch interaction, preventing misclicks on mobile devices.

**Reference:** [WCAG 2.5.5 Target Size Enhanced](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html) (Level AAA — 44x44px), [WCAG 2.5.8 Target Size Minimum](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) (Level AA — 24x24px)

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Explicit small height on buttons/inputs | Warning | `height: 20px` on interactive element |
| Explicit small width on interactive elements | Warning | `width: 20px` on button/link |
| Small padding that implies tiny target | Info | Very small padding on clickable elements |

**Note:** This is a static analysis heuristic. Elements may have additional padding, parent sizing, or `min-height` that makes the actual target larger. Manual verification is recommended.

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/touch-targets/audit.sh
```

- [ ] No interactive elements smaller than 44x44px (enhanced) or 24x24px (minimum)
- [ ] Adequate spacing between adjacent touch targets
- [ ] Mobile breakpoints don't shrink interactive elements below threshold
