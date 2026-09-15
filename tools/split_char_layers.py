"""Split magenta-key character gens into 1024 body + grayscale scarf layers.

  python tools/split_char_layers.py --pack kangaroo --src DIR [--ride]
  python tools/split_char_layers.py --pack horse --src DIR
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CANVAS = 1024
BOTTOM_PAD = 48
ANIMS = ("idle", "walk", "run", "work", "sleep", "toilet")


def _dilate(mask: np.ndarray, n: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(n):
        p = np.pad(out, 1)
        out = out | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def key_magenta(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    f = rgb.astype(np.float32)
    r, g, b = f[:, :, 0], f[:, :, 1], f[:, :, 2]
    mag = np.minimum(r, b) - g
    bg = mag > 70
    alpha = np.clip(1.0 - mag / 210.0, 0.0, 1.0)
    alpha = np.where(bg, 0.0, alpha)
    rec = np.clip(f - np.maximum(mag, 0.0)[:, :, None] * np.array([0.55, 0.0, 0.48], np.float32), 0, 255)
    rec[bg] = 0
    alpha = np.where(alpha < 0.12, 0.0, alpha)
    rec[alpha == 0] = 0
    return rec, alpha


def scarf_mask(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    core = (
        (alpha > 0.2)
        & (g > r + 22)
        & (b > r + 14)
        & (g > 70)
        & (b > 90)
        & (chroma > 28)
        & (r < 160)
    )
    return core | (_dilate(core, 2) & (alpha > 0.2) & (g > r + 8) & (b > r + 6) & (r < 170))


def fill_scarf_hole(rgb: np.ndarray, alpha: np.ndarray, scarf: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    body = (alpha > 0.2) & ~scarf
    if body.any():
        fill = np.median(rgb[body], axis=0)
    else:
        fill = np.array([80.0, 80.0, 86.0], np.float32)
    out[scarf] = fill
    return out


def aligned_layers(src: Image.Image) -> tuple[np.ndarray, np.ndarray, dict]:
    rec, alpha = key_magenta(np.array(src.convert("RGB")))
    scarf = scarf_mask(rec, alpha)
    body_rgb = fill_scarf_hole(rec, alpha, scarf)
    h, w = alpha.shape
    body = np.zeros((h, w, 4), np.float32)
    scarf_l = np.zeros((h, w, 4), np.float32)
    body[:, :, :3] = body_rgb
    body[:, :, 3] = alpha * 255.0
    body[scarf, 3] = alpha[scarf] * 255.0
    if scarf.any():
        lum = np.clip(rec[:, :, 1] * 0.45 + rec[:, :, 2] * 0.45 + rec[:, :, 0] * 0.1, 0, 255)
        gray = np.clip(lum / 0.82, 0, 255)
        scarf_l[scarf, 0] = gray[scarf]
        scarf_l[scarf, 1] = gray[scarf]
        scarf_l[scarf, 2] = gray[scarf]
        scarf_l[scarf, 3] = alpha[scarf] * 255.0
    empty = body[:, :, 3] < 8
    edge = _dilate(empty, 1) & (body[:, :, 3] > 0)
    pink = edge & (body[:, :, 0] > body[:, :, 1] + 18) & (body[:, :, 2] > body[:, :, 1] + 12)
    body[pink, 3] = 0
    scarf_l[pink, 3] = 0
    vis = (body[:, :, 3] > 8) | (scarf_l[:, :, 3] > 8)
    canvas_b = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    canvas_s = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    if not vis.any():
        return canvas_b, canvas_s, {"scarf_px": 0, "vis": 0}
    ys, xs = np.nonzero(vis)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    crop_b = np.clip(body[y0:y1, x0:x1], 0, 255).astype(np.uint8)
    crop_s = np.clip(scarf_l[y0:y1, x0:x1], 0, 255).astype(np.uint8)
    ch, cw = crop_b.shape[:2]
    scale = min((CANVAS - 80) / max(ch, 1), (CANVAS - 80) / max(cw, 1), 1.0)
    if scale < 0.999:
        nh, nw = max(1, int(ch * scale)), max(1, int(cw * scale))
        crop_b = np.array(Image.fromarray(crop_b, "RGBA").resize((nw, nh), Image.Resampling.NEAREST))
        crop_s = np.array(Image.fromarray(crop_s, "RGBA").resize((nw, nh), Image.Resampling.NEAREST))
        ch, cw = crop_b.shape[:2]
    x = (CANVAS - cw) // 2
    y = CANVAS - BOTTOM_PAD - ch
    y = max(16, min(y, CANVAS - ch - 8))
    canvas_b[y : y + ch, x : x + cw] = crop_b
    canvas_s[y : y + ch, x : x + cw] = crop_s
    canvas_b[canvas_b[:, :, 3] == 0, :3] = 0
    canvas_s[canvas_s[:, :, 3] == 0, :3] = 0
    return canvas_b, canvas_s, {"scarf_px": int(scarf.sum()), "vis": int(vis.sum())}


def poses_for(ride: bool) -> list[str]:
    anims = ANIMS + (("ride",) if ride else ())
    return [f"{anim}_{i}" for anim in anims for i in range(4)]


def find_src(src_dir: Path, pack: str, pose: str) -> Path | None:
    for name in (f"{pack}_{pose}.png", f"{pose}.png"):
        p = src_dir / name
        if p.exists():
            return p
    return None


def archive_old(pack: str, poses: list[str]) -> None:
    body_out = ROOT / "assets" / "game" / "chars" / pack
    old_out = ROOT / "assets" / "废弃素材" / "chars" / f"{pack}_pre_layers"
    marker = old_out / "idle_0.png"
    if marker.exists() or not (body_out / "idle_0.png").exists():
        return
    old_out.mkdir(parents=True, exist_ok=True)
    for pose in poses:
        src = body_out / f"{pose}.png"
        if src.exists():
            shutil.copy2(src, old_out / f"{pose}.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True, help="horse / kangaroo / rabbit ...")
    ap.add_argument("--src", required=True, type=Path, help="folder of magenta gens")
    ap.add_argument("--ride", action="store_true", help="also split ride_0..3")
    args = ap.parse_args()
    pack = args.pack.strip().lower()
    src_dir = args.src.expanduser().resolve()
    poses = poses_for(args.ride)
    body_out = ROOT / "assets" / "game" / "chars" / pack
    scarf_out = body_out / "scarf"
    archive_old(pack, poses)
    body_out.mkdir(parents=True, exist_ok=True)
    scarf_out.mkdir(parents=True, exist_ok=True)
    missing = 0
    for pose in poses:
        src = find_src(src_dir, pack, pose)
        if src is None:
            print("missing", f"{pack}_{pose}.png")
            missing += 1
            continue
        body, scarf, info = aligned_layers(Image.open(src))
        Image.fromarray(body, "RGBA").save(body_out / f"{pose}.png", optimize=True)
        Image.fromarray(scarf, "RGBA").save(scarf_out / f"{pose}.png", optimize=True)
        print(pose, "scarf", info["scarf_px"], "vis", info["vis"])
    print("done", body_out, "missing", missing)


if __name__ == "__main__":
    main()
