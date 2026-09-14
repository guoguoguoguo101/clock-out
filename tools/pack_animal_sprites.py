"""Split animal sprite strips into 1024 transparent frames + preview copies."""
from __future__ import annotations

from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

CURSOR = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")
ROOT = Path(r"d:\idea_project\liudian-xiaban")
PREVIEW = ROOT / "preview" / "sprites"
SIZE = 1024
MARGIN = 0.86

ANIMALS = ["rabbit", "cow", "pelican"]
STRIPS = [
    ("idle", "01_idle", ["idle_0", "idle_1", "idle_2", "idle_3"]),
    ("walk", "02_walk", ["walk_0", "walk_1", "walk_2", "walk_3"]),
    ("run", "03_run", ["run_0", "run_1", "run_2", "run_3"]),
    ("work", "04_acts", ["work_0", "work_1", "work_2", "work_3"]),
    ("rest", "04_acts", ["sleep_0", "sleep_1", "sleep_2", "sleep_3"]),
    ("toilet", "04_acts", ["toilet_0", "toilet_1", "toilet_2", "toilet_3"]),
]


def is_bg_pixel(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    if g >= 88 and g > r + 16 and g > b + 6 and (g - r) + (g - b) > 36:
        return True
    if min(r, g, b) >= 246 and max(r, g, b) - min(r, g, b) <= 10:
        return True
    return False


def knock_bg(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    arr = np.array(im)
    h, w = arr.shape[:2]
    vis = np.zeros((h, w), dtype=np.uint8)
    q: deque[tuple[int, int]] = deque()

    def ok(y: int, x: int) -> bool:
        r, g, b, a = arr[y, x]
        return is_bg_pixel(int(r), int(g), int(b), int(a))

    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))
    while q:
        y, x = q.popleft()
        if vis[y, x]:
            continue
        if not ok(y, x):
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


def keep_full_frames(frames: list[Image.Image]) -> list[Image.Image]:
    areas = []
    for im in frames:
        b = im.getbbox()
        areas.append(0 if not b else (b[2] - b[0]) * (b[3] - b[1]))
    med = sorted(areas)[len(areas) // 2] if areas else 0
    out: list[Image.Image] = []
    prev = frames[0] if frames else None
    for im, area in zip(frames, areas):
        if prev is not None and med and area < med * 0.45:
            out.append(prev)
        else:
            out.append(im)
            prev = im
    return out


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


def copy_horse() -> None:
    src = ROOT / "preview" / "horse-sprites"
    dst = PREVIEW / "horse"
    dst.mkdir(parents=True, exist_ok=True)
    if not src.exists():
        return
    for p in src.glob("*"):
        if p.is_file():
            shutil.copy2(p, dst / p.name)


def pack_animal(animal: str) -> int:
    sheets = ROOT / "assets" / animal / "sheets"
    hd = ROOT / "assets" / animal / "hd"
    prev = PREVIEW / animal
    sheets.mkdir(parents=True, exist_ok=True)
    hd.mkdir(parents=True, exist_ok=True)
    prev.mkdir(parents=True, exist_ok=True)
    count = 0
    for act, folder, names in STRIPS:
        src_name = f"{animal}_{act}_strip.png"
        src = CURSOR / src_name
        if not src.exists():
            print("missing", src)
            continue
        shutil.copy2(src, sheets / src_name)
        shutil.copy2(src, prev / src_name)
        knocked = knock_bg(Image.open(src))
        frames = [pad_square(im) for im in keep_full_frames(split_x(knocked, 4))]
        out_dir = hd / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        for im, name in zip(frames, names):
            im.save(out_dir / f"{name}.png", optimize=True)
            im.save(prev / f"{name}.png", optimize=True)
            count += 1
        if act in {"work", "rest", "toilet"}:
            alias = {"work": "work", "rest": "sleep", "toilet": "toilet"}[act]
            shutil.copy2(prev / f"{names[0]}.png", prev / f"{alias}.png")
            shutil.copy2(out_dir / f"{names[0]}.png", out_dir / f"{alias}.png")
        if act == "idle":
            shutil.copy2(prev / "idle_0.png", prev / "portrait.png")
    print(animal, count)
    return count


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    copy_horse()
    total = 0
    for animal in ANIMALS:
        total += pack_animal(animal)
    print("frames", total)


if __name__ == "__main__":
    main()
