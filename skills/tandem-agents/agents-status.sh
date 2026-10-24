#!/usr/bin/env bash
# tandem-agents: one screen of "who is where" before any decision.
# Lists every checkout (worktree) of a repo, its branch, its uncommitted and
# untracked files, and -- inside herdr -- which agent pane sits in each one.
# Read-only: it changes nothing.
#
# Usage: bash <skill-dir>/agents-status.sh [repo-path]
#        (default: the current directory)
set -u

repo="${1:-$PWD}"
if ! top=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null); then
  echo "not a git repo: $repo"; exit 1
fi

# Every checkout of this repo: the main one plus each linked worktree.
worktrees=$(git -C "$top" worktree list --porcelain | awk '/^worktree /{print $2}')

# The first checkout listed is the main one; it names the repo.
echo "== checkouts of $(basename "$(printf '%s\n' "$worktrees" | head -1)")"
while read -r wt; do
  [ -z "$wt" ] && continue
  branch=$(git -C "$wt" branch --show-current 2>/dev/null)
  status=$(git -C "$wt" status --porcelain 2>/dev/null)
  changed=$(printf '%s' "$status" | grep -c . )
  untracked=$(printf '%s' "$status" | grep -c '^??')
  printf '\n%s\n  branch: %s   changed: %s   untracked: %s\n' \
    "$wt" "${branch:-(detached)}" "$changed" "$untracked"
  # Untracked files are where strays from other agents show up first.
  printf '%s\n' "$status" | grep '^??' | head -8 | sed 's/^??/    new:/'
done <<< "$worktrees"

# herdr's agent map: only from inside a herdr pane (the herdr skill's rule).
if [ "${HERDR_ENV:-}" = 1 ] && command -v herdr >/dev/null 2>&1; then
  echo; echo "== herdr panes and the checkout each one sits in"
  herdr pane list 2>/dev/null | WORKTREES="$worktrees" python3 -c '
import json, os, sys
trees = [t for t in os.environ["WORKTREES"].splitlines() if t]
panes = json.load(sys.stdin)["result"]["panes"]
for p in panes:
    cwd = p.get("cwd") or ""
    # The deepest checkout that contains this pane.
    home = max((t for t in trees if cwd == t or cwd.startswith(t + "/")), key=len, default=None)
    if home:
        where = home
    elif any(t.startswith(cwd.rstrip("/") + "/") for t in trees):
        where = "ABOVE the repo (" + cwd + "): can read and write every checkout"
    else:
        continue  # a pane in some other repo
    agent = p.get("agent") or "shell"
    pane, state = p["pane_id"], p.get("agent_status") or ""
    print(f"  {pane:7} {agent:7} {state:8} {where}")
'
fi
