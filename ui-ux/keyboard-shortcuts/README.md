# Keyboard Shortcuts Audit

**Purpose:** Ensure keyboard shortcuts respect web accessibility and browser native controls. Reserved shortcuts (like `Ctrl+C`, `Ctrl+V`, `Cmd+C`) should not be overridden by custom `keydown` listeners.

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Unvalidated `keydown` listeners | Warning | Flags global keydown listeners. Manual review should ensure reserved shortcuts are protected. |

## Pre-Release Checklist

```bash
./quality-checks/ui-ux/keyboard-shortcuts/audit.sh
```

- [ ] Extension doesn't override browser native commands (`Ctrl+C`, `Ctrl+V`, `Ctrl+T`, `Ctrl+W`, `Ctrl+N`, `Ctrl+R`).
- [ ] Shortcuts have a visible management UI to allow users to disable or remap them.
