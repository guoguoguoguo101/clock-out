"""Move unused art into assets/废弃素材. Keep only in-game textures."""
from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(r"d:\idea_project\liudian-xiaban")
UNUSED = ROOT / "assets" / "废弃素材"

KEEP_POSES = {
    "idle_0", "idle_1", "idle_2", "idle_3",
    "walk_0", "walk_1", "walk_2", "walk_3",
    "run_0", "run_1", "run_2", "run_3",
    "work_0", "work_1", "work_2", "work_3",
    "sleep_0", "sleep_1", "sleep_2", "sleep_3",
    "toilet_0", "toilet_1", "toilet_2", "toilet_3",
}
KEEP_CHARS = ["horse", "rabbit", "cow", "pelican", "tiger"]
KEEP_PROPS = {
    "desk", "screen", "chair", "laptop", "paper", "coffee", "plant", "phone",
    "books", "file", "sink", "door", "toilet", "cabinet", "coffee_machine",
    "drink", "water", "sofa", "clock", "browser_ui", "meeting",
}
KEEP_UI = {"hours", "energy"}
MOVED: list[str] = []


def move(src: Path, dest: Path) -> None:
    if not src.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if dest.is_dir() and src.is_dir():
            for child in src.iterdir():
                move(child, dest / child.name)
            if src.exists() and not any(src.iterdir()):
                src.rmdir()
            return
        dest = dest.parent / (dest.name + "_old")
    shutil.move(str(src), str(dest))
    MOVED.append(f"{src.relative_to(ROOT)} -> {dest.relative_to(ROOT)}")


def move_sidecars(src: Path, dest: Path) -> None:
    move(src, dest)
    if src.suffix.lower() == ".png":
        return
    # when moving a png, also move .import if still beside original parent
    # shutil.move already moved the file; sidecars handled in move_png


def move_png_with_import(src: Path, dest: Path) -> None:
    if not src.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dest))
    MOVED.append(src.name)
    imp = Path(str(src) + ".import")
    if imp.exists():
        shutil.move(str(imp), str(dest) + ".import")


def main() -> None:
    UNUSED.mkdir(parents=True, exist_ok=True)
    trees = [
        ("concept", ROOT / "assets" / "concept"),
        ("svg", ROOT / "assets" / "svg"),
        ("horse_src", ROOT / "assets" / "horse"),
        ("rabbit_src", ROOT / "assets" / "rabbit"),
        ("cow_src", ROOT / "assets" / "cow"),
        ("pelican_src", ROOT / "assets" / "pelican"),
        ("sheets", ROOT / "assets" / "sheets"),
        ("props_old", ROOT / "assets" / "props"),
        ("preview_html", ROOT / "assets" / "preview"),
        ("layers", ROOT / "assets" / "game" / "layers"),
        ("chars_panda", ROOT / "assets" / "game" / "chars" / "panda"),
        ("chars_penguin", ROOT / "assets" / "game" / "chars" / "penguin"),
        ("preview_game", ROOT / "preview" / "game"),
        ("preview_sheets", ROOT / "preview" / "sheets"),
    ]
    for name, src in trees:
        move(src, UNUSED / name)

    for html in ["index.html", "horse.html"]:
        src = ROOT / "preview" / html
        if src.exists():
            move(src, UNUSED / "preview_pages" / html)

    man = ROOT / "assets" / "game" / "manifest.json"
    if man.exists():
        move(man, UNUSED / "game_manifest.json")

    chars = ROOT / "assets" / "game" / "chars"
    for animal in KEEP_CHARS:
        folder = chars / animal
        if not folder.exists():
            continue
        extra = UNUSED / "chars_extra" / animal
        extra.mkdir(parents=True, exist_ok=True)
        for png in list(folder.glob("*.png")):
            if png.stem in KEEP_POSES:
                continue
            move_png_with_import(png, extra / png.name)

    props = ROOT / "assets" / "game" / "props"
    extra_props = UNUSED / "props_extra"
    extra_props.mkdir(parents=True, exist_ok=True)
    if props.exists():
        for png in list(props.glob("*.png")):
            if png.stem in KEEP_PROPS:
                continue
            move_png_with_import(png, extra_props / png.name)

    ui = ROOT / "assets" / "game" / "ui"
    extra_ui = UNUSED / "ui_extra"
    extra_ui.mkdir(parents=True, exist_ok=True)
    if ui.exists():
        for png in list(ui.glob("*.png")):
            if png.stem in KEEP_UI:
                continue
            move_png_with_import(png, extra_ui / png.name)

    (UNUSED / ".gdignore").write_text("", encoding="utf-8")
    readme = UNUSED / "说明.txt"
    readme.write_text(
        "\n".join(
            [
                "游戏没用到的素材，从工程里挪出来，避免 Godot 继续导入。",
                "在用的只有：",
                "- assets/game/chars/{horse,rabbit,cow,pelican,tiger} 的站立/走/跑/工作/休息/厕所帧",
                "- assets/game/props 里办公室实际摆出去的家具",
                "- assets/game/ui/hours.png energy.png 和 lobby/",
                "- preview/sprites.html 与 preview/sprites、preview/horse-sprites",
                "",
                "已移动条目：%d" % len(MOVED),
            ]
        ),
        encoding="utf-8",
    )
    print("moved", len(MOVED))
    print("unused", UNUSED)


if __name__ == "__main__":
    main()
