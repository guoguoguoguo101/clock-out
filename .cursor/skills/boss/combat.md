# 老板技能与交互

代码入口：`Game._edge_keys` → `Actor.apply_input` → `Actor._boss_tick` / `Match.*`。Bot：`src/bot/BossBot.gd`。

数值在 `Rules.gd` 的 `TIGER_*` / `REPORT_*` / `KPI_*`（名字带 TIGER，实际是 `Kind.BOSS`）。

## 按键

| 键 | 脉冲 | 效果 |
|---|---|---|
| 空格 | `want_interact` | 短扑 `Match.start_lunge` |
| Q | `want_meeting` | 开会大招 `Match.try_meeting` |
| F | `want_report` | 单发周报 |
| G | `want_fan` | 扇形 7 发周报 |
| R | `want_kpi` | 全员 KPI（开局 40s 后，CD 75s） |
| Shift | `want_dash` | 冲刺 0.28s / CD 12s / 420 速 |
| 靠近门 | 短扑键也会 `try_door` | 老板能开门 |

员工空格是鹈鹕飞，老板空格是扑。不要混。

## 短扑

1. 不能在扑中、硬直、冲刺中再扑。
2. 朝 `facing_dir` 冲 `TIGER_LUNGE_TIME`（0.32s）、速 320、半径 46。
3. **命中**可扑员工（非 LEFT/TALK/MEETING/CLOCKING/CARRIED）→ `grab_lunge`：员工 `begin_talk`（复盘）、势力 +1（上限 3）、老板硬直 0.4s。爪印/印章特效。
4. **小狗兄弟**可挡一次扑（`hit_lunge_bro`）。
5. **扑空** → 硬直 1.5s，气泡「扑空了」。
6. 动画：有 `lunge_0..3` 用扑，否则回退 `run_0`。

复盘中：员工停手 `EmpState.TALK` 约 10s，结束 `apply_talk_fail`（当前任务作废；连坐窗口内再抓会扣已完成单）。同事可贴着 E 救 2.5s。

## 开会（势力大招）

- 条件：`power_pips >= 3`，且 `TIGER_MEETING_RANGE`（180）内、视线内有人正在 **TALK**。
- 消耗 3 格势力，把目标瞬移到 `office.points.meeting`，`EmpState.MEETING` 30s。
- 结束 `apply_meeting_fail`：作废任务、扣已完成单、精力清空。
- 会议室可被同事开门进来再 E 救。
- 动画：`ult_flash`，有 `ult_*` 用，否则 idle。

## 周报

- F 朝面向丢一份；G 扇形 90°×7。命中减速（0.5× / 3s）。
- 硬直/扑中也能丢。`throw_flash` 播 `throw_*` 或 idle。
- 纸是 `WeeklyReport` 道具，角色帧不要画报纸。

## KPI

- `Match.elapsed >= 40` 后 R：所有未下班员工 `lose_task()`。
- 全图压力，不瞄准。

## 被动

| 被动 | 规则 |
|---|---|
| 监视 | 距员工 ≤78 或站在工位监视点 → 产出 × `TIGER_SUPERVISE_MUL`（0.3） |
| 移速 | `BOSS_BASE_SPEED * TIGER_SPEED_MUL`（182×1.15） |
| 雾 | 老板视野略涨，员工看老板会缩 |
| 开门 | 可开会议室等门 |
| 缩放 | `BOSS_SPRITE` 0.11 |

## HUD

势力点 `power_pips_ui`（3 格）。状态栏：`势力 n/3  周报  扇形  KPI  冲刺`。提示「请勿对视」。

## 换皮时

- 默认不改这套循环，只换 PNG / `SCARF_FOR_SKIN`。
- 要新手感再改 `Rules` 常量，并同步 `BossBot`（满 3 势找开会目标，靠近就扑）。
- 特效路径 `FX_CLAW` / `FX_LUNGE` / `FX_MEETING` 现用虎爪图；新物种可换图但 RPC 仍走 `spawn_fx`。
