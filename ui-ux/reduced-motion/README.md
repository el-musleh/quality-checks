# Reduced Motion Audit

**Purpose:** Ensure every animation and transition respects `prefers-reduced-motion`, preventing motion sickness, seizures, and vestibular discomfort for affected users.

**Reference:** [WCAG 2.3.3 Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) (Level AAA)

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| `@keyframes` without reduced-motion query | Error | Animated elements must be disableable |
| `animation:` without reduced-motion coverage | Warning | Direct animation declarations need a reduced-motion override |
| `transition:` without reduced-motion coverage | Info | Transitions are typically subtle enough to be safe, but long ones should be checked |
| Files with animations but no reduced-motion query at all | Error | The file has no `prefers-reduced-motion` anywhere |

**Pattern to follow:**
```css
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/reduced-motion/audit.sh
```

- [ ] Every file with `@keyframes` has a `prefers-reduced-motion` media query
- [ ] Every file with `animation:` has reduced-motion coverage
- [ ] Global reduced-motion override exists in the design tokens / base CSS
