"""Copy packed animal frames into Godot game char folders."""
from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(r"d:\idea_project\liudian-xiaban")
PREV = ROOT / "preview" / "sprites"
GAME = ROOT / "assets" / "game" / "chars"

ANIMALS = ["horse", "rabbit", "cow", "pelican"]
FRAMES = [
    "idle_0", "idle_1", "idle_2", "idle_3",
    "walk_0", "walk_1", "walk_2", "walk_3",
    "run_0", "run_1", "run_2", "run_3",
    "work_0", "work_1", "work_2", "work_3", "work",
    "sleep_0", "sleep_1", "sleep_2", "sleep_3", "sleep",
    "toilet_0", "toilet_1", "toilet_2", "toilet_3", "toilet",
    "portrait",
]
ALIASES = {
    "stand.png": "idle_0.png",
    "sit.png": "work.png",
    "front.png": "idle_0.png",
    "side.png": "idle_0.png",
    "back.png": "idle_0.png",
    "coffee.png": "work.png",
    "read.png": "work.png",
    "think.png": "idle_0.png",
}


def main() -> None:
    for animal in ANIMALS:
        src = PREV / animal
        dst = GAME / animal
        dst.mkdir(parents=True, exist_ok=True)
        n = 0
        for name in FRAMES:
            p = src / f"{name}.png"
            if p.exists():
                shutil.copy2(p, dst / f"{name}.png")
                n += 1
        skip_alias = {"coffee.png", "read.png", "think.png"} if animal == "horse" else set()
        for dst_name, src_name in ALIASES.items():
            if dst_name in skip_alias:
                continue
            sp = dst / src_name
            if sp.exists():
                shutil.copy2(sp, dst / dst_name)
        print(animal, n, "->", dst)


if __name__ == "__main__":
    main()
