"""Key magenta HUD gens and force overlay centers transparent."""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path.home() / ".cursor" / "projects" / "d-idea-project-liudian-xiaban" / "assets"
OUT = ROOT / "assets" / "game" / "ui"

PIPS = [
    "cell_task_on.png",
    "cell_task_off.png",
    "cell_energy_on.png",
    "cell_energy_off.png",
    "cell_perf_on.png",
    "cell_perf_off.png",
    "icon_task.png",
    "icon_energy.png",
    "icon_perf.png",
    "mark_dizzy.png",
]
OVERLAYS = ["overlay_review.png", "overlay_drag.png", "overlay_meeting.png"]


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


def punch_pip(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGB")
    rec, alpha = key_magenta(np.array(im))
    vis = alpha > 0.12
    if vis.mean() < 0.02:
        print("empty", src.name)
        return
    rgba = np.zeros((rec.shape[0], rec.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(rec, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(dest, optimize=True)
    print("pip", dest.name, "vis", int(vis.sum()))


def punch_overlay(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGB")
    rec, alpha = key_magenta(np.array(im))
    h, w = alpha.shape
    ys = (np.arange(h)[:, None] + 0.5) / h
    xs = (np.arange(w)[None, :] + 0.5) / w
    dx = (xs - 0.5) * 2.0
    dy = (ys - 0.5) * 2.0
    d = np.sqrt((dx * 1.05) ** 2 + (dy * 0.92) ** 2)
    # Keep corners/edges, punch the playable center.
    frame = np.clip((d - 0.58) / 0.38, 0.0, 1.0)
    frame = frame * frame * (3.0 - 2.0 * frame)
    chroma = rec.max(axis=2) - rec.min(axis=2)
    detail = np.clip((chroma - 18.0) / 80.0, 0.0, 1.0)
    luma = rec.mean(axis=2)
    dark = np.clip((70.0 - luma) / 70.0, 0.0, 1.0)
    keep = np.maximum(alpha, np.maximum(detail, dark * 0.55))
    a = np.clip(keep * frame, 0.0, 1.0)
    a = np.where(d < 0.42, 0.0, a)
    rec[a < 0.04] = 0
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[:, :, :3] = np.clip(rec, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(a * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(dest, optimize=True)
    print("overlay", dest.name, "meanA", round(float(a.mean()), 3))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in PIPS:
        src = SRC / name
        if not src.exists():
            print("missing", src)
            continue
        punch_pip(src, OUT / name)
    for name in OVERLAYS:
        src = SRC / name
        if not src.exists():
            print("missing", src)
            continue
        punch_overlay(src, OUT / name)


if __name__ == "__main__":
    main()
