"""Copy the new horse pose pack into every employee character folder."""
from pathlib import Path
import shutil

ROOT = Path(r"d:\idea_project\liudian-xiaban")
HORSE = ROOT / "assets" / "game" / "chars" / "horse"
HD = ROOT / "assets" / "horse" / "hd"

POSES = [
    "idle_0", "idle_1", "idle_2", "idle_3",
    "walk_0", "walk_1", "walk_2", "walk_3",
    "run_0", "run_1", "run_2", "run_3",
    "work", "sleep", "coffee", "think", "cheer", "read",
    "portrait", "stand", "side",
]

# Replace leftover front-blob poses with the new idle.
for name in ("sit", "front", "back"):
    src = HORSE / "idle_0.png"
    dst = HORSE / f"{name}.png"
    shutil.copy2(src, dst)

# If HD has a better portrait, keep horse folder as source of truth (already copied earlier).
for pack in ("rabbit", "penguin", "panda"):
    dest = ROOT / "assets" / "game" / "chars" / pack
    dest.mkdir(parents=True, exist_ok=True)
    for pose in POSES + ["sit", "front", "back"]:
        src = HORSE / f"{pose}.png"
        if src.exists():
            shutil.copy2(src, dest / f"{pose}.png")
    print(pack, "copied", len(list(dest.glob("*.png"))))

print("horse sit/front/back refreshed")
