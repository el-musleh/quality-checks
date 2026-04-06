# Format String Injection Audit

**Purpose:** Detect `console.log()` / `console.warn()` / `console.error()` calls where user-controlled data (variables, function parameters) is interpolated into the format string via template literals or string concatenation. Format specifiers like `%s`, `%d`, `%o` inside user-supplied content can produce garbled output or leak object internals.

## What It Checks

| Check | Severity | Description |
|---|---|---|
| Template literal as first argument to `console.*` containing variables | Warning | Variables may contain format specifiers (`%s`, `%d`, etc.) that `console` interprets |
| String concatenation as first argument to `console.*` | Warning | Same risk as template literals when concatenating user-controlled values |

## Safe Patterns

```javascript
// GOOD: explicit format specifiers, data as separate arguments
console.log("%s [%s] %s", prefix, level, message);
console.log("Static message with no variables");
console.log("Literal prefix:", variable);  // variable is a separate argument, not in the format string

// BAD: user-controlled values interpolated into the format string
console.log(`${prefix} [${level}] ${message}`);
console.log(prefix + " " + message);
```

## Pre-Release Checklist

```bash
./quality-checks/code-review/format-string/audit.sh
```

- [ ] No `console.log/warn/error` calls interpolate external variables into the format string.
- [ ] Logging helper functions use `%s` placeholders or pass data as separate arguments.

## Customization

Edit `config.conf` to change scan directories or file extensions.
