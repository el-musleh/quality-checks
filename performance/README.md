# Performance Quality Checks

Automated audits for build output size and runtime performance.

## Available Checks

| Check | What it does |
|---|---|
| [`bundle-size/`](bundle-size/) | Reports build output file sizes and flags files exceeding thresholds |

## Run All Performance Checks

```bash
./quality-checks/performance/bundle-size/audit.sh

# Or run everything at once
./quality-checks/run-all.sh
```
