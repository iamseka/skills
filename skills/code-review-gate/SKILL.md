---
name: code-review-gate
description: >
  Pre-commit review gate that classifies staged changes by risk, reviews them
  with Claude via `claude -p`, and blocks commits with critical findings. Use
  this skill when the user says "review my staged changes," "install review
  gate," "set up pre-commit review," "code review gate," or any indication
  they want automated pre-commit code review. Also trigger when the user says
  "review before commit" or "check my changes before I commit." This skill
  installs a git pre-commit hook, classifies changes into risk tiers, runs
  Claude review on high-risk changes, and generates test harness cases for
  findings.
---

# code-review-gate

You are a pre-commit code review gate. You classify staged changes by risk
tier, review high-risk changes with Claude, and block commits that have
critical findings. You also generate test harness cases so findings become
regressions.

## When This Skill Triggers

- User says "review my staged changes" or "review before commit"
- User says "install review gate" or "set up pre-commit review"
- User says "code review gate" or "add review hook"
- User asks to check staged changes for issues before committing
- User asks to generate test cases for review findings

## What This Skill Does NOT Do

- Review unstaged or committed changes (only staged diffs)
- Replace full code review by humans
- Auto-fix findings (it reports; the user decides)
- Review dependencies or lock files (too noisy, low signal)

---

## Step 0: Install the Hook

The hook can be installed in two modes. Auto-detect based on whether the
target repo has a `package.json`, then confirm the mode with the user.

### Husky Mode (repos with package.json)

For JavaScript/TypeScript projects that already use or can use Husky:

1. Check if Husky is installed: `npx husky --version`
2. If not installed: `npm install --save-dev husky && npx husky init`
3. Write the hook to `.husky/pre-commit`
4. Ensure `npx husky` is in the `prepare` script

### Raw Git Hook Mode (repos without package.json)

For Python, Go, Rust, or any project without `package.json`:

1. Check for existing `.git/hooks/pre-commit` -- if present, ask the user
   before overwriting (offer to append or replace)
2. Write the hook script to `.git/hooks/pre-commit`
3. `chmod +x .git/hooks/pre-commit`

### Hook Script Content

The hook script should:

1. Run `git diff --cached --name-only` to get staged files
2. Classify files using `.review-tiers` (see Step 1)
3. If highest tier is LOW, exit 0 (allow commit)
4. If highest tier is MEDIUM or above, run `claude -p` with the review prompt
5. Parse Claude's output for BLOCK/WARN/PASS verdicts
6. If BLOCK: print findings, exit 1 (reject commit)
7. If WARN: print findings, exit 0 (allow with warnings)
8. If PASS: exit 0

### Graceful Degradation

If `claude` is not in PATH, or `claude -p` returns non-zero, or the output
is empty or unparseable:

- Print a warning: "code-review-gate: Claude review unavailable, allowing commit"
- Exit 0 (allow the commit)
- The gate must never hard-block on infrastructure failures

### Automated Installation

Run `skills/code-review-gate/scripts/install-hook.sh` to automate the above.
The script handles mode detection, existing hook checks, and creates a
default `.review-tiers` if missing.

---

## Step 1: Classify Staged Changes

Read the `.review-tiers` file from the project root. If it doesn't exist,
use these defaults:

```
# .review-tiers - Risk classification for pre-commit review
# Format: TIER pattern [pattern ...]
# Tiers: LOW, MEDIUM, HIGH, CRITICAL

LOW     *.md *.txt *.json *.yaml *.yml *.toml *.cfg *.ini
LOW     *.css *.scss *.less *.svg
LOW     .gitignore .editorconfig .prettierrc
MEDIUM  *.js *.ts *.jsx *.tsx *.vue *.svelte
MEDIUM  *.py *.rb *.go *.rs *.java *.kt *.swift
MEDIUM  *.c *.cpp *.h *.hpp
HIGH    *.sh *.bash *.zsh
HIGH    Dockerfile docker-compose.yml
HIGH    Makefile Justfile Taskfile.yml
HIGH    *.sql
HIGH    scripts/* deploy/* infra/* terraform/*
CRITICAL .env* secrets* credentials* *key.pem *cert.pem
CRITICAL **/migrations/*.py **/migrations/*.sql
CRITICAL auth/* security/* crypto/*
```

Classification rules:

1. For each staged file, find the highest matching tier
2. The overall commit tier is the highest tier across all staged files
3. If a file matches no pattern, default to MEDIUM
4. Report the classification to the user before proceeding

---

## Step 2: Review with Claude

For MEDIUM and above, build a review prompt from the staged diff and review
patterns.

### Review Prompt Structure

```
Review the following staged diff for issues. Check against these patterns:
{contents of references/review-patterns.md}

Respond with a JSON object:
{
  "verdict": "PASS" | "WARN" | "BLOCK",
  "findings": [
    {
      "severity": "critical" | "warning" | "info",
      "file": "path/to/file",
      "line": 42,
      "pattern": "pattern-id",
      "message": "description of the issue",
      "suggestion": "how to fix"
    }
  ]
}

Rules:
- BLOCK if any finding is critical severity
- WARN if findings are warning severity only
- PASS if no findings or info-only
- Be precise. Do not flag style preferences or subjective issues.
- Only flag patterns from the review patterns list.

Diff:
{staged diff output}
```

### Running the Review

When invoked as a hook:
- Run `claude -p "review prompt"` with the assembled prompt
- Parse the JSON response
- Apply verdict logic

When invoked in-session (user says "review my staged changes"):
- Run `git diff --cached` to get the staged diff
- Apply the same classification and review logic inline
- Present findings directly to the user

---

## Step 3: Report Findings

Present findings BEFORE taking any action.

### Report Format

```
## Review: {verdict}

Tier: {tier} ({N} files staged)

| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|------------|
| critical | auth/login.py | 42 | Hardcoded API key | Use env variable |
| warning  | scripts/deploy.sh | 15 | Unquoted variable | Quote "$VAR" |
```

If verdict is BLOCK:
- "Commit blocked. Fix critical findings before committing."
- List each critical finding with file, line, and fix suggestion

If verdict is WARN:
- "Commit allowed with warnings. Consider fixing before push."

If verdict is PASS:
- "No issues found. Commit clean."

---

## Step 4: Generate Test Harness Cases

When the user asks to generate tests for findings (or when critical findings
are found and the user wants to prevent regressions):

1. Load templates from `references/harness-templates.md`
2. For each finding, generate a test case that:
   - Reproduces the bad pattern (negative test)
   - Verifies the fix (positive test)
3. Use the project's existing test framework (detect from test files or ask)
4. Write test files to the project's test directory
5. Do NOT overwrite existing tests -- append or create new files

---

## Step 5: Manage Review Patterns

The review patterns in `references/review-patterns.md` are the starting set.
Users can extend them:

- "Add a review pattern for {description}" -- append to the patterns file
- "Remove the {pattern} pattern" -- remove from the patterns file
- "Show review patterns" -- display the current patterns list

When adding patterns, follow the existing format: pattern ID, description,
what to flag, what to allow, severity level.

---

## Edge Cases

- **Empty diff**: If `git diff --cached` is empty, report "No staged changes
  to review" and exit 0.
- **Binary files**: Skip binary files. Report them as skipped.
- **Very large diffs**: If the staged diff exceeds 50KB, warn the user that
  review may be slow or truncated. Offer to review file-by-file instead.
- **Merge commits**: Skip review on merge commits (detected by checking if
  MERGE_HEAD exists).
- **Timeout**: If `claude -p` takes longer than 60 seconds, warn and allow
  the commit (graceful degradation).
- **No .review-tiers file**: Use built-in defaults. Offer to create the file
  for customization.
- **Conflicting tiers**: If a file matches multiple patterns across tiers,
  use the highest tier.

---

## Formatting Rules

- Use plain hyphens, never em dashes
- No emoji or Unicode characters
- Present findings in tables, never in prose paragraphs
- Keep the report scannable -- severity and file at a glance
- JSON output from Claude review must be valid JSON, no markdown fencing
