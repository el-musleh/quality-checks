# Semantic HTML Audit

**Purpose:** Ensure proper HTML semantics: correct heading hierarchy, landmark roles, form associations, and appropriate use of semantic elements over generic divs.

**Reference:** [WCAG 1.3.1 Info and Relationships](https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html) (Level A), [WCAG 2.4.6 Headings and Labels](https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html) (Level AA)

---

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Skipped heading levels | Warning | `<h1>` followed by `<h3>` (skipping h2) breaks document outline |
| `<nav>` without `aria-label` | Warning | Multiple navs need distinct labels for screen readers |
| Forms without `<label>` | Warning | Form inputs not associated with labels |
| `<div>` or `<span>` with click handler | Info | May need `<button>` or `role="button"` instead |
| Missing `<main>` landmark | Info | Pages should have one `<main>` element |

---

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/semantic-html/audit.sh
```

- [ ] Heading levels don't skip (h1 → h2 → h3, not h1 → h3)
- [ ] Navigation elements have descriptive aria-labels
- [ ] Form inputs are associated with labels
- [ ] Page has a `<main>` landmark
- [ ] Interactive elements use `<button>` or `<a>`, not styled divs
