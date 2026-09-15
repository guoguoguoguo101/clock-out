"""Invalidate stale horse ctex cache and write scarf .import files."""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(r"d:\idea_project\liudian-xiaban")
IMP = ROOT / ".godot" / "imported"
HORSE = ROOT / "assets" / "game" / "chars" / "horse"
IMPORT_BODY = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{src}"
dest_files=["res://.godot/imported/{dest}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def main() -> None:
    deleted = 0
    for p in HORSE.glob("*.png.import"):
        txt = p.read_text(encoding="utf-8").replace(
            "process/fix_alpha_border=true", "process/fix_alpha_border=false"
        )
        p.write_text(txt, encoding="utf-8")
        m = re.search(r'path="res://\.godot/imported/([^"]+)"', txt)
        if m and IMP.exists():
            ctex = IMP / m.group(1)
            md5 = ctex.with_suffix(".md5")
            for f in (ctex, md5):
                if f.exists():
                    f.unlink()
                    deleted += 1
    wrote = 0
    for png in sorted((HORSE / "scarf").glob("*.png")):
        rel = png.relative_to(ROOT).as_posix()
        digest = hashlib.md5(rel.encode("utf-8")).hexdigest()
        dest = f"{png.name}-{digest}.ctex"
        uid = "c" + digest[:12]
        png.with_suffix(".png.import").write_text(
            IMPORT_BODY.format(uid=uid, dest=dest, src=rel),
            encoding="utf-8",
        )
        wrote += 1
    print("deleted cache", deleted, "scarf imports", wrote)


if __name__ == "__main__":
    main()
