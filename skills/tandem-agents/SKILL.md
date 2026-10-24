---
name: tandem-agents
description: >
  Rules for running several coding agents at once on the same repo (Claude
  sessions, agy / Gemini, codex, any herdr pane) without stray folders, copied
  work or crossed branches. Use when starting a session while other agents are
  live, when setting up a second agent or a blind comparison, when handing off
  between agents, or before deciding anything based on files you did not write.
  Trigger on "run agents in tandem", "parallel agents", "have gemini/agy/codex
  take a shot", "compare agents", "worktree for this agent", "handoff doc".
---

# tandem-agents

One repo, several agents, one person deciding. The job of these rules is to
keep every file's author obvious, so a copy or a stray never passes for an
independent answer.

## Why this exists (seka.works S73, 2026-09-29)

Claude built a pixel wordmark in a worktree; agy was meant to take an
independent shot in a second worktree. What happened instead:

- The launch command was typed INTO an agy that was already running, so its
  `--model` and `--mode` flags never applied and it worked from the folder it
  was already open in: the main checkout, which a live S72 session owned.
- A worktree is a convention, not a fence. agy read Claude's script in the
  sibling worktree, reproduced it (seven SVGs, byte-identical), and wrote copies
  into all three checkouts, including the one S72 was about to commit from.
- The brief gave a RELATIVE output path, which exists in every checkout.
- agy's handover said "Gemini 3.1 Pro" and linked files in the wrong folder.
  Nothing on screen said which folder belonged to which agent.

## Before anything: look

```bash
bash <skill-dir>/agents-status.sh [repo-path]
```

Read-only. Lists every checkout of the repo (branch, changed and untracked
files) and, inside herdr, which agent pane sits in each one. It flags panes
rooted ABOVE the repo (e.g. `~/Developer`), which can reach every checkout.
Run it at session start, before launching a second agent, and before any
decision that rests on files you did not write.

## The rules

1. **The main checkout has one owner at a time.** If another live agent is in
   it (the status script shows it), do not switch branches, stage with
   `git add -A`, or delete anything there. Work in your own worktree.
2. **One agent, one folder, named by owner.**
   `~/Developer/<repo>--<agent>-<slug>`, e.g. `seka.works--claude-s73`,
   `seka.works--agy-s73`. Create it with
   `git worktree add ~/Developer/<repo>--<agent>-<slug> -b <branch> main`
   or `herdr worktree create --branch <branch> --base main --path <path> --label <agent>-<slug>`.
   A Claude session doing worktree work should `cd` there (or be launched
   there), so its pane maps to its folder in the status output.
3. **Start each agent from a fresh shell prompt inside its folder.** Never type
   a launch command into a running agent: the flags are silently ignored. After
   it starts, confirm three things on screen: its folder, its model, its
   approval mode. Claude cannot launch other agents itself (Claude Code's
   auto-mode check blocks it); give the user the exact one-line command.
4. **Briefs use absolute paths.** Name the input files, the ONE folder the agent
   may write to, and say plainly: "Do not read or write any other checkout of
   this repo." Say what is off limits in the repo (e.g. `src/site/`) and
   whether to commit.
5. **Blind comparisons need isolation, not just a worktree.** Give the second
   agent a fresh clone OUTSIDE `~/Developer` (a scratch folder), holding only
   the brief and the inputs, and use its sandbox option if it has one
   (`agy --sandbox`; what it restricts is unverified). Or run it before the
   first agent writes or pushes anything. Afterwards, prove independence:
   `cmp` the outputs; byte-identical files mean a copy, not a second opinion.
6. **Verify a handoff against the disk.** Ask the user for the handover's path
   (agy keeps them at `~/.gemini/antigravity-cli/brain/<conversation-id>/`,
   e.g. `walkthrough.md`). Check every claim: which folder it wrote to
   (`git status` in every checkout), which model actually ran, whether the
   gates it says passed pass for you.
7. **Strays are the user's call.** Report files that appear where their
   author should not have written. Delete them only in your own folder, or with
   the user's OK after confirming they are untracked copies (`cmp`,
   `git ls-files --error-unmatch`).
8. **Merge order is explicit.** A side branch that records a decision (a pick,
   a verdict) says so in its commit, and the next session that owns main merges
   it before building on it. Tracking files (MEMORY, progress, DECISIONS) are
   reconciled at that merge, not written on two branches at once.

## herdr quick reference

- Map: `herdr workspace list`, `herdr pane list`, `herdr agent list` (JSON).
- A pane's folder is its `cwd`; an agent's real folder is where it was started.
- State hooks: `herdr integration status`; agy needs
  `herdr integration install antigravity-cli` for working / blocked / done.
- Launch (user runs it, in the agent's own pane):
  `agy --model <model> --mode accept-edits -i "<prompt with absolute paths>"`.
  `agy models` lists the models.
