"""Knock white, split 4-frame strips, write HD frames + preview gallery."""
from __future__ import annotations

from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont

CURSOR = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")
ROOT = Path(r"d:\idea_project\liudian-xiaban")
SHEETS = ROOT / "assets" / "horse" / "sheets"
HD = ROOT / "assets" / "horse" / "hd"
PREVIEW = ROOT / "preview" / "horse-sprites"
SIZE = 1024
MARGIN = 0.86

STRIPS = [
    ("horse_idle_strip.png", "01_idle", ["idle_0", "idle_1", "idle_2", "idle_3"], "站立"),
    ("horse_walk_strip.png", "02_walk", ["walk_0", "walk_1", "walk_2", "walk_3"], "走路"),
    ("horse_run_strip.png", "03_run", ["run_0", "run_1", "run_2", "run_3"], "奔跑"),
    ("horse_work_strip.png", "04_acts", ["work_0", "work_1", "work_2", "work_3"], "工作"),
    ("horse_rest_strip.png", "04_acts", ["sleep_0", "sleep_1", "sleep_2", "sleep_3"], "休息"),
    ("horse_toilet_strip.png", "04_acts", ["toilet_0", "toilet_1", "toilet_2", "toilet_3"], "上厕所"),
]


def knock_white(im: Image.Image, thresh: int = 242) -> Image.Image:
    im = im.convert("RGBA")
    arr = np.array(im)
    h, w = arr.shape[:2]
    vis = np.zeros((h, w), dtype=np.uint8)
    q: deque[tuple[int, int]] = deque()

    def is_bg(y: int, x: int) -> bool:
        r, g, b, a = arr[y, x]
        if a < 8:
            return True
        if r < thresh or g < thresh or b < thresh:
            return False
        return abs(int(r) - int(g)) < 18 and abs(int(g) - int(b)) < 18

    for x in range(w):
        if is_bg(0, x):
            q.append((0, x))
        if is_bg(h - 1, x):
            q.append((h - 1, x))
    for y in range(h):
        if is_bg(y, 0):
            q.append((y, 0))
        if is_bg(y, w - 1):
            q.append((y, w - 1))
    while q:
        y, x = q.popleft()
        if vis[y, x]:
            continue
        if not is_bg(y, x):
            continue
        vis[y, x] = 1
        arr[y, x, 3] = 0
        if y:
            q.append((y - 1, x))
        if y + 1 < h:
            q.append((y + 1, x))
        if x:
            q.append((y, x - 1))
        if x + 1 < w:
            q.append((y, x + 1))
    return Image.fromarray(arr)


def pad_square(im: Image.Image, size: int = SIZE) -> Image.Image:
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    im = im.crop(bbox)
    w, h = im.size
    scale = min((size * MARGIN) / w, (size * MARGIN) / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(im, ((size - nw) // 2, size - nh - int(size * 0.04)), im)
    return canvas


def runs_1d(mask: np.ndarray, min_gap: int, min_len: int) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    in_run = False
    start = 0
    for i, v in enumerate(mask):
        if v and not in_run:
            start = i
            in_run = True
        elif not v and in_run:
            if i - start >= min_len:
                runs.append((start, i))
            in_run = False
    if in_run and len(mask) - start >= min_len:
        runs.append((start, len(mask)))
    if not runs:
        return [(0, len(mask))]
    merged = [runs[0]]
    for a, b in runs[1:]:
        if a - merged[-1][1] < min_gap:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    return merged


def split_x(im: Image.Image, expected: int = 4) -> list[Image.Image]:
    arr = np.array(im)
    alpha = arr[:, :, 3] > 16
    density = alpha.sum(axis=0)
    mask = density > 6
    segs = runs_1d(mask, min_gap=max(8, im.width // 80), min_len=max(8, im.width // 80))
    while expected and len(segs) > expected:
        gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
        i = int(np.argmin(gaps))
        segs[i] = (segs[i][0], segs[i + 1][1])
        segs.pop(i + 1)
    while expected and len(segs) < expected:
        widths = [b - a for a, b in segs]
        i = int(np.argmax(widths))
        a, b = segs[i]
        mid = (a + b) // 2
        segs[i : i + 1] = [(a, mid), (mid, b)]
    out = []
    pad = 6
    for a, b in segs:
        a = max(0, a - pad)
        b = min(im.width, b + pad)
        out.append(im.crop((a, 0, b, im.height)))
    return out


def make_atlas(rows: list[tuple[str, list[Image.Image]]]) -> Image.Image:
    cell = 280
    label_h = 48
    pad = 24
    cols = 4
    w = pad * 2 + cols * cell + (cols - 1) * 16
    h = pad * 2 + len(rows) * (cell + label_h + 28)
    atlas = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    draw = ImageDraw.Draw(atlas)
    try:
        font = ImageFont.truetype("msyh.ttc", 28)
    except OSError:
        font = ImageFont.load_default()
    y = pad
    for title, frames in rows:
        draw.text((pad, y), title, fill=(30, 34, 42), font=font)
        y += label_h
        for i, fr in enumerate(frames):
            x = pad + i * (cell + 16)
            thumb = fr.copy()
            thumb.thumbnail((cell, cell), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
            canvas.paste(thumb, ((cell - thumb.width) // 2, (cell - thumb.height) // 2), thumb)
            atlas.paste(canvas, (x, y), canvas)
        y += cell + 28
    return atlas


def main() -> None:
    SHEETS.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    atlas_rows: list[tuple[str, list[Image.Image]]] = []
    saved = []
    for src_name, folder, names, title in STRIPS:
        src = CURSOR / src_name
        if not src.exists():
            print("missing", src)
            continue
        shutil.copy2(src, SHEETS / src_name)
        shutil.copy2(src, PREVIEW / src_name)
        knocked = knock_white(Image.open(src))
        frames = [pad_square(im) for im in split_x(knocked, 4)]
        out_dir = HD / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        for im, name in zip(frames, names):
            path = out_dir / f"{name}.png"
            im.save(path, optimize=True)
            im.save(PREVIEW / f"{name}.png", optimize=True)
            saved.append(path)
        atlas_rows.append((title, frames))
        print(title, [p.name for p in (out_dir.glob(names[0].split("_")[0] + "_*.png") if False else [])] or names)
    (HD / "00_portrait").mkdir(parents=True, exist_ok=True)
    idle0 = HD / "01_idle" / "idle_0.png"
    if idle0.exists():
        shutil.copy2(idle0, HD / "00_portrait" / "hero.png")
        shutil.copy2(idle0, PREVIEW / "portrait.png")
    for name in ("work", "sleep", "toilet"):
        src = HD / "04_acts" / f"{name}_0.png"
        if src.exists():
            shutil.copy2(src, HD / "04_acts" / f"{name}.png")
            shutil.copy2(src, PREVIEW / f"{name}.png")
    atlas = make_atlas(atlas_rows)
    atlas_path = SHEETS / "horse_game_atlas.png"
    atlas.save(atlas_path)
    atlas.save(PREVIEW / "horse_game_atlas.png")
    print("saved", len(saved), "frames")
    print("atlas", atlas_path)


if __name__ == "__main__":
    main()
