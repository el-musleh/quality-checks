# Animation Performance Audit

**Purpose:** Ensure animations are GPU-accelerated, use perceptually correct durations, and don't animate layout-triggering properties that cause jank.

**Reference:** [Google web.dev — Animations Guide](https://web.dev/animations-guide/), [CSS Triggers](https://csstriggers.com/)

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Layout-triggering animations | Warning | `transition` or `animation` on `top`, `left`, `width`, `height`, `margin`, `padding` — these cause layout recalculation every frame |
| Slow animations (>500ms) | Warning | Animations longer than 500ms feel sluggish |
| Too-fast animations (<100ms) | Warning | Animations under 100ms are imperceptible |
| Non-GPU properties in keyframes | Info | `@keyframes` that animate layout properties instead of `transform`/`opacity` |

**GPU-safe properties:** `transform`, `opacity`, `filter`, `backdrop-filter`, `clip-path`

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/animation-performance/audit.sh
```

- [ ] No transitions on layout properties (`top`, `left`, `width`, `height`, `margin`, `padding`)
- [ ] All animation durations between 100ms and 500ms
- [ ] `@keyframes` only animate `transform` and `opacity`
- [ ] Smooth 60fps on mid-range devices

---

## Customization

Edit `config.conf`:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html,css,scss,less` | Extensions to check |
| `MAX_DURATION_MS` | `500` | Warn if animation exceeds this |
| `MIN_DURATION_MS` | `100` | Warn if animation is below this |
