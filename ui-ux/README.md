# UI/UX Quality Checks

Automated audits for visual, interactive, and accessibility quality.

## Available Checks

| Check | WCAG | What it does |
|---|---|---|
| [`zindex/`](zindex/) | — | Detects z-index layering conflicts between sticky bars, headers, modals |
| [`design-tokens/`](design-tokens/) | — | Flags hardcoded colors, font sizes, and shadows that bypass CSS variables |
| [`unused-css/`](unused-css/) | — | Captures unused CSS selector warnings from the build compiler |
| [`animation-performance/`](animation-performance/) | — | Ensures animations use GPU-safe properties and sensible durations |
| [`reduced-motion/`](reduced-motion/) | 2.3.3 | Verifies `prefers-reduced-motion` coverage for all animations |
| [`focus-management/`](focus-management/) | 2.4.7, 2.4.11 | Checks focus indicators aren't removed and `:focus-visible` is used |
| [`accessibility/`](accessibility/) | 1.1.1, 4.1.2 | Finds missing alt text, unlabeled buttons, inputs without labels |
| [`touch-targets/`](touch-targets/) | 2.5.5, 2.5.8 | Flags interactive elements below 44x44px minimum size |
| [`responsive/`](responsive/) | — | Checks breakpoint consistency, viewport meta, overflow patterns |
| [`semantic-html/`](semantic-html/) | 1.3.1, 2.4.6 | Verifies heading hierarchy, landmark roles, semantic element usage |

## Run All UI/UX Checks

```bash
./quality-checks/run-all.sh ui-ux
```
