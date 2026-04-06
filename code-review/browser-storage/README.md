# Browser Storage Audit

**Purpose:** Ensure `browser.storage.sync` is considered for user settings and preferences, allowing seamless cross-device synchronization, instead of defaulting to `browser.storage.local`.

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Usage of `browser.storage.local` or `chrome.storage.local` | Warning | Identifies when local storage is used. A manual review should determine if sync storage is more appropriate (e.g., for user preferences vs cached data). |

## Pre-Release Checklist

```bash
./quality-checks/code-review/browser-storage/audit.sh
```

- [ ] All user preferences (themes, shortcuts, toggles) are stored in `sync`.
- [ ] `local` is only used for caching, large data (playlists), or sensitive machine-bound state.
