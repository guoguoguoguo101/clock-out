#!/usr/bin/env python3
"""Scan live game assets and rebuild preview/index.html."""

from __future__ import annotations

import json
import re
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUT_HTML = ROOT / "preview" / "index.html"
OUT_MANIFEST = ROOT / "preview" / "manifest.json"

SKIP_DIR_PARTS = {"__pycache__", ".git", ".godot"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp"}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}
KEEP_EXT = IMAGE_EXT | AUDIO_EXT
SEQ_RE = re.compile(r"^(?P<stem>.+)_(?P<i>\d+)$")

KIND_LABEL = {
    "chars": "角色",
    "props": "道具",
    "ui": "界面",
    "concept": "概念图",
    "audio": "音频",
    "archived": "废弃",
    "other": "其他",
}

CHAR_LABEL = {
    "horse": "小马",
    "rabbit": "小兔子",
    "cow": "牛",
    "pelican": "鹈鹕",
    "tiger": "老虎",
    "panda": "熊猫",
    "penguin": "企鹅",
    "cat": "猫",
}


def posix(path: Path) -> str:
    return path.as_posix()


def kind_of(rel: Path) -> str:
    parts = rel.parts
    if not parts:
        return "other"
    if parts[0] == "废弃素材":
        return "archived"
    if parts[0] != "game" and "concept" in parts:
        return "concept"
    if len(parts) >= 2 and parts[0] == "game":
        folder = parts[1]
        if folder in KIND_LABEL:
            return folder
    ext = rel.suffix.lower()
    if ext in AUDIO_EXT:
        return "audio"
    return "other"


def group_title(rel: Path, kind: str) -> str:
    parts = rel.parts
    if kind == "archived":
        sub = posix(rel.parent)
        if sub.startswith("废弃素材/"):
            sub = sub[len("废弃素材/") :]
        elif sub == "废弃素材":
            sub = "根目录"
        return f"废弃 · {sub}"
    if kind == "chars" and len(parts) >= 3:
        folder = parts[2]
        return CHAR_LABEL.get(folder, folder)
    if kind == "props" and len(parts) >= 3:
        return "/".join(parts[1:])
    if kind == "ui":
        return "/".join(parts[1:]) if len(parts) > 1 else "界面"
    return str(rel.parent).replace("\\", "/")


def should_skip(path: Path) -> bool:
    return any(part in SKIP_DIR_PARTS for part in path.parts)


def scan() -> dict:
    items: list[dict] = []
    if not ASSETS.is_dir():
        raise SystemExit(f"missing {ASSETS}")
    for path in sorted(ASSETS.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in KEEP_EXT:
            continue
        if should_skip(path.relative_to(ASSETS)):
            continue
        rel = path.relative_to(ASSETS)
        kind = kind_of(rel)
        rec = {
            "rel": posix(rel),
            "src": "../assets/" + posix(rel),
            "name": path.stem,
            "file": path.name,
            "ext": path.suffix.lower(),
            "kind": kind,
            "kind_label": KIND_LABEL.get(kind, kind),
            "group": group_title(rel, kind),
            "folder": posix(rel.parent),
            "bytes": path.stat().st_size,
            "mtime": int(path.stat().st_mtime),
            "w": 0,
            "h": 0,
            "audio": path.suffix.lower() in AUDIO_EXT,
        }
        if rec["ext"] in IMAGE_EXT and rec["ext"] != ".svg":
            try:
                with Image.open(path) as im:
                    rec["w"], rec["h"] = im.size
            except OSError:
                pass
        items.append(rec)

    sequences: list[dict] = []
    by_folder: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for rec in items:
        if rec["audio"]:
            continue
        m = SEQ_RE.match(rec["name"])
        if not m:
            continue
        by_folder[(rec["folder"], m.group("stem"))].append(rec)
    for (folder, stem), frames in by_folder.items():
        indexed = []
        for rec in frames:
            m = SEQ_RE.match(rec["name"])
            indexed.append((int(m.group("i")), rec))
        indexed.sort(key=lambda x: x[0])
        if len(indexed) < 2:
            continue
        nums = [i for i, _ in indexed]
        if nums != list(range(nums[0], nums[-1] + 1)):
            continue
        sequences.append(
            {
                "folder": folder,
                "stem": stem,
                "kind": indexed[0][1]["kind"],
                "group": indexed[0][1]["group"],
                "frames": [rec["src"] + "?t=" + str(rec["mtime"]) for _, rec in indexed],
                "count": len(indexed),
            }
        )

    kinds: dict[str, int] = defaultdict(int)
    for rec in items:
        kinds[rec["kind"]] += 1
    return {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "count": len(items),
        "kinds": dict(kinds),
        "items": items,
        "sequences": sequences,
    }


HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>六点下班 · 素材预览</title>
  <style>
    :root {
      --bg:#0e1116; --panel:#161b22; --ink:#e8edf4; --muted:#8b95a7;
      --line:#2a3340; --accent:#3ee0f2; --warn:#f4c14a;
    }
    * { box-sizing:border-box; }
    html, body { margin:0; background:var(--bg); color:var(--ink);
      font-family:"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif; }
    header {
      position:sticky; top:0; z-index:5;
      display:flex; flex-wrap:wrap; gap:12px; align-items:center;
      padding:14px 20px; background:rgba(14,17,22,.92);
      border-bottom:1px solid var(--line); backdrop-filter:blur(8px);
    }
    h1 { font-size:18px; margin:0; font-weight:650; }
    .meta { color:var(--muted); font-size:12px; }
    input[type=search] {
      flex:1; min-width:180px; max-width:360px;
      background:#0b0e13; color:var(--ink); border:1px solid var(--line);
      border-radius:10px; padding:8px 12px; font-size:14px;
    }
    .tabs { display:flex; gap:6px; flex-wrap:wrap; }
    .tabs button, .copy {
      border:1px solid var(--line); background:var(--panel); color:var(--ink);
      border-radius:999px; padding:6px 12px; cursor:pointer; font-size:12px;
    }
    .tabs button.on { background:var(--accent); color:#072026; border-color:var(--accent); font-weight:650; }
    .tabs button[data-id="archived"].on { background:var(--warn); color:#2a1e00; border-color:var(--warn); }
    figure.archived { border-color:#5a4a22; }
    figure.archived figcaption .tag { color:var(--warn); }
    main { display:grid; grid-template-columns:220px 1fr; min-height:calc(100vh - 64px); }
    nav {
      border-right:1px solid var(--line); padding:16px 12px 40px;
      position:sticky; top:64px; height:calc(100vh - 64px); overflow:auto;
    }
    nav a {
      display:block; color:var(--muted); text-decoration:none; font-size:13px;
      padding:6px 10px; border-radius:8px;
    }
    nav a:hover, nav a.on { background:#1d2430; color:var(--ink); }
    section { padding:20px 24px 64px; }
    h2 { font-size:16px; margin:28px 0 12px; color:var(--accent); }
    h2:first-child { margin-top:0; }
    .row { display:flex; flex-wrap:wrap; gap:12px; }
    figure {
      margin:0; width:156px; background:var(--panel);
      border:1px solid var(--line); border-radius:14px; padding:8px; cursor:pointer;
    }
    figure.wide { width:240px; }
    .thumb {
      width:100%; height:132px; object-fit:contain; border-radius:10px; display:block;
      background:
        linear-gradient(45deg,#2a3140 25%,transparent 25%),
        linear-gradient(-45deg,#2a3140 25%,transparent 25%),
        linear-gradient(45deg,transparent 75%,#2a3140 75%),
        linear-gradient(-45deg,transparent 75%,#2a3140 75%);
      background-size:16px 16px; background-position:0 0,0 8px,8px -8px,-8px 0;
      background-color:#1a1f28;
    }
    figcaption { font-size:11px; color:var(--muted); margin-top:6px; word-break:break-all; line-height:1.35; }
    .stage {
      width:160px; background:var(--panel); border:1px solid var(--line);
      border-radius:14px; padding:8px; text-align:center;
    }
    .stage img { width:140px; height:140px; object-fit:contain; }
    .stage p { margin:6px 0 0; font-size:12px; color:var(--muted); }
    .empty { color:var(--muted); padding:40px 8px; }
    #lightbox {
      display:none; position:fixed; inset:0; background:rgba(0,0,0,.78);
      z-index:20; align-items:center; justify-content:center; padding:24px;
    }
    #lightbox.on { display:flex; }
    #lightbox img { max-width:min(92vw,1100px); max-height:78vh; object-fit:contain; }
    #lightbox .info { position:absolute; bottom:18px; left:0; right:0; text-align:center; color:#fff; font-size:13px; }
    audio { width:140px; }
    @media (max-width:860px) {
      main { grid-template-columns:1fr; }
      nav { position:relative; top:0; height:auto; border-right:0; border-bottom:1px solid var(--line); }
    }
  </style>
</head>
<body>
<header>
  <div>
    <h1>六点下班 · 素材预览</h1>
    <div class="meta" id="meta"></div>
  </div>
  <input id="q" type="search" placeholder="搜文件名 / 路径" />
  <div class="tabs" id="tabs"></div>
</header>
<main>
  <nav id="nav"></nav>
  <section id="board"></section>
</main>
<div id="lightbox"><img alt=""><div class="info"></div></div>
<script>
const DATA = __DATA__;
const KINDS = [
  { id:"all", label:"全部" },
  { id:"chars", label:"角色" },
  { id:"props", label:"道具" },
  { id:"ui", label:"界面" },
  { id:"concept", label:"概念图" },
  { id:"audio", label:"音频" },
  { id:"archived", label:"废弃" },
  { id:"other", label:"其他" },
];
let kind = "all";
let folder = "";
let q = "";
const timers = [];

document.getElementById("meta").textContent =
  `${DATA.count} 个文件 · 生成于 ${DATA.generated_at} · 改完素材后运行 python tools/build_asset_preview.py`;

const tabs = document.getElementById("tabs");
KINDS.forEach(k => {
  if (k.id !== "all" && !DATA.kinds[k.id]) return;
  const b = document.createElement("button");
  b.textContent = k.id === "all" ? `全部 ${DATA.count}` : `${k.label} ${DATA.kinds[k.id]||0}`;
  b.dataset.id = k.id;
  b.className = k.id === kind ? "on" : "";
  b.onclick = () => { kind = k.id; folder = ""; render(); };
  tabs.appendChild(b);
});

const lb = document.getElementById("lightbox");
lb.onclick = () => lb.classList.remove("on");

document.getElementById("q").addEventListener("input", e => {
  q = e.target.value.trim().toLowerCase();
  render();
});

function filtered() {
  return DATA.items.filter(it => {
    if (kind !== "all" && it.kind !== kind) return false;
    if (folder && it.folder !== folder) return false;
    if (!q) return true;
    return (it.rel + " " + it.name + " " + it.group).toLowerCase().includes(q);
  });
}

function renderNav() {
  const folders = {};
  DATA.items.forEach(it => {
    if (kind !== "all" && it.kind !== kind) return;
    folders[it.folder] = (folders[it.folder] || 0) + 1;
  });
  const nav = document.getElementById("nav");
  const keys = Object.keys(folders).sort();
  nav.innerHTML = `<a href="#" class="${folder===""?"on":""}" data-folder="">全部目录</a>` +
    keys.map(f => `<a href="#" class="${folder===f?"on":""}" data-folder="${f}">${f} · ${folders[f]}</a>`).join("");
  nav.querySelectorAll("a").forEach(a => {
    a.onclick = ev => {
      ev.preventDefault();
      folder = a.dataset.folder;
      render();
    };
  });
}

function card(it) {
  const src = it.src + "?t=" + it.mtime;
  const size = it.w ? `${it.w}×${it.h}` : (Math.max(1, Math.round(it.bytes/1024)) + " KB");
  const archived = it.kind === "archived";
  const cls = (it.audio ? "wide" : "") + (archived ? " archived" : "");
  const tag = archived ? `<span class="tag">废弃</span> ` : "";
  if (it.audio) {
    return `<figure class="${cls}"><audio controls src="${src}"></audio><figcaption>${tag}${it.file}<br>${it.rel}</figcaption></figure>`;
  }
  return `<figure class="${cls}" data-src="${src}" data-info="${it.rel} · ${size}">
    <img class="thumb" src="${src}" alt="${it.name}">
    <figcaption>${tag}${it.file}<br>${size}</figcaption>
  </figure>`;
}

function render() {
  timers.splice(0).forEach(clearInterval);
  [...tabs.children].forEach(b => b.classList.toggle("on", b.dataset.id === kind));
  renderNav();
  const items = filtered();
  const board = document.getElementById("board");
  if (!items.length) {
    board.innerHTML = `<p class="empty">没有匹配的素材</p>`;
    return;
  }
  const seqs = DATA.sequences.filter(s => {
    if (kind !== "all" && s.kind !== kind) return false;
    if (folder && s.folder !== folder) return false;
    if (q && !(s.stem + s.folder).toLowerCase().includes(q)) return false;
    return true;
  });
  const byGroup = {};
  items.forEach(it => {
    const g = it.kind_label + " · " + it.group;
    (byGroup[g] = byGroup[g] || []).push(it);
  });
  let html = "";
  if (seqs.length) {
    html += `<h2>循环播放</h2><div class="row" id="loops"></div>`;
  }
  Object.keys(byGroup).sort().forEach(g => {
    html += `<h2>${g} · ${byGroup[g].length}</h2><div class="row">${byGroup[g].map(card).join("")}</div>`;
  });
  board.innerHTML = html;
  board.querySelectorAll("figure[data-src]").forEach(fig => {
    fig.onclick = () => {
      lb.classList.add("on");
      lb.querySelector("img").src = fig.dataset.src;
      lb.querySelector(".info").textContent = fig.dataset.info;
    };
  });
  const loops = document.getElementById("loops");
  if (loops) {
    seqs.forEach(s => {
      const el = document.createElement("div");
      el.className = "stage";
      el.innerHTML = `<img alt="${s.stem}"><p>${s.group} / ${s.stem} · ${s.count}帧</p>`;
      const img = el.querySelector("img");
      let i = 0;
      img.src = s.frames[0];
      timers.push(setInterval(() => {
        i = (i + 1) % s.frames.length;
        img.src = s.frames[i];
      }, 140));
      loops.appendChild(el);
    });
  }
}
render();
</script>
</body>
</html>
"""


def main() -> None:
    data = scan()
    OUT_HTML.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False)
    OUT_HTML.write_text(HTML.replace("__DATA__", payload), encoding="utf-8")
    OUT_MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"preview {data['count']} files -> {OUT_HTML}")
    for k, n in sorted(data["kinds"].items()):
        print(f"  {KIND_LABEL.get(k, k)}: {n}")
    print(f"  sequences: {len(data['sequences'])}")


if __name__ == "__main__":
    t0 = time.time()
    main()
    print(f"done {time.time()-t0:.2f}s")
