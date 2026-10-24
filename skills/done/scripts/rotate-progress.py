#!/usr/bin/env python3
"""
rotate-progress.py

Keeps a project's progress.md to a 14-day window of full session entries.
Older entries move, verbatim, into monthly archive files. Nothing is deleted.

An entry is a "## YYYY-MM-DD ..." heading and everything under it, up to
the next "## " heading. Other "## " sections (state blocks, old index
tables) are never touched.

Rules, applied in this order:
  1. Hot window: entries dated more than 14 days before today move out.
  2. Backstop: if the file is still over 1,500 lines, the oldest remaining
     entries move out one at a time until it is under.
  3. Floor: the newest 3 entries always stay, whatever their age.

Moved entries go to docs/archive/progress-YYYY-MM.md, keyed by each entry's
own date, newest on top.

Usage:
  rotate-progress.py <project-root>              # rotate
  rotate-progress.py <project-root> --dry-run    # show what would move
  rotate-progress.py <project-root> --check      # exit 1 if anything would move
  rotate-progress.py <project-root> --today YYYY-MM-DD   # override today (tests)

Exit code:
  0 on success (or nothing to move)
  1 if --check finds entries to move, or the safety check fails
"""

import argparse
import datetime
import os
import re
import sys

WINDOW_DAYS = 14
BACKSTOP_LINES = 1500
FLOOR_ENTRIES = 3

ENTRY_HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2})")


def split_sections(text):
    """Split markdown into [preamble, section, section, ...].

    A section starts at a "## " line. "## " lines inside ``` fences are
    ignored so code samples never split an entry.
    """
    sections = [""]
    in_fence = False
    for line in text.splitlines(keepends=True):
        if line.startswith("```"):
            in_fence = not in_fence
        if not in_fence and line.startswith("## "):
            sections.append("")
        sections[-1] += line
    return sections


def entry_date(section):
    """Return the entry's date, or None if the section is not a dated entry."""
    m = ENTRY_HEADING.match(section)
    if not m:
        return None
    try:
        return datetime.date.fromisoformat(m.group(1))
    except ValueError:
        return None


def count_entries(text):
    return sum(1 for s in split_sections(text)[1:] if entry_date(s))


def with_blank_line(section):
    """Make sure a section ends in a blank line so joined sections stay apart."""
    return section.rstrip("\n") + "\n\n"


def choose_moves(sections, today):
    """Return the set of section indexes that should move to the archive."""
    entries = [(i, entry_date(s)) for i, s in enumerate(sections) if i > 0 and entry_date(s)]

    # Floor: newest 3 by date. On a tie, the one higher in the file is newer
    # (progress.md is newest on top).
    by_newest = sorted(entries, key=lambda e: (-e[1].toordinal(), e[0]))
    floor = {i for i, _ in by_newest[:FLOOR_ENTRIES]}

    cutoff = today - datetime.timedelta(days=WINDOW_DAYS)
    moves = {i for i, d in entries if d < cutoff and i not in floor}

    # Backstop: still too long, so move the oldest remaining entries.
    def line_count():
        return sum(s.count("\n") for i, s in enumerate(sections) if i not in moves)

    for i, _ in reversed(by_newest):
        if line_count() <= BACKSTOP_LINES:
            break
        if i not in floor and i not in moves:
            moves.add(i)
    return moves


def build_archive(existing_text, month, new_entries):
    """Merge moved entries into one month's archive, newest on top."""
    if existing_text:
        parts = split_sections(existing_text)
        header, old_entries = parts[0], parts[1:]
    else:
        header, old_entries = "# Progress Archive -- %s\n\n---\n\n" % month, []
    # Moved entries go ahead of existing ones on the same date; the sort is
    # stable, so file order is kept otherwise.
    merged = sorted(new_entries + old_entries, key=lambda s: -(entry_date(s) or datetime.date.min).toordinal())
    return header + "".join(with_blank_line(s) for s in merged)


def find_progress(root):
    for name in ("progress.md", "PROGRESS.md"):
        path = os.path.join(root, name)
        if os.path.isfile(path):
            return path
    return None


def write_atomic(path, text):
    tmp = path + ".rotate-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser(description="Keep progress.md to a 14-day window.")
    ap.add_argument("root")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--today", type=datetime.date.fromisoformat, default=datetime.date.today())
    args = ap.parse_args()

    progress_path = find_progress(args.root)
    if not progress_path:
        print("rotate-progress: no progress.md in %s, nothing to do" % args.root)
        return 0

    with open(progress_path, encoding="utf-8") as f:
        original = f.read()
    sections = split_sections(original)
    moves = choose_moves(sections, args.today)

    if not moves:
        print("rotate-progress: nothing to move (%d entries, %d lines)"
              % (count_entries(original), original.count("\n")))
        return 0

    # Group moved entries by month, keeping their file order.
    archive_dir = os.path.join(args.root, "docs", "archive")
    by_month = {}
    for i in sorted(moves):
        by_month.setdefault(entry_date(sections[i]).strftime("%Y-%m"), []).append(sections[i])

    for month, entries in sorted(by_month.items(), reverse=True):
        for s in entries:
            print("move  %s -> docs/archive/progress-%s.md" % (s.splitlines()[0][3:][:70], month))

    if args.check:
        print("rotate-progress: %d entries are outside the window" % len(moves))
        return 1
    if args.dry_run:
        return 0

    # Build every new file in memory before writing anything.
    kept = [s for i, s in enumerate(sections) if i not in moves]
    new_progress = kept[0] + "".join(with_blank_line(s) for s in kept[1:])
    new_progress = new_progress.rstrip("\n") + "\n"

    old_archives, new_archives = {}, {}
    for month, entries in by_month.items():
        path = os.path.join(archive_dir, "progress-%s.md" % month)
        old = ""
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                old = f.read()
        old_archives[path] = old
        new_archives[path] = build_archive(old, month, entries)

    # Test hook: lets the verification prove the safety check can fail.
    # It drops the last character of the first moved entry in its archive.
    if os.environ.get("ROTATE_PROGRESS_TEST_CORRUPT"):
        month, entries = next(iter(by_month.items()))
        path = os.path.join(archive_dir, "progress-%s.md" % month)
        entry = entries[0].rstrip("\n")
        new_archives[path] = new_archives[path].replace(entry, entry[:-1], 1)

    # Safety check 1: entry count before equals entry count after.
    before = count_entries(original) + sum(count_entries(t) for t in old_archives.values())
    after = count_entries(new_progress) + sum(count_entries(t) for t in new_archives.values())
    problems = []
    if before != after:
        problems.append("entry count changed: %d before, %d after" % (before, after))

    # Safety check 2: every moved entry appears unchanged in its archive,
    # and every kept section appears unchanged in progress.md.
    for month, entries in by_month.items():
        archive_text = new_archives[os.path.join(archive_dir, "progress-%s.md" % month)]
        for s in entries:
            if s.rstrip("\n") not in archive_text:
                problems.append("moved entry not found verbatim: %s" % s.splitlines()[0])
    for s in kept[1:]:
        if s.rstrip("\n") not in new_progress:
            problems.append("kept section changed: %s" % s.splitlines()[0])

    if problems:
        for p in problems:
            print("rotate-progress: SAFETY CHECK FAILED -- " + p, file=sys.stderr)
        print("rotate-progress: nothing was written", file=sys.stderr)
        return 1

    # Archives first, then progress.md: if anything stops halfway, the worst
    # case is an entry in both places, never an entry in neither.
    os.makedirs(archive_dir, exist_ok=True)
    for path, text in new_archives.items():
        write_atomic(path, text)
    write_atomic(progress_path, new_progress)
    print("rotate-progress: moved %d entries; progress.md now %d lines"
          % (len(moves), new_progress.count("\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
