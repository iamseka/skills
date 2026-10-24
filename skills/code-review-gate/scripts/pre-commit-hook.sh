#!/usr/bin/env bash
# code-review-gate pre-commit hook
# Classifies staged changes by risk tier and runs Claude review on
# non-trivial changes. Installed by install-hook.sh.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Get staged files.
STAGED_FILES="$(git diff --cached --name-only)"
if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

# Classify files.
TIERS_FILE="$REPO_ROOT/.review-tiers"
HIGHEST_TIER="LOW"

classify_file() {
    local file="$1"
    local tier="LOW"

    if [ ! -f "$TIERS_FILE" ]; then
        # No tiers file - default non-config files to MEDIUM.
        case "$file" in
            *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini) tier="LOW" ;;
            *.css|*.scss|*.less|*.svg) tier="LOW" ;;
            .gitignore|.editorconfig|.prettierrc) tier="LOW" ;;
            *.sh|*.bash|*.zsh) tier="HIGH" ;;
            Dockerfile|docker-compose.yml) tier="HIGH" ;;
            Makefile|Justfile|Taskfile.yml) tier="HIGH" ;;
            *.sql) tier="HIGH" ;;
            .env*|secrets*|credentials*|*key.pem|*cert.pem) tier="CRITICAL" ;;
            *) tier="MEDIUM" ;;
        esac
    else
        # Read tiers file and match patterns.
        while IFS= read -r line || [ -n "$line" ]; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue
            read -r file_tier patterns <<< "$line"
            for pattern in $patterns; do
                case "$file" in
                    $pattern) tier="$file_tier" ;;
                esac
            done
        done < "$TIERS_FILE"
    fi

    echo "$tier"
}

tier_rank() {
    case "$1" in
        LOW) echo 0 ;;
        MEDIUM) echo 1 ;;
        HIGH) echo 2 ;;
        CRITICAL) echo 3 ;;
        *) echo 1 ;;
    esac
}

while IFS= read -r file; do
    [ -z "$file" ] && continue
    file_tier="$(classify_file "$file")"
    if [ "$(tier_rank "$file_tier")" -gt "$(tier_rank "$HIGHEST_TIER")" ]; then
        HIGHEST_TIER="$file_tier"
    fi
done <<< "$STAGED_FILES"

file_count="$(echo "$STAGED_FILES" | wc -l | tr -d ' ')"
echo "code-review-gate: tier=$HIGHEST_TIER ($file_count files staged)"

# LOW tier - no review needed.
if [ "$HIGHEST_TIER" = "LOW" ]; then
    echo "code-review-gate: PASS (low-risk changes only)"
    exit 0
fi

# Skip merge commits.
if [ -f "$REPO_ROOT/.git/MERGE_HEAD" ]; then
    echo "code-review-gate: skipping review for merge commit"
    exit 0
fi

# Run Claude review with graceful degradation.
if ! command -v claude >/dev/null 2>&1; then
    echo "code-review-gate: Claude CLI not found, allowing commit"
    exit 0
fi

DIFF="$(git diff --cached)"
DIFF_SIZE="${#DIFF}"

if [ "$DIFF_SIZE" -gt 51200 ]; then
    echo "code-review-gate: diff exceeds 50KB ($DIFF_SIZE bytes), skipping automated review"
    echo "code-review-gate: run the skill manually for file-by-file review"
    exit 0
fi

REVIEW_PROMPT="Review the following staged diff for issues. Check for: hardcoded secrets/API keys, empty catch blocks, unhandled async, deleted tests without replacement, SQL injection, command injection, debug statements left in code. Respond with ONLY a JSON object: {\"verdict\": \"PASS\"|\"WARN\"|\"BLOCK\", \"findings\": [{\"severity\": \"critical\"|\"warning\"|\"info\", \"file\": \"path\", \"line\": 0, \"message\": \"description\"}]}. BLOCK if any critical finding. WARN if warnings only. PASS if clean.

Diff:
$DIFF"

REVIEW_OUTPUT=""
REVIEW_OUTPUT="$(timeout 60 claude -p "$REVIEW_PROMPT" 2>/dev/null)" || {
    echo "code-review-gate: Claude review unavailable or timed out, allowing commit"
    exit 0
}

if [ -z "$REVIEW_OUTPUT" ]; then
    echo "code-review-gate: Claude returned empty response, allowing commit"
    exit 0
fi

# Extract verdict.
VERDICT=""
if echo "$REVIEW_OUTPUT" | grep -q '"verdict"'; then
    VERDICT="$(echo "$REVIEW_OUTPUT" | grep -oE '"verdict"[[:space:]]*:[[:space:]]*"[A-Z]+"' | head -1 | grep -oE '"[A-Z]+"$' | tr -d '"')"
fi

if [ -z "$VERDICT" ]; then
    echo "code-review-gate: could not parse review output, allowing commit"
    echo "---"
    echo "$REVIEW_OUTPUT"
    echo "---"
    exit 0
fi

case "$VERDICT" in
    PASS)
        echo "code-review-gate: PASS"
        exit 0
        ;;
    WARN)
        echo "code-review-gate: WARN -- review findings above before pushing"
        echo "$REVIEW_OUTPUT"
        exit 0
        ;;
    BLOCK)
        echo "code-review-gate: BLOCK -- critical findings detected"
        echo "$REVIEW_OUTPUT"
        echo ""
        echo "Fix critical findings before committing. Use --no-verify to bypass (not recommended)."
        exit 1
        ;;
    *)
        echo "code-review-gate: unknown verdict \"$VERDICT\", allowing commit"
        exit 0
        ;;
esac
