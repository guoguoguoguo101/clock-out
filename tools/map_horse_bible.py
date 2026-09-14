from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"d:\idea_project\liudian-xiaban")
SRC = ROOT / "assets" / "concept" / "horse-bible.jpg"
OUT = ROOT / "assets" / "horse" / "_debug"
OUT.mkdir(parents=True, exist_ok=True)

im = Image.open(SRC).convert("RGB")
arr = np.array(im)
h, w = arr.shape[:2]
lum = arr.mean(axis=2)

cell = 16
gh, gw = h // cell, w // cell
grid = np.zeros((gh, gw), dtype=np.uint8)
for gy in range(gh):
    for gx in range(gw):
        patch = lum[gy * cell : (gy + 1) * cell, gx * cell : (gx + 1) * cell]
        # content if any pixel is bright (eyes/scarf/props) or saturated
        patch_rgb = arr[gy * cell : (gy + 1) * cell, gx * cell : (gx + 1) * cell]
        sat = patch_rgb.max(axis=2) - patch_rgb.min(axis=2)
        bright = patch.max()
        grid[gy, gx] = 2 if bright > 80 or sat.max() > 40 else (1 if patch.mean() > 14 else 0)

# print occupancy
chars = ".#@"
for gy in range(gh):
    line = "".join(chars[int(v)] for v in grid[gy])
    print(f"{gy*cell:3d} {line}")

# overlay grid
ov = im.copy()
dr = ImageDraw.Draw(ov)
for x in range(0, w, cell):
    dr.line([(x, 0), (x, h)], fill=(40, 80, 120), width=1)
for y in range(0, h, cell):
    dr.line([(0, y), (w, y)], fill=(40, 80, 120), width=1)
for x in range(0, w, 64):
    dr.text((x + 2, 2), str(x), fill=(0, 220, 255))
for y in range(0, h, 64):
    dr.text((2, y + 2), str(y), fill=(255, 180, 0))
ov.save(OUT / "grid.png")
print("saved", OUT / "grid.png")
