# Quality Checks — AI Agent Guide

This document instructs AI agents on how to navigate and use the quality checks system.

---

## Directory Structure

```
quality-checks/
├── AGENT-GUIDE.md              ← you are here
├── run-all.sh                  ← runs every audit at once
├── ui-ux/                      ← visual, interactive, and accessibility checks
│   ├── zindex/                 ← z-index layering conflicts
│   ├── design-tokens/          ← hardcoded colors, fonts, shadows bypassing CSS vars
│   ├── unused-css/             ← dead CSS selectors
│   ├── animation-performance/  ← GPU-safe props, duration ranges
│   ├── reduced-motion/         ← prefers-reduced-motion coverage (WCAG 2.3.3)
│   ├── focus-management/       ← focus indicators, :focus-visible (WCAG 2.4.7)
│   ├── accessibility/          ← missing alt, labels, ARIA roles (WCAG 1.1.1, 4.1.2)
│   ├── touch-targets/          ← minimum 44x44px interactive elements (WCAG 2.5.5)
│   ├── responsive/             ← breakpoint consistency, viewport meta
│   └── semantic-html/          ← heading hierarchy, landmarks (WCAG 1.3.1, 2.4.6)
├── performance/                ← build and runtime performance checks
│   └── bundle-size/            ← file size thresholds for build output
├── code-review/                ← code quality checks (planned)
│   ├── browser-storage/        ← encourages browser.storage.sync usage
│   ├── lint-warnings/          ← summarizes compiler warnings
│   ├── deprecated-deps/        ← flags deprecated/vulnerable npm dependencies
│   ├── format-string/          ← detects format string injection in console.log calls
│   ├── secrets/                ← finds hardcoded API keys and secrets
│   └── todo-fixme/             ← flags unresolved TODO/FIXME comments
```

Each check folder follows a standard convention:
- `README.md` — rules, checklist, what it detects
- `config.conf` — settings (scan dir, thresholds, file types)
- `audit.sh` — the executable scanner script

---

## When to Run Quality Checks

Run the relevant audit(s) in these situations:

| Trigger | What to run |
|---|---|
| **Adding/modifying `z-index`, `position: sticky/fixed`** | `ui-ux/zindex/audit.sh` |
| **Adding/removing CSS classes or selectors** | `ui-ux/unused-css/audit.sh` |
| **Adding hardcoded colors, font sizes, or shadows** | `ui-ux/design-tokens/audit.sh` |
| **Adding animations or transitions** | `ui-ux/animation-performance/audit.sh` + `ui-ux/reduced-motion/audit.sh` |
| **Adding interactive elements (buttons, links, inputs)** | `ui-ux/accessibility/audit.sh` + `ui-ux/focus-management/audit.sh` + `ui-ux/touch-targets/audit.sh` |
| **Adding clickable divs or heading elements** | `ui-ux/semantic-html/audit.sh` |
| **Adding media queries or responsive styles** | `ui-ux/responsive/audit.sh` |
| **Adding new dependencies or significant code** | `performance/bundle-size/audit.sh` |
| **Adding, removing, or updating npm dependencies** | `code-review/deprecated-deps/audit.sh` |
| **Adding API integrations or external services** | `code-review/secrets/audit.sh` |
| **Adding or modifying `console.log/warn/error` calls** | `code-review/format-string/audit.sh` |
| **Before a release or major PR** | `run-all.sh` (runs everything) |

---

## How to Run

From the project root:

```bash
# Run a specific audit
./quality-checks/ui-ux/zindex/audit.sh

# Run all audits in a topic
./quality-checks/run-all.sh ui-ux

# Run everything
./quality-checks/run-all.sh
```

Most audit scripts accept an optional directory argument to narrow the scan:

```bash
./quality-checks/ui-ux/zindex/audit.sh src/components/
```

---

## How to Interpret Results

Each audit uses consistent severity levels:

| Prefix | Meaning | Action |
|---|---|---|
| `ERROR` | Definite issue — WCAG violation or broken behavior | Must fix before merge |
| `WARNING` | Likely issue or deviation from conventions | Review and fix or justify |
| `INFO` | Informational, not necessarily a problem | Review if relevant |

---

## WCAG Coverage Map

| WCAG Criterion | Level | Check |
|---|---|---|
| 1.1.1 Non-text Content | A | `accessibility/` (alt text) |
| 1.3.1 Info and Relationships | A | `semantic-html/` (headings, landmarks) |
| 2.3.3 Animation from Interactions | AAA | `reduced-motion/` |
| 2.4.6 Headings and Labels | AA | `semantic-html/` |
| 2.4.7 Focus Visible | AA | `focus-management/` |
| 2.4.11 Focus Not Obscured | AA | `focus-management/` |
| 2.5.5 Target Size Enhanced | AAA | `touch-targets/` (44px) |
| 2.5.8 Target Size Minimum | AA | `touch-targets/` (24px) |
| 4.1.2 Name, Role, Value | A | `accessibility/` (ARIA labels) |

---

## How to Add a New Check

1. Choose the right topic folder (`ui-ux/`, `performance/`, `code-review/`, or create a new one)
2. Create a subfolder with the standard structure:
   ```
   topic/your-check/
   ├── README.md      # Rules, checklist, customization docs
   ├── config.conf    # Key=value settings (optional)
   └── audit.sh       # Executable scanner script
   ```
3. The `audit.sh` must:
   - Start with `#!/usr/bin/env bash`
   - Resolve `PROJECT_ROOT` via: `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"`
   - Read `config.conf` if it exists, with sensible defaults
   - Accept an optional CLI arg to override the scan directory
   - Exclude `node_modules/`, `.git/`, `dist/`, `build/`, and minified files
   - Use consistent severity prefixes: `ERROR`, `WARNING`, `INFO`
   - Exit 0 on success, non-zero on fatal errors
4. Update the topic's `README.md` to list the new check
5. `run-all.sh` auto-discovers it — no changes needed there

---

## For the Developer

This folder is designed to be **portable**. Copy `quality-checks/` into any frontend project and edit the `config.conf` files to match your project's structure, file types, and thresholds.

When creating a dedicated skill or hook for quality checks, point it at this `AGENT-GUIDE.md` as the entry point.
