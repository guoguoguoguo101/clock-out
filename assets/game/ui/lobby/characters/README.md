# 大厅角色循环素材

这五张 PNG 都是横向 2 帧图集：左半为帧 0，右半为帧 1。导入 Godot 后以 `Sprite2D` 或 `TextureRect` 显示，`hframes = 2`、`vframes = 1`，循环切换 `frame` 即可。

| 文件 | 建议循环 | 建议节奏 |
| --- | --- | --- |
| `employee_typing_2frame.png` | 0 ↔ 1，辅以 1–2 px 的呼吸位移 | 0.18–0.35 秒/帧，随机停顿 |
| `employee_coffee_2frame.png` | 0 停留 → 1 啜饮 → 0 停留 | 7–14 秒触发一次，不连续重复 |
| `employee_desk_nap_2frame.png` | 0 熟睡 → 1 微醒 → 0 | 11–18 秒/轮，慢速 |
| `employee_lookout_2frame.png` | 0 工作 → 1 张望 → 0 | 8–16 秒触发一次，时间随机 |
| `employee_fifth_2frame.png` | 0 隐约出现 → 1 转头 → 隐藏 | 主菜单每 70–150 秒最多一次；显示 1.2–2 秒并以透明度淡入淡出 |

素材是独立前景层，适合叠在大厅背景的不同工位上。为保留菜单可读性，角色不应遮住标题、房间列表或主要按钮。
