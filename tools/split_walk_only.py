"""Split horse_walk_cycle.png into four 1024 walk frames. Does not import split_horse_hd."""
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Load helpers without running process_all: exec only the top of the file
src = Path(__file__).with_name("split_horse_hd.py").read_text(encoding="utf-8")
head = src.split("def process_all")[0]
ns: dict = {}
exec(head, ns)

ROOT = ns["ROOT"]
SHEETS = ns["SHEETS"]
HD = ns["GAME"].parent.parent.parent / "horse" / "hd"
# HD is assets/horse/hd
HD = ROOT / "assets" / "horse" / "hd"
GAME = ns["GAME"]
CURSOR = Path(r"C:\Users\guohongzhi\.cursor\projects\d-idea-project-liudian-xiaban\assets")

cycle = CURSOR / "horse_walk_cycle.png"
shutil.copy2(cycle, SHEETS / "horse_walk_cycle.png")
shutil.copy2(cycle, SHEETS / "horse_walk_strip.png")

im = ns["knock_white"](ns["Image"].open(SHEETS / "horse_walk_cycle.png"))
frames = ns["split_axis"](im, "x", 4)
ns["save_list"](frames, ["walk_0", "walk_1", "walk_2", "walk_3"], "02_walk")
for i in range(4):
    shutil.copy2(HD / f"02_walk/walk_{i}.png", GAME / f"walk_{i}.png")
print("walk frames", [p.name for p in (HD / "02_walk").glob("*.png")])
