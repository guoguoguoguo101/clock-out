# 出图提示词

每帧独立生成。固定下面「总规则」，只改动作段落。`filename` 用 `<pack>_<anim>_<i>.png`，例如 `rabbit_idle_0.png`。

## 总规则（每张都贴）

Flat 2D office-game character sprite, front or slight 3/4 view, verticals parallel, no isometric diamond. Cute tired office animal, matte, simple cel shading, readable at very small size. Solid magenta background exactly #FF00FF, no floor, no drop shadow, no checkerboard fake transparency, no extra props, no text, no watermark.

Body is the animal's real fur/skin color (keep species identity). Do NOT turn it into a black horse silhouette unless the pack is horse.

Neck accessory: a simple wrapped scarf in pure cyan #24C8F0 only (marker color for layer split). Scarf must be a separate solid cyan shape, not patterned, not the final team color.

Same character proportions and silhouette across all frames of this pack. 1:1 canvas, character large and centered, feet near the bottom.

## 动作

每个动作 4 帧（`_0`…`_3`），表情/手脚轻微循环即可，不要换构图。

| 动作 | 内容 | 不要 |
|---|---|---|
| `idle` | 站着，轻微呼吸/眨眼 | 道具、椅子 |
| `walk` | 走路循环 | 跑、飘 |
| `run` | 跑，比 walk 步幅大 | 骑车 |
| `work` | 坐着（无椅子），抱一台银色小笔记本，像在工位打字 | **白桌子、显示器、整套工位** |
| `sleep` | 摸鱼：坐着看手机 | 躺下、站着 Zzz、枕头、床 |
| `toilet` | 坐着看手机，和 sleep 类似的坐姿 | **马桶、隔间、卷纸**（马桶是公用层） |
| `ride` | 仅袋鼠等：坐姿 + **一小截黑色车把** | **整车、滑板车、轮子** |

马（`horse`）身体用深灰 `#25262C` 左右，仍要围巾纯青标记。袋鼠保持黄色。

## 改一帧 / 改一套

- 改现有皮肤：`reference_image_paths` 带上该 pack 的 `idle_0.png`，以及最像目标动作的旧帧。
- 模型把围巾画成最终色（橙/红/紫）而不走纯青：重出该帧，不要靠后期乱染色。
- 模型仍画出马桶：该帧作废重出，或拆完再用 `tools/split_toilet_layer.py` 剥马桶；身体上不能留马桶。

## 检查

看生图（拆层前）确认：

1. 底是洋红，不是白/灰/棋盘。
2. 围巾是一块连上的纯青，不是毛色、也不是描边细线。
3. 眼睛、手机、笔记本不是青色。
4. toilet / work / ride 没有违禁道具。
