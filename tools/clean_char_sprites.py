"""Clean leftover matte, chroma fringe, ground shadows and studio desks on character sprites."""
from __future__ import annotations

from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(r"d:\idea_project\liudian-xiaban")
CHARS = ROOT / "assets" / "game" / "chars"
TEST_OUT = ROOT / "preview" / "_char_clean"


def _dilate(mask: np.ndarray, n: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(n):
        p = np.pad(out, 1)
        out = out | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def flood_mask(walk: np.ndarray, seeds: np.ndarray, step: int = 1, limit: int = 80) -> np.ndarray:
    hit = (seeds & walk).copy()
    if not hit.any():
        return hit
    for _ in range(limit):
        nxt = walk & _dilate(hit, step)
        if not (nxt & ~hit).any():
            return nxt
        hit = nxt
    return hit


def channels(arr: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rgb = arr[:, :, :3].astype(np.int16)
    a = arr[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    mean = rgb.mean(axis=2)
    return r, g, b, a, chroma, mean, rgb


def studio_white(r, g, b, chroma, mean, mn) -> np.ndarray:
    warm = (r.astype(np.int16) - b.astype(np.int16)) > 10
    return (mn >= 208) & (chroma <= 14) & ~warm


def outer_empty_mask(a: np.ndarray) -> np.ndarray:
    empty = a < 8
    h, w = empty.shape
    border = np.zeros_like(empty)
    border[0] = True
    border[-1] = True
    border[:, 0] = True
    border[:, -1] = True
    return flood_mask(empty, empty & border, step=4, limit=60)


def clean_array(arr: np.ndarray) -> np.ndarray:
    arr = arr.copy()
    r, g, b, a, chroma, mean, rgb = channels(arr)
    mn = rgb.min(axis=2)
    outer = outer_empty_mask(a)

    green_screen = (g >= 55) & (g > r + 10) & (g > b + 4) & ((g - r) + (g - b) > 24)
    blue_shadow = (b >= 128) & (b > r + 16) & (g > r + 6) & (mean >= 108) & (mean <= 220) & (chroma <= 90) & (a < 220)
    white = studio_white(r, g, b, chroma, mean, mn) & (a > 8)
    knockable = (white | green_screen | blue_shadow | ((a > 0) & (a < 26))) & ~outer
    eaten = flood_mask(knockable, knockable & _dilate(outer, 2))
    arr[eaten, 3] = 0
    arr[a < 26, 3] = 0

    a = arr[:, :, 3]
    outer = outer_empty_mask(a)
    r, g, b, a, chroma, mean, rgb = channels(arr)
    mn = rgb.min(axis=2)
    vis = a > 8
    white = studio_white(r, g, b, chroma, mean, mn) & vis
    blue_shadow = vis & (b >= 128) & (b > r + 16) & (g > r + 6) & (mean >= 108) & (mean <= 220) & (chroma <= 90)
    character = vis & ~white & ~blue_shadow
    if character.any():
        body_bottom = int(np.nonzero(character.any(axis=1))[0].max())
        h = a.shape[0]
        ys = np.arange(h)[:, None]
        floor = vis & (ys >= body_bottom - 22) & (white | blue_shadow | ((mn >= 198) & (chroma <= 16) & ((r - b) <= 10)))
        arr[floor, 3] = 0

    a = arr[:, :, 3].astype(np.float32) / 255.0
    rgb_f = arr[:, :, :3].astype(np.float32)
    keep = a > 0.05
    a_safe = np.maximum(a, 1e-4)
    recovered = np.clip((rgb_f - (1.0 - a[:, :, None]) * 255.0) / a_safe[:, :, None], 0, 255)
    mix = keep & (a < 0.97)
    rgb_f[mix] = recovered[mix]
    r2, g2, b2 = rgb_f[:, :, 0], rgb_f[:, :, 1], rgb_f[:, :, 2]
    spill = keep & (g2 > r2 + 8) & (g2 > b2 + 4)
    rgb_f[:, :, 1] = np.where(spill, np.minimum(g2, np.maximum(r2, b2) + 3), g2)

    arr[:, :, :3] = np.clip(np.rint(rgb_f), 0, 255).astype(np.uint8)
    arr[:, :, 3] = np.where(keep, np.clip(np.rint(a * 255.0), 0, 255), 0).astype(np.uint8)

    a = arr[:, :, 3]
    outer = outer_empty_mask(a)
    rgb = arr[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    near_outer = _dilate(outer, 2)
    gray_halo = (a > 0) & near_outer & (chroma <= 18) & (mean >= 16) & (mean <= 210)
    green_halo = (a > 0) & near_outer & (g > r + 6) & (g > b + 3)
    arr[gray_halo | green_halo | (a < 36), 3] = 0

    a = arr[:, :, 3]
    rgb = arr[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    h = a.shape[0]
    vis = a > 8
    above = np.zeros(vis.shape, dtype=np.int16)
    below = np.zeros(vis.shape, dtype=np.int16)
    for y in range(1, h):
        above[y] = np.where(vis[y] & vis[y - 1], above[y - 1] + 1, 0)
    for y in range(h - 2, -1, -1):
        below[y] = np.where(vis[y] & vis[y + 1], below[y + 1] + 1, 0)
    vspan = above + below + vis.astype(np.int16)
    thin_floor = vis & (vspan <= 20) & (np.arange(h)[:, None] > int(h * 0.68)) & (chroma <= 22) & (mean >= 32) & ((r - b) <= 14)
    shadow_oval = vis & (np.arange(h)[:, None] > int(h * 0.58)) & (b > r + 10) & (b > g) & (mean <= 190) & (chroma <= 110) & (a < 230)
    arr[thin_floor | shadow_oval, 3] = 0

    a = arr[:, :, 3]
    a = np.where(a >= 190, 255, a)
    a = np.where((a > 0) & (a < 64), 0, a)
    arr[:, :, 3] = a
    arr[arr[:, :, 3] == 0, :3] = 0
    return arr


def clean_image(im: Image.Image) -> Image.Image:
    return Image.fromarray(clean_array(np.array(im.convert("RGBA"))), "RGBA")


def main() -> None:
    apply = "--apply" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    files = [CHARS / n for n in names] if names else [
        p for p in sorted(CHARS.rglob("*.png")) if p.parent.name in {"cow", "horse", "pelican", "rabbit", "tiger"}
    ]
    dest_root = CHARS if apply else TEST_OUT
    n = 0
    for src in files:
        if not src.exists():
            print("missing", src)
            continue
        cleaned = clean_image(Image.open(src))
        dst = src if apply else dest_root / src.relative_to(CHARS)
        dst.parent.mkdir(parents=True, exist_ok=True)
        cleaned.save(dst, optimize=True)
        n += 1
        print(("apply" if apply else "test"), src.relative_to(CHARS).as_posix(), flush=True)
    print("done", n, "->", dest_root)


if __name__ == "__main__":
    main()
