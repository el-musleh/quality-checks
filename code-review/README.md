# Code Review Quality Checks

Automated audits for code health, technical debt, and compiler diagnostics.

## Available Checks

| Check | What it does |
|---|---|
| [`lint-warnings/`](lint-warnings/) | Captures and summarizes compiler/linter warnings (e.g., Svelte a11y, unused CSS) |
| [`todo-fixme/`](todo-fixme/) | Finds and reports all TODO, FIXME, HACK, and BUG comments |
| `dead-code/` | Planned |
| `dependency-audit/` | Planned |

## Run All Code Review Checks

```bash
# Run a specific check
./quality-checks/code-review/lint-warnings/audit.sh

# Or run everything in this topic
./quality-checks/run-all.sh code-review
```
