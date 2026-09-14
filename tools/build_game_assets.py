"""Build game PNG sprites from the horse character bible.

Source sheet is too small to crop into playable frames, so this renderer
recreates every pose (walk / act / face) as transparent PNG, then recolors
the same rig for rabbit / penguin / panda / tiger.
"""
from __future__ import annotations

import json
import os
import shutil
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_SHEET = os.path.join(
    os.path.expanduser("~"),
    ".cursor",
    "projects",
    "d-idea-project-liudian-xiaban",
    "assets",
    "c__Users_guohongzhi_AppData_Roaming_Cursor_User_workspaceStorage_dfeb0a65593a9636ce8899de1c8232bd_images_75a05f2d-7b34-40b6-aea1-7fed4da09875-d1aa96c4-a184-4f70-8b73-79776aa52c23.jpg",
)
OUT = os.path.join(ROOT, "assets", "game")
SHEET_OUT = os.path.join(ROOT, "assets", "sheets")
PREVIEW = os.path.join(ROOT, "preview")

SIZE = 256
INK = (20, 20, 20, 255)
WHITE = (255, 255, 255, 255)
SHADOW = (122, 163, 184, 72)

CHARS = {
    "horse": {
        "name": "黑马",
        "role": "员工",
        "scarf": (61, 218, 240, 255),
        "scarf_dark": (43, 184, 212, 255),
        "species": "horse",
    },
    "rabbit": {
        "name": "兔子",
        "role": "员工",
        "scarf": (245, 200, 74, 255),
        "scarf_dark": (224, 160, 32, 255),
        "species": "rabbit",
    },
    "penguin": {
        "name": "企鹅",
        "role": "员工",
        "scarf": (91, 140, 255, 255),
        "scarf_dark": (58, 110, 232, 255),
        "species": "penguin",
    },
    "panda": {
        "name": "熊猫",
        "role": "员工",
        "scarf": (255, 143, 191, 255),
        "scarf_dark": (224, 106, 154, 255),
        "species": "panda",
    },
    "tiger": {
        "name": "老虎",
        "role": "老板",
        "scarf": (255, 154, 61, 255),
        "scarf_dark": (224, 106, 18, 255),
        "species": "tiger",
    },
}

LOCOMOTION = {
    "idle": [
        {"lean": 0, "bob": 0, "arm": 0, "stretch": 0},
        {"lean": 2, "bob": -2, "arm": 4, "stretch": 0},
        {"lean": 0, "bob": 0, "arm": 0, "stretch": 0},
        {"lean": -2, "bob": -1, "arm": -3, "stretch": 0},
    ],
    "walk": [
        {"lean": 18, "bob": -8, "arm": 22, "stretch": 8},
        {"lean": 8, "bob": 4, "arm": -16, "stretch": 3},
        {"lean": 20, "bob": -10, "arm": 20, "stretch": 9},
        {"lean": 6, "bob": 5, "arm": -18, "stretch": 3},
    ],
    "run": [
        {"lean": 22, "bob": -8, "arm": 22, "stretch": 10},
        {"lean": 16, "bob": 2, "arm": -18, "stretch": 8},
        {"lean": 24, "bob": -10, "arm": 20, "stretch": 12},
        {"lean": 14, "bob": 4, "arm": -16, "stretch": 7},
    ],
}

ACTS = ["work", "read", "coffee", "think", "cheer", "sleep"]
FACES = [
    "idle",
    "happy",
    "proud",
    "angry",
    "sad",
    "confused",
    "awkward",
    "cry",
    "love",
]


def ensure(path: str) -> str:
    os.makedirs(path, exist_ok=True)
    return path


def new_canvas(scale: int = 2) -> Image.Image:
    return Image.new("RGBA", (SIZE * scale, SIZE * scale), (0, 0, 0, 0))


def ellipse(d: ImageDraw.ImageDraw, box, fill):
    d.ellipse(box, fill=fill)


def draw_character(pose: str, spec: dict, face: str = "idle") -> Image.Image:
    s = 2
    img = new_canvas(s)
    d = ImageDraw.Draw(img)
    scarf = spec["scarf"]
    scarf_d = spec["scarf_dark"]
    species = spec["species"]

    lean = bob = arm = stretch = 0
    sitting = pose in ("work", "read", "coffee", "sleep")
    cheering = pose == "cheer"
    thinking = pose == "think"
    sleeping = pose == "sleep"
    kind = "idle"
    frame_i = 0
    if pose.startswith("idle_"):
        kind, frame_i = "idle", int(pose[-1])
    elif pose.startswith("walk_"):
        kind, frame_i = "walk", int(pose[-1])
    elif pose.startswith("run_"):
        kind, frame_i = "run", int(pose[-1])
    if kind in LOCOMOTION:
        f = LOCOMOTION[kind][frame_i]
        lean, bob, arm, stretch = f["lean"], f["bob"], f["arm"], f["stretch"]

    cx = 128 * s + lean * s
    cy = (142 if not sitting else 168) * s + bob * s
    if pose.startswith("face_") or pose == "portrait":
        cx, cy = 128 * s, 132 * s
        lean = arm = stretch = 0

    rx = (54 + stretch) * s
    ry = (60 - stretch // 2) * s
    if sitting:
        ry = 48 * s
        cy += 8 * s

    # shadow
    ellipse(d, [cx - 46 * s, 216 * s, cx + 46 * s, 238 * s], SHADOW)

    def body_col():
        return INK

    # ears / extras behind
    if species == "rabbit":
        ellipse(d, [cx - 38 * s, cy - ry - 44 * s, cx - 14 * s, cy - ry + 8 * s], INK)
        ellipse(d, [cx + 14 * s, cy - ry - 44 * s, cx + 38 * s, cy - ry + 8 * s], INK)
        ellipse(d, [cx - 32 * s, cy - ry - 36 * s, cx - 20 * s, cy - ry - 4 * s], (255, 224, 138, 255))
        ellipse(d, [cx + 20 * s, cy - ry - 36 * s, cx + 32 * s, cy - ry - 4 * s], (255, 224, 138, 255))
    elif species == "tiger":
        d.polygon(
            [cx - 40 * s, cy - ry + 8 * s, cx - 48 * s, cy - ry - 28 * s, cx - 16 * s, cy - ry + 4 * s],
            fill=INK,
        )
        d.polygon(
            [cx + 40 * s, cy - ry + 8 * s, cx + 48 * s, cy - ry - 28 * s, cx + 16 * s, cy - ry + 4 * s],
            fill=INK,
        )
        d.polygon(
            [cx - 36 * s, cy - ry, cx - 40 * s, cy - ry - 16 * s, cx - 24 * s, cy - ry],
            fill=spec["scarf"],
        )
        d.polygon(
            [cx + 36 * s, cy - ry, cx + 40 * s, cy - ry - 16 * s, cx + 24 * s, cy - ry],
            fill=spec["scarf"],
        )
    elif species == "panda":
        ellipse(d, [cx - 50 * s, cy - ry - 8 * s, cx - 22 * s, cy - ry + 20 * s], INK)
        ellipse(d, [cx + 22 * s, cy - ry - 8 * s, cx + 50 * s, cy - ry + 20 * s], INK)
        ellipse(d, [cx - 42 * s, cy - ry, cx - 30 * s, cy - ry + 12 * s], (255, 183, 213, 255))
        ellipse(d, [cx + 30 * s, cy - ry, cx + 42 * s, cy - ry + 12 * s], (255, 183, 213, 255))
    elif species == "horse":
        pass

    # arms
    ax = 18 * s
    ay = 10 * s + arm * s // 3
    if cheering:
        ellipse(d, [cx - rx - 8 * s, cy - ry - 10 * s, cx - rx + 18 * s, cy - 8 * s], INK)
        ellipse(d, [cx + rx - 18 * s, cy - ry - 10 * s, cx + rx + 8 * s, cy - 8 * s], INK)
    else:
        ellipse(d, [cx - rx - ax, cy - 4 * s + ay, cx - rx + 14 * s, cy + 36 * s + ay], INK)
        ellipse(d, [cx + rx - 14 * s, cy - 4 * s - ay, cx + rx + ax, cy + 36 * s - ay], INK)

    # body
    ellipse(d, [cx - rx, cy - ry, cx + rx, cy + ry], body_col())

    if species == "penguin":
        ellipse(d, [cx - 28 * s, cy - 8 * s, cx + 28 * s, cy + ry - 4 * s], (244, 247, 250, 255))
        ellipse(d, [cx - 40 * s, cy + ry - 6 * s, cx - 16 * s, cy + ry + 10 * s], (244, 162, 97, 255))
        ellipse(d, [cx + 16 * s, cy + ry - 6 * s, cx + 40 * s, cy + ry + 10 * s], (244, 162, 97, 255))
    elif species == "panda":
        ellipse(d, [cx - 30 * s, cy - 6 * s, cx + 30 * s, cy + 28 * s], (247, 247, 247, 255))
    elif species == "tiger":
        for ox in (-16, 8):
            ellipse(d, [cx + ox * s, cy - ry + 18 * s, cx + (ox + 8) * s, cy - ry + 40 * s], spec["scarf"])

    # scarf tails
    d.polygon(
        [
            cx - 20 * s,
            cy - 6 * s,
            cx - 56 * s,
            cy + 28 * s,
            cx - 40 * s,
            cy + 40 * s,
            cx - 8 * s,
            cy + 8 * s,
        ],
        fill=scarf_d,
    )
    d.polygon(
        [
            cx - 12 * s,
            cy - 2 * s,
            cx - 36 * s,
            cy + 44 * s,
            cx - 16 * s,
            cy + 46 * s,
            cx + 6 * s,
            cy + 6 * s,
        ],
        fill=scarf,
    )
    # scarf band
    d.rounded_rectangle(
        [cx - rx + 6 * s, cy - 12 * s, cx + rx - 6 * s, cy + 16 * s],
        radius=18 * s,
        fill=scarf,
    )

    # horse snout
    if species == "horse":
        ellipse(d, [cx - rx + 4 * s, cy - 8 * s, cx - 18 * s, cy + 18 * s], INK)

    # eyes
    eye_y = cy - 28 * s
    eye_dx = 18 * s
    erx, ery = 18 * s, 24 * s
    if face in ("happy", "love"):
        ery = 16 * s
        eye_y += 4 * s
    if face == "angry":
        eye_y += 2 * s
        ery = 18 * s
    if face == "sad" or face == "cry":
        eye_y += 6 * s
        ery = 20 * s
    if face == "sleep" or sleeping:
        # closed
        d.arc([cx - eye_dx - erx, eye_y, cx - eye_dx + erx, eye_y + 18 * s], 200, 340, fill=WHITE, width=5 * s)
        d.arc([cx + eye_dx - erx, eye_y, cx + eye_dx + erx, eye_y + 18 * s], 200, 340, fill=WHITE, width=5 * s)
    else:
        ellipse(d, [cx - eye_dx - erx, eye_y - ery, cx - eye_dx + erx, eye_y + ery], WHITE)
        ellipse(d, [cx + eye_dx - erx, eye_y - ery, cx + eye_dx + erx, eye_y + ery], WHITE)
        if face == "confused":
            ellipse(d, [cx + eye_dx - 6 * s, eye_y - 6 * s, cx + eye_dx + 6 * s, eye_y + 10 * s], WHITE)
        if face == "awkward":
            # look aside
            ellipse(d, [cx - eye_dx - erx + 8 * s, eye_y - ery, cx - eye_dx + erx + 8 * s, eye_y + ery], WHITE)

    # face extras
    if face == "happy":
        d.ellipse([cx + 40 * s, cy - 70 * s, cx + 52 * s, cy - 58 * s], fill=(255, 220, 90, 255))
        d.ellipse([cx + 54 * s, cy - 56 * s, cx + 62 * s, cy - 48 * s], fill=(255, 220, 90, 255))
    if face == "proud":
        d.polygon([cx + 36 * s, cy - 64 * s, cx + 58 * s, cy - 52 * s, cx + 36 * s, cy - 40 * s], fill=(255, 210, 80, 255))
    if face == "angry":
        d.polygon(
            [cx - eye_dx - 16 * s, eye_y - 28 * s, cx - eye_dx + 12 * s, eye_y - 18 * s, cx - eye_dx - 16 * s, eye_y - 14 * s],
            fill=INK,
        )
        d.polygon(
            [cx + eye_dx + 16 * s, eye_y - 28 * s, cx + eye_dx - 12 * s, eye_y - 18 * s, cx + eye_dx + 16 * s, eye_y - 14 * s],
            fill=INK,
        )
    if face == "sad":
        d.arc([cx - 16 * s, cy + 8 * s, cx + 16 * s, cy + 28 * s], 20, 160, fill=(180, 180, 190, 255), width=3 * s)
    if face == "cry":
        ellipse(d, [cx - eye_dx - 6 * s, eye_y + 16 * s, cx - eye_dx + 6 * s, eye_y + 40 * s], (160, 210, 255, 255))
        ellipse(d, [cx + eye_dx - 6 * s, eye_y + 16 * s, cx + eye_dx + 6 * s, eye_y + 40 * s], (160, 210, 255, 255))
    if face == "love":
        heart(d, cx + 48 * s, cy - 56 * s, 10 * s, (255, 92, 140, 255))
    if thinking:
        ellipse(d, [cx + 44 * s, cy - 78 * s, cx + 72 * s, cy - 50 * s], (255, 220, 80, 255))
        d.polygon(
            [cx + 50 * s, cy - 64 * s, cx + 66 * s, cy - 64 * s, cx + 58 * s, cy - 42 * s],
            fill=(255, 220, 80, 255),
        )

    # sit furniture
    if pose == "work":
        desk(d, s)
        laptop(d, cx, cy + 36 * s, s)
    elif pose == "read":
        d.rounded_rectangle([cx + 20 * s, cy - 8 * s, cx + 58 * s, cy + 36 * s], radius=6 * s, fill=(255, 214, 90, 255))
    elif pose == "coffee":
        cup(d, cx + 36 * s, cy + 8 * s, s)
    elif sleeping:
        zzz(d, cx + 36 * s, cy - 70 * s, s)

    if species == "tiger" and pose in ("portrait", "idle_0", "face_idle"):
        crown(d, cx, cy - ry - 8 * s, s)

    out = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return out


def heart(d, x, y, r, fill):
    ellipse(d, [x - r, y - r // 2, x, y + r // 2], fill)
    ellipse(d, [x, y - r // 2, x + r, y + r // 2], fill)
    d.polygon([x - r, y, x + r, y, x, y + r], fill=fill)


def crown(d, x, y, s):
    d.polygon(
        [
            x - 22 * s,
            y,
            x - 16 * s,
            y - 18 * s,
            x,
            y - 8 * s,
            x + 16 * s,
            y - 18 * s,
            x + 22 * s,
            y,
        ],
        fill=(245, 200, 74, 255),
    )


def desk(d, s):
    d.rounded_rectangle([40 * s, 188 * s, 216 * s, 214 * s], radius=8 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=2 * s)


def laptop(d, x, y, s):
    d.rounded_rectangle([x - 28 * s, y - 36 * s, x + 28 * s, y - 4 * s], radius=6 * s, fill=(238, 244, 248, 255))
    d.rounded_rectangle([x - 22 * s, y - 30 * s, x + 22 * s, y - 8 * s], radius=3 * s, fill=(91, 159, 255, 255))


def cup(d, x, y, s):
    d.rounded_rectangle([x - 12 * s, y - 8 * s, x + 12 * s, y + 18 * s], radius=6 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=2 * s)
    d.rectangle([x - 12 * s, y, x + 12 * s, y + 8 * s], fill=(61, 218, 240, 255))
    ellipse(d, [x - 8 * s, y - 12 * s, x + 8 * s, y - 4 * s], (107, 58, 26, 255))


def zzz(d, x, y, s):
    d.ellipse([x, y, x + 8 * s, y + 8 * s], fill=(180, 190, 210, 200))
    d.ellipse([x + 14 * s, y - 12 * s, x + 24 * s, y - 2 * s], fill=(180, 190, 210, 200))
    d.ellipse([x + 28 * s, y - 28 * s, x + 42 * s, y - 14 * s], fill=(180, 190, 210, 200))


def icon_canvas(draw_fn, size=128) -> Image.Image:
    img = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, 2)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def save(img: Image.Image, path: str):
    ensure(os.path.dirname(path))
    img.save(path, "PNG")


def draw_prop_icon(name: str) -> Image.Image:
    def fn(d: ImageDraw.ImageDraw, s: int):
        cx, cy = 64 * s, 64 * s
        if name == "backpack":
            d.rounded_rectangle([cx - 28 * s, cy - 32 * s, cx + 28 * s, cy + 32 * s], 12 * s, fill=(61, 218, 240, 255))
            d.rounded_rectangle([cx - 12 * s, cy - 8 * s, cx + 12 * s, cy + 16 * s], 6 * s, fill=(20, 20, 20, 255))
        elif name == "coffee":
            cup(d, cx, cy, s)
        elif name == "laptop":
            laptop(d, cx, cy + 20 * s, s)
        elif name == "file":
            d.rounded_rectangle([cx - 22 * s, cy - 32 * s, cx + 22 * s, cy + 32 * s], 6 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rectangle([cx - 12 * s, cy - 16 * s, cx + 12 * s, cy - 10 * s], fill=(61, 218, 240, 255))
        elif name == "pencil":
            d.rounded_rectangle([cx - 8 * s, cy - 40 * s, cx + 8 * s, cy + 28 * s], 4 * s, fill=(255, 210, 80, 255))
            d.polygon([cx - 8 * s, cy - 40 * s, cx + 8 * s, cy - 40 * s, cx, cy - 56 * s], fill=(20, 20, 20, 255))
        elif name == "books":
            d.rounded_rectangle([cx - 28 * s, cy - 8 * s, cx + 28 * s, cy + 28 * s], 4 * s, fill=(91, 140, 255, 255))
            d.rounded_rectangle([cx - 24 * s, cy - 28 * s, cx + 24 * s, cy + 8 * s], 4 * s, fill=(255, 143, 191, 255))
        elif name == "plant":
            ellipse(d, [cx - 22 * s, cy + 8 * s, cx + 22 * s, cy + 40 * s], (247, 251, 255, 255))
            ellipse(d, [cx - 28 * s, cy - 36 * s, cx + 8 * s, cy + 8 * s], (126, 217, 87, 255))
            ellipse(d, [cx - 8 * s, cy - 44 * s, cx + 28 * s, cy], (99, 199, 66, 255))
        elif name == "headset":
            d.arc([cx - 32 * s, cy - 36 * s, cx + 32 * s, cy + 20 * s], 200, 340, fill=(20, 20, 20, 255), width=8 * s)
            ellipse(d, [cx - 40 * s, cy - 8 * s, cx - 16 * s, cy + 24 * s], (61, 218, 240, 255))
            ellipse(d, [cx + 16 * s, cy - 8 * s, cx + 40 * s, cy + 24 * s], (61, 218, 240, 255))
        elif name == "phone":
            d.rounded_rectangle([cx - 16 * s, cy - 32 * s, cx + 16 * s, cy + 32 * s], 8 * s, fill=(91, 140, 255, 255))
            d.rounded_rectangle([cx - 12 * s, cy - 24 * s, cx + 12 * s, cy + 20 * s], 4 * s, fill=(180, 210, 255, 255))
        elif name == "drink":
            d.rounded_rectangle([cx - 16 * s, cy - 20 * s, cx + 16 * s, cy + 32 * s], 8 * s, fill=(255, 92, 140, 255))
            ellipse(d, [cx - 16 * s, cy - 28 * s, cx + 16 * s, cy - 12 * s], (255, 180, 200, 255))
        elif name == "coin":
            ellipse(d, [cx - 28 * s, cy - 28 * s, cx + 28 * s, cy + 28 * s], (245, 200, 74, 255))
        elif name == "gift":
            d.rounded_rectangle([cx - 28 * s, cy - 16 * s, cx + 28 * s, cy + 28 * s], 8 * s, fill=(255, 92, 140, 255))
            d.rectangle([cx - 6 * s, cy - 16 * s, cx + 6 * s, cy + 28 * s], fill=(255, 220, 90, 255))
        elif name == "gold":
            ellipse(d, [cx - 24 * s, cy - 8 * s, cx + 24 * s, cy + 28 * s], (245, 200, 74, 255))
            ellipse(d, [cx - 18 * s, cy - 28 * s, cx + 18 * s, cy + 8 * s], (255, 220, 90, 255))
        elif name == "star":
            d.polygon(
                [
                    (cx, cy - 32 * s),
                    (cx + 10 * s, cy - 8 * s),
                    (cx + 32 * s, cy - 8 * s),
                    (cx + 14 * s, cy + 8 * s),
                    (cx + 20 * s, cy + 32 * s),
                    (cx, cy + 16 * s),
                    (cx - 20 * s, cy + 32 * s),
                    (cx - 14 * s, cy + 8 * s),
                    (cx - 32 * s, cy - 8 * s),
                    (cx - 10 * s, cy - 8 * s),
                ],
                fill=(245, 200, 74, 255),
            )
        elif name == "heart":
            heart(d, cx, cy, 28 * s, (255, 92, 140, 255))
        elif name == "bulb":
            ellipse(d, [cx - 24 * s, cy - 32 * s, cx + 24 * s, cy + 12 * s], (255, 220, 90, 255))
            d.rounded_rectangle([cx - 10 * s, cy + 8 * s, cx + 10 * s, cy + 28 * s], 4 * s, fill=(238, 244, 248, 255))
        elif name == "desk":
            desk(d, s)
            laptop(d, cx, cy, s)
        elif name == "chair":
            d.rounded_rectangle([cx - 22 * s, cy - 8 * s, cx + 22 * s, cy + 8 * s], 4 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rectangle([cx - 16 * s, cy + 8 * s, cx - 8 * s, cy + 36 * s], fill=(232, 238, 246, 255))
            d.rectangle([cx + 8 * s, cy + 8 * s, cx + 16 * s, cy + 36 * s], fill=(232, 238, 246, 255))
        elif name == "sink":
            d.rounded_rectangle([cx - 40 * s, cy - 8 * s, cx + 40 * s, cy + 28 * s], 14 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rectangle([cx - 4 * s, cy - 28 * s, cx + 4 * s, cy - 8 * s], fill=(197, 216, 230, 255))
            d.rounded_rectangle([cx - 12 * s, cy - 36 * s, cx + 12 * s, cy - 24 * s], 4 * s, fill=(61, 218, 240, 255))
        elif name == "water":
            d.rounded_rectangle([cx - 18 * s, cy - 8 * s, cx + 18 * s, cy + 40 * s], 8 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            ellipse(d, [cx - 16 * s, cy - 40 * s, cx + 16 * s, cy - 4 * s], (168, 228, 255, 255))
            d.rounded_rectangle([cx - 10 * s, cy + 4 * s, cx - 2 * s, cy + 16 * s], 3 * s, fill=(226, 59, 59, 255))
            d.rounded_rectangle([cx + 2 * s, cy + 4 * s, cx + 10 * s, cy + 16 * s], 3 * s, fill=(91, 159, 255, 255))
        elif name == "coffee_machine":
            d.rounded_rectangle([cx - 24 * s, cy - 24 * s, cx + 24 * s, cy + 32 * s], 8 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            ellipse(d, [cx - 10 * s, cy - 12 * s, cx - 2 * s, cy - 4 * s], (61, 218, 240, 255))
            ellipse(d, [cx + 2 * s, cy - 12 * s, cx + 10 * s, cy - 4 * s], (255, 143, 191, 255))
            cup(d, cx, cy + 16 * s, s)
        elif name == "sofa":
            d.rounded_rectangle([cx - 52 * s, cy - 16 * s, cx + 52 * s, cy + 24 * s], 14 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rounded_rectangle([cx - 44 * s, cy - 8 * s, cx - 4 * s, cy + 16 * s], 8 * s, fill=(232, 246, 251, 255))
            d.rounded_rectangle([cx + 4 * s, cy - 8 * s, cx + 44 * s, cy + 16 * s], 8 * s, fill=(232, 246, 251, 255))
        elif name == "clock":
            d.rounded_rectangle([cx - 16 * s, cy - 36 * s, cx + 16 * s, cy + 36 * s], 10 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rounded_rectangle([cx - 12 * s, cy - 28 * s, cx + 12 * s, cy], 6 * s, fill=(91, 159, 255, 255))
        elif name == "door":
            d.rounded_rectangle([cx - 22 * s, cy - 40 * s, cx + 22 * s, cy + 36 * s], 8 * s, fill=(126, 200, 232, 255))
            d.rounded_rectangle([cx - 16 * s, cy - 32 * s, cx + 16 * s, cy + 28 * s], 4 * s, fill=(244, 251, 255, 255))
            ellipse(d, [cx + 6 * s, cy - 4 * s, cx + 14 * s, cy + 4 * s], (61, 218, 240, 255))
        elif name == "toilet":
            d.rounded_rectangle([cx - 24 * s, cy - 40 * s, cx + 24 * s, cy + 36 * s], 8 * s, fill=(232, 244, 250, 255), outline=(183, 211, 230, 255), width=3 * s)
            d.rounded_rectangle([cx - 16 * s, cy - 28 * s, cx + 16 * s, cy + 16 * s], 4 * s, fill=(247, 251, 255, 255))
            d.rounded_rectangle([cx - 16 * s, cy - 28 * s, cx + 16 * s, cy - 16 * s], 4 * s, fill=(61, 218, 240, 255))
        elif name == "cabinet":
            d.rounded_rectangle([cx - 24 * s, cy - 40 * s, cx + 24 * s, cy + 36 * s], 8 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            for i in range(3):
                yy = cy - 28 * s + i * 20 * s
                d.rounded_rectangle([cx - 16 * s, yy, cx + 16 * s, yy + 12 * s], 3 * s, fill=(232, 242, 250, 255))
        elif name == "meeting":
            d.rounded_rectangle([cx - 52 * s, cy - 8 * s, cx + 52 * s, cy + 24 * s], 12 * s, fill=(247, 251, 255, 255), outline=(213, 230, 242, 255), width=3 * s)
            d.rounded_rectangle([cx - 12 * s, cy - 28 * s, cx + 12 * s, cy - 8 * s], 4 * s, fill=(91, 159, 255, 255))
        elif name == "hat":
            ellipse(d, [cx - 36 * s, cy - 8 * s, cx + 36 * s, cy + 16 * s], (20, 20, 20, 255))
            d.rounded_rectangle([cx - 20 * s, cy - 28 * s, cx + 20 * s, cy], 8 * s, fill=(20, 20, 20, 255))
        elif name == "crown":
            crown(d, cx, cy, s)
        elif name == "hat_acc":
            ellipse(d, [cx - 36 * s, cy - 8 * s, cx + 36 * s, cy + 16 * s], INK)
        else:
            ellipse(d, [cx - 24 * s, cy - 24 * s, cx + 24 * s, cy + 24 * s], scarf_fallback())

    return icon_canvas(fn, 128)


def scarf_fallback():
    return (61, 218, 240, 255)


def draw_ui(name: str) -> Image.Image:
    colors = {
        "collect": (61, 218, 240, 255),
        "task": (91, 140, 255, 255),
        "bag": (61, 218, 240, 255),
        "settings": (160, 176, 190, 255),
        "heart": (255, 92, 140, 255),
        "zap": (245, 200, 74, 255),
        "smile": (255, 210, 80, 255),
        "mail": (91, 140, 255, 255),
        "hours": (61, 218, 240, 255),
        "energy": (245, 200, 74, 255),
    }

    def fn(d, s):
        cx, cy = 64 * s, 64 * s
        fill = colors[name]
        ellipse(d, [8 * s, 8 * s, 120 * s, 120 * s], fill)
        if name in ("heart",):
            heart(d, cx, cy, 22 * s, WHITE)
        elif name == "zap":
            d.polygon(
                [cx, cy - 28 * s, cx - 10 * s, cy, cx, cy, cx - 8 * s, cy + 28 * s, cx + 16 * s, cy - 4 * s, cx + 4 * s, cy - 4 * s],
                fill=WHITE,
            )
        elif name == "hours":
            d.rounded_rectangle([cx - 16 * s, cy - 22 * s, cx + 16 * s, cy + 22 * s], 4 * s, fill=WHITE)
            d.rectangle([cx - 10 * s, cy - 12 * s, cx + 10 * s, cy - 6 * s], fill=fill)
        elif name == "energy":
            d.polygon(
                [cx, cy - 24 * s, cx - 12 * s, cy + 4 * s, cx, cy + 4 * s, cx - 6 * s, cy + 24 * s, cx + 16 * s, cy - 2 * s, cx + 2 * s, cy - 2 * s],
                fill=WHITE,
            )
        elif name == "smile":
            ellipse(d, [cx - 8 * s, cy - 10 * s, cx - 2 * s, cy - 2 * s], INK)
            ellipse(d, [cx + 2 * s, cy - 10 * s, cx + 8 * s, cy - 2 * s], INK)
            d.arc([cx - 16 * s, cy - 4 * s, cx + 16 * s, cy + 20 * s], 20, 160, fill=INK, width=4 * s)
        elif name == "mail":
            d.rounded_rectangle([cx - 22 * s, cy - 14 * s, cx + 22 * s, cy + 14 * s], 4 * s, fill=WHITE)
            d.polygon([cx - 22 * s, cy - 14 * s, cx + 22 * s, cy - 14 * s, cx, cy + 4 * s], fill=(220, 235, 255, 255))
        elif name == "bag":
            d.rounded_rectangle([cx - 18 * s, cy - 10 * s, cx + 18 * s, cy + 22 * s], 6 * s, fill=WHITE)
            d.arc([cx - 10 * s, cy - 22 * s, cx + 10 * s, cy], 200, 340, fill=WHITE, width=4 * s)
        elif name == "task":
            d.rounded_rectangle([cx - 16 * s, cy - 20 * s, cx + 16 * s, cy + 20 * s], 4 * s, fill=WHITE)
            d.rectangle([cx - 8 * s, cy - 8 * s, cx + 8 * s, cy - 2 * s], fill=fill)
        elif name == "settings":
            ellipse(d, [cx - 10 * s, cy - 10 * s, cx + 10 * s, cy + 10 * s], WHITE)
            ellipse(d, [cx - 4 * s, cy - 4 * s, cx + 4 * s, cy + 4 * s], fill)
        else:
            ellipse(d, [cx - 16 * s, cy - 16 * s, cx + 16 * s, cy + 16 * s], WHITE)

    return icon_canvas(fn, 96)


def slice_source_sheet():
    if not os.path.isfile(SRC_SHEET):
        print("missing source sheet", SRC_SHEET)
        return []
    ensure(SHEET_OUT)
    shutil.copy2(SRC_SHEET, os.path.join(SHEET_OUT, "horse_master.jpg"))
    im = Image.open(SRC_SHEET).convert("RGB")
    boxes = {
        "portrait": (16, 40, 172, 308),
        "locomotion": (176, 40, 472, 308),
        "interact": (476, 40, 772, 308),
        "faces": (776, 40, 1010, 308),
        "props": (8, 318, 372, 488),
        "colors": (376, 318, 720, 488),
        "accessories": (724, 318, 1012, 488),
        "scenes": (8, 496, 528, 668),
        "ui": (532, 496, 748, 668),
        "misc": (752, 496, 1012, 668),
    }
    out_dir = ensure(os.path.join(SHEET_OUT, "horse_slices"))
    saved = []
    for name, box in boxes.items():
        crop = im.crop(box)
        path = os.path.join(out_dir, f"{name}.png")
        crop.save(path, "PNG")
        saved.append(("sheet/" + name, path))

    loc = im.crop(boxes["locomotion"])
    lw, lh = loc.size
    cell_w, cell_h = lw // 4, lh // 3
    labels = [
        "idle_0",
        "idle_1",
        "idle_2",
        "idle_3",
        "walk_0",
        "walk_1",
        "walk_2",
        "walk_3",
        "run_0",
        "run_1",
        "run_2",
        "run_3",
    ]
    i = 0
    for row in range(3):
        for col in range(4):
            cell = loc.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            path = os.path.join(out_dir, f"{labels[i]}.png")
            cell.save(path, "PNG")
            saved.append(("sheet/" + labels[i], path))
            i += 1

    faces = im.crop(boxes["faces"])
    fw, fh = faces.size
    cw, ch = fw // 3, fh // 3
    fi = 0
    for row in range(3):
        for col in range(3):
            cell = faces.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            path = os.path.join(out_dir, f"face_{FACES[fi]}.png")
            cell.save(path, "PNG")
            saved.append(("sheet/face_" + FACES[fi], path))
            fi += 1
    return saved


def build_chars():
    poses = []
    for anim, frames in LOCOMOTION.items():
        for i in range(len(frames)):
            poses.append(f"{anim}_{i}")
    poses += ACTS
    poses += [f"face_{f}" for f in FACES]
    poses.append("portrait")

    catalog = []
    for pack, spec in CHARS.items():
        folder = ensure(os.path.join(OUT, "chars", pack))
        for pose in poses:
            face = "idle"
            if pose.startswith("face_"):
                face = pose.replace("face_", "")
            if pose == "sleep":
                face = "sleep"
            if pose == "cheer":
                face = "happy"
            img = draw_character(pose, spec, face)
            path = os.path.join(folder, f"{pose}.png")
            save(img, path)
            catalog.append({"pack": pack, "pose": pose, "file": f"chars/{pack}/{pose}.png"})
        print("built", pack, len(poses), "poses")
    return poses, catalog


def build_items():
    props = [
        "backpack",
        "coffee",
        "laptop",
        "file",
        "pencil",
        "books",
        "plant",
        "headset",
        "phone",
        "drink",
        "coin",
        "gift",
        "gold",
        "star",
        "heart",
        "bulb",
        "desk",
        "chair",
        "sink",
        "water",
        "coffee_machine",
        "sofa",
        "clock",
        "door",
        "toilet",
        "cabinet",
        "meeting",
        "hat",
        "crown",
    ]
    files = []
    for name in props:
        img = draw_prop_icon(name)
        path = os.path.join(OUT, "props", f"{name}.png")
        save(img, path)
        files.append(f"props/{name}.png")
    ui = ["collect", "task", "bag", "settings", "heart", "zap", "smile", "mail", "hours", "energy"]
    for name in ui:
        img = draw_ui(name)
        path = os.path.join(OUT, "ui", f"{name}.png")
        save(img, path)
        files.append(f"ui/{name}.png")
    return files


def write_manifest(poses, items):
    data = {
        "version": 1,
        "style": "horse-bible-2d",
        "size": SIZE,
        "chars": {k: {"name": v["name"], "role": v["role"]} for k, v in CHARS.items()},
        "anims": {
            "idle": [f"idle_{i}" for i in range(4)],
            "walk": [f"walk_{i}" for i in range(4)],
            "run": [f"run_{i}" for i in range(4)],
        },
        "acts": ACTS,
        "faces": [f"face_{f}" for f in FACES],
        "state_anim": {
            "WALK": "walk_or_idle",
            "WORK": "work",
            "SLACK": "sleep",
            "COFFEE": "coffee",
            "TOILET": "idle",
            "MEETING": "read",
            "CLOCKING": "run",
            "LEFT": "idle",
        },
        "items": items,
        "poses": poses,
    }
    path = os.path.join(OUT, "manifest.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return data


def write_preview(manifest):
    ensure(PREVIEW)
    # portable copy
    dest_game = os.path.join(PREVIEW, "game")
    if os.path.isdir(dest_game):
        shutil.rmtree(dest_game)
    shutil.copytree(OUT, dest_game)
    sheet_dest = os.path.join(PREVIEW, "sheets")
    if os.path.isdir(SHEET_OUT):
        if os.path.isdir(sheet_dest):
            shutil.rmtree(sheet_dest)
        shutil.copytree(SHEET_OUT, sheet_dest)

    cards = []
    for pack, info in manifest["chars"].items():
        cards.append(f'<section class="pack"><h2>{info["name"]} · {info["role"]}</h2>')
        cards.append('<h3>走 / 站 / 跑</h3><div class="row">')
        for anim in ("idle", "walk", "run"):
            frames = ",".join(f"game/chars/{pack}/{p}.png" for p in manifest["anims"][anim])
            cards.append(
                f'<figure data-anim="{frames}"><img src="game/chars/{pack}/{anim}_0.png" alt="{anim}"><figcaption>{anim}</figcaption></figure>'
            )
        cards.append("</div><h3>交互</h3><div class='row'>")
        for pose in manifest["acts"]:
            cards.append(
                f'<figure><img src="game/chars/{pack}/{pose}.png" alt="{pose}"><figcaption>{pose}</figcaption></figure>'
            )
        cards.append("</div><h3>表情</h3><div class='row'>")
        for pose in manifest["faces"]:
            cards.append(
                f'<figure><img src="game/chars/{pack}/{pose}.png" alt="{pose}"><figcaption>{pose}</figcaption></figure>'
            )
        cards.append("</div></section>")

    item_html = ["<section><h2>道具 / 家具 / UI</h2><div class='row'>"]
    for item in manifest["items"]:
        name = os.path.splitext(os.path.basename(item))[0]
        item_html.append(f'<figure><img src="game/{item}" alt="{name}"><figcaption>{name}</figcaption></figure>')
    item_html.append("</div></section>")

    sheet_html = ""
    slice_dir = os.path.join(PREVIEW, "sheets", "horse_slices")
    if os.path.isdir(slice_dir):
        sheet_html = "<section><h2>设定图原片（从 PNG 拆出）</h2><div class='row source'>"
        for fn in sorted(os.listdir(slice_dir)):
            if fn.endswith(".png"):
                sheet_html += f'<figure><img src="sheets/horse_slices/{fn}" alt="{fn}"><figcaption>{fn}</figcaption></figure>'
        sheet_html += "</div></section>"

    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>六点下班 · 游戏资产</title>
  <style>
    :root {{ --bg:#07080c; --card:#12141c; --ink:#f4f7fb; --muted:#8b93a7; --line:#1d2230; --cyan:#3ddaf0; }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; background:var(--bg); color:var(--ink); font-family:"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif; }}
    main {{ max-width:1200px; margin:0 auto; padding:40px 24px 80px; }}
    h1 {{ font-size:32px; margin:0 0 8px; }}
    .lead {{ color:var(--muted); margin:0 0 32px; line-height:1.6; }}
    h2 {{ font-size:20px; margin:36px 0 12px; color:var(--cyan); }}
    h3 {{ font-size:13px; color:var(--muted); font-weight:600; margin:18px 0 8px; }}
    .row {{ display:flex; flex-wrap:wrap; gap:12px; }}
    figure {{ margin:0; width:96px; background:var(--card); border:1px solid var(--line); border-radius:16px; padding:8px 8px 6px; text-align:center; }}
    figure img {{ width:80px; height:80px; object-fit:contain; image-rendering:auto; }}
    figcaption {{ color:var(--muted); font-size:11px; margin-top:4px; }}
    .source figure {{ width:160px; }}
    .source img {{ width:144px; height:96px; object-fit:cover; border-radius:8px; }}
    .pack {{ background:#0c0e14; border:1px solid var(--line); border-radius:24px; padding:8px 18px 22px; margin-bottom:18px; }}
  </style>
</head>
<body>
<main>
  <h1>六点下班 · 游戏资产</h1>
  <p class="lead">角色走同一套姿势名：idle / walk / run / work / coffee / 表情。黑马是设定图主角，其它角色只换围巾和物种特征。点开走动图会自己播动画。</p>
  {''.join(cards)}
  {''.join(item_html)}
  {sheet_html}
</main>
<script>
  document.querySelectorAll("figure[data-anim]").forEach((fig) => {{
    const frames = fig.dataset.anim.split(",");
    const img = fig.querySelector("img");
    let i = 0;
    setInterval(() => {{
      i = (i + 1) % frames.length;
      img.src = frames[i];
    }}, 140);
  }});
</script>
</body>
</html>
"""
    with open(os.path.join(PREVIEW, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)
    print("preview", os.path.join(PREVIEW, "index.html"))


def main():
    ensure(OUT)
    slice_source_sheet()
    poses, _catalog = build_chars()
    items = build_items()
    manifest = write_manifest(poses, items)
    write_preview(manifest)
    print("done", OUT)


if __name__ == "__main__":
    main()
