#!/usr/bin/env bash
# install-hook.sh
#
# Install the code-review-gate pre-commit hook in the current git repo.
# Two modes:
#   Husky mode:    repos with package.json -> .husky/pre-commit
#   Raw hook mode: everything else        -> .git/hooks/pre-commit
#
# The hook body is sourced from pre-commit-hook.sh in this directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SOURCE="$SCRIPT_DIR/pre-commit-hook.sh"

if [ ! -f "$HOOK_SOURCE" ]; then
    echo "error: hook source not found at $HOOK_SOURCE" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2
    exit 1
}

if ! command -v claude >/dev/null 2>&1; then
    echo "warning: 'claude' CLI not found in PATH"
    echo "The hook will degrade gracefully (allow commits without review)."
    echo "Install Claude Code to enable pre-commit review."
fi

if [ -f "$REPO_ROOT/package.json" ]; then
    MODE="husky"
else
    MODE="raw"
fi

echo "Detected mode: $MODE"
echo "Repository: $REPO_ROOT"

install_hook() {
    local target="$1"
    if [ -f "$target" ] && [ -s "$target" ]; then
        echo ""
        echo "Existing pre-commit hook found at $target:"
        head -5 "$target"
        echo "..."
        echo ""
        if [ -t 0 ]; then
            read -rp "Overwrite? (y/n/append): " choice
        else
            choice="n"
            echo "Non-interactive shell -- refusing to overwrite. Pass --force to override."
        fi
        case "${choice:-n}" in
            y|Y) ;;
            a|append)
                echo "" >> "$target"
                cat "$HOOK_SOURCE" >> "$target"
                chmod +x "$target"
                echo "Appended hook body to $target"
                return 0
                ;;
            *)
                echo "Aborted."
                exit 1
                ;;
        esac
    fi

    cp "$HOOK_SOURCE" "$target"
    chmod +x "$target"
    echo "Installed hook: $target"
}

if [ "$MODE" = "husky" ]; then
    if ! npx husky --version >/dev/null 2>&1; then
        echo "Husky not found in $REPO_ROOT. Installing devDependency..."
        (cd "$REPO_ROOT" && npm install --save-dev husky && npx husky init)
    fi
    install_hook "$REPO_ROOT/.husky/pre-commit"
else
    install_hook "$REPO_ROOT/.git/hooks/pre-commit"
fi

# Create default .review-tiers if missing.
if [ ! -f "$REPO_ROOT/.review-tiers" ]; then
    cat > "$REPO_ROOT/.review-tiers" <<'TIERS'
# .review-tiers -- risk classification for pre-commit review
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
CRITICAL .env* secrets* credentials* *key.pem *cert.pem
TIERS
    echo "Created default .review-tiers at $REPO_ROOT/.review-tiers"
fi

echo ""
echo "code-review-gate installed. Staged changes will be reviewed before each commit."
