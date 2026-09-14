"""Rebuild the horse bible as 1024x1024 transparent layered PNGs.

Not a crop/upscale of the sheet. Each part is redrawn so body, scarf,
accessories and props stay independent for tinting, dressing and Spine.
"""
from __future__ import annotations

import json
import os
import shutil
from dataclasses import dataclass
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "game")
LAYERS = os.path.join(OUT, "layers")
PREVIEW = os.path.join(ROOT, "preview")
SHEETS = os.path.join(ROOT, "assets", "sheets")

OUT_SIZE = 1024
SS = 2  # draw at 2048, downsample
INK = (18, 18, 18, 255)
WHITE = (255, 255, 255, 255)
SHADOW = (140, 176, 196, 90)
CYAN = (61, 218, 240, 255)
CYAN_D = (38, 184, 210, 255)

SCARF_COLORS = {
    "cyan": ((61, 218, 240, 255), (38, 184, 210, 255)),
    "yellow": ((245, 200, 74, 255), (214, 160, 32, 255)),
    "red": ((232, 72, 86, 255), (196, 48, 62, 255)),
    "purple": ((155, 92, 230, 255), (118, 62, 196, 255)),
    "green": ((92, 201, 110, 255), (58, 160, 78, 255)),
    "pink": ((255, 143, 191, 255), (224, 106, 154, 255)),
}


def px(n: float) -> int:
    return int(round(n * SS))


def blank() -> Image.Image:
    return Image.new("RGBA", (OUT_SIZE * SS, OUT_SIZE * SS), (0, 0, 0, 0))


def down(img: Image.Image) -> Image.Image:
    return img.resize((OUT_SIZE, OUT_SIZE), Image.Resampling.LANCZOS)


def save(img: Image.Image, path: str) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = down(img) if img.size[0] != OUT_SIZE else img
    out.save(path, "PNG")
    return path


def composite(layers: list[Image.Image]) -> Image.Image:
    acc = blank()
    for layer in layers:
        if layer is not None:
            acc = Image.alpha_composite(acc, layer)
    return acc


def ellipse(d: ImageDraw.ImageDraw, x, y, rx, ry, fill):
    d.ellipse([px(x - rx), px(y - ry), px(x + rx), px(y + ry)], fill=fill)


def round_rect(d: ImageDraw.ImageDraw, x0, y0, x1, y1, r, fill, outline=None, width=0):
    d.rounded_rectangle(
        [px(x0), px(y0), px(x1), px(y1)],
        radius=px(r),
        fill=fill,
        outline=outline,
        width=px(width) if width else 0,
    )


@dataclass
class BodyPose:
    name: str
    view: str  # front, side, back, sit, three
    lean: float = 0
    bob: float = 0
    leg_a: float = 0
    leg_b: float = 0
    arms_up: bool = False
    sleep: bool = False
    face: str = "idle"


BODY_POSES = [
    BodyPose("front", "front"),
    BodyPose("side", "side"),
    BodyPose("back", "back"),
    BodyPose("sit", "sit"),
    BodyPose("stand", "three"),
    BodyPose("walk_0", "side", lean=18, bob=-8, leg_a=28, leg_b=-32),
    BodyPose("walk_1", "side", lean=8, bob=6, leg_a=-8, leg_b=12),
    BodyPose("walk_2", "side", lean=20, bob=-12, leg_a=-30, leg_b=26),
    BodyPose("walk_3", "side", lean=6, bob=8, leg_a=14, leg_b=-10),
    BodyPose("idle_0", "three", lean=0, bob=0),
    BodyPose("idle_1", "three", lean=4, bob=-6),
    BodyPose("idle_2", "three", lean=0, bob=0),
    BodyPose("idle_3", "three", lean=-4, bob=-4),
    BodyPose("run_0", "side", lean=36, bob=-14, leg_a=40, leg_b=-44),
    BodyPose("run_1", "side", lean=24, bob=4, leg_a=-16, leg_b=18),
    BodyPose("run_2", "side", lean=38, bob=-16, leg_a=-42, leg_b=38),
    BodyPose("run_3", "side", lean=22, bob=6, leg_a=18, leg_b=-14),
    BodyPose("cheer", "three", arms_up=True, face="happy"),
    BodyPose("think", "three", face="idle"),
    BodyPose("read", "three"),
    BodyPose("coffee", "three"),
    BodyPose("work", "sit"),
    BodyPose("sleep", "sit", sleep=True, face="sleep"),
]


def origin(pose: BodyPose) -> tuple[float, float]:
    # feet / sit origin in 1024 space
    cx = 512 + pose.lean
    cy = 430 + pose.bob
    if pose.view == "sit":
        cy = 470 + pose.bob
    return cx, cy


def draw_shadow(pose: BodyPose) -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, _ = origin(pose)
    y = 930
    w = 210 if pose.view != "sit" else 240
    ellipse(d, cx, y, w, 28, SHADOW)
    return img.filter(ImageFilter.GaussianBlur(radius=SS * 2))


def draw_body(pose: BodyPose) -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(pose)
    view = pose.view

    # legs
    if view == "sit":
        ellipse(d, cx - 90, cy + 230, 70, 36, INK)
        ellipse(d, cx + 90, cy + 230, 70, 36, INK)
    elif view == "front":
        round_rect(d, cx - 78, cy + 200, cx - 38, cy + 340, 22, INK)
        round_rect(d, cx + 38, cy + 200, cx + 78, cy + 340, 22, INK)
        ellipse(d, cx - 58, cy + 348, 28, 14, INK)
        ellipse(d, cx + 58, cy + 348, 28, 14, INK)
    elif view == "back":
        round_rect(d, cx - 78, cy + 200, cx - 38, cy + 340, 22, INK)
        round_rect(d, cx + 38, cy + 200, cx + 78, cy + 340, 22, INK)
        ellipse(d, cx - 58, cy + 348, 28, 14, INK)
        ellipse(d, cx + 58, cy + 348, 28, 14, INK)
    else:  # side / three
        a = pose.leg_a
        b = pose.leg_b
        # back leg then front leg
        round_rect(d, cx - 30 + a * 0.15, cy + 190, cx + 18 + a * 0.15, cy + 340 + a * 0.1, 20, INK)
        round_rect(d, cx + 40 + b * 0.15, cy + 190, cx + 88 + b * 0.15, cy + 340 + b * 0.1, 20, INK)
        ellipse(d, cx - 6 + a * 0.15, cy + 348 + a * 0.1, 30, 14, INK)
        ellipse(d, cx + 64 + b * 0.15, cy + 348 + b * 0.1, 30, 14, INK)

    # body
    if view == "sit":
        ellipse(d, cx, cy + 140, 210, 150, INK)
    elif view in ("front", "back"):
        ellipse(d, cx, cy + 150, 168, 150, INK)
    else:
        ellipse(d, cx + 20, cy + 150, 190, 130, INK)

    # arms
    if pose.arms_up:
        ellipse(d, cx - 210, cy - 20, 48, 70, INK)
        ellipse(d, cx + 210, cy - 20, 48, 70, INK)
    elif view == "sit":
        ellipse(d, cx - 200, cy + 90, 46, 60, INK)
        ellipse(d, cx + 200, cy + 90, 46, 60, INK)
    elif view == "front":
        ellipse(d, cx - 175, cy + 110, 40, 62, INK)
        ellipse(d, cx + 175, cy + 110, 40, 62, INK)
    elif view == "back":
        ellipse(d, cx - 170, cy + 110, 38, 58, INK)
        ellipse(d, cx + 170, cy + 110, 38, 58, INK)
    elif view == "side":
        ellipse(d, cx + 110, cy + 100, 36, 58, INK)
    else:
        ellipse(d, cx - 175, cy + 100, 42, 60, INK)
        ellipse(d, cx + 195, cy + 105, 40, 58, INK)

    # head
    hx, hy = cx, cy - 40
    if view == "side":
        hx = cx + 36
        ellipse(d, hx, hy, 168, 168, INK)
        # snout
        ellipse(d, hx + 140, hy + 30, 70, 52, INK)
        # ears
        ellipse(d, hx - 90, hy - 150, 32, 48, INK)
        ellipse(d, hx - 20, hy - 158, 28, 44, INK)
        if pose.face != "sleep":
            ellipse(d, hx + 40, hy - 20, 52, 72, WHITE)
        else:
            d.arc([px(hx + 10), px(hy - 20), px(hx + 90), px(hy + 20)], 200, 340, fill=WHITE, width=px(10))
    elif view == "back":
        ellipse(d, hx, hy, 176, 176, INK)
        ellipse(d, hx - 70, hy - 150, 34, 50, INK)
        ellipse(d, hx + 70, hy - 150, 34, 50, INK)
    else:
        # front / three-quarter / sit : blob head like the bible
        ellipse(d, hx, hy, 188, 188, INK)
        ellipse(d, hx - 78, hy - 150, 30, 46, INK)
        ellipse(d, hx + 78, hy - 150, 30, 46, INK)
        if pose.face == "sleep":
            d.arc([px(hx - 90), px(hy - 30), px(hx - 20), px(hy + 20)], 200, 340, fill=WHITE, width=px(10))
            d.arc([px(hx + 20), px(hy - 30), px(hx + 90), px(hy + 20)], 200, 340, fill=WHITE, width=px(10))
        else:
            # huge white eyes
            ex = 48 if view == "three" else 0
            ellipse(d, hx - 58 + ex, hy - 18, 58, 82, WHITE)
            ellipse(d, hx + 62 + ex, hy - 18, 58, 82, WHITE)
            if pose.face == "happy":
                ellipse(d, hx + 150, hy - 120, 16, 16, (255, 220, 90, 255))
                ellipse(d, hx + 175, hy - 90, 10, 10, (255, 220, 90, 255))
            if pose.face == "angry":
                d.polygon(
                    [
                        (px(hx - 110), px(hy - 90)),
                        (px(hx - 20), px(hy - 50)),
                        (px(hx - 110), px(hy - 40)),
                    ],
                    fill=INK,
                )
    return img


def draw_scarf(pose: BodyPose, fill=CYAN, fill_d=CYAN_D) -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(pose)
    view = pose.view
    hx, hy = cx, cy - 40
    if view == "side":
        hx = cx + 36
        # neck band
        round_rect(d, hx - 90, hy + 70, hx + 80, hy + 150, 40, fill)
        # tails hanging back-left
        d.polygon(
            [
                (px(hx - 70), px(hy + 90)),
                (px(hx - 170), px(hy + 200)),
                (px(hx - 120), px(hy + 230)),
                (px(hx - 40), px(hy + 120)),
            ],
            fill=fill_d,
        )
        d.polygon(
            [
                (px(hx - 50), px(hy + 100)),
                (px(hx - 130), px(hy + 240)),
                (px(hx - 80), px(hy + 250)),
                (px(hx - 10), px(hy + 120)),
            ],
            fill=fill,
        )
        return img
    if view == "back":
        round_rect(d, hx - 140, hy + 70, hx + 140, hy + 155, 42, fill)
        ellipse(d, hx, hy + 150, 50, 28, fill_d)
        return img
    # front / three / sit : bible wrap + two tails on the left
    ox = 36 if view == "three" else 0
    round_rect(d, hx - 150 + ox, hy + 70, hx + 150 + ox, hy + 160, 48, fill)
    d.polygon(
        [
            (px(hx - 120 + ox), px(hy + 90)),
            (px(hx - 230 + ox), px(hy + 230)),
            (px(hx - 170 + ox), px(hy + 270)),
            (px(hx - 70 + ox), px(hy + 130)),
        ],
        fill=fill_d,
    )
    d.polygon(
        [
            (px(hx - 90 + ox), px(hy + 100)),
            (px(hx - 180 + ox), px(hy + 280)),
            (px(hx - 120 + ox), px(hy + 290)),
            (px(hx - 40 + ox), px(hy + 130)),
        ],
        fill=fill,
    )
    return img


def tint_white_scarf(pose: BodyPose) -> Image.Image:
    return draw_scarf(pose, fill=WHITE, fill_d=(230, 230, 230, 255))


def draw_prop_desk() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    # isometric-ish white desk, bottom-center
    round_rect(d, 140, 620, 884, 760, 28, (247, 251, 255, 255), outline=(210, 228, 240, 255), width=6)
    round_rect(d, 190, 760, 240, 900, 8, (232, 242, 250, 255))
    round_rect(d, 784, 760, 834, 900, 8, (232, 242, 250, 255))
    round_rect(d, 700, 760, 860, 880, 16, (244, 249, 252, 255), outline=(210, 228, 240, 255), width=4)
    return img


def draw_prop_chair() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 380, 640, 644, 720, 24, (247, 251, 255, 255), outline=(210, 228, 240, 255), width=6)
    round_rect(d, 430, 720, 470, 900, 10, (232, 242, 250, 255))
    round_rect(d, 554, 720, 594, 900, 10, (232, 242, 250, 255))
    return img


def draw_prop_screen() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 360, 430, 664, 650, 28, (236, 244, 250, 255), outline=(210, 228, 240, 255), width=6)
    round_rect(d, 388, 458, 636, 610, 16, (91, 159, 255, 255))
    round_rect(d, 492, 650, 532, 700, 6, (220, 232, 240, 255))
    round_rect(d, 400, 700, 624, 724, 8, (236, 244, 250, 255), outline=(210, 228, 240, 255), width=4)
    return img


def draw_prop_zzz() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    for i, (x, y, r) in enumerate([(640, 280, 18), (700, 210, 26), (780, 140, 34)]):
        ellipse(d, x, y, r, r, (176, 196, 214, 220))
    return img


def draw_prop_coffee() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 700, 560, 800, 700, 28, (247, 251, 255, 255), outline=(210, 228, 240, 255), width=5)
    round_rect(d, 700, 610, 800, 660, 16, CYAN)
    ellipse(d, 750, 560, 40, 16, (107, 58, 26, 255))
    d.arc([px(800), px(590), px(860), px(670)], 270, 90, fill=(210, 228, 240, 255), width=px(8))
    return img


def draw_prop_paper() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 660, 520, 860, 760, 18, (255, 214, 90, 255))
    round_rect(d, 690, 560, 830, 580, 6, (255, 236, 160, 255))
    round_rect(d, 690, 610, 800, 628, 6, (255, 236, 160, 255))
    round_rect(d, 690, 660, 820, 678, 6, (255, 236, 160, 255))
    return img


def draw_prop_bulb() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    ellipse(d, 780, 220, 70, 70, (255, 220, 80, 255))
    round_rect(d, 752, 280, 808, 340, 10, (236, 244, 250, 255), outline=(210, 228, 240, 255), width=4)
    d.polygon([(px(750), px(200)), (px(810), px(200)), (px(780), px(140))], fill=(255, 220, 80, 255))
    return img


def draw_prop_browser() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 160, 180, 864, 760, 36, (247, 251, 255, 255), outline=(210, 228, 240, 255), width=6)
    round_rect(d, 160, 180, 864, 260, 36, (232, 242, 250, 255))
    ellipse(d, 210, 220, 12, 12, (255, 92, 140, 255))
    ellipse(d, 250, 220, 12, 12, (255, 210, 80, 255))
    ellipse(d, 290, 220, 12, 12, (92, 201, 110, 255))
    round_rect(d, 340, 200, 780, 240, 16, (255, 255, 255, 255), outline=(210, 228, 240, 255), width=3)
    round_rect(d, 200, 300, 824, 700, 16, (232, 244, 255, 255))
    round_rect(d, 240, 340, 500, 380, 8, (61, 218, 240, 255))
    round_rect(d, 240, 420, 700, 452, 8, (210, 228, 240, 255))
    round_rect(d, 240, 480, 640, 512, 8, (210, 228, 240, 255))
    return img


def draw_prop_video() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    round_rect(d, 180, 240, 844, 720, 32, (18, 22, 30, 255))
    round_rect(d, 180, 240, 844, 620, 32, (40, 56, 78, 255))
    d.polygon([(px(460), px(380)), (px(460), px(500)), (px(580), px(440))], fill=WHITE)
    round_rect(d, 220, 650, 700, 678, 8, (61, 218, 240, 255))
    ellipse(d, 720, 664, 14, 14, WHITE)
    return img


def draw_acc_hat() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(BodyPose("stand", "three"))
    ellipse(d, cx + 20, cy - 210, 170, 28, INK)
    round_rect(d, cx - 70, cy - 300, cx + 110, cy - 200, 40, INK)
    return img


def draw_acc_headset() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(BodyPose("stand", "three"))
    d.arc([px(cx - 160), px(cy - 220), px(cx + 200), px(cy + 40)], 200, 340, fill=CYAN, width=px(22))
    ellipse(d, cx - 150, cy - 20, 48, 58, CYAN)
    ellipse(d, cx + 190, cy - 20, 48, 58, CYAN)
    return img


def draw_acc_backpack() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(BodyPose("stand", "three"))
    round_rect(d, cx - 40, cy + 40, cx + 160, cy + 250, 36, CYAN)
    round_rect(d, cx + 20, cy + 80, cx + 100, cy + 150, 16, INK)
    return img


def draw_acc_crown() -> Image.Image:
    img = blank()
    d = ImageDraw.Draw(img)
    cx, cy = origin(BodyPose("stand", "three"))
    y = cy - 250
    d.polygon(
        [
            (px(cx - 90), px(y)),
            (px(cx - 70), px(y - 70)),
            (px(cx - 10), px(y - 20)),
            (px(cx + 40), px(y - 80)),
            (px(cx + 90), px(y - 20)),
            (px(cx + 140), px(y - 70)),
            (px(cx + 160), px(y)),
        ],
        fill=(245, 200, 74, 255),
    )
    return img


def pose_by_name(name: str) -> BodyPose:
    for p in BODY_POSES:
        if p.name == name:
            return p
    raise KeyError(name)


def write_manifest(files: dict) -> None:
    data = {
        "version": 2,
        "size": OUT_SIZE,
        "transparent": True,
        "note": "Rebuilt from the horse bible. Independent layers for Spine / dressing.",
        "body": files["body"],
        "scarf_mask": files["scarf_mask"],
        "scarf_colors": list(SCARF_COLORS),
        "acts": ["work", "read", "coffee", "think", "cheer", "sleep"],
        "props": files["props"],
        "accessories": files["acc"],
        "game_map": {
            "idle": ["idle_0", "idle_1", "idle_2", "idle_3"],
            "walk": ["walk_0", "walk_1", "walk_2", "walk_3"],
            "run": ["run_0", "run_1", "run_2", "run_3"],
            "WORK": "work",
            "SLACK": "sleep",
            "COFFEE": "coffee",
            "MEETING": "read",
        },
    }
    path = os.path.join(OUT, "manifest.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def copy_preview():
    dest = os.path.join(PREVIEW, "game")
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(OUT, dest)
    html = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>六点下班 · 1024 分层资产</title>
  <style>
    :root { --bg:#07080c; --card:#12141c; --ink:#f4f7fb; --muted:#8b93a7; --line:#1d2230; --cyan:#3ddaf0; }
    * { box-sizing: border-box; }
    body { margin:0; background:var(--bg); color:var(--ink); font-family:"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif; }
    main { max-width:1240px; margin:0 auto; padding:40px 24px 80px; }
    h1 { font-size:32px; margin:0 0 8px; }
    .lead { color:var(--muted); line-height:1.65; max-width:820px; }
    h2 { color:var(--cyan); font-size:20px; margin:40px 0 12px; }
    h3 { color:var(--muted); font-size:13px; margin:16px 0 8px; }
    .row { display:flex; flex-wrap:wrap; gap:14px; }
    figure { margin:0; width:168px; background:var(--card); border:1px solid var(--line); border-radius:18px; padding:10px; text-align:center; }
    figure.wide { width:220px; }
    figure img { width:100%; height:148px; object-fit:contain; background:
      linear-gradient(45deg,#1a1d27 25%,transparent 25%),
      linear-gradient(-45deg,#1a1d27 25%,transparent 25%),
      linear-gradient(45deg,transparent 75%,#1a1d27 75%),
      linear-gradient(-45deg,transparent 75%,#1a1d27 75%);
      background-size:16px 16px; background-position:0 0,0 8px,8px -8px,-8px 0; border-radius:12px; }
    figcaption { color:var(--muted); font-size:12px; margin-top:6px; }
    .checker img { background-color:#fff; background-image:
      linear-gradient(45deg,#eceff4 25%,transparent 25%),
      linear-gradient(-45deg,#eceff4 25%,transparent 25%),
      linear-gradient(45deg,transparent 75%,#eceff4 75%),
      linear-gradient(-45deg,transparent 75%,#eceff4 75%);
      background-size:16px 16px; background-position:0 0,0 8px,8px -8px,-8px 0; }
  </style>
</head>
<body>
<main>
  <h1>小马 1024 分层资产</h1>
  <p class="lead">按设定图重建，不是裁切放大。每张 1024×1024 透明 PNG。身体 / 围巾 / 桌椅屏幕 / UI 分文件，后续换围巾、换装和 Spine 可以直接叠层。</p>

  <h2>1. 基础身体（无围巾）</h2>
  <p class="lead">正、侧、背、坐、站，以及行走四帧。透明底用浅色棋盘格显示。</p>
  <div class="row checker" id="body"></div>

  <h2>2. 围巾（独立层，可换色）</h2>
  <h3>白色遮罩 · 给 Spine / 引擎染色</h3>
  <div class="row checker" id="scarf-mask"></div>
  <h3>六色成品 · 叠在站立身体上</h3>
  <div class="row checker" id="scarf-color"></div>

  <h2>3. 六个工作动作</h2>
  <div class="row checker" id="acts"></div>

  <h2>4. 道具层</h2>
  <div class="row checker" id="props"></div>

  <h2>5. 装饰独立层</h2>
  <div class="row checker" id="acc"></div>
</main>
<script>
  const fig = (src, cap, extra="") =>
    `<figure class="${extra}"><img src="${src}" alt="${cap}"><figcaption>${cap}</figcaption></figure>`;
  const body = ["front","side","back","sit","stand","walk_0","walk_1","walk_2","walk_3"];
  document.getElementById("body").innerHTML = body.map(n => fig("game/layers/body/"+n+".png", n)).join("");
  document.getElementById("scarf-mask").innerHTML = ["front","side","back","sit","stand"].map(n => fig("game/layers/scarf/mask_"+n+".png", "mask "+n)).join("");
  const colors = ["cyan","yellow","red","purple","green","pink"];
  document.getElementById("scarf-color").innerHTML = colors.map(n => fig("game/chars/horse/stand_"+n+".png", n)).join("");
  const acts = ["work","read","coffee","think","cheer","sleep"];
  document.getElementById("acts").innerHTML = acts.map(n => fig("game/chars/horse/"+n+".png", n)).join("");
  const props = ["desk","chair","screen","zzz","coffee","paper","bulb","browser_ui","video_ui"];
  document.getElementById("props").innerHTML = props.map(n => fig("game/layers/props/"+n+".png", n, "wide")).join("");
  const acc = ["hat","headset","backpack","crown"];
  document.getElementById("acc").innerHTML = acc.map(n => fig("game/layers/acc/"+n+".png", n)).join("");
</script>
</body>
</html>
"""
    os.makedirs(PREVIEW, exist_ok=True)
    with open(os.path.join(PREVIEW, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    files = {"body": [], "scarf_mask": [], "props": [], "acc": []}
    # body + scarf masks for every pose
    for pose in BODY_POSES:
        shadow = draw_shadow(pose)
        body = draw_body(pose)
        scarf = draw_scarf(pose)
        mask = tint_white_scarf(pose)
        save(body, os.path.join(LAYERS, "body", f"{pose.name}.png"))
        save(mask, os.path.join(LAYERS, "scarf", f"mask_{pose.name}.png"))
        save(scarf, os.path.join(LAYERS, "scarf", f"cyan_{pose.name}.png"))
        files["body"].append(f"layers/body/{pose.name}.png")
        files["scarf_mask"].append(f"layers/scarf/mask_{pose.name}.png")
        # default cyan composite for game
        save(composite([shadow, body, scarf]), os.path.join(OUT, "chars", "horse", f"{pose.name}.png"))

    # 6 scarf colors on stand
    stand = pose_by_name("stand")
    shadow = draw_shadow(stand)
    body = draw_body(stand)
    for name, (c, cd) in SCARF_COLORS.items():
        sc = draw_scarf(stand, fill=c, fill_d=cd)
        save(sc, os.path.join(LAYERS, "scarf", f"{name}_stand.png"))
        save(composite([shadow, body, sc]), os.path.join(OUT, "chars", "horse", f"stand_{name}.png"))

    # accessories
    accs = {
        "hat": draw_acc_hat,
        "headset": draw_acc_headset,
        "backpack": draw_acc_backpack,
        "crown": draw_acc_crown,
    }
    for name, fn in accs.items():
        img = fn()
        save(img, os.path.join(LAYERS, "acc", f"{name}.png"))
        files["acc"].append(f"layers/acc/{name}.png")
        save(composite([shadow, body, draw_scarf(stand), img]), os.path.join(OUT, "chars", "horse", f"stand_{name}.png"))

    # props
    props = {
        "desk": draw_prop_desk,
        "chair": draw_prop_chair,
        "screen": draw_prop_screen,
        "zzz": draw_prop_zzz,
        "coffee": draw_prop_coffee,
        "paper": draw_prop_paper,
        "bulb": draw_prop_bulb,
        "browser_ui": draw_prop_browser,
        "video_ui": draw_prop_video,
    }
    for name, fn in props.items():
        img = fn()
        save(img, os.path.join(LAYERS, "props", f"{name}.png"))
        # also into game props for the office map
        save(img, os.path.join(OUT, "props", f"{name}.png"))
        files["props"].append(f"layers/props/{name}.png")

    # six work action composites (body + scarf + relevant props)
    work_layers = {
        "work": ["desk", "chair", "screen"],
        "read": ["paper"],
        "coffee": ["coffee"],
        "think": ["bulb"],
        "cheer": [],
        "sleep": ["desk", "zzz"],
    }
    for act, extra in work_layers.items():
        pose = pose_by_name(act)
        parts = [draw_shadow(pose)]
        if "desk" in extra:
            parts.append(draw_prop_desk())
        if "chair" in extra:
            parts.append(draw_prop_chair())
        parts.append(draw_body(pose))
        parts.append(draw_scarf(pose))
        if "screen" in extra:
            parts.append(draw_prop_screen())
        if "paper" in extra:
            parts.append(draw_prop_paper())
        if "coffee" in extra:
            parts.append(draw_prop_coffee())
        if "bulb" in extra:
            parts.append(draw_prop_bulb())
        if "zzz" in extra:
            parts.append(draw_prop_zzz())
        save(composite(parts), os.path.join(OUT, "chars", "horse", f"{act}.png"))

    # other characters: same pony body, scarf recolor (independent layer)
    others = {
        "rabbit": "yellow",
        "penguin": "purple",
        "panda": "pink",
        "tiger": "red",
    }
    for pack, color_name in others.items():
        c, cd = SCARF_COLORS[color_name]
        for pose in BODY_POSES:
            sh = draw_shadow(pose)
            bd = draw_body(pose)
            sc = draw_scarf(pose, fill=c, fill_d=cd)
            parts = [sh, bd, sc]
            if pack == "tiger" and pose.name in ("stand", "idle_0", "front"):
                parts.append(draw_acc_crown())
            save(composite(parts), os.path.join(OUT, "chars", pack, f"{pose.name}.png"))
        shutil.copy2(os.path.join(OUT, "chars", pack, "stand.png"), os.path.join(OUT, "chars", pack, "portrait.png"))
        shutil.copy2(os.path.join(OUT, "chars", pack, "stand.png"), os.path.join(OUT, "chars", pack, "face_idle.png"))
        for act, extra in work_layers.items():
            pose = pose_by_name(act)
            c, cd = SCARF_COLORS[color_name]
            parts = [draw_shadow(pose)]
            if "desk" in extra:
                parts.append(draw_prop_desk())
            if "chair" in extra:
                parts.append(draw_prop_chair())
            parts.append(draw_body(pose))
            parts.append(draw_scarf(pose, fill=c, fill_d=cd))
            if "screen" in extra:
                parts.append(draw_prop_screen())
            if "paper" in extra:
                parts.append(draw_prop_paper())
            if "coffee" in extra:
                parts.append(draw_prop_coffee())
            if "bulb" in extra:
                parts.append(draw_prop_bulb())
            if "zzz" in extra:
                parts.append(draw_prop_zzz())
            save(composite(parts), os.path.join(OUT, "chars", pack, f"{act}.png"))

    # aliases used by current CharKit
    alias = {
        "idle_0": "idle_0",
        "portrait": "stand",
        "face_idle": "stand",
    }
    horse_dir = os.path.join(OUT, "chars", "horse")
    shutil.copy2(os.path.join(horse_dir, "stand.png"), os.path.join(horse_dir, "portrait.png"))
    shutil.copy2(os.path.join(horse_dir, "stand.png"), os.path.join(horse_dir, "face_idle.png"))

    write_manifest(files)
    copy_preview()
    print("layers", LAYERS)
    print("preview", os.path.join(PREVIEW, "index.html"))


if __name__ == "__main__":
    main()
