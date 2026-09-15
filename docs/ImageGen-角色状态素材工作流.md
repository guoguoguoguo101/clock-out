# ImageGen 角色状态素材工作流

> 适用范围：当前四名可玩员工（小马、鹈鹕、袋鼠、小狗）与虎老板。目标是补齐“被扑—审查—救援—提交”过程中的**状态资产**，不替换现有行走/工作帧。

## 先说结论

不要让 AI 一次生成“四个角色 × 多个动作”的最终 sprite sheet。它很容易改掉角色物种、围巾、视角和比例，不能安全接入现有 `CharKit`。

正确流程是：**一个角色 + 一个状态 + 一个方向 + 透明底**，先得到单张源图；人工验收后再裁切/补帧，再由代码按状态加载。首批只做能立刻改善手感的状态。

## 第一批资产（建议顺序）

| 文件前缀 | 角色 | 用途 | 需要帧数 |
| --- | --- | --- | ---: |
| `audit_hit_*` | 小马、鹈鹕、袋鼠、小狗 | 虎老板短扑命中后的失衡瞬间；0.25–0.35 秒 | 1 张关键姿势 + 代码抖动 |
| `audit_drag_*` | 四名员工 | 被带往审查区的拖拽状态；角色要朝前进方向倾斜 | 2 张交替姿势 |
| `rescue_pull_*` | 四名员工 | 被队友救出后的回弹/拉手状态 | 1 张关键姿势 + 代码位移 |
| `submit_*` | 小马优先 | 工作任务成功提交，文件与屏幕同时亮 | 2 张交替姿势 |
| `tiger_lunge_*` | 虎老板 | 预备、冲刺、命中、扑空四段 | 每段 1 张，代码补间 |

## 目录与接入约定

生成后先放在对应角色目录，**不要覆盖**已有 `idle_*`、`walk_*`、`work_*`：

```text
assets/game/chars/horse/audit_hit_0.png
assets/game/chars/pelican/audit_hit_0.png
assets/game/chars/kangaroo/audit_hit_0.png
assets/game/chars/dog/audit_hit_0.png
assets/game/chars/tiger/lunge_windup_0.png
```

所有图统一 1024×1024、透明 PNG、角色完整不裁边。现有代码会根据贴图高度缩放；因此先保持与当前角色帧一致的画布，比追求小文件更重要。

接入时只需在 `src/actor/CharKit.gd` 加状态帧集合，并在 `src/actor/Actor.gd` 的视觉状态机中，让“命中/审查/获救”分别选择对应 pose。冲击、纸屑、红章、拖痕应由 Godot 的粒子/补间实时绘制，不应全部烤进人物 PNG。

## 单角色可复制提示词

将 `<角色>`、`<参考图路径>` 与 `<状态>` 替换后，使用 ImageGen 的内建生图；输入图片是**角色身份和风格参考**，不是要被覆盖的目标文件。

```text
Use case: stylized-concept
Asset type: 1024x1024 transparent game character state asset
Input image: <参考图路径>, character identity and rendering-style reference.
Primary request: Keep this exact <角色> recognisable: same species,
body proportions, material and top-down three-quarter game-camera angle. The character
body must have no scarf, no clothing, and no skin-specific accessory; those are added
by the runtime wardrobe layer. Create only
the <状态> pose: immediately after a tiger manager's claw strike, with a readable
off-balance lean and one or two loose report pages.
Scene/backdrop: genuinely transparent background.
Style/medium: match the supplied flat 2D cartoon game asset: clean dark outline,
simple filled colour blocks, minimal soft shading, paper-cut readability. Do not
render 3D fur, plastic, realistic lighting, or a toy-like volumetric character.
Composition/framing: one full character, centred, generous transparent padding,
consistent scale with the input reference.
Lighting/mood: cool office lighting; only a small local red warning-stamp glow.
Constraints: no tiger, no other character, no text, no UI, no border, no watermark,
no gore, no warped face, no full-screen red filter.
```

### 每个角色必须额外锁定的特征

- 小马：深色马脸；提示词明确写 `horse, not hedgehog or dog`。
- 鹈鹕：长橙色喙、白色羽毛；喙不能变成鸭嘴。
- 袋鼠：长尾；不能裁掉尾巴，镜头要留全身。
- 小狗：浅色垂耳；不生成额外“兄弟”以免和小狗技能混淆。

## 换装分层约定

角色本体图不包含围巾、衣服、工牌或其他皮肤专属物件。当前围巾层继续由
`assets/game/chars/<角色>/scarf/` 与 `CharKit.scarf_tex()` 单独叠加；以后换肤、换装
也沿用这一接口增加独立层，而不是重生整张人物本体图。这样同一套受击、工作、救援
状态能服务所有皮肤。

## 已生成的样张如何使用

本轮生成的是四角色“被审查命中”构图样张，用来验证氛围、透明底和纸张表现。2026-09-16 已通过第一轮视觉验收，并以不覆盖的方式进入项目资源库：

- `assets/game/chars/horse/audit_hit_0.png`
- `assets/game/chars/pelican/audit_hit_0.png`
- `assets/game/chars/kangaroo/audit_hit_0.png`
- `assets/game/chars/dog/audit_hit_0.png`

四张均为 1254 x 1254 的透明 PNG。本轮只新增素材，不改变现有角色状态机；接入时应将它们作为短暂的 `audit_hit` 反馈帧，并继续由独立换装层覆盖围巾等皮肤物件。

验收一个 AI 输出时，依次检查：

1. 物种、围巾、色彩、镜头和尺度是否仍与当前角色一致；
2. 是否真的有 alpha 透明底；
3. 轮廓是否留有 8% 以上安全边，方便运行时缩放与抖动；
4. 是否没有错误文字、额外角色和难以分离的背景；
5. 是否能清楚传达一个状态，而非只是“更恐怖”。

通过后再将最终图复制到项目目录、导入 Godot，并在一段真实试玩中验收可读性。

## 当前项目的画风决策

采用 **2D 扁平卡通角色 + 2.5D 等距办公空间**，不做全 3D 改造。

- 角色、道具、UI：统一为干净的 2D 轮廓线、少量色块和局部阴影；恐怖感来自异常状态和颜色，而非写实材质。
- 地图：可以保留等距空间、投影和层次，但用分层贴图、阴影、遮罩与光照伪造深度，不需要三维模型。
- 大厅：现有大厅背景的体积渲染感比角色强，是断裂来源。后续应把大厅调成“2D 等距插画”：降低真实高光、减少材质细节，角色使用同一套 2D 帧与环境互动。
- ImageGen 提示词必须包含：`flat 2D cartoon, clean dark outline, simple color blocks, no 3D render, no realistic fur, no plastic toy`。
