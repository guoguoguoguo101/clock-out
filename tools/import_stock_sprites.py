"""Key generated stock sprites and copy them into game asset folders."""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from clean_char_sprites import _dilate, clean_image, flood_mask

ROOT = Path(r"d:\idea_project\liudian-xiaban")
SRC = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")
CHARS = ROOT / "assets" / "game" / "chars"
PROPS = ROOT / "assets" / "game" / "props"
UI = ROOT / "assets" / "game" / "ui"

ANIMALS = ["horse", "rabbit", "cow", "pelican", "kangaroo"]


def _ch(arr: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rgb = arr.astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = 0.22 * r + 0.55 * g + 0.23 * b
    return r, g, b, lum


def key_rgb(im: Image.Image) -> Image.Image:
    rgb = np.array(im.convert("RGB"))
    r, g, b, lum = _ch(rgb)
    mx = rgb.max(axis=2).astype(np.int16)
    mn = rgb.min(axis=2).astype(np.int16)
    sat = np.where(mx > 8, (mx - mn) / np.maximum(mx, 1), 0.0)
    h, w = lum.shape
    corners = np.array([lum[2, 2], lum[2, -3], lum[-3, 2], lum[-3, -3]])
    white_bg = float(corners.mean()) > 200.0
    border = np.zeros((h, w), dtype=bool)
    border[0] = True
    border[-1] = True
    border[:, 0] = True
    border[:, -1] = True
    if white_bg:
        walk = (r >= 242) & (g >= 242) & (b >= 242)
    else:
        walk = (lum < 16) & (sat < 0.16)
    killed = flood_mask(walk, walk & border, step=3, limit=140)

    cyan = (b > 90) & (g > 70) & (r < 170) & (b > r + 12) & (g > r + 6) & (sat > 0.22)
    orange = (r > 165) & (g > 85) & (b < 100) & (sat > 0.28)
    cream = (r > 200) & (g > 185) & (b > 155) & (lum > 175)
    pale = (r > 215) & (g > 215) & (b > 215) & (sat < 0.12) & ~killed
    horn = (r > 150) & (g > 115) & (b > 70) & (lum > 115) & (sat < 0.55)
    seeds = cyan | orange | cream | pale | horn
    if not seeds.any():
        seeds = (~killed) & (lum > 40)
    keep = flood_mask(~killed, seeds, step=3, limit=110)
    keep |= _dilate(keep, 2) & ~killed & (sat > 0.18)
    keep |= _dilate(keep, 6) & ~killed & (lum < 95)

    gray = (~keep) & (~killed) & (sat < 0.14) & (lum < 96)
    vignette = flood_mask(gray | killed, killed, step=2, limit=90) & gray
    keep &= ~vignette

    alpha = np.where(keep, 255, 0).astype(np.uint8)
    out = np.dstack([rgb, alpha])
    out[alpha == 0, :3] = 0
    return clean_image(Image.fromarray(out, "RGBA"))


def crop_pad(im: Image.Image, size: int = 1024, pad: int = 48) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    vis = arr[:, :, 3] > 16
    if not vis.any():
        return im.resize((size, size), Image.Resampling.NEAREST)
    ys, xs = np.where(vis)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    crop = im.crop((x0, y0, x1, y1))
    side = max(crop.size[0], crop.size[1]) + pad * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2), crop)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def copy_ui() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC / "stock_ui_bg.png", UI / "stock_bg.png")
    shutil.copy2(SRC / "stock_ui_bg_alert.png", UI / "stock_bg_alert.png")
    print("ui", UI / "stock_bg.png")


def copy_machine() -> None:
    PROPS.mkdir(parents=True, exist_ok=True)
    keyed = crop_pad(key_rgb(Image.open(SRC / "stock_machine.png")), 1024, 36)
    keyed.save(PROPS / "stock_machine.png")
    print("prop", PROPS / "stock_machine.png")


def copy_chars() -> None:
    for animal in ANIMALS:
        dst = CHARS / animal
        dst.mkdir(parents=True, exist_ok=True)
        for i in (0, 1):
            src = SRC / f"{animal}_trade_{i}.png"
            if not src.exists():
                print("missing", src)
                continue
            out = crop_pad(key_rgb(Image.open(src)))
            dest = dst / f"trade_{i}.png"
            out.save(dest)
            print("char", dest.relative_to(ROOT).as_posix())


def main() -> None:
    copy_ui()
    copy_machine()
    copy_chars()


if __name__ == "__main__":
    main()
