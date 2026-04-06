# Deprecated & Vulnerable Dependencies Audit

**Purpose:** Detect deprecated npm packages and known security vulnerabilities in both direct and transitive dependencies. Deprecated packages stop receiving security patches, so their transitive dependencies silently accumulate CVEs over time (e.g., `rollup-plugin-terser` → `serialize-javascript@4.0.0` → CVE-2026-34043).

## What It Checks

| Check | Severity | Description |
|---|---|---|
| `npm audit` vulnerabilities | Error | Known CVEs in direct or transitive dependencies |
| Deprecated packages | Warning | Packages marked deprecated on the npm registry |
| Known deprecated-to-replacement mappings | Warning | Common deprecated packages with known official replacements |

## Known Deprecated → Replacement Mappings

| Deprecated Package | Replacement | Notes |
|---|---|---|
| `rollup-plugin-terser` | `@rollup/plugin-terser` | Import changes from `{ terser }` named to `terser` default export |
| `rollup-plugin-json` | `@rollup/plugin-json` | Drop-in replacement |
| `rollup-plugin-buble` | `@rollup/plugin-buble` | Drop-in replacement |
| `@babel/polyfill` | `core-js` + `regenerator-runtime` | Must configure separately |
| `node-sass` | `sass` (Dart Sass) | API compatible for most use cases |
| `request` | `node-fetch` or `undici` | Different API, requires migration |

## Why This Matters

Transitive dependencies (deps of your deps) don't appear in `package.json`. When a direct dependency is deprecated and unmaintained, its own dependencies never get bumped — so vulnerabilities in the transitive tree accumulate silently. `npm audit` catches known CVEs, but checking for deprecated packages catches the problem *before* CVEs are filed.

## Pre-Release Checklist

```bash
./quality-checks/code-review/deprecated-deps/audit.sh
```

- [ ] No high/critical vulnerabilities reported by `npm audit`.
- [ ] No deprecated packages in the dependency tree.
- [ ] Any deprecated packages have been replaced with their maintained successors.

## Customization

Edit `config.conf` to change the package directory or severity threshold.
