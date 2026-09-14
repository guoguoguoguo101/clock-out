"""Knock white background, split sheets by alpha projection, pad to 1024."""
from __future__ import annotations

from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

ROOT = Path(r"d:\idea_project\liudian-xiaban")
SHEETS = ROOT / "assets" / "horse" / "sheets"
HD = ROOT / "assets" / "horse" / "hd"
GAME = ROOT / "assets" / "game" / "chars" / "horse"
CURSOR_ASSETS = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")
HD.mkdir(parents=True, exist_ok=True)
GAME.mkdir(parents=True, exist_ok=True)

SIZE = 1024
MARGIN = 0.86


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
        return abs(int(r) - int(g)) < 14 and abs(int(g) - int(b)) < 14

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
    canvas.paste(im, ((size - nw) // 2, (size - nh) // 2), im)
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


def split_axis(im: Image.Image, axis: str, expected: int | None = None, min_gap: int = 10) -> list[Image.Image]:
    arr = np.array(im)
    alpha = arr[:, :, 3] > 16
    if axis == "x":
        density = alpha.sum(axis=0)
        min_len = max(8, im.width // 80)
    else:
        density = alpha.sum(axis=1)
        min_len = max(8, im.height // 80)
    mask = density > 6
    segs = runs_1d(mask, min_gap=min_gap, min_len=min_len)
    if expected and len(segs) > expected:
        # merge the closest pairs until expected
        while len(segs) > expected:
            gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
            i = int(np.argmin(gaps))
            segs[i] = (segs[i][0], segs[i + 1][1])
            segs.pop(i + 1)
    if expected and len(segs) < expected:
        # split the widest segment
        while len(segs) < expected:
            widths = [b - a for a, b in segs]
            i = int(np.argmax(widths))
            a, b = segs[i]
            mid = (a + b) // 2
            segs[i : i + 1] = [(a, mid), (mid, b)]
    out = []
    pad = 4
    for a, b in segs:
        a = max(0, a - pad)
        b = min(len(mask), b + pad)
        if axis == "x":
            out.append(im.crop((a, 0, b, im.height)))
        else:
            out.append(im.crop((0, a, im.width, b)))
    return out


def save_list(images: list[Image.Image], names: list[str], folder: str) -> list[Path]:
    out_dir = HD / folder
    out_dir.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    for im, name in zip(images, names):
        if im.getbbox() is None:
            continue
        path = out_dir / f"{name}.png"
        pad_square(im).save(path, optimize=True)
        saved.append(path)
    return saved


def save_one(im: Image.Image, folder: str, name: str) -> Path:
    return save_list([im], [name], folder)[0]


def load_sheet(name: str) -> Image.Image:
    src = SHEETS / name
    return knock_white(Image.open(src))


def copy_game() -> None:
    pairs = [
        ("00_portrait/hero.png", "portrait.png"),
        ("00_portrait/hero.png", "stand.png"),
        ("00_portrait/hero.png", "side.png"),
        ("01_idle/idle_0.png", "idle_0.png"),
        ("01_idle/idle_1.png", "idle_1.png"),
        ("01_idle/idle_2.png", "idle_2.png"),
        ("01_idle/idle_3.png", "idle_3.png"),
        ("02_walk/walk_0.png", "walk_0.png"),
        ("02_walk/walk_1.png", "walk_1.png"),
        ("02_walk/walk_2.png", "walk_2.png"),
        ("02_walk/walk_3.png", "walk_3.png"),
        ("03_run/run_0.png", "run_0.png"),
        ("03_run/run_1.png", "run_1.png"),
        ("03_run/run_2.png", "run_2.png"),
        ("03_run/run_3.png", "run_3.png"),
        ("04_acts/work.png", "work.png"),
        ("04_acts/read.png", "read.png"),
        ("04_acts/coffee.png", "coffee.png"),
        ("04_acts/think.png", "think.png"),
        ("04_acts/cheer.png", "cheer.png"),
        ("04_acts/sleep.png", "sleep.png"),
        ("05_faces/idle.png", "face_idle.png"),
        ("05_faces/happy.png", "face_happy.png"),
        ("05_faces/proud.png", "face_proud.png"),
        ("05_faces/angry.png", "face_angry.png"),
        ("05_faces/confused.png", "face_confused.png"),
        ("05_faces/question.png", "face_sad.png"),
        ("05_faces/shock.png", "face_cry.png"),
        ("05_faces/awkward.png", "face_awkward.png"),
        ("05_faces/love.png", "face_love.png"),
        ("07_colors/cyan.png", "stand_cyan.png"),
        ("07_colors/yellow.png", "stand_yellow.png"),
        ("07_colors/red.png", "stand_red.png"),
        ("07_colors/purple.png", "stand_purple.png"),
        ("07_colors/green.png", "stand_green.png"),
        ("07_colors/pink.png", "stand_pink.png"),
        ("08_acc/hat.png", "stand_hat.png"),
        ("08_acc/headset.png", "stand_headset.png"),
        ("08_acc/backpack.png", "stand_backpack.png"),
        ("08_acc/crown.png", "stand_crown.png"),
    ]
    for src_rel, dst_name in pairs:
        src = HD / src_rel
        if src.exists():
            shutil.copy2(src, GAME / dst_name)


if __name__ == "__main__":
    copy_game()
    print("hd", len(list(HD.rglob("*.png"))))
    print("game", len(list(GAME.glob("*.png"))))
