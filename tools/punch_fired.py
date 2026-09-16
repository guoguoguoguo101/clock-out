"""Key magenta fired-stamp gens and crop into assets/game/ui/fired/."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from punch_ui_key import key_magenta

ROOT = Path(__file__).resolve().parents[1]
SRC_CANDIDATES = [
    Path.home() / ".cursor" / "projects" / "d-idea-project-liudian-xiaban" / "assets",
    ROOT / "assets",
]
OUT = ROOT / "assets" / "game" / "ui" / "fired"

FILES = {
    "fired_stamp.png": ("stamp.png", 8),
    "fired_imprint.png": ("imprint.png", 4),
    "fired_notice.png": ("notice.png", 8),
    "fired_shard.png": ("shard.png", 4),
    "fired_bang.png": ("bang.png", 6),
    "fired_debris.png": ("debris.png", 6),
    "fired_shadow.png": ("shadow.png", 8),
    "fired_next.png": ("next.png", 4),
    "fired_react.png": ("react.png", 8),
}


def find_src(name: str) -> Path | None:
    for folder in SRC_CANDIDATES:
        path = folder / name
        if path.exists():
            return path
    return None


def crop_rgba(rgba: np.ndarray, pad: int) -> np.ndarray:
    a = rgba[:, :, 3]
    vis = np.argwhere(a > 18)
    if vis.size == 0:
        return rgba
    y0, x0 = vis.min(axis=0)
    y1, x1 = vis.max(axis=0) + 1
    y0 = max(0, y0 - pad)
    x0 = max(0, x0 - pad)
    y1 = min(rgba.shape[0], y1 + pad)
    x1 = min(rgba.shape[1], x1 + pad)
    return rgba[y0:y1, x0:x1]


def key_notice(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    rec, alpha = key_magenta(rgb)
    f = rgb.astype(np.float32)
    r, g, b = f[:, :, 0], f[:, :, 1], f[:, :, 2]
    luma = f.mean(axis=2)
    chroma = rec.max(axis=2) - rec.min(axis=2)
    corners = np.stack([f[0, 0], f[0, -1], f[-1, 0], f[-1, -1]], axis=0)
    bg_col = np.median(corners, axis=0)
    dist = np.linalg.norm(f - bg_col, axis=2)
    pink = (r > 150.0) & (g < 110.0) & (b > 70.0) & ((r - g) > 55.0)
    cream = (luma > 165.0) & ((r - b) < 48.0) & (chroma < 70.0)
    header = (r > 140.0) & (g < 90.0) & (b < 90.0) & (luma < 170.0)
    clip = (chroma < 28.0) & (luma > 70.0) & (luma < 190.0) & (dist > 40.0)
    keep = cream | header | clip
    bg = (pink | (dist < 62.0)) & ~keep
    alpha = np.where(bg, 0.0, np.clip(np.maximum(alpha, (~bg).astype(np.float32)), 0.0, 1.0))
    rec = rec.copy()
    rec[bg] = 0
    alpha = np.where(alpha < 0.08, 0.0, alpha)
    rec[alpha == 0] = 0
    return rec, alpha


def punch(src: Path, dest: Path, pad: int, notice: bool = False) -> None:
    im = Image.open(src).convert("RGB")
    rgb = np.array(im)
    rec, alpha = key_notice(rgb) if notice else key_magenta(rgb)
    rgba = np.zeros((rec.shape[0], rec.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(rec, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    rgba = crop_rgba(rgba, pad)
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(dest, optimize=True)
    print(
        dest.name,
        rgba.shape[1],
        "x",
        rgba.shape[0],
        "meanA",
        round(float(rgba[:, :, 3].mean()) / 255.0, 3),
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for src_name, (dest_name, pad) in FILES.items():
        src = find_src(src_name)
        if src is None:
            print("missing", src_name)
            continue
        punch(src, OUT / dest_name, pad, notice=dest_name == "notice.png")


if __name__ == "__main__":
    main()
