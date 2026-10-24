---
name: features-list
description: >
  A machine-readable feature contract for each project. The harness writes
  state; the agent never self-asserts that work is "done." Use when adding
  a new feature, when asking "is X shipped?", or when verifying the slice
  contract before sign-off.
---

# features-list

A `features.json` at each project root captures what the project promises
to do. The runner (`<skill-dir>/scripts/run-features.sh`) is the only
process that flips state to `passing` or `blocked`. The agent never
self-asserts.

This skill exists because "shipped" used to be a verbal claim. Three
sessions of seka.works in May 2026 declared work done and were
retrospectively reset. The features.json + runner pattern removes the
agent's ability to lie -- accidentally or otherwise -- about completion.

## When to use it

- Adding a new feature to a project: append an entry with state
  `not_started`.
- Starting work: flip the state to `active` so the next session can see
  what is open.
- Verifying completion: run the runner. Wait for it to return zero. Only
  then is the feature passing.
- Asking "is X shipped?": read `features.json`. Do not ask the agent for
  a verbal confirmation -- the file is the answer.

## File shape

The schema lives at `<skill-dir>/schemas/features.json.schema.json`.
Minimal example:

```json
{
  "version": "1",
  "project": "seka.works",
  "features": [
    {
      "id": "l0-scene-lock-targets",
      "behavior": "Scene-lock spec exists at docs/superpowers/specs/2026-05-21-scene-lock-targets.md and references tomato_dense as the reference geometry.",
      "verification": "test -f docs/superpowers/specs/2026-05-21-scene-lock-targets.md && grep -q 'tomato_dense' docs/superpowers/specs/2026-05-21-scene-lock-targets.md",
      "state": "active",
      "evidence": null,
      "last_run": null,
      "tags": ["docs"]
    }
  ]
}
```

## State machine

- `not_started`: feature defined, no work begun. Agent writes this.
- `active`: work in progress. Agent writes this.
- `blocked`: most recent runner pass returned non-zero. Runner writes this.
- `passing`: most recent runner pass returned zero. Runner writes this.
- `retired`: feature decommissioned. Agent writes this. Kept in the file
  for history; the runner skips retired features unless `--all` is passed.

The agent may write `not_started`, `active`, or `retired`. The agent
must NEVER write `passing` or `blocked` directly. If you find yourself
about to edit those values by hand, stop and invoke the runner instead.

## How to add a feature

1. Open `features.json` at the project root. Create it from the minimal
   example above if the file does not exist.
2. Append a new entry. Give it a slug id, a one-sentence behavior, and a
   shell command that returns 0 when the behavior is true.
3. Set state to `not_started`.
4. Commit. Future Claude reads the file; the runner verifies it.

## How to run the runner

From the project root:

```bash
bash <skill-dir>/scripts/run-features.sh
```

Single feature:

```bash
bash <skill-dir>/scripts/run-features.sh --id l0-scene-lock-targets
```

The runner reads `features.json`, executes each non-retired feature's
verification command, and writes the result back. Exit code 0 means
every targeted feature passed.

## Writing a good verification command

- Must be deterministic. No "did the screenshot look right" without a
  diff tool returning an exit code.
- Must be runnable from the project root with no extra setup beyond
  what the project's normal build needs.
- Should be fast (target under 30s per feature). Long verifications
  reduce how often anyone runs the runner, which defeats the point.
- Visual features get a `render-vs-reference` verification (see the
  companion skill). The runner invokes that skill, the skill returns
  an exit code, the runner flips state.

## Pairs with

- `render-vs-reference` skill -- verification for visual features.
- `code-review-gate` skill -- complementary pre-commit gate, not a
  replacement.
- `done` skill -- on session close, check that newly active
  features were transitioned correctly.

## Anti-patterns to avoid

- Manually editing `state: "passing"` because "I know it works." That is
  the exact failure mode the file exists to prevent.
- Writing a verification command that exits 0 unconditionally just to
  unblock a session.
- Letting `features.json` accumulate stale `blocked` entries from old
  experiments. Either fix or retire them.

## Pilot

The first project to adopt this is `seka.works`. See its `features.json`
for the active slice's verification.
