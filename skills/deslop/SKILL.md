---
name: deslop
description: >
  Detect and remove AI-generated slop patterns from text and code. Use this
  skill when the user says "deslop," "remove slop," "clean up AI writing,"
  "make this sound human," "de-slop," or any indication they want to strip
  characteristic AI writing artifacts from content. Also trigger when the user
  says "this sounds too AI" or "make this less ChatGPT." This skill scans for
  known slop patterns, reports findings, and applies fixes with user approval.
  It supports prose, documentation, code comments, and commit messages.
---

# deslop

You are scanning content for AI-generated slop patterns and removing them.
Slop is the set of verbal tics, filler phrases, and stylistic artifacts that
make AI-written text immediately recognizable. Your job is to flag these
patterns and replace them with cleaner, more direct alternatives -- or remove
them entirely when they add nothing.

## When This Skill Triggers

- User says "deslop," "de-slop," "remove slop," "clean up AI writing"
- User says "make this sound human" or "this sounds too AI"
- User says "clean up this text" in the context of AI-generated content
- User asks to review writing quality of generated documentation or comments

## What This Skill Does NOT Do

- Rewrite content for style or tone beyond slop removal
- Change technical accuracy or meaning
- Add new content, restructure documents, or change formatting
- Make subjective editorial decisions (it flags patterns, not opinions)

---

## Step 1: Determine Scope

Ask or infer what content to scan:

1. **Named files**: User specifies files or paths ("deslop README.md")
2. **Staged changes**: User says "deslop my changes" -- scan `git diff --staged`
3. **Recent changes**: User says "deslop what I just wrote" -- scan
   `git diff` (unstaged) or last-edited files
4. **Project-wide**: User says "deslop everything" or "scan the project" --
   scan all .md files and code comments across the project

If scope is ambiguous, ask: "Which files should I scan?"

### .deslop-ignore

If a `.deslop-ignore` file exists in the project root, respect it. Format
is one glob pattern per line (same as .gitignore). Common entries:

```
# Don't touch third-party docs
vendor/
node_modules/
# Don't touch changelog
CHANGELOG.md
```

---

## Step 2: Scan for Patterns

Load patterns from `references/slop-patterns.md` (bundled with this skill).
Patterns are organized into categories with confidence levels:

- **High confidence**: Always flag. These are nearly always slop regardless
  of context (e.g., "Let's dive in," "I'd be happy to help")
- **Medium confidence**: Flag but check context. Some have legitimate uses
  (e.g., "robust" is slop in marketing copy but valid in engineering docs
  describing fault tolerance)

For each file in scope:

1. Read the file content
2. Match against all pattern categories
3. Record each match with: file, line number, matched text, category,
   confidence level, and suggested replacement (or "remove")

Skip binary files and files matching .deslop-ignore patterns.

---

## Step 3: Report Findings

Present findings BEFORE making any changes. Always confirm before editing.

### Report Format

**Summary line**: "{N} slop patterns found across {M} files"

**By file** (for targeted scans of 1-5 files):

```
## filename.md

- Line 12: "It's important to note that" -> remove (filler phrase, high)
- Line 34: "robust" -> check context (marketing word, medium)
- Line 56: "Let's dive into" -> remove (sycophantic opener, high)
```

**By category** (for project-wide scans):

```
## Filler phrases (23 found)
  - README.md:12 "It's important to note that"
  - docs/guide.md:5 "In order to"
  ...

## Sycophantic openers (4 found)
  - README.md:1 "Great question!"
  ...
```

If zero patterns found, say so: "No slop patterns detected." and stop.

### User Decision

After presenting the report, ask:

- "Fix all {N} high-confidence patterns automatically?" (recommended)
- "Review each change interactively?"
- "Fix specific categories only?"

---

## Step 4: Apply Fixes

Based on user choice:

### Fix All (High Confidence)

Apply all high-confidence fixes at once. For medium-confidence patterns,
list them separately and ask about each.

### Interactive Review

Walk through each finding one at a time:
- Show the line with surrounding context (2 lines above and below)
- Show the proposed change
- Ask: fix / skip / custom replacement

### Category-Specific

Apply all fixes within user-selected categories.

### Replacement Rules

When replacing slop:

1. **Filler phrases**: Remove entirely. Tighten the surrounding sentence.
   "It's important to note that the system requires auth" becomes
   "The system requires auth"
2. **Unnecessary adverbs**: Remove the adverb. "Effectively manages" becomes
   "Manages"
3. **Marketing words**: Replace with precise terms or remove.
   "Cutting-edge solution" becomes "solution" (or a specific descriptor)
4. **Hedging language**: Make definitive or remove.
   "It seems like this might work" becomes "This works" (if true)
5. **Structural slop**: Remove the sloppy element entirely.
   "Great question! Let me explain..." becomes the explanation directly
6. **Formatting slop**: Remove excess punctuation/emoji.
   "Amazing feature!!!" becomes "Feature" (rewrite the sentence)
7. **Code comment slop**: Remove the comment if it restates the code.
   `// increment counter` above `counter++` -- remove the comment

---

## Step 5: Verify

After applying fixes:

1. Re-read each modified file
2. Check that no formatting was broken (unclosed markdown, broken links,
   orphaned list items)
3. Check that no meaning was changed (removal shouldn't alter technical
   content)
4. If any issues are found, fix them before reporting completion

Report: "Fixed {N} patterns across {M} files. No formatting issues."

---

## Edge Cases

- **Mixed content**: Files with both human-written and AI-generated sections.
  Scan everything but be more conservative with medium-confidence flags in
  files that appear mostly human-written.
- **Intentional slop**: If the user says "keep that one," respect it. Don't
  re-flag patterns the user explicitly approved.
- **Code vs. prose**: Code comments get code-comment-slop patterns only.
  Don't flag "robust" in a variable name or "comprehensive" in a test
  description where it has technical meaning.
- **Non-English content**: Skip files that aren't primarily English. Pattern
  matching is English-only.

---

## Formatting Rules

- Use plain hyphens, never em dashes
- No emoji or Unicode characters
- Present findings in tables or structured lists, never in prose paragraphs
- Keep the report scannable -- the user should see the problem and fix at a glance
