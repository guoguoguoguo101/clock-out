# 老板出图提示词

先给用户挑概念，再锁 idle，再出循环帧。`filename` 用 `<pack>_<anim>_<i>.png`，例如 `tiger_idle_0.png`。`aspect_ratio: "1:1"`。定稿/旧帧放进 `reference_image_paths`。

## 总规则（每张都贴）

Flat 2D office-game character sprite, FRONT VIEW or very slight 3/4, verticals parallel, no isometric.
Orange (or this pack's real fur color) BOSS animal, imposing not cute: thick black V-shaped angry eyebrows, narrow squinting glare, small straight frown, NO smile, NOT sad, NOT roaring, NOT Disney cute.
Round ears, cream muzzle and huge cream oval belly, bold black stripes if tiger, black nose.
ONLY accessory: a simple necktie in solid cyan #24C8F0 (marker for layer split — never final red). No scarf, no crown, no suit, no phone, no desk, no toilet, no bike.
Stubby two-leg standing body, short tail, arms at sides. Slightly broader/heavier than employees.
Matte simple cel shading, clean geometric mascot, thick outlines, readable at very small size.
Solid magenta background exactly #FF00FF. No floor, no drop shadow, no checkerboard, no window, no other characters, no text, no watermark.
Character large and centered, feet near the bottom.

中文可并用：扁平办公室立绘、正面霸气、皱眉瞪视、纯青领带 #24C8F0、洋红底 #FF00FF、比员工胖一圈。

## 概念阶段（4～6 张，不入库）

同一套总规则，只改体型/脸：正面瞪眼、略侧、更胖、更几何、条纹更重。放到 `assets/concept/boss-<pack>/`。等用户挑字母/一张图。

## 定稿之后

| 动作 | 内容 | 不要 |
|---|---|---|
| `idle` 4 帧 | 正面站，呼吸/重心微调，构图锁死 | 换脸、换胖瘦 |
| `walk` 4 帧 | 迈步循环，朝向全套一致（建议朝右） | 跑、左右来回翻面 |
| `run` 4 帧 | 步幅更大、拳头带风，朝向与 walk 相同 | 朝左一张朝右一张 |
| `lunge` 可选 | 朝面向猛扑，领带甩一下 | 出画、换造型 |
| `throw` 可选 | 甩周报/扔的瞬间 | 画报纸实体（特效是道具） |
| `ult` 可选 | 开会瞬间，仍是同一只动物 | 变身、魔法阵 |

同一 pack 所有帧：比例、条纹、耳形、肚皮、领带位置要像同一只。

## 检查（拆层前）

1. 底是洋红 #FF00FF，不是白/灰/棋盘。
2. 领带是一块连上的纯青，不是红、不是描边细线。
3. 眼睛、鼻子、条纹不是青色。
4. 没有马桶、车、桌子、王冠、围巾。
