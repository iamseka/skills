# skills

Agent skills I wrote for my own Claude Code setup, cleaned up so anyone can
use them. Each one exists because something broke without it.

More on each one, and the failure behind it: https://seka.works/skills/

## Install

```bash
npx skills add iamseka/skills
```

Or copy a folder from `skills/` into `~/.claude/skills/`.

## Skills

| Skill | What it does |
|---|---|
| `/done` | Ends a session: summarizes the work from git evidence, updates progress notes, commits and pushes |
| `/deslop` | Finds and removes AI writing patterns in prose, docs, comments and commit messages |
| `/tandem-agents` | Rules for several coding agents on one repo at once: a worktree per agent, absolute paths, verified handoffs |
| `/features-list` | A features.json contract where only a runner script can mark work passing, never the agent |
| `/render-vs-reference` | Screenshots a live page and diffs it against a design comp; returns an exit code |
| `/code-review-gate` | A git pre-commit hook that sorts staged changes by risk and blocks commits with critical review findings |
| `/garden-plugin-author` | Builds, tests and publishes plugins for the Digital Garden Eleventy template |

## Paths

Some skills call a bundled script. They write its path as `<skill-dir>/...`,
meaning the skill's own installed folder (Claude Code shows it when the skill
loads).

`render-vs-reference` needs Pillow and Playwright
(`pip install Pillow playwright && playwright install chromium`).

## License

MIT
