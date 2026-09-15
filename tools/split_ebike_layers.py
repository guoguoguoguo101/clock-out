"""Split the side-view e-bike into back (seat/frame) and front (bars/fork) layers."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "game" / "props" / "ebike.png"
OUT_BACK = ROOT / "assets" / "game" / "props" / "ebike_back.png"
OUT_FRONT = ROOT / "assets" / "game" / "props" / "ebike_front.png"
PREVIEW = ROOT / "preview" / "_ride_diag" / "ebike_layers.png"


def _dilate(mask: np.ndarray, n: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(n):
        p = np.pad(out, 1)
        out = out | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def split() -> None:
    arr = np.array(Image.open(SRC).convert("RGBA"))
    h, w = arr.shape[:2]
    ys, xs = np.ogrid[:h, :w]
    opaque = arr[:, :, 3] > 20
    # Handlebars / stem / headlight live upper-right; front wheel is the right tire.
    front = opaque & (
        ((xs > 530) & (ys < 430))
        | ((xs > 680) & (ys >= 360))
        | ((xs > 760) & (ys >= 250))
    )
    front = _dilate(front, 2) & opaque
    back = opaque & ~front

    back_img = arr.copy()
    back_img[~back] = 0
    front_img = arr.copy()
    front_img[~front] = 0
    Image.fromarray(back_img).save(OUT_BACK)
    Image.fromarray(front_img).save(OUT_FRONT)

    prev = np.zeros((h, w, 4), dtype=np.uint8)
    prev[back] = back_img[back]
    # Tint front cyan so the split is obvious in the diagnostic.
    tint = front_img.copy()
    tint[front, 0] = np.clip(tint[front, 0].astype(np.int16) // 2, 0, 255).astype(np.uint8)
    tint[front, 2] = np.clip(tint[front, 2].astype(np.int16) + 80, 0, 255).astype(np.uint8)
    prev[front] = tint[front]
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(prev).save(PREVIEW)
    print("back", OUT_BACK, "front", OUT_FRONT, "preview", PREVIEW)


if __name__ == "__main__":
    split()
