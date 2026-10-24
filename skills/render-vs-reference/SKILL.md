---
name: render-vs-reference
description: >
  Compare a live rendered page against a reference design comp via Playwright
  + Pillow. Returns an exit code suitable for use as a features.json
  verification command. Use when closing a visual slice, gating sign-off on a
  design comp, or codifying the render-vs-reference checkpoint.
---

# render-vs-reference

This skill codifies a rule that was already in memory but never enforced:
when implementing from a design comp, end the session by capturing the
live render and comparing it against the comp. The May 14 seka.works
visual-layer reset is what happens when that step gets skipped.

The skill is two pieces:

1. A convention -- where reference images live, how slices reference them,
   what tolerance means.
2. A runnable script -- `<skill-dir>/scripts/render-vs-reference.py` --
   that captures, diffs, writes a side-by-side artifact, and returns an
   exit code.

The script is designed to be the verification command for any features.json
entry tagged `visual`.

## When to use it

- Closing any slice whose work touched the visual layer.
- Before declaring a feature with `tags: ["visual"]` as passing.
- When a comp has shifted and you want to see what changed in the render.
- During design review, to capture an evidence artifact you can drop into
  a /done summary.

## Convention: where reference images live

Each project keeps reference images at:

```
docs/references/<slice-or-feature-id>.png
```

Examples:

- `docs/references/l1-metacard.png`
- `docs/references/l2-metacard-content.png`
- `docs/references/canvas-home.png`

If the comp lives elsewhere already (claude_design/, Figma export,
prototype/), copy or symlink it into docs/references/ once so the
verification command has a stable path. The original can keep evolving
in its source location.

## How to invoke the script

```bash
python3 <skill-dir>/scripts/render-vs-reference.py \
  docs/references/l2-metacard-content.png \
  http://localhost:8080/east-africa-farm-vision/ \
  --selector ".metacard" \
  --viewport 1280x720 \
  --tolerance 5.0 \
  --out-dir docs/references/diffs
```

Arguments:

- `<reference>`: PNG to compare against. Required.
- `<url>`: URL to capture. Required. Can be `http://localhost:...` (start
  the dev server first) or `file:///...` for static HTML.
- `--selector`: optional CSS selector to crop the capture to. Without it,
  the full viewport is captured.
- `--viewport`: browser viewport. Default 1280x720.
- `--tolerance`: mean per-pixel RGB delta (0-255). Default 5.0 is roughly
  "no visible difference unless you look closely." Tighter slices may use
  2.0; first-look polish may stay at 5.0.
- `--out-dir`: where the diff PNG lands. Default `docs/references/diffs/`.

Exit codes:

- 0: render matches reference within tolerance.
- 1: mismatch beyond tolerance. The diff PNG shows where.
- 2: setup error (missing reference, browser launch failed, etc.).

## How to use it from features.json

Add a verification field that calls the script. The runner invokes it
verbatim, captures the output, and flips state based on exit code:

```json
{
  "id": "l1-metacard-framing",
  "behavior": "Metacard framing matches the L1 reference at 1280x720 with the .metacard selector.",
  "verification": "python3 <skill-dir>/scripts/render-vs-reference.py docs/references/l1-metacard.png http://localhost:8080/east-africa-farm-vision/ --selector .metacard --viewport 1280x720 --tolerance 5.0",
  "state": "active",
  "tags": ["visual", "l1"]
}
```

A few notes:

- The runner runs the verification from the project root, so relative
  paths to references resolve correctly.
- The dev server must be running before `run-features.sh` invokes the
  verification. Either start it manually first, or wrap the command in
  a shell line that starts and stops the server (`npm run start &`, etc).
- A single feature can run at multiple viewports by chaining commands
  with `&&`. The runner will mark the whole feature blocked if any
  viewport fails.

## Tolerance: what to pick

- `2.0` -- tight. Use after the design is locked and you are confirming
  no regression. A 2.0 fail is genuinely a visible delta or a stale
  reference image.
- `5.0` -- normal. The default. Catches structural drift while ignoring
  anti-aliasing and font hinting noise.
- `10.0` -- loose. Use during early framing slices where you want the
  signal but expect minor pixel-level wobble.
- Anything above 15 means you are probably not gating anything; revisit.

If a slice has known platform-specific noise (font rendering on Linux
vs macOS, headless vs headed Chromium), raise the tolerance with a
written justification in the slice's spec rather than silently widening.

## What this skill deliberately does NOT do

- It does not generate the reference image. Comps come from the design
  process; this skill only verifies against them.
- It does not auto-update the reference if the new render "looks better."
  That decision is human + design review + spec edit.
- It does not replace gstack-design-review. Design review judges taste
  (spacing, hierarchy, AI slop). render-vs-reference judges fidelity.
  Use both.

## Pairs with

- `features-list` skill -- this is the verification implementation for
  any feature tagged `visual`.
- `gstack-design-review` -- live taste-level critique. Different layer.
- `done` -- on session close, the runner's last verdict should
  already be the file's truth.

## Pilot

The first project to wire this in is `seka.works`. As L1, L2, and L3
slices come into focus, each gets a reference under
`seka.works/docs/references/` and a corresponding features.json entry.
