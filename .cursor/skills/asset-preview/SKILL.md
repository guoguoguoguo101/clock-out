---
name: asset-preview
description: >-
  Rebuilds the H5 asset gallery at preview/index.html after any game art is
  added, replaced, cropped, copied, or generated. Use when creating sprites,
  props, UI, concept images, audio, or anything under assets/; when the user
  mentions 素材预览, H5预览, 图鉴, preview/index.html, or asks to generate/import
  art for 《六点下班》.
---

# 素材 H5 预览

《六点下班》的调试图鉴是 `preview/index.html`。**每次写入或改动 `assets/` 里的实际素材后，必须重建它。** 不要手改 `preview/index.html` 或 `preview/manifest.json`。

## 何时做

生成、替换、裁切、拷贝、导出下列任一内容之后立刻重建：

- `assets/game/chars/**`
- `assets/game/props/**`
- `assets/game/ui/**`
- `assets/` 下新的 png / webp / svg / gif / jpg / ogg / wav / mp3
- `assets/废弃素材/**`（预览里单独一个「废弃」分类，方便对照，不要拷回 `assets/game/`）

## 怎么重建

在仓库根目录执行：

```bash
python tools/build_asset_preview.py
```

成功时会打印文件数量，并覆盖：

- `preview/index.html`（打开这个看）
- `preview/manifest.json`

用浏览器打开 `preview/index.html`（相对路径读 `../assets/...`）。改完图若页面还是旧的，硬刷新。

## 新素材怎么放

| 类型 | 路径 |
|---|---|
| 角色帧 | `assets/game/chars/<皮肤>/idle_0.png` 这种 `动作_序号` |
| 家具道具 | `assets/game/props/` 或 `assets/game/props/<分组>/` |
| 界面 | `assets/game/ui/` |
| 概念图 | `assets/concept/` |

同一动作多帧请用 `name_0.png` `name_1.png`… 预览页会自动做成循环播放。

## 做完检查

- [ ] 文件已落到 `assets/`（不是只在 `preview/` 或对话里）
- [ ] 已运行 `python tools/build_asset_preview.py`
- [ ] 告诉用户打开 `preview/index.html`，并说清新增了哪些目录
