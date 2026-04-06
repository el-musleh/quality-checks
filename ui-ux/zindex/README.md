# Z-Index Audit & Layering Checklist

**Purpose:** Run this checklist during development and before any release to catch z-index conflicts that cause UI elements to overlap incorrectly across all device sizes.

**Portable:** This folder can be dropped into any frontend project. Configure `zindex.conf` to match your project's file types and z-index scale.

---

## Z-Index Scale (authoritative)

Every `z-index` in the project must fit one of these layers. Edit `zindex.conf` to match your project's scale.

| Layer | z-index | What belongs here |
|---|---|---|
| **Card-local** | `1` | Badges, overlays, tooltips inside a card (`position: absolute` within a parent) |
| **In-flow elements** | `10` | Filters, preview badges that sit above siblings but below sticky bars |
| **Sticky sub-bars** | `99` | Filter bars, chip-bars, toolbars that stick below the header |
| **Header** | `1000` | The main site header and its dropdown menu |
| **Dropdowns / popovers** | `2000` | Sort menus, action menus, popover panels |
| **Confirmation modals** | `9999` | Blocking confirmation dialogs — above everything except loading |
| **Loading overlay** | `10000` | Full-screen loading spinner — absolute top layer |

---

## Rules

1. **Header is king.** The header (`z-index: 1000`) and its dropdown must always be above any sticky sub-bar. No sticky element below the header may use `z-index >= 1000`.

2. **Sticky sub-bars use `z-index: 99`** and offset their `top` value by the header height (e.g. `top: 56px`, adjusted for mobile). They sit visually below the header, not overlapping it.

3. **Modals are full-screen overlays.** They use `position: fixed; inset: 0` and must be above everything except the loading overlay. Use `9999` for confirmation modals, `10000` for loading.

4. **Dropdowns inside sticky bars** use `z-index: 2000` so they escape the sticky bar's stacking context and appear above page content.

5. **Card-local overlays** (badges, count pills, hover effects) use `z-index: 1`. They only need to layer above sibling elements within the same card.

6. **Never add a new z-index tier** without updating `zindex.conf` and this file.

---

## Pre-Release Checklist

Run the audit script and then manually verify each item:

```bash
./quality-checks/ui-ux/zindex/audit.sh
```

### Automated (script catches these)
- [ ] No z-index values outside the defined scale
- [ ] No sticky elements with `z-index >= 1000` except the header
- [ ] No `position: fixed` elements below `z-index: 1000` (they should be modals/overlays)

### Manual Testing (test at 3 widths: desktop 1280px, tablet 768px, mobile 375px)
- [ ] **Header dropdown:** Open any dropdown in the header. Scroll the page. It must stay above all page content including sticky bars.
- [ ] **Sticky sub-bars:** Scroll down on any page with a sticky filter/chip bar. It sticks below the header, not on top of it. Content scrolls underneath both.
- [ ] **Dropdowns in sticky bars:** Open any dropdown inside a sticky bar. It appears above surrounding content and is not clipped.
- [ ] **Confirmation modal:** Trigger any confirm dialog. It covers the entire viewport including the header.
- [ ] **Loading overlay:** Trigger a loading state. It covers everything, including any open modal.
- [ ] **Modal overlays:** Open any modal. It appears above page content and the header.
- [ ] **Mobile full-screen menus:** On small viewports, menus that expand full-screen are not blocked by any sticky bar.

---

## Live Inventory

Run the audit script to generate a current inventory of all z-index values in the project:

```bash
./quality-checks/ui-ux/zindex/audit.sh
```

The script reports:
- All z-index declarations with file, line number, and value
- Values that don't match the defined scale (potential issues)
- Sticky elements with `z-index >= 1000` that aren't the header (conflicts)
- Fixed-position elements with low z-index (may be hidden)

---

## Customization

### `zindex.conf`

Edit `quality-checks/zindex.conf` to configure:

| Key | Default | Description |
|---|---|---|
| `SCAN_DIR` | `.` | Directory to scan (relative to project root) |
| `FILE_TYPES` | `svelte,vue,jsx,tsx,html,css,scss,less` | File extensions to include |
| `VALID_ZINDEX` | `1,10,90,99,1000,2000,9999,10000` | Your project's z-index scale |
| `HEADER_PATTERN` | `header` | Basename pattern for header files (case-insensitive) |

### CLI arguments

Override the scan directory at runtime:

```bash
./quality-checks/ui-ux/zindex/audit.sh src/components/
./quality-checks/ui-ux/zindex/audit.sh src/ lib/
```
