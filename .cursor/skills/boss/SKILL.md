---
name: boss
description: >-
  Builds 《六点下班》 boss (Slot.BOSS) art and combat kit: concept pick,
  layered body+necktie, idle/walk/run, lunge/meeting/reports/KPI.
  Use when generating a boss, redrawing the tiger, 老板, 短扑, 开会,
  红领带, 势力, or editing Kind.BOSS / chars/tiger / BossBot.
---

# 老板（Boss）

一场只有一个 `Slot.BOSS`。现皮是老虎 `CharSkin.TIGER` / pack `tiger`。玩法挂在 **`Kind.BOSS`** 上，不跟皮肤走；换皮默认继承同一套技能。

出图走分层（身体 + 领带），工具复用 [char-layers](../char-layers/SKILL.md)，**不要**给老板出员工那套 work/sleep/toilet。提示词见 [prompts.md](prompts.md)，技能表见 [combat.md](combat.md)。改完图跑 [asset-preview](../asset-preview/SKILL.md)。

## 何时用

- 生成 / 重画老板，或用户说老板、老虎、短扑、开会、红领带
- 改老板按键、势力、硬直、周报、KPI
- 新老板物种（换 `SKIN_FOR_SLOT`，不要复制第二个老板位）

## 和员工的差别

| | 员工 | 老板 |
|---|---|---|
| 动作 | idle/walk/run/work/sleep/toilet（+ride） | **idle/walk/run ×4**；可选 lunge/throw/ult（缺则回退 run/idle） |
| 配饰 | 围巾识别色 | **领带**（同一套 `scarf/` 层） |
| 体型 | `SPRITE_SCALE=0.088` | `BOSS_SPRITE=0.11`，更宽更沉 |
| 表情 | 疲惫上班 | **霸气皱眉**，不要可爱、不要委屈 |
| 马桶/车 | 坐厕、袋鼠车 | 不要 |

## 出图流程

```
- [ ] 概念：洋红底，出 4～6 张不同方向，放 assets/concept/boss-<pack>/，给用户挑。不要入库。
- [ ] 定稿锁 idle：身体本色 + 领带纯青 #24C8F0 + 底 #FF00FF。用户图若是红领带，重出一帧青领带再拆。
- [ ] 同造型出 idle_1..3、walk_0..3、run_0..3（浅循环，朝向一致）
- [ ] 可选：lunge / throw / ult 各 4 帧（没有就用 CharKit 回退）
- [ ] python tools/split_char_layers.py --pack <pack> --src <gens> --only idle walk run
- [ ] 目视：领带洞是肚皮色（奶油），不是橘色块；scarf/ 是灰度领带；无洋红边
- [ ] 接线：见下方。已有 pack 只换 PNG 则只预览 + 重启游戏
- [ ] python tools/build_asset_preview.py
```

拆层后身体上会留领带黑描边，灰度层叠上去再乘 `SCARF_FOR_SKIN` 变红，这是对的。

## 接线（新 pack / 换物种）

1. `CharKit.PACK` ← 新皮肤
2. `Rules.CharSkin` + `SKIN_FOR_SLOT[Slot.BOSS]` + `SCARF_FOR_SKIN`（领带最终色，现虎 `#E02020`）
3. `Game._char_pack()` 的 `BOSS` 分支
4. **不要**写 `BODY_FOR_SKIN`（橘色身体）
5. `Actor._sync_scarf` 必须对老板也显示配饰层（不要 `kind != EMPLOYEE` 就藏领带）
6. 朝向：新皮画成**朝右**（和员工一样）。不要再加 `flip_h` 特例。现老虎 walk/run 朝左，只有 `CharSkin.TIGER` 反转，那是历史包袱。

大厅有 `scarf/idle_0.png` 时不要套 `lobby_haunt`。

## 技能（现老虎套，换皮默认照搬）

按键在 `Game._edge_keys`，结算在 `Actor._boss_tick` / `Match.*`。详情 [combat.md](combat.md)。

| 键 | 做什么 |
|---|---|
| 空格 | 朝面向短扑。命中 → 员工进「复盘」+ 势力+1；扑空硬直 1.5s |
| Q | 势力满 3 且附近有正在复盘的人 → 拉去会议室 30s，势力清零 |
| F / G | 丢周报 / 扇形周报（减速） |
| R | 开局 40s 后 KPI，全员作废当前任务 |
| Shift | 冲刺（CD 12s） |
| 靠近 | 监视：工位产出 ×0.3；可开门 |

不要为换皮复制一套 `TIGER_*` 常量，除非用户要改手感。常量名带 TIGER，实际绑的是 `Kind.BOSS`。

## 禁止

- 没让用户挑就直接替换 `chars/tiger`
- 老板帧画马桶、整车、工位桌、围巾（用领带）
- 出可爱/委屈脸顶掉定稿霸气
- 把红领带画进身体还不拆层
- 手改 `preview/index.html`；把 `assets/废弃素材/` 拷回 `assets/game/`

## 参考

- 定稿：`assets/concept/boss-tiger/chosen.jpg`
- 成品：`assets/game/chars/tiger/` + `tiger/scarf/`
- 员工分层：`.cursor/skills/char-layers/SKILL.md`
