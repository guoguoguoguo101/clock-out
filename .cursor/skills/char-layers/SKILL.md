---
name: char-layers
description: >-
  Builds 《六点下班》 character art as layered base + accessories (body PNG,
  scarf layer, shared toilet/bike). Magenta-key AI gens, split to 1024,
  wire CharKit/Rules, rebuild preview. Use when adding a character, changing
  a skin, redrawing idle/walk/run/work/sleep/toilet/ride, 换装, 围巾, 分层,
  角色素材, or editing assets/game/chars.
---

# 角色分层素材

《六点下班》角色**禁止**把围巾、马桶、整辆车画进身体。一律：

1. **base** = 动物身体（无围巾、无马桶、无整车）
2. **配饰层** = 围巾（每帧一张）+ 公用马桶 / 电瓶车（道具，不跟皮肤走）

马、袋鼠已按这套落地。新增或改任何角色都走本 skill，不要再各写一套抠图脚本，也不要整套 AI 重画来「去白边」。

改完图必须再跑 [asset-preview](../asset-preview/SKILL.md)。出图提示词见 [prompts.md](prompts.md)，游戏接线见 [wiring.md](wiring.md)。

## 何时用

- 新增员工 / 老板皮肤
- 改现有角色某一动作或全套
- 用户说换装、围巾、分层、马桶单独、角色重画

## 目录约定

```
assets/game/chars/<pack>/
  idle_0.png … idle_3.png     # 身体，1024×1024，底对齐，透明底
  walk_0.png … 以及 run/work/sleep/toilet（各 4 帧）
  ride_0.png …                # 仅会骑车的皮肤（袋鼠）
  scarf/<同名>.png            # 灰度围巾，与身体像素对齐
  bowl.png                    # 可选：该皮肤坐姿马桶（无则用公用层）
assets/game/props/
  toilet_sit.png              # 隔间空马桶
  toilet_sit_layer.png        # 1024 坐姿马桶（无 pack bowl 时的回退）
  ebike_back.png / ebike_front.png
assets/废弃素材/chars/<pack>_pre_layers/   # 覆盖前备份，不要拷回 game
```

`<pack>` 与 `CharKit.PACK` 一致：`horse` `rabbit` `cow` `pelican` `kangaroo` `tiger` `dog`。

游戏缩放约 `Rules.SPRITE_SCALE = 0.088`。脚底对齐靠 1024 画布底部留白（拆层脚本 `BOTTOM_PAD = 48`）。

## 分层规则

| 东西 | 画在哪 | 游戏里怎么用 |
|---|---|---|
| 身体、眼睛、手机、笔记本 | `chars/<pack>/*.png` | `Body`，**不要**给非深灰身体上 `BODY_FOR_SKIN` |
| 围巾 | `chars/<pack>/scarf/*.png` | `Scarf`，`modulate = Rules.scarf_color(skin)` |
| 马桶 | 角色坐姿**不画马桶**；公用 `toilet_sit*` / 可选 `bowl.png` | `ToiletBowl` z=0，仅 `TOILET` 状态 |
| 电瓶车 | 角色 `ride` 最多一小截车把 | `RideKit` 的 back/front，不是角色帧 |

## 标准流程

复制并勾选：

```
- [ ] 定 pack 名、识别色、要哪些动作（员工默认 6 动作×4 帧；骑车再加 ride×4）
- [ ] 出图：洋红底 #FF00FF + 身体本色 + 围巾纯青 #24C8F0
- [ ] python tools/split_char_layers.py --pack <pack> --src <gens目录> [--ride]
- [ ] 目视 body / scarf：围巾洞已用身体色填上；没有洋红边
- [ ] toilet 帧没有马桶；若模型仍画出了，用 tools/split_toilet_layer.py 剥掉
- [ ] 接线：CharKit / Rules / 大厅肖像（见 wiring.md）
- [ ] python tools/build_asset_preview.py
- [ ] 告诉用户打开 preview/index.html 硬刷新；游戏需重启（躲开 .ctex 缓存）
```

### 1. 出图

用 `GenerateImage`，`aspect_ratio: "1:1"`，`filename: "<pack>_<pose>.png"`。改现有角色时把该皮肤 `idle_0.png`（或同动作旧帧）放进 `reference_image_paths`。

**每一张**都要：正面/浅 3/4 侧、扁平办公室卡通、透明不要假棋盘——实际用**实心洋红 `#FF00FF` 底**方便抠。身体用该动物的真实毛色，**不要**画成黑剪影（除非用户明确要马那种深灰）。围巾必须是可抠的纯青 `#24C8F0`，不要直接画成最终识别色。

姿势细则、提示词模板：[prompts.md](prompts.md)。

生成文件常落在 Cursor 工程 `assets/`。不要把生图原件直接当游戏帧。

### 2. 拆层

```bash
python tools/split_char_layers.py --pack <pack> --src <生图目录>
# 袋鼠等需要骑车时加 --ride
```

脚本会：抠洋红 → 青像素拆成灰度围巾 → 围巾洞用身体中位色填上 → 对齐到 1024 底边。覆盖已有 `chars/<pack>` 前，若还没有备份，会拷到 `assets/废弃素材/chars/<pack>_pre_layers/`。

不要为每个皮肤再复制一份 `split_horse_layers.py`。

### 3. 接入游戏

只在**新皮肤**或**新动作文件名**时改代码。已有 pack 只换 PNG 则改图 + 预览即可。清单见 [wiring.md](wiring.md)。

关键坑：

- **仅当**身体是马那种深灰剪影，才写入 `Rules.BODY_FOR_SKIN`。黄袋鼠、白兔、花牛不要写，否则 `body.gdshader` 会把暗部（眼睛等）染脏。
- 有 `scarf/` 时 Actor 走分层围巾，不再对身体扫青 shader。
- `CharKit._try_tex` 会 `Image.load_from_file` 躲 Godot `.ctex`；大厅 `_lobby_tex` 仍可能走 `load()`，换图后要重启游戏。

### 4. 预览

```bash
python tools/build_asset_preview.py
```

## 禁止

- 为去白边 / 去描边而让 AI **整套重画造型**（先清边或拆层）。
- 全局去绿、下半张一律清近白（会吃牛肚子、笔记本 Logo、眼睛高光）。
- 马桶画进每套皮肤的 toilet 帧。
- `ride` 画出整辆车 / 滑板车。
- `work` 画出白桌子（只要角色 + 银笔记本）。
- 手改 `preview/index.html`。
- 把 `assets/废弃素材/` 拷回 `assets/game/`。

## 参考成品

拆层成功长这样：`assets/game/chars/horse/` + `horse/scarf/`，以及 `kangaroo/` + `kangaroo/scarf/`。围巾层是灰度，颜色由 `SCARF_FOR_SKIN` 乘上去。
