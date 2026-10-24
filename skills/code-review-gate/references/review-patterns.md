# Review Patterns Reference

Patterns to check during pre-commit review. Each pattern has an ID,
description, and severity level. The review process flags code that matches
these patterns in staged diffs.

- **critical**: Always block. These are security or correctness issues.
- **warning**: Flag but allow. These are best-practice violations.
- **info**: Note but don't affect verdict. These are style suggestions.

---

## 1. Secrets and Credentials (Critical)

Hardcoded secrets, API keys, tokens, and credentials in source code.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| secrets-api-key | Strings matching API key formats (e.g., `sk-`, `AKIA`, `ghp_`, `glpat-`) | References to environment variables or config files |
| secrets-password | Hardcoded password strings in assignment (`password = "..."`) | Password validation logic, hashing, or placeholder values in tests |
| secrets-token | Bearer tokens, JWTs, or session tokens in source | Token handling/parsing code without literal values |
| secrets-private-key | Inline PEM keys or private key material | Public key references, key file path references |
| secrets-connection-string | Database connection strings with credentials | Connection string templates with env var placeholders |

---

## 2. Error Handling (Warning)

Missing or inadequate error handling that could cause silent failures.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| error-empty-catch | Empty catch/except blocks with no handling or comment | Catch blocks with intentional pass/ignore and a comment explaining why |
| error-swallowed | Caught exceptions that are neither logged nor re-raised | Exceptions caught for transformation or wrapping |
| error-bare-except | Bare `except:` or `catch (Exception)` catching everything | Catch-all at top-level entry points with proper logging |
| error-todo-handling | `# TODO: handle error` comments without actual handling | TODO comments with linked issue numbers |

---

## 3. Async and Concurrency (Warning)

Unhandled async patterns that cause race conditions or lost errors.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| async-unhandled-promise | `.then()` chains without `.catch()`, fire-and-forget promises | Promises with upstream error boundaries, void-returning event handlers |
| async-missing-await | Async function calls without `await` in async context | Intentional fire-and-forget with comment, Promise.all usage |
| async-shared-state | Mutable shared state accessed without synchronization | Immutable data, thread-local storage, lock-protected access |

---

## 4. Test Coverage (Warning)

Changes that reduce test coverage or remove safety nets.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| test-deleted | Test files or test functions deleted without replacement | Test refactoring that moves tests to a new location (both sides visible in diff) |
| test-skipped | Tests marked as skip/xfail/pending without linked issue | Skipped tests with issue tracker reference |
| test-weakened | Assertions removed or made less specific | Assertion changes that match intentional behavior changes |

---

## 5. Security (Critical)

Common security vulnerabilities in application code.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| security-sql-injection | String concatenation or f-strings in SQL queries | Parameterized queries, ORM usage |
| security-xss | Unescaped user input in HTML output | Sanitized output, framework auto-escaping |
| security-command-injection | User input passed to shell commands, `os.system()`, `subprocess` with `shell=True` | Subprocess with argument lists (no shell), hardcoded commands |
| security-path-traversal | User input used in file paths without sanitization | Paths validated against allowlist, chroot/jail usage |

---

## 6. Code Hygiene (Info)

Non-blocking observations about code quality.

| Pattern ID | What to flag | What to allow |
|---|---|---|
| hygiene-debug-left | Debug print statements, console.log, debugger statements | Logging framework calls, intentional debug flags behind env vars |
| hygiene-commented-code | Large blocks of commented-out code (3+ lines) | Single-line comments explaining alternatives |
| hygiene-fixme | FIXME/HACK comments without linked issue | FIXME/HACK with issue number or expiration date |
