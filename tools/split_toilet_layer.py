"""Pull the baked toilet out of horse/kangaroo sit frames into a shared prop."""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(r"d:\idea_project\liudian-xiaban")
CHARS = ROOT / "assets" / "game" / "chars"
BAKED = ROOT / "assets" / "废弃素材" / "chars"
PROP_OUT = ROOT / "assets" / "game" / "props" / "toilet_sit.png"
LAYER_OUT = ROOT / "assets" / "game" / "props" / "toilet_sit_layer.png"
PREVIEW = ROOT / "preview" / "_toilet_layers"
PACKS = ("horse", "kangaroo")
POSES = [f"toilet_{i}" for i in range(4)]
PORCELAIN = np.array([246.0, 247.0, 249.0], np.float32)
SEAT = np.array([92.0, 102.0, 112.0], np.float32)


def _dilate(mask: np.ndarray, n: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(n):
        p = np.pad(out, 1)
        out = out | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def _erode(mask: np.ndarray, n: int = 1) -> np.ndarray:
    return ~_dilate(~mask, n)


def _close(mask: np.ndarray, n: int) -> np.ndarray:
    return _erode(_dilate(mask, n), n)


def _components(mask: np.ndarray) -> list[np.ndarray]:
    h, w = mask.shape
    seen = np.zeros((h, w), np.bool_)
    labels: list[np.ndarray] = []
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys.tolist(), xs.tolist()):
        if seen[y, x]:
            continue
        q = deque([(y, x)])
        seen[y, x] = True
        pix: list[tuple[int, int]] = []
        while q:
            cy, cx = q.popleft()
            pix.append((cy, cx))
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        comp = np.zeros((h, w), np.bool_)
        for py, px in pix:
            comp[py, px] = True
        labels.append(comp)
    return labels


def _convex_hull_mask(mask: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(mask)
    if xs.size < 8:
        return mask.copy()
    pts = np.stack([xs, ys], axis=1)
    hull_pts = _monotone_chain(pts)
    img = Image.new("L", (mask.shape[1], mask.shape[0]), 0)
    ImageDraw.Draw(img).polygon([tuple(map(int, p)) for p in hull_pts], fill=255)
    return np.array(img) > 0


def _monotone_chain(points: np.ndarray) -> list[tuple[int, int]]:
    pts = sorted({(int(x), int(y)) for x, y in points})
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower: list[tuple[int, int]] = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper: list[tuple[int, int]] = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def toilet_mask(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[:, :, :3].astype(np.float32)
    a = rgba[:, :, 3].astype(np.float32) / 255.0
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    yellow = (r > 150) & (g > 90) & (r > b + 18) & (chroma > 28)
    dark = (mean < 78) & (chroma < 42)
    phone = (mean < 90) & (chroma < 28) & (a > 0.2)
    vis = a > 0.18
    core = vis & ~yellow & ~dark & ~phone & (mean > 188) & (chroma < 42)
    grow = vis & ~yellow & ~dark & ~phone & (mean > 96) & (chroma < 58)
    mask = core | (_dilate(core, 6) & grow)
    mask = _dilate(mask, 1) & vis & ~yellow & ~dark
    comps = _components(mask)
    keep = np.zeros(mask.shape, np.bool_)
    for comp in comps:
        if int(comp.sum()) >= 3500:
            keep |= comp
    if not keep.any() and comps:
        keep = max(comps, key=lambda c: int(c.sum()))
    return keep


def keep_main_body(rgba: np.ndarray, bowl: np.ndarray) -> np.ndarray:
    vis = rgba[:, :, 3] > 8
    comps = _components(vis)
    if not comps:
        return rgba
    main = max(comps, key=lambda c: int(c.sum()))
    core = _erode(main, 3)
    ghost = vis & _dilate(bowl, 5) & ~core
    out = rgba.copy()
    out[~main | ghost] = 0
    return out


def fill_bowl(layer: np.ndarray) -> np.ndarray:
    a = layer[:, :, 3] > 8
    if not a.any():
        return layer
    closed = np.zeros_like(a)
    for y in range(a.shape[0]):
        xs = np.nonzero(a[y])[0]
        if xs.size < 2:
            continue
        closed[y, int(xs.min()) : int(xs.max()) + 1] = True
    fill = closed & ~a
    out = layer.copy()
    if fill.any():
        porcelain = np.median(layer[a, :3], axis=0)
        out[fill, :3] = porcelain
        out[fill, 3] = 255
        ys, _xs = np.nonzero(a)
        y_seat = int(np.percentile(ys, 62))
        yy = np.arange(fill.shape[0])[:, None]
        band = fill & (yy >= y_seat - 3) & (yy <= y_seat + 2)
        out[band, :3] = SEAT
        out[band, 3] = 255
    out[out[:, :, 3] == 0, :3] = 0
    return out


def split_frame(path: Path) -> tuple[np.ndarray, np.ndarray, int]:
    rgba = np.array(Image.open(path).convert("RGBA"))
    bowl = toilet_mask(rgba)
    body = rgba.copy()
    body[bowl, 3] = 0
    body[body[:, :, 3] == 0, :3] = 0
    body = keep_main_body(body, bowl)
    layer = np.zeros_like(rgba)
    layer[bowl] = rgba[bowl]
    leftover = (rgba[:, :, 3] > 8) & (body[:, :, 3] <= 8) & ~bowl
    layer[leftover] = rgba[leftover]
    layer[layer[:, :, 3] == 0, :3] = 0
    return body, layer, int(bowl.sum())


def tight_crop(rgba: np.ndarray, pad: int = 8) -> np.ndarray:
    a = rgba[:, :, 3] > 8
    if not a.any():
        return rgba
    ys, xs = np.nonzero(a)
    y0, y1 = max(0, int(ys.min()) - pad), min(rgba.shape[0], int(ys.max()) + 1 + pad)
    x0, x1 = max(0, int(xs.min()) - pad), min(rgba.shape[1], int(xs.max()) + 1 + pad)
    return rgba[y0:y1, x0:x1]


def checker(*layers: np.ndarray) -> Image.Image:
    h, w = layers[0].shape[:2]
    yy, xx = np.indices((h, w))
    ch = np.where(((yy // 24) + (xx // 24)) % 2 == 0, 46, 62).astype(np.uint8)
    out = Image.fromarray(np.dstack([ch, ch, ch, np.full((h, w), 255, np.uint8)]), "RGBA")
    for layer in layers:
        out.alpha_composite(Image.fromarray(layer, "RGBA"))
    return out.convert("RGB")


def tint_scarf(path: Path, tint: tuple[int, int, int]) -> np.ndarray:
    scarf = np.array(Image.open(path).convert("RGBA"))
    lum = scarf[:, :, 0].astype(np.float32)
    out = np.zeros_like(scarf)
    out[:, :, 0] = np.clip(lum / 255.0 * tint[0], 0, 255)
    out[:, :, 1] = np.clip(lum / 255.0 * tint[1], 0, 255)
    out[:, :, 2] = np.clip(lum / 255.0 * tint[2], 0, 255)
    out[:, :, 3] = scarf[:, :, 3]
    return out


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    pack_bowl: dict[str, np.ndarray] = {}
    shared_src = None
    for pack in PACKS:
        src_dir = BAKED / f"{pack}_toilet_baked"
        body_dir = CHARS / pack
        for pose in POSES:
            src = src_dir / f"{pose}.png"
            body, layer, px = split_frame(src)
            Image.fromarray(body, "RGBA").save(body_dir / f"{pose}.png", optimize=True)
            checker(body).save(PREVIEW / f"{pack}_{pose}_body.png")
            checker(layer).save(PREVIEW / f"{pack}_{pose}_bowl.png")
            print(pack, pose, "toilet_px", px, "body", int((body[:, :, 3] > 8).sum()))
            if pose == "toilet_0":
                pack_bowl[pack] = layer
                Image.fromarray(layer, "RGBA").save(body_dir / "bowl.png", optimize=True)
            if pack == "horse" and pose == "toilet_0":
                shared_src = layer

    if shared_src is None:
        raise SystemExit("no shared toilet")
    shared = fill_bowl(shared_src)
    Image.fromarray(shared, "RGBA").save(LAYER_OUT, optimize=True)
    crop = tight_crop(shared, 12)
    Image.fromarray(crop, "RGBA").save(PROP_OUT, optimize=True)
    checker(shared).save(PREVIEW / "shared_layer.png")
    checker(crop).save(PREVIEW / "shared_prop.png")
    tints = {"horse": (62, 224, 242), "kangaroo": (255, 154, 26)}
    for pack in PACKS:
        body = np.array(Image.open(CHARS / pack / "toilet_0.png").convert("RGBA"))
        bowl = pack_bowl[pack]
        scarf_p = CHARS / pack / "scarf" / "toilet_0.png"
        layers = [bowl, body]
        if scarf_p.exists():
            layers.append(tint_scarf(scarf_p, tints[pack]))
        checker(*layers).save(PREVIEW / f"{pack}_own_comp.png")
        checker(shared, body, *( [tint_scarf(scarf_p, tints[pack])] if scarf_p.exists() else [])).save(
            PREVIEW / f"{pack}_shared_comp.png"
        )
    print("prop", PROP_OUT, crop.shape)
    print("layer", LAYER_OUT)


if __name__ == "__main__":
    main()
