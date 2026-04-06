# Code Review Quality Checks

Placeholder for automated code review audits.

## Planned Checks

| Check | Status | What it will do |
|---|---|---|
| `lint-warnings/` | Planned | Capture and summarize linter warnings across the codebase |
| `todo-fixme/` | Planned | Find and report all TODO/FIXME/HACK comments |
| `dead-code/` | Planned | Detect unused exports, unreachable branches, and orphaned files |
| `dependency-audit/` | Planned | Flag outdated, deprecated, or vulnerable dependencies |

## Adding a New Check

Create a folder with the standard structure:

```
code-review/
└── your-check/
    ├── README.md      # What it checks, checklist, customization
    ├── config.conf    # Key=value settings (optional)
    └── audit.sh       # The scanner script (must be executable)
```

The `run-all.sh` script at the root auto-discovers every `audit.sh`.
