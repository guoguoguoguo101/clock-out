# 游戏接线

只换 PNG、pack 名已在 `CharKit.PACK` 里：不用改代码。下列是**新皮肤**或**新文件名**时要动的地方。

## 已有皮肤只换图

1. 拆层写入 `assets/game/chars/<pack>/` 与 `scarf/`。
2. `python tools/build_asset_preview.py`
3. 重启 Godot 游戏（大厅肖像走 `load()`，会吃旧 `.ctex`）。

## 新 pack

按顺序改：

1. `src/actor/CharKit.gd` → `PACK` 增加 `CharSkin.XXX: "packname"`
2. `src/game/Rules.gd`
   - `enum CharSkin`
   - `SLOT_NAMES` / `SKIN_FOR_SLOT`（若占一个员工位）
   - `SCARF_FOR_SKIN`：该皮肤围巾识别色
   - **不要**写 `BODY_FOR_SKIN`，除非身体是马那种深灰剪影、需要 `body.gdshader` 染色
3. `src/game/Game.gd` → `_char_pack()` 的 slot 分支
4. 会骑车：`src/actor/RideKit.gd` 的 `HIP_FOR_SKIN`；`ride` 帧 + 拆层 `--ride`
5. 马桶：坐姿不画马桶。有对齐的 `chars/<pack>/bowl.png` 时 `CharKit.bowl_tex` 会用它；否则鹈鹕回退 `toilet_sit_layer.png`，其他皮肤没有 bowl 就不显示角色马桶层（隔间仍有地图马桶）

## 分层怎么显示

`Actor.gd`：

- `Body` z=1，有围巾层则：仅 `BODY_FOR_SKIN.has(skin)` 时上 `body.gdshader`
- `Scarf` z=2，灰度贴图 × `Rules.scarf_color`
- `ToiletBowl` z=0，仅 `EmpState.TOILET`
- 电瓶车 `RideKit`，与角色帧无关

大厅选角 `_add_slot_portrait`：有 `scarf/idle_0.png` 就叠一层并 `modulate` 围巾色；马才上 body shader。新皮肤有围巾层时不要套 `lobby_haunt` 把图抹暗。

## 颜色

`Rules.SCARF_FOR_SKIN` 现状：马青 `#3EE0F2`，兔黄 `#F4C14A`，牛红 `#E23B3B`，鹈鹕紫 `#7B5CFF`，袋鼠橙 `#FF9A1A`，小狗京东红 `#E1251B`，老虎领带红 `#E02020`。出图围巾/领带永远是标记青 `#24C8F0`，不要画成这些最终色。

## 加载

角色帧走 `CharKit._try_tex`（磁盘 PNG 优先）。不要改回纯 `load()` 除非同时清 `.ctex`。
