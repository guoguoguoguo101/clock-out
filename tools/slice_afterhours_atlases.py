"""Slice the generated environment atlases into Godot-friendly individual PNGs."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def slice_grid(source: Path, destination: Path, columns: int, rows: int, prefix: str) -> None:
    image = Image.open(source).convert("RGBA")
    cell_width = image.width / columns
    cell_height = image.height / rows
    destination.mkdir(parents=True, exist_ok=True)
    for row in range(rows):
        for column in range(columns):
            left = round(column * cell_width)
            top = round(row * cell_height)
            right = round((column + 1) * cell_width)
            bottom = round((row + 1) * cell_height)
            index = row * columns + column + 1
            image.crop((left, top, right, bottom)).save(destination / f"{prefix}-{index:02d}.png")


def main() -> None:
    atlas_dir = ROOT / "assets/concept/afterhours/atlases"
    slice_grid(atlas_dir / "notice-atlas-01.png", ROOT / "assets/concept/afterhours/posters", 3, 4, "notice")
    slice_grid(atlas_dir / "monitor-atlas-01.png", ROOT / "assets/concept/afterhours/monitors", 3, 2, "monitor")


if __name__ == "__main__":
    main()
