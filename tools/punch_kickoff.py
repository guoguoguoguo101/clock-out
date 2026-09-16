"""Key magenta kickoff gens and crop to the sprite."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from punch_ui_key import key_magenta

ROOT = Path(__file__).resolve().parents[1]
SRC = Path.home() / ".cursor" / "projects" / "d-idea-project-liudian-xiaban" / "assets"
OUT = ROOT / "assets" / "game" / "ui" / "kickoff"

FILES = {
    "kickoff_clock.png": "clock.png",
    "kickoff_title_10.png": "title_10.png",
    "kickoff_title_3.png": "title_3.png",
}


def crop_rgba(rgba: np.ndarray, pad: int = 10) -> np.ndarray:
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


def punch(src: Path, dest: Path, pad: int) -> None:
    im = Image.open(src).convert("RGB")
    rec, alpha = key_magenta(np.array(im))
    rgba = np.zeros((rec.shape[0], rec.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(rec, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    rgba = crop_rgba(rgba, pad)
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(dest, optimize=True)
    print(dest.name, rgba.shape[1], "x", rgba.shape[0], "meanA", round(float(rgba[:, :, 3].mean()) / 255.0, 3))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for src_name, dest_name in FILES.items():
        src = SRC / src_name
        if not src.exists():
            print("missing", src)
            continue
        pad = 6 if dest_name == "clock.png" else 12
        punch(src, OUT / dest_name, pad)


if __name__ == "__main__":
    main()
