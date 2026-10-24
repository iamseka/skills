#!/usr/bin/env python3
"""
render-vs-reference

Capture a rendered URL, compare against a reference image, write a
side-by-side diff PNG, and return an exit code suitable for use as a
features.json verification command.

Usage:
    render-vs-reference.py <reference.png> <url> [options]

Options:
    --tolerance FLOAT   Max allowed mean per-pixel RGB delta (0-255).
                        Default 5.0 (about 2% perceived difference).
    --viewport WxH      Browser viewport in pixels. Default 1280x720.
    --selector CSS      Optional CSS selector to crop to. If omitted,
                        the full viewport is used.
    --out-dir PATH      Where to write the diff image. Default
                        ./docs/references/diffs.
    --label NAME        Label used in the diff filename. Default is
                        derived from the reference filename.

Exit codes:
    0  reference and render match within tolerance
    1  mismatch beyond tolerance
    2  setup error (missing files, browser launch failure)
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:
    print("PIL (Pillow) is required: pip install Pillow", file=sys.stderr)
    sys.exit(2)

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("playwright is required: pip install playwright && playwright install chromium",
          file=sys.stderr)
    sys.exit(2)


def parse_viewport(s: str) -> tuple[int, int]:
    try:
        w, h = s.lower().split("x")
        return int(w), int(h)
    except Exception:
        raise argparse.ArgumentTypeError(
            f"Viewport must be WxH, got {s!r}")


def capture(url: str, viewport: tuple[int, int], selector: str | None,
            out_path: Path) -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch()
        try:
            ctx = browser.new_context(
                viewport={"width": viewport[0], "height": viewport[1]})
            page = ctx.new_page()
            page.goto(url, wait_until="networkidle", timeout=30000)
            if selector:
                el = page.locator(selector)
                el.screenshot(path=str(out_path))
            else:
                page.screenshot(path=str(out_path), full_page=False)
        finally:
            browser.close()


def mean_pixel_delta(ref: Image.Image, render: Image.Image) -> float:
    # Align sizes by resizing render to ref dimensions.
    if render.size != ref.size:
        render = render.resize(ref.size)
    if ref.mode != render.mode:
        render = render.convert(ref.mode)

    diff = ImageChops.difference(ref.convert("RGB"), render.convert("RGB"))
    hist = diff.histogram()
    # 3 channels of 256 buckets each. Sum index * count, divide by total
    # pixel count * 3 channels.
    total_pixels = ref.size[0] * ref.size[1]
    total_delta = 0
    for channel in range(3):
        chan_hist = hist[channel * 256:(channel + 1) * 256]
        total_delta += sum(i * c for i, c in enumerate(chan_hist))
    return total_delta / (total_pixels * 3.0)


def build_side_by_side(ref: Image.Image, render: Image.Image,
                       diff_path: Path) -> None:
    if render.size != ref.size:
        render = render.resize(ref.size)
    diff = ImageChops.difference(ref.convert("RGB"), render.convert("RGB"))

    w, h = ref.size
    canvas = Image.new("RGB", (w * 3 + 20, h), (32, 32, 32))
    canvas.paste(ref.convert("RGB"), (0, 0))
    canvas.paste(render.convert("RGB"), (w + 10, 0))
    canvas.paste(diff, (w * 2 + 20, 0))
    canvas.save(diff_path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("url")
    parser.add_argument("--tolerance", type=float, default=5.0,
                        help="Max mean per-pixel RGB delta (0-255). Default 5.0.")
    parser.add_argument("--viewport", type=parse_viewport, default=(1280, 720))
    parser.add_argument("--selector", default=None)
    parser.add_argument("--out-dir", type=Path,
                        default=Path("docs/references/diffs"))
    parser.add_argument("--label", default=None)
    args = parser.parse_args()

    if not args.reference.exists():
        print(f"reference not found: {args.reference}", file=sys.stderr)
        return 2

    args.out_dir.mkdir(parents=True, exist_ok=True)
    label = args.label or args.reference.stem
    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    render_path = args.out_dir / f"{label}-render-{timestamp}.png"
    diff_path = args.out_dir / f"{label}-diff-{timestamp}.png"

    try:
        capture(args.url, args.viewport, args.selector, render_path)
    except Exception as e:
        print(f"capture failed: {e}", file=sys.stderr)
        return 2

    try:
        ref = Image.open(args.reference)
        render = Image.open(render_path)
    except Exception as e:
        print(f"image open failed: {e}", file=sys.stderr)
        return 2

    delta = mean_pixel_delta(ref, render)
    build_side_by_side(ref, render, diff_path)

    verdict = "pass" if delta <= args.tolerance else "fail"
    print(f"[render-vs-reference] {label}: delta={delta:.2f} "
          f"tolerance={args.tolerance} -> {verdict}")
    print(f"[render-vs-reference] render: {render_path}")
    print(f"[render-vs-reference] diff:   {diff_path}")

    return 0 if verdict == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
