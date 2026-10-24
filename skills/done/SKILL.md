---
name: done
description: >
  Produce a structured summary of the current working session. Use this skill
  when the user says "/done," "done," "session done," "wrap up," "end session," "summarize this
  session," or any indication they want to capture what happened before ending
  their session. Also trigger if the user asks for a mid-session checkpoint or
  progress snapshot, or says "update progress." Also run it unprompted after
  finishing a big chunk of work (a feature or fix finished and verified,
  or a multi-file change in a working state). This skill uses git history
  and project state as evidence -- it never fabricates or assumes work that
  isn't reflected in the file system.
model: sonnet
effort: low
---

# done

You are producing a structured summary of the current working session. Your
summary is evidence-based -- everything you report must be backed by git
history, file changes, or explicit user statements from this conversation.

**CRITICAL: Steps 1-5 execute as a single uninterrupted sequence. Do not
pause for confirmation between steps. The user triggered /done -- that is
the only confirmation needed. Present the summary, update files, commit,
and push in one continuous flow.**

## When This Skill Triggers

- User says "session done," "wrap up," "end session," "we're done"
- User asks to "summarize this session" or "what did we do"
- User wants a checkpoint or progress snapshot mid-session
- User says "save progress" or "capture where we are"
- User says "update progress" or "update progress.md"
- Claude just finished a big chunk of work -- run without being asked.
  A big chunk is a feature or fix finished and verified, a plan phase
  completed, or a multi-file change in a working state. Hold off mid-task,
  after read-only work, or while tests are failing

## What This Skill Does NOT Do

- Fabricate accomplishments not reflected in git or file changes
- Edit or rewrite existing documentation beyond root progress/memory files
- Make decisions about next steps without grounding in project context
- Create new project files (summaries are ephemeral or go in root files)

## Relationship to the SessionEnd hook

A SessionEnd hook, if you run one (not included here), fires on every
session exit. It does NOT auto-commit -- it only warns when registered
repos have uncommitted work, so the next session does not start blind.

This skill is still the right place to actually wrap up a session: it
builds a real commit message from session evidence, updates the right
tracking files, and pushes. The hook is the safety net for when the
user forgot to invoke it.

---

## Step 1: Gather Evidence

Collect the following from the current project. If any source is unavailable,
skip it -- do not error or block.

### Git Evidence

1. **Status**: `git status` -- what's staged, modified, untracked
2. **Log**: `git log --oneline` for commits made this session (use timestamps
   or compare against session start to scope appropriately; when in doubt,
   show the last 10-20 commits and let recency guide you)
3. **Diff summary**: `git diff --stat HEAD~N` where N covers session commits
   (shows files changed, insertions, deletions)
4. **Files created**: new files added this session
5. **Files deleted**: files removed this session

### Project Evidence

6. **Root progress files**: discover which files this project uses for
   session tracking (see Step 3 for discovery logic)
7. **Conversation context**: what the user asked for and what you discussed

Write the new entry from this session's evidence only. Read prior progress
entries to reuse their format or a workstream name, but do not copy their
content forward -- stale state repeated session after session is how
progress files drift.

### Edge Cases

- **No git repo**: Use file modification times and conversation context only.
  Note that evidence is limited.
- **Empty session**: If no meaningful changes were made, say so honestly.
  A summary of "we discussed X but made no changes" is valid.
- **Multiple projects**: If the session touched multiple repos or directories,
  produce a separate summary section for each.
- **Mid-session**: Label it as a checkpoint, not a final summary.

---

## Step 2: Build the Summary

Structure the summary with exactly these six sections. Each section can be
empty (use "None this session") but must be present.

### Accomplished

What was done. Each item should be one sentence referencing specific files,
features, or changes. Group by theme if more than 5 items.

Rules:
- Only list things with evidence (commits, file changes, conversation record)
- Use past tense ("Added X," "Fixed Y," "Refactored Z")
- Include counts when useful ("Created 3 new modules," "Modified 12 files")

### Decisions Made

Architectural, design, or strategic choices made during the session. Each
entry should state the decision and its rationale in one sentence.

Rules:
- Include decisions made in conversation even if not yet logged
- Format: "**Decision**: {what}. **Why**: {rationale}"

### Next Steps

Concrete actions that should happen in the next session. These should be
actionable, not vague aspirations.

Rules:
- Derive from conversation context, open questions, and incomplete work
- Each item should be specific enough to act on without re-reading the
  full session history
- Mark urgency if apparent (e.g., "blocking" or "when time allows")

### Open Questions

Unresolved questions, uncertainties, or things that need external input.

Rules:
- Include questions raised but not answered during the session
- Include technical uncertainties discovered during implementation
- Do not invent questions -- only list what actually came up

### Blockers

Anything waiting on an external party, an access grant, a rate limit, a
deploy. Name who or what unblocks it and the expected timing if known.

### Pointers for Next Session

The files the next session should re-read first, and anyone waiting on a
reply. Paths, not descriptions.

---

## Step 3: Discover and Update Root Files

This step executes automatically -- no confirmation prompts.

### Discovery

Scan the project root for the following known file types. Also check
`CLAUDE.md` for references to project-specific tracking files.

If none of these files exist, skip this step entirely. Do not create
tracking files the project has not established.

### File Purposes and Update Rules

Each file has a distinct purpose. Apply only the update that matches
that purpose -- do not bleed content from one file into another.

---

**progress.md / PROGRESS.md**
Purpose: Current state snapshot plus the last 14 days of session entries.
Answers "where is the project right now, and what happened lately."
Data: active phase, what is in progress, blockers, immediate next steps,
and one entry per session.
Update: Every session. This is the highest-priority file to keep current.
How: Update "last updated" date and any undated state block. Then add this
session's entry at the top of the entries (newest on top), with a heading
in exactly this form so rotation can find it:

    ## YYYY-MM-DD -- short headline

    **Branch / repo state:** `<branch>` (worktree path if not the main checkout)

Follow it with the six summary sections (Accomplished through Pointers for
Next Session), matching the file's existing entry style.

Retention: there is no line cap. After writing the entry, run

    python3 <skill-dir>/scripts/rotate-progress.py <project-root>

It keeps the last 14 days of entries in full (the newest 3 always stay,
whatever their age), moves older entries verbatim to
`docs/archive/progress-YYYY-MM.md` by each entry's own date, and only
trims further if the file passes 1,500 lines. It checks that no entry was
lost and writes nothing if the check fails -- if it exits 1, stop and tell
the user. Never trim progress.md by hand and never leave stub or index rows
for moved entries; older work is found with
`grep -n '<topic>' docs/archive/progress-*.md`.

Reading at session start: read what is relevant to the task. The top
entries and the state block are usually enough; grep the rest of the file
or the archive when the task reaches further back.

---

**MEMORY.md**
Purpose: Persistent context for Claude. Answers "what does Claude need
to know to work effectively in this project."
Data: architecture decisions, naming conventions, gotchas, key file
locations, things that would take multiple sessions to re-discover.
Update: Only when something fundamental changes -- architecture shifts,
renamed modules, new conventions adopted. Skip routine sessions.
How: Update the relevant section. Do not bloat with session-level detail.
If the file has a current-state block, keep exactly one: replace it in
place, never stack a new dated block above the old one. Dated session
detail belongs in progress.md, where rotation handles it. No line cap.

---

**MILESTONES.md**
Purpose: Record of completed phases and goals. Answers "what has been
delivered and when."
Data: milestone name, completion date, what was delivered.
Update: Only when a milestone is reached -- not every session.
How: Append under the current phase. Do not restructure existing content.

---

**CHANGELOG.md**
Purpose: User-facing versioned history. Answers "what changed between
releases" for someone consuming or depending on this project.
Data: version number, release date, user-visible changes grouped by type
(Added, Changed, Fixed, Removed).
Update: On releases or meaningful version bumps -- not every session.
How: Append a new version block at the top. Follow Keep a Changelog
format if the file already uses it.
Note: If a project has both CHANGELOG.md and build-log.md, they are not
redundant. CHANGELOG is for users and releases; build-log is for
developers and sessions. Keep them separate.

---

**build-log.md / BUILD-LOG.md**
Purpose: Developer session log. Answers "what happened during each work
session."
Data: date, files added or modified, implementation notes, problems
solved, approaches tried.
Update: Every session that touched code or config.
How: Append a dated entry. Keep it short (3-8 lines) -- this is a log,
not a narrative. Do not summarize decisions or lessons here; those belong
in their own files.

---

**decisions.md / DECISIONS.md**
Purpose: Architectural and strategic decision log. Answers "why things
are built the way they are."
Data: decision, rationale, date, alternatives considered if relevant.
Update: When a significant decision is made -- not for routine choices.
How: Append a new entry formatted consistently with existing entries.
Do not modify or second-guess prior decisions.

---

**lessons.md / LESSONS.md**
Purpose: Process learnings. Answers "what did we figure out that future
sessions should know."
Data: insight, context that makes it meaningful, date.
Update: Only when something genuinely new was learned -- skip routine
sessions entirely.
How: Append a new entry. One concrete insight per entry. Do not pad with
observations that would be obvious in hindsight.

---

**README.md / README**
Purpose: Project documentation for any human (or Claude) approaching the
project fresh. Answers "what is this, how do I set it up, how do I run it."
Data: project summary, setup steps, commands, architecture overview.
Update: When the session changes how the project is built, run, or
structured in a way that makes the README inaccurate.
Triggers: new setup steps, changed commands, renamed modules, added or
removed features the README describes.
How: Read the file first. Update only the stale sections. Do not append
a session block -- this is reference documentation, not a log.
Skip entirely if nothing README-relevant changed this session.

---

### Rules

- Read each file first to understand its structure before editing
- Match the existing formatting conventions of each file
- Do not rewrite sections unrelated to this session's work
- If a file's structure is unclear, append a clearly labeled session
  block at the end rather than guessing where content belongs
- Never write session summaries into README.md or MEMORY.md -- those
  are reference documents, not logs

---

## Step 3.5: Fallbacks when no tracking files were updated

If Step 3 found NO project tracking files in the primary project's
root (no progress.md, MILESTONES.md, CHANGELOG.md, build-log.md,
decisions.md, or lessons.md existed, and so none were updated), apply
these fallbacks so the session's WHY is not lost. The auto-memory and
plan-file infrastructure already exist; this step routes the session's
captured reasoning into them.

Skip this step entirely if Step 3 successfully updated any project
tracking file -- the existing convention is sufficient.

### Fallback A: Auto-memory decisions log

Applies if Step 2's "Decisions Made" section has at least one entry.

1. Locate the auto-memory directory at
   `~/.claude/projects/-Users-<user>-Developer/memory/`. Skip Fallback
   A if the directory does not exist.
2. Identify the primary project (the directory under `~/Developer/`
   with the most file changes this session). Derive a slug from its
   folder name (kebab-case).
3. Target file: `<memory-dir>/project_<slug>_decisions.md`.
   - If it does not exist, create it with frontmatter
     (`type: project`, name = "<Project name> decisions log",
     description naming the canonical artifact location).
   - If it exists, append a new dated section -- do not overwrite or
     rewrite prior entries.
4. Each appended section contains: an `## YYYY-MM-DD -- <session topic>`
   heading, a pointer line to the canonical project artifact if one is
   known (BRAND.md / DESIGN.md / ARCHITECTURE.md), a pointer line to
   the archived plan if Fallback B ran, and the Decisions Made entries
   from Step 2 verbatim (preserving the **Decision**/**Why** structure).
5. If a new memory file was created, also append an index line to
   `<memory-dir>/MEMORY.md`.

### Fallback B: Plan-file archiving

Applies if a plan file from this session exists at `~/.claude/plans/`.

1. List `~/.claude/plans/*.md` with their mtimes.
2. Identify candidates modified during this session. Heuristic: mtime
   later than the earliest commit on the primary project this session,
   OR within the last 48 hours if no commits exist. Prefer the most-
   recently-modified file if multiple candidates exist; if the topic
   is recoverable from filename, prefer the closest topic match.
3. If exactly zero candidates: skip silently.
4. If at least one candidate: copy the chosen plan to the primary
   project at `<project-root>/docs/plans/YYYY-MM-DD-<original-filename>`.
   Create the `docs/plans/` directory if needed. Copy, do not move --
   the original under `~/.claude/plans/` stays for harness reference.
5. If the primary project has no writable on-disk root suitable for a
   `docs/plans/` subdirectory (e.g., not under `~/Developer/`): skip
   and note in the summary.

### Rules

- Both fallbacks are non-destructive: append-only memory, copy-only
  plans. Never overwrite, never delete.
- Mention what each fallback did (or skipped, and why) in the Step 4
  summary so the user can see where the WHY landed.
- Do not run these fallbacks if Step 3 already updated tracking files;
  respect the project's established convention.
- If the primary project is not in a git repo, Fallback B may still
  copy the plan locally even though Step 5 will not commit it. Note
  this explicitly in Step 4 ("plan archived locally; project not under
  git").

---

## Step 4: Present the Summary

Display the session summary to the user. Include a brief note of which
root files were updated (e.g., "Updated MEMORY.md and MILESTONES.md"),
how many progress entries rotation moved and to which archive files, and
anything you intentionally did not capture, so the user can correct you.

This is informational -- do not wait for approval before proceeding to
Step 5.

---

## Step 5: Commit and Push

This step always executes. No confirmation prompt, with one exception:

0. Check `git status` against what this session changed. If there are
   uncommitted changes this session did not make (another agent's work,
   a parallel session), stop and ask before staging -- `git add -A`
   would sweep them into this commit.
1. `git add -A` to stage all changes (session work + root file updates)
2. Commit with message format:
   `[docs] Session N -- {brief summary of session work}`
   where N is the session number if discoverable from root files, otherwise
   use the date: `[docs] {date} -- {brief summary}`
3. `git push` if a remote is configured
4. Confirm completion: "All changes committed and pushed." or report any
   errors encountered
5. Name the branch you committed to. If it is not main, or the commit was
   made in a worktree, say whether main still needs a merge.

If everything was already committed and pushed before this skill triggered,
confirm: "All changes were already committed and pushed."

---

## Formatting Rules

- Use plain hyphens, never em dashes
- No emoji or Unicode characters
- Keep the summary scannable -- prefer bullet points over paragraphs
- Total summary should fit in one screen (roughly 30-50 lines)
