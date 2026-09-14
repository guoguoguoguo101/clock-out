"""Crop every labeled sprite from the 1024x682 horse bible."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"d:\idea_project\liudian-xiaban")
SRC = ROOT / "assets" / "concept" / "horse-bible.jpg"
CROP = ROOT / "assets" / "horse" / "crops"
DBG = ROOT / "assets" / "horse" / "_debug"
CROP.mkdir(parents=True, exist_ok=True)
DBG.mkdir(parents=True, exist_ok=True)

im = Image.open(SRC).convert("RGB")
preview = im.copy()
dr = ImageDraw.Draw(preview)


def save(box, rel):
    x0, y0, x1, y1 = box
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(im.width, x1), min(im.height, y1)
    path = CROP / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"")  # ensure parent
    crop = im.crop((x0, y0, x1, y1))
    crop.save(path)
    dr.rectangle((x0, y0, x1, y1), outline=(0, 220, 255), width=1)
    dr.text((x0 + 2, y0 + 2), path.stem[:10], fill=(255, 200, 40))
    return path


# --- 主角色 ---
save((12, 52, 162, 292), "00_portrait/hero.jpg")
save((18, 250, 150, 292), "00_portrait/palette.jpg")

# --- 基础动作 3x4 ---
# card ~ (168, 12)-(468, 300); left labels; 4 frames
idle_y = (52, 118)
walk_y = (128, 198)
run_y = (208, 292)
xs = [(214, 274), (276, 336), (338, 398), (400, 462)]
for i, (x0, x1) in enumerate(xs):
    save((x0, idle_y[0], x1, idle_y[1]), f"01_idle/idle_{i}.jpg")
    save((x0, walk_y[0], x1, walk_y[1]), f"02_walk/walk_{i}.jpg")
    save((x0, run_y[0], x1, run_y[1]), f"03_run/run_{i}.jpg")

# --- 交互动作 2x3 ---
act_cells = [
    ((478, 52, 568, 148), "work"),
    ((572, 52, 662, 148), "read"),
    ((666, 52, 756, 148), "coffee"),
    ((478, 156, 568, 292), "think"),
    ((572, 156, 662, 292), "cheer"),
    ((666, 156, 756, 292), "sleep"),
]
for box, name in act_cells:
    save(box, f"04_acts/{name}.jpg")

# --- 表情 3x3 ---
face_names = [
    ["idle", "happy", "proud"],
    ["angry", "confused", "question"],
    ["shock", "awkward", "love"],
]
fx0, fy0 = 768, 48
fw, fh = 80, 80
for r, row in enumerate(face_names):
    for c, name in enumerate(row):
        x0 = fx0 + c * fw
        y0 = fy0 + r * fh
        save((x0, y0, x0 + fw, y0 + fh), f"05_faces/{name}.jpg")

# --- 道具 2x8 ---
prop_names = [
    ["bag", "coffee", "laptop", "paper", "pencil", "books", "plant", "headset"],
    ["phone", "drink", "cookie", "gift", "coin", "star", "heart", "bulb"],
]
px0, py0 = 16, 348
pw, ph = 46, 62
for r, row in enumerate(prop_names):
    for c, name in enumerate(row):
        x0 = px0 + c * pw
        y0 = py0 + r * ph
        save((x0, y0, x0 + pw - 2, y0 + ph - 2), f"06_props/{name}.jpg")

# --- 六色围巾 ---
colors = ["cyan", "yellow", "red", "purple", "green", "pink"]
cx0, cy0, cw = 412, 348, 50
for i, name in enumerate(colors):
    save((cx0 + i * cw, cy0, cx0 + (i + 1) * cw - 2, 456), f"07_colors/{name}.jpg")

# --- 服饰 ---
acc = ["hat", "headset", "backpack", "crown"]
ax0, aw = 732, 70
for i, name in enumerate(acc):
    save((ax0 + i * aw, 348, ax0 + (i + 1) * aw - 2, 456), f"08_acc/{name}.jpg")

# --- 场景 5 格 ---
scenes = ["move", "stairs", "jump", "interact", "door"]
sx0, sw = 12, 102
for i, name in enumerate(scenes):
    save((sx0 + i * sw, 508, sx0 + (i + 1) * sw - 4, 660), f"09_scenes/{name}.jpg")

# --- UI ---
ui = [
    ((540, 508, 600, 568), "collect"),
    ((604, 508, 664, 568), "task"),
    ((540, 572, 600, 632), "bag"),
    ((604, 572, 664, 632), "settings"),
    ((536, 628, 700, 668), "hud"),
    ((536, 500, 720, 668), "ui_panel"),
]
for box, name in ui:
    save(box, f"10_ui/{name}.jpg")

# --- 其他 ---
extras = [
    ((732, 508, 812, 600), "peek"),
    ((816, 508, 900, 600), "hide"),
    ((904, 508, 1012, 600), "dash"),
    ((732, 604, 820, 668), "lie"),
    ((900, 600, 1012, 668), "bubble"),
]
for box, name in extras:
    save(box, f"11_extras/{name}.jpg")

preview.save(DBG / "crop_boxes.jpg", quality=90)
n = len(list(CROP.rglob("*.jpg")))
print("crops", n)
print("preview", DBG / "crop_boxes.jpg")
