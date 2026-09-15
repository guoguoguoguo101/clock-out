"""Chroma-key magenta horse gens, split cyan scarf, write 1024 body + scarf PNGs."""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(r"d:\idea_project\liudian-xiaban")
SRC = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")
BODY_OUT = ROOT / "assets" / "game" / "chars" / "horse"
SCARF_OUT = BODY_OUT / "scarf"
OLD_OUT = ROOT / "assets" / "废弃素材" / "chars" / "horse_baked_scarf"
CANVAS = 1024
BOTTOM_PAD = 48
POSES = [f"{anim}_{i}" for anim in ("idle", "walk", "run", "work", "sleep", "toilet") for i in range(4)]


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
    return core | (_dilate(core, 2) & (alpha > 0.2) & (g > r + 8) & (b > r + 6))


def fill_scarf_hole(rgb: np.ndarray, alpha: np.ndarray, scarf: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    body = (alpha > 0.2) & ~scarf
    dark = body & (rgb.mean(axis=2) < 130) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 48)
    if dark.any():
        fill = np.median(rgb[dark], axis=0)
    else:
        fill = np.array([66.0, 66.0, 74.0], np.float32)
    out[scarf] = fill
    return out


def to_white_scarf(rgb: np.ndarray, alpha: np.ndarray, scarf: np.ndarray) -> np.ndarray:
    layer = np.zeros((rgb.shape[0], rgb.shape[1], 4), np.uint8)
    if not scarf.any():
        return layer
    lum = np.clip(rgb[:, :, 1] * 0.45 + rgb[:, :, 2] * 0.45 + rgb[:, :, 0] * 0.1, 0, 255)
    gray = np.clip(lum / 0.82, 0, 255)
    layer[scarf, 0] = gray[scarf].astype(np.uint8)
    layer[scarf, 1] = gray[scarf].astype(np.uint8)
    layer[scarf, 2] = gray[scarf].astype(np.uint8)
    layer[scarf, 3] = np.clip(alpha[scarf] * 255.0, 0, 255).astype(np.uint8)
    return layer


def place_1024(rgba: np.ndarray) -> np.ndarray:
    a = rgba[:, :, 3]
    vis = a > 8
    canvas = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    if not vis.any():
        return canvas
    ys, xs = np.nonzero(vis)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    crop = rgba[y0:y1, x0:x1]
    ch, cw = crop.shape[:2]
    scale = min((CANVAS - 80) / max(ch, 1), (CANVAS - 80) / max(cw, 1), 1.0)
    if scale < 0.999:
        nh, nw = max(1, int(ch * scale)), max(1, int(cw * scale))
        crop = np.array(Image.fromarray(crop, "RGBA").resize((nw, nh), Image.Resampling.NEAREST))
        ch, cw = crop.shape[:2]
    x = (CANVAS - cw) // 2
    y = CANVAS - BOTTOM_PAD - ch
    y = max(16, min(y, CANVAS - ch - 8))
    canvas[y : y + ch, x : x + cw] = crop
    return canvas


def process(src: Path) -> tuple[Image.Image, Image.Image, dict]:
    rgb8 = np.array(src.convert("RGB"))
    rec, alpha = key_magenta(rgb8)
    scarf = scarf_mask(rec, alpha)
    body_rgb = fill_scarf_hole(rec, alpha, scarf)
    body = np.dstack([np.clip(body_rgb, 0, 255).astype(np.uint8), np.clip(alpha * 255.0, 0, 255).astype(np.uint8)])
    body[scarf, 3] = np.clip(alpha[scarf] * 255.0, 0, 255).astype(np.uint8)
    # keep body alpha in scarf region so the neck stays opaque
    scarf_rgba = to_white_scarf(rec, alpha, scarf)
    empty = body[:, :, 3] < 8
    edge = _dilate(empty, 1) & (body[:, :, 3] > 0)
    mean = body[:, :, :3].astype(np.int16).mean(axis=2)
    chroma = body[:, :, :3].max(axis=2).astype(np.int16) - body[:, :, :3].min(axis=2).astype(np.int16)
    pink = edge & (body[:, :, 0] > body[:, :, 1] + 18) & (body[:, :, 2] > body[:, :, 1] + 12)
    gray_halo = edge & (chroma <= 14) & (mean >= 90)
    body[pink | gray_halo, 3] = 0
    body[body[:, :, 3] == 0, :3] = 0
    scarf_rgba[pink | gray_halo, 3] = 0
    body = place_1024(body)
    # place scarf with the SAME crop/scale as body by compositing from already-aligned pair
    # Re-place scarf using body used-rect mapping: process scarf on original then map identically.
    return Image.fromarray(body, "RGBA"), None, {"scarf_px": int(scarf.sum()), "vis": int((alpha > 0.2).sum())}


def aligned_layers(src: Image.Image) -> tuple[np.ndarray, np.ndarray, dict]:
    rgb8 = np.array(src.convert("RGB"))
    rec, alpha = key_magenta(rgb8)
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


def archive_old() -> None:
    OLD_OUT.mkdir(parents=True, exist_ok=True)
    marker = OLD_OUT / "idle_0.png"
    if marker.exists():
        return
    for pose in POSES:
        src = BODY_OUT / f"{pose}.png"
        if src.exists():
            shutil.copy2(src, OLD_OUT / f"{pose}.png")


def main() -> None:
    archive_old()
    BODY_OUT.mkdir(parents=True, exist_ok=True)
    SCARF_OUT.mkdir(parents=True, exist_ok=True)
    for pose in POSES:
        src = SRC / f"horse_{pose}.png"
        if not src.exists():
            print("missing", src.name)
            continue
        body, scarf, info = aligned_layers(Image.open(src))
        Image.fromarray(body, "RGBA").save(BODY_OUT / f"{pose}.png", optimize=True)
        Image.fromarray(scarf, "RGBA").save(SCARF_OUT / f"{pose}.png", optimize=True)
        print(pose, "scarf", info["scarf_px"], "vis", info["vis"])
    print("done", BODY_OUT)


if __name__ == "__main__":
    main()
