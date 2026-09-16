extends CharacterBody2D
class_name Actor

const SNAP_HZ := 15.0
const Kit := preload("res://src/actor/CharKit.gd")
const Ride := preload("res://src/actor/RideKit.gd")
const SCARF_SHADER := preload("res://src/actor/scarf.gdshader")
const BODY_SHADER := preload("res://src/actor/body.gdshader")

@onready var name_label: Label = $Name

var body_sprite: Sprite2D
var scarf_sprite: Sprite2D
var bowl_sprite: Sprite2D
var zzz_label: Label
var hold_sprite: Sprite2D
var hours_chip: Label
var energy_chip: Label
var prompt_bg: ColorRect
var prompt_lab: Label
var bubble_bg: ColorRect
var bubble_lab: Label
var bubble_t := 0.0

var slot := 0
var peer_id := 0
var kind := Rules.Kind.EMPLOYEE
var skin := Rules.CharSkin.HORSE
var display_name := ""

var hours := Rules.HOURS_START
var energy := Rules.ENERGY_START
var energy_cells := 0
var energy_charge := 0.0
var tasks_done := 0
var task_progress := 0.0
var tasking := false
var play_kind := ""
var play_t := 0.0
var play_mark := 0.5
var play_hits := 0
var play_lock := 0.0
var play_msg := ""
var emp_state := Rules.EmpState.WALK
var coffee_buff := 0.0
var stand_lock := 0.0
var meeting_left := 0.0
var catch_chain := 0.0
var slack_seen := 0.0
var occupy_id := ""
var last_seat := 0
var left_clock := ""
var talk_progress := 0.0
var rescue_left := 0.0
var rescue_slot := -1
var boost_left := 0.0
var slow_left := 0.0
var _slow_flash := 0.0
var carrying_slot := -1
var carried_by := -1
var carry_left := 0.0
var carry_windup := 0.0
var carry_recovery := 0.0
var carry_saved_talk := -1.0
var carry_visual: Node2D
var landing_left := 0.0
var bike_left := 0.0
var bike_cd := 0.0
var bike_sprite: Sprite2D
var bike_front: Sprite2D
var trade_left := 0.0
var trade_cd := 0.0
var trade_price := Rules.STOCK_START
var trade_cash := Rules.STOCK_START
var trade_shares := 0.0
var trade_holding := false
var trade_tick := 0.0
var trade_history: PackedFloat32Array = PackedFloat32Array()
var _trade_settling := false

var meeting_cd := 0.0
var kpi_cd := 0.0
var dash_cd := 0.0
var dash_left := 0.0
var dash_dir := Vector2.DOWN
var report_cd := 0.0
var fan_cd := 0.0
var throw_flash := 0.0
var match_elapsed := 0.0
var kpi_flash := 0.0
var incident_cd := 0.0
var is_blame_target := false
var blame_timer := 0.0
var blame_slot := -1
var fix_progress := 0.0
var fixing := false
var blamed_once := false
var delivery_boost_left := 0.0

# 装备系统
var coins := 0
var item_slots: Array[int] = []
var item_active_cds: Dictionary = {}  # item_id -> cd_left
var catch_stack := 0  # 弹性工时叠层
var _overtime_acc := 0.0  # 加班铃计时
var _auto_task_acc := 0.0  # 居家办公自动任务计时
var _flash_acc := 0.0  # 全域监控闪现计时
var flash_reveal_left := 0.0
var invisible_left := 0.0  # 摸鱼之王隐身

var input_dir := Vector2.ZERO
var want_interact := false
var want_slack := false
var want_meeting := false
var want_kpi := false
var want_dash := false
var want_report := false
var want_fan := false
var want_incident := false
var want_blame := false
var want_shop := false
var want_active := -1  # item slot index for active skill

var _sync_acc := 0.0
var _remote_pos := Vector2.ZERO
var _facing := Vector2.DOWN
var _anim_acc := 0.0


func setup(p_slot: int, p_peer: int, p_name: String) -> void:
	slot = p_slot
	peer_id = p_peer
	display_name = p_name
	kind = Rules.Kind.BOSS if p_slot == Rules.Slot.BOSS else Rules.Kind.EMPLOYEE
	skin = Rules.SKIN_FOR_SLOT[p_slot]
	name = "actor_%d" % p_slot
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var cs := get_node("Collision") as CollisionShape2D
	var sh := CircleShape2D.new()
	sh.radius = 11
	cs.shape = sh
	var nl := get_node("Name") as Label
	nl.position = Vector2(-36, -78)
	nl.size = Vector2(72, 18)
	nl.add_theme_font_size_override("font_size", 11)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ensure_sprite()


func is_local() -> bool:
	if Net.go_match():
		return peer_id != 0 and peer_id == Net.go_peer_id
	if not Net.has_peer():
		return false
	return peer_id != 0 and peer_id == multiplayer.get_unique_id()


func is_bot() -> bool:
	return peer_id == 0


func office() -> OfficeMap:
	return get_parent() as OfficeMap


# ── 装备 buff 查询 ──
func item_buff(key: String) -> float:
	return ItemDB.total_buff(item_slots, key)

func item_has(key: String) -> bool:
	return ItemDB.has_buff(item_slots, key)

func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)

func buy_item(item_id: int) -> bool:
	var d := ItemDB.get_item(item_id)
	if d == null:
		return false
	if d.side == ItemDB.Side.EMPLOYEE and kind != Rules.Kind.EMPLOYEE:
		return false
	if d.side == ItemDB.Side.BOSS and kind != Rules.Kind.BOSS:
		return false
	# 尝试合成
	if not d.recipe.is_empty():
		if not ItemDB.can_combine(item_slots, item_id):
			return false
		if coins < d.combine_cost:
			return false
		coins -= d.combine_cost
		for need_id in d.recipe:
			var idx := item_slots.find(need_id)
			if idx >= 0:
				item_slots.remove_at(idx)
		item_slots.append(item_id)
		_apply_on_buy(d)
		return true
	# 直接购买基础件
	if item_slots.size() >= ItemDB.MAX_SLOTS:
		return false
	if coins < d.cost:
		return false
	coins -= d.cost
	item_slots.append(item_id)
	_apply_on_buy(d)
	return true

func sell_item(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= item_slots.size():
		return false
	var item_id := item_slots[slot_idx]
	var refund := ItemDB.sell_price(item_id)
	item_slots.remove_at(slot_idx)
	coins += refund
	return true

func _apply_on_buy(d: ItemDB.ItemDef) -> void:
	if d.buffs.has("hours_reduce"):
		hours = maxf(0.0, hours - float(d.buffs["hours_reduce"]))
	if d.active_cd > 0.0:
		item_active_cds[d.id] = 0.0


func nearby_action() -> String:
	if kind == Rules.Kind.BOSS:
		return _boss_nearby_action()
	if carried_by >= 0:
		return "顺风嘴 · E 主动下来"
	if carrying_slot >= 0:
		return "接活水 · E 放下同事（%.0fs）" % ceilf(carry_left)
	if skin == Rules.CharSkin.PELICAN and emp_state == Rules.EmpState.WALK and stand_lock <= 0.0:
		var passenger: Actor = Match.nearest_carry_target(self)
		if passenger != null:
			return "E 接活水「%s」" % passenger.display_name
	if emp_state == Rules.EmpState.TALK:
		if Match.is_watched(self):
			return "约谈中 · 老板盯着，捞不走"
		return "约谈中 · 等同事捞人"
	if rescue_left > 0.0:
		return "正在捞人…"
	if emp_state == Rules.EmpState.WORK or emp_state == Rules.EmpState.SLACK:
		if tasking:
			return "正在写%s · WASD 会作废    %.0f%%" % [Rules.task_name(tasks_done), task_progress * 100.0]
		if energy_cells <= 0:
			return "没精力 · F 摸鱼充一格    WASD 起身去找吃的"
		return "E 确认开工「%s」    F 摸鱼    WASD 起身" % Rules.task_name(tasks_done)
	if play_kind != "":
		if play_kind == "snack":
			return "F 拆包装  %d/5    E 扔掉" % play_hits
		if play_kind == "water":
			return "水位晃到刚好满时按 F    E 撤"
		return "F 卡点续命    E 撤了"
	if emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET:
		return "E 撤了"
	if emp_state == Rules.EmpState.TRADE:
		if trade_holding:
			return "F 卖出    E 撤了（%.0fs）" % ceilf(trade_left)
		return "F 买入    E 撤了（%.0fs）" % ceilf(trade_left)
	if emp_state == Rules.EmpState.CLOCKING:
		return "润了 · 去打卡"
	if emp_state == Rules.EmpState.MEETING:
		return "被拉去开会 · 救不了"
	if stand_lock > 0.0:
		return "刚复盘完 · 先站一会儿"
	if fixing:
		return "正在修 Bug…  %.0f%%" % (fix_progress * 100.0)
	if Match.incident_active and is_blame_target:
		var term_pos: Vector2 = Match.incident_terminal_pos
		var d := global_position.distance_to(term_pos)
		if d < Rules.INTERACT_RANGE + 20.0:
			return "E 修 Bug    F 甩锅给附近同事"
		return "⚠ 你是责任人 · 去终端修 Bug 或 F 甩锅"
	if Match.incident_active and not is_blame_target:
		var term_pos: Vector2 = Match.incident_terminal_pos
		var d := global_position.distance_to(term_pos)
		if d < Rules.INTERACT_RANGE + 20.0:
			return "E 帮忙修 Bug · 缩短事故时间"
	if _is_riding():
		return "F 下车才能交互"
	if not Match.delivery_spots.is_empty():
		for k in Match.delivery_spots:
			if global_position.distance_to(Match.delivery_spots[k]) < 100.0:
				return "E 抢外卖 · 回复精力 +2"
	# 贩卖机
	if Match.elapsed >= ItemDB.SHOP_UNLOCK_TIME:
		var omap := office()
		if omap:
			for key in ["shop_0", "shop_1"]:
				if omap.points.has(key) and global_position.distance_to(omap.points[key]) < Rules.INTERACT_RANGE + 16.0:
					return "E 打开贩卖机 · 💰%d" % coins
	var map := office()
	if map == null:
		return ""
	var door = map.nearest_door(global_position, Rules.DOOR_RANGE)
	if door != null:
		return door.prompt_text(kind)
	var talk := Match.nearest_talk(global_position, Rules.RESCUE_RANGE)
	if talk != null:
		if Match.is_watched(talk):
			return "老板盯着 · 捞不走"
		return "E 捞人"
	var seat := map.nearest_spot("seat", global_position, Rules.INTERACT_RANGE)
	if seat != "":
		var who: int = map.occupiers.get(seat, -1)
		if who != -1 and who != slot:
			return "这个位子有人"
		return "E 坐下 · 还要再按一次才开工"
	var loot := map.nearest_energy(global_position, Rules.INTERACT_RANGE)
	if loot != "":
		return map.energy_prompt(loot)
	var coffee := map.nearest_free("coffee", global_position)
	if coffee != "" and global_position.distance_to(map.points[coffee]) < Rules.INTERACT_RANGE:
		return "E 手冲咖啡（卡点出杯）"
	var toilet := map.nearest_free("toilet", global_position)
	if toilet != "" and global_position.distance_to(map.points[toilet]) < Rules.INTERACT_RANGE:
		return "E 躲进隔间缓一缓"
	var stock := map.nearest_spot("stock", global_position, Rules.INTERACT_RANGE)
	if stock != "":
		var who: int = map.occupiers.get(stock, -1)
		if who != -1 and who != slot:
			return "有人在盘中"
		if trade_cd > 0.05:
			return "内网交易冷却 %.0fs" % ceilf(trade_cd)
		return "E 炒股 · 赚了加精力"
	if skin == Rules.CharSkin.KANGAROO and emp_state == Rules.EmpState.WALK:
		if bike_cd > 0.05:
			return "电瓶车冷却 %.0fs" % ceilf(bike_cd)
		return "F 骑电瓶车    下车后才能交互"
	return ""


func _boss_nearby_action() -> String:
	# 贩卖机
	if Match.elapsed >= ItemDB.SHOP_UNLOCK_TIME:
		var map := office()
		if map:
			for key in ["shop_0", "shop_1"]:
				if map.points.has(key) and global_position.distance_to(map.points[key]) < Rules.INTERACT_RANGE + 16.0:
					return "E 打开贩卖机 · 💰%d" % coins
	var talk := Match.nearest_talk(global_position, 220.0)
	if talk != null and Match.is_watched(talk):
		return "现场督导中 · 复盘加速"
	for a in Match.actors.values():
		var e := a as Actor
		if not Match.is_catchable(e):
			continue
		if global_position.distance_to(e.global_position) <= Rules.CATCH_RANGE:
			if e.rescue_left > 0.0:
				return "E 约谈（捞人的也别跑）"
			return "E 约谈"
	var map := office()
	if map:
		var door = map.nearest_door(global_position, Rules.DOOR_RANGE)
		if door != null:
			return door.prompt_text(kind)
	return ""


func remaining_work_sec() -> float:
	return hours / Rules.WORK_HOURS_PER_SEC


func _skin_tex() -> Texture2D:
	return Kit.tex(skin, "idle_0")


func _ready() -> void:
	_remote_pos = global_position
	if name_label:
		name_label.text = display_name
	_ensure_sprite()
	_update_visual(0.0)


func _ensure_sprite() -> void:
	if body_sprite != null:
		return
	body_sprite = Sprite2D.new()
	body_sprite.name = "Body"
	body_sprite.texture = _skin_tex()
	body_sprite.centered = false
	body_sprite.z_index = 1
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(body_sprite)
	scarf_sprite = Sprite2D.new()
	scarf_sprite.name = "Scarf"
	scarf_sprite.centered = false
	scarf_sprite.z_index = 2
	scarf_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(scarf_sprite)
	bowl_sprite = Sprite2D.new()
	bowl_sprite.name = "ToiletBowl"
	bowl_sprite.centered = false
	bowl_sprite.z_index = 0
	bowl_sprite.visible = false
	bowl_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(bowl_sprite)
	_apply_scarf()
	if skin == Rules.CharSkin.PELICAN:
		carry_visual = preload("res://src/fx/PelicanCarry.gd").new()
		carry_visual.z_index = 3
		add_child(carry_visual)
	if kind == Rules.Kind.EMPLOYEE:
		_ensure_bike_sprites()
	zzz_label = Label.new()
	zzz_label.text = "z z"
	zzz_label.visible = false
	zzz_label.position = Vector2(10, -64)
	zzz_label.add_theme_font_size_override("font_size", 12)
	zzz_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	add_child(zzz_label)
	hold_sprite = Sprite2D.new()
	hold_sprite.centered = true
	hold_sprite.z_index = 4
	hold_sprite.visible = false
	add_child(hold_sprite)
	hours_chip = _make_chip(Color(0.22, 0.48, 0.58))
	energy_chip = _make_chip(Color(0.62, 0.48, 0.12))
	prompt_bg = ColorRect.new()
	prompt_bg.color = Color(0.12, 0.14, 0.18, 0.86)
	prompt_bg.visible = false
	prompt_bg.z_index = 6
	prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_bg)
	prompt_lab = Label.new()
	prompt_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lab.add_theme_font_size_override("font_size", 11)
	prompt_lab.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	prompt_lab.z_index = 7
	add_child(prompt_lab)
	bubble_bg = ColorRect.new()
	bubble_bg.color = Color(1, 1, 1, 0.92)
	bubble_bg.visible = false
	bubble_bg.z_index = 6
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble_bg)
	bubble_lab = Label.new()
	bubble_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lab.add_theme_font_size_override("font_size", 12)
	bubble_lab.add_theme_color_override("font_color", Color(0.18, 0.18, 0.20))
	bubble_lab.z_index = 7
	add_child(bubble_lab)


func say(text: String, hold := 1.7) -> void:
	if bubble_lab == null:
		return
	bubble_lab.text = text
	bubble_t = hold
	bubble_bg.visible = true
	bubble_lab.visible = true


func _apply_scarf() -> void:
	if body_sprite == null:
		return
	if kind != Rules.Kind.EMPLOYEE:
		body_sprite.material = null
		if scarf_sprite:
			scarf_sprite.visible = false
		return
	if Kit.has_scarf_layer(skin):
		if Rules.BODY_FOR_SKIN.has(skin):
			var body_mat := ShaderMaterial.new()
			body_mat.shader = BODY_SHADER
			body_mat.set_shader_parameter("body_color", Rules.body_color(skin))
			body_sprite.material = body_mat
		else:
			body_sprite.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = SCARF_SHADER
	mat.set_shader_parameter("scarf_color", Rules.scarf_color(skin))
	body_sprite.material = mat


func _sync_scarf(pose: String) -> void:
	if scarf_sprite == null:
		return
	if kind != Rules.Kind.EMPLOYEE or not Kit.has_scarf_layer(skin) or pose.begins_with("trade"):
		scarf_sprite.visible = false
		return
	var tex: Texture2D = Kit.scarf_tex(skin, pose)
	if tex == null or body_sprite == null or not body_sprite.visible:
		scarf_sprite.visible = false
		return
	scarf_sprite.visible = true
	scarf_sprite.texture = tex
	scarf_sprite.position = body_sprite.position
	scarf_sprite.offset = body_sprite.offset
	scarf_sprite.scale = body_sprite.scale
	scarf_sprite.rotation = body_sprite.rotation
	scarf_sprite.flip_h = body_sprite.flip_h
	var tint := Rules.scarf_color(skin)
	var threat := body_sprite.modulate
	scarf_sprite.modulate = Color(tint.r * threat.r, tint.g * threat.g, tint.b * threat.b, 1.0)


func _sync_bowl() -> void:
	if bowl_sprite == null or body_sprite == null:
		return
	var sitting := emp_state == Rules.EmpState.TOILET and carried_by < 0
	var tex: Texture2D = Kit.bowl_tex(skin) if sitting else null
	if tex == null or not body_sprite.visible:
		bowl_sprite.visible = false
		return
	bowl_sprite.visible = true
	bowl_sprite.texture = tex
	bowl_sprite.position = body_sprite.position
	bowl_sprite.offset = body_sprite.offset
	bowl_sprite.scale = body_sprite.scale
	bowl_sprite.rotation = body_sprite.rotation
	bowl_sprite.flip_h = body_sprite.flip_h
	bowl_sprite.modulate = body_sprite.modulate


func _make_chip(color: Color) -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 10)
	lab.add_theme_color_override("font_color", color)
	lab.position = Vector2(-44, 8)
	lab.size = Vector2(88, 14)
	add_child(lab)
	return lab


func _update_visual(delta := 0.0) -> void:
	if body_sprite == null:
		return
	_anim_acc += delta
	if velocity.x > 10.0:
		_facing.x = 1.0
	elif velocity.x < -10.0:
		_facing.x = -1.0
	var sitting := emp_state == Rules.EmpState.WORK or emp_state == Rules.EmpState.SLACK or emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET or emp_state == Rules.EmpState.MEETING or emp_state == Rules.EmpState.TRADE
	var pose := _anim_pose()
	var tex: Texture2D = Kit.tex(skin, pose)
	if tex != null:
		body_sprite.texture = tex
	var sz := body_sprite.texture.get_size() if body_sprite.texture else Vector2(1024, 1024)
	var sc := Rules.BOSS_SPRITE if kind == Rules.Kind.BOSS else Rules.SPRITE_SCALE
	if sitting:
		sc *= 0.92
	sc *= 1024.0 / maxf(sz.y, 1.0)
	var walk_sc := sc
	if _is_riding():
		sc *= Ride.RIDER_SCALE_MUL
	body_sprite.position = Vector2.ZERO
	body_sprite.rotation = 0.0
	body_sprite.scale = Vector2(sc, sc)
	landing_left = maxf(0.0, landing_left - delta)
	if landing_left > 0.0:
		var bounce := sin((1.0 - landing_left / 0.4) * PI)
		body_sprite.position.y = -bounce * 12.0
		body_sprite.scale *= Vector2(1.0 + bounce * 0.12, 1.0 - bounce * 0.1)
	if carrying_slot >= 0:
		var lean := sin(clampf(carry_windup / Rules.CARRY_WINDUP, 0.0, 1.0) * PI)
		body_sprite.scale *= Vector2(1.0 + lean * 0.18, 1.0 - lean * 0.1)
		body_sprite.position.x = (1.0 if _facing.x >= 0.0 else -1.0) * lean * 7.0
		body_sprite.position.y = sin(_anim_acc * 12.0) * 1.5
	body_sprite.visible = carried_by < 0
	body_sprite.offset = Vector2(-sz.x * 0.5, -sz.y + Ride.FOOT_PAD)
	if emp_state == Rules.EmpState.TRADE:
		_facing = Vector2.RIGHT
		body_sprite.flip_h = false
	else:
		body_sprite.flip_h = (not sitting) and _facing.x < 0.0
	_update_bike_visual(_is_riding(), walk_sc)
	if zzz_label:
		if emp_state == Rules.EmpState.TALK:
			zzz_label.visible = true
			zzz_label.text = "复盘中" if Match.is_watched(self) else "救命"
			zzz_label.add_theme_color_override("font_color", Color(0.92, 0.18, 0.14))
		elif emp_state == Rules.EmpState.CLOCKING:
			zzz_label.visible = true
			zzz_label.text = "润"
			zzz_label.add_theme_color_override("font_color", Color(0.45, 0.82, 0.42))
		elif emp_state == Rules.EmpState.TRADE:
			zzz_label.visible = true
			zzz_label.text = "盘中"
			zzz_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.22))
		else:
			zzz_label.visible = false
			zzz_label.text = "z z"
			zzz_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	if name_label:
		name_label.position = Vector2(-40, -sz.y * sc - 18.0)
	_update_chips(sz.y * sc)
	_update_world_text(sz.y * sc, delta)
	_update_hold()
	_update_threat_modulate()
	_sync_scarf(pose)
	_sync_bowl()
	if carried_by >= 0:
		name_label.visible = false
		zzz_label.visible = false
		hold_sprite.visible = false
	else:
		name_label.visible = true


func _anim_pose() -> String:
	var anim := "idle"
	match emp_state:
		Rules.EmpState.WORK:
			anim = "work"
		Rules.EmpState.SLACK:
			anim = "sleep"
		Rules.EmpState.COFFEE:
			anim = "work"
		Rules.EmpState.MEETING:
			anim = "work"
		Rules.EmpState.TALK:
			anim = "idle"
		Rules.EmpState.TOILET:
			anim = "toilet"
		Rules.EmpState.TRADE:
			anim = "trade"
		Rules.EmpState.CLOCKING:
			anim = "ride" if _is_riding() else "run"
		_:
			if _is_riding():
				anim = "ride"
			elif velocity.length() > 24.0:
				anim = "run" if dash_left > 0.0 else "walk"
			else:
				anim = "idle"
	var frames: PackedStringArray = Kit.loop_frames(anim)
	var fps := 10.0 if anim == "run" else (8.0 if anim == "walk" else 5.0)
	if dash_left > 0.0 and anim == "run":
		fps = 16.0
	if anim == "sleep":
		fps = 4.0
	var i: int = int(_anim_acc * fps) % frames.size()
	return frames[i]


func _is_riding() -> bool:
	return bike_left > 0.0 and carried_by < 0 and (emp_state == Rules.EmpState.WALK or emp_state == Rules.EmpState.CLOCKING)


func _dismount_bike() -> void:
	if bike_left <= 0.0:
		return
	Match.clear_bike(self)
	bike_cd = maxf(bike_cd, Rules.BIKE_CD)


func _try_toggle_bike() -> void:
	if skin != Rules.CharSkin.KANGAROO:
		return
	if emp_state != Rules.EmpState.WALK and emp_state != Rules.EmpState.CLOCKING:
		return
	if play_kind != "" or rescue_left > 0.0:
		return
	if carrying_slot >= 0 or carried_by >= 0:
		return
	if _is_riding():
		_dismount_bike()
		say("下车", 0.8)
		return
	if bike_cd > 0.05:
		say("电瓶车冷却 %.0fs" % ceilf(bike_cd), 0.9)
		return
	Match.try_bike(self)


func _ensure_bike_sprites() -> void:
	if bike_sprite != null:
		return
	bike_sprite = Sprite2D.new()
	bike_sprite.name = "BikeBack"
	bike_front = Sprite2D.new()
	bike_front.name = "BikeFront"
	add_child(bike_sprite)
	add_child(bike_front)
	Ride.setup(bike_sprite, bike_front, Rules.bike_color(skin))


func _update_bike_visual(riding: bool, walk_sc := Rules.SPRITE_SCALE) -> void:
	if not riding:
		Ride.hide(bike_sprite, bike_front)
		return
	_ensure_bike_sprites()
	var bob := sin(_anim_acc * 11.0) * 1.2 if velocity.length() > 24.0 else 0.0
	Ride.apply(body_sprite, bike_sprite, bike_front, skin, _facing.x, walk_sc, bob)


func _update_chips(body_h: float) -> void:
	if hours_chip:
		hours_chip.visible = false
	if energy_chip:
		energy_chip.visible = false
	if prompt_bg:
		prompt_bg.position.y = -body_h - 36.0


func _update_world_text(body_h: float, delta: float) -> void:
	if bubble_t > 0.0:
		bubble_t = maxf(0.0, bubble_t - delta)
		if bubble_t <= 0.0:
			if bubble_bg:
				bubble_bg.visible = false
			if bubble_lab:
				bubble_lab.visible = false
	if bubble_lab and bubble_lab.visible:
		var bw := maxf(72.0, bubble_lab.text.length() * 13.0)
		bubble_lab.size = Vector2(bw, 18)
		bubble_lab.position = Vector2(-bw * 0.5, -body_h - 58.0)
		bubble_bg.size = Vector2(bw + 12, 20)
		bubble_bg.position = Vector2(-bw * 0.5 - 6, -body_h - 60.0)
	if prompt_lab == null or prompt_bg == null:
		return
	var act := nearby_action() if is_local() else ""
	var show := act != ""
	prompt_lab.visible = show
	prompt_bg.visible = show
	if not show:
		return
	prompt_lab.text = act
	var pw := maxf(56.0, act.length() * 12.0)
	prompt_lab.size = Vector2(pw, 16)
	prompt_lab.position = Vector2(-pw * 0.5, -body_h - 36.0)
	prompt_bg.size = Vector2(pw + 12, 18)
	prompt_bg.position = Vector2(-pw * 0.5 - 6, -body_h - 38.0)


func _update_hold() -> void:
	if hold_sprite == null:
		return
	if emp_state == Rules.EmpState.TALK:
		hold_sprite.texture = Rules.tex("res://assets/game/props/paper.png")
		hold_sprite.visible = true
		hold_sprite.position = Vector2(18, -10)
		hold_sprite.scale = Vector2(0.035, 0.035)
		hold_sprite.modulate = Color(1, 0.85, 0.82)
	elif emp_state == Rules.EmpState.COFFEE:
		hold_sprite.texture = Rules.tex("res://assets/game/props/coffee.png")
		hold_sprite.visible = true
		hold_sprite.position = Vector2(16, -8)
		hold_sprite.scale = Vector2(0.03, 0.03)
		hold_sprite.modulate = Color.WHITE
	elif throw_flash > 0.0:
		var hand := throw_hand_offset()
		hold_sprite.texture = Rules.tex("res://assets/game/props/reports/weekly.png")
		hold_sprite.region_enabled = false
		hold_sprite.visible = true
		hold_sprite.position = hand
		hold_sprite.scale = Vector2(0.022, 0.022)
		hold_sprite.rotation = 0.18 * (1.0 if hand.x >= 0.0 else -1.0)
		hold_sprite.modulate = Color(1, 1, 1, clampf(throw_flash / 0.16, 0.0, 1.0))
	elif slow_left > 0.0:
		hold_sprite.texture = Rules.tex("res://assets/game/props/reports/weekly.png")
		hold_sprite.region_enabled = false
		hold_sprite.visible = true
		hold_sprite.position = Vector2(16, -36)
		hold_sprite.scale = Vector2(0.024, 0.024)
		hold_sprite.rotation = 0.35
		hold_sprite.modulate = Color(1, 1, 1, 0.95)
	else:
		hold_sprite.visible = false
		hold_sprite.rotation = 0.0


func _update_threat_modulate() -> void:
	if body_sprite == null:
		return
	var c := Color.WHITE
	if kind == Rules.Kind.EMPLOYEE:
		var map := office()
		var threat := map.threat_for(self) if map else 0.0
		if emp_state == Rules.EmpState.TALK:
			c = Color(1.0, 0.58, 0.54)
		elif emp_state == Rules.EmpState.CLOCKING:
			c = Color(0.72, 1.0, 0.78)
		elif Match.is_supervised(self):
			c = Color(0.82, 0.78, 0.78)
		elif threat > 0.18:
			c = Color.WHITE.lerp(Color(0.90, 0.70, 0.68), clampf(threat, 0.0, 1.0))
		if boost_left > 0.0:
			c = c.lerp(Color(0.75, 1.0, 0.82), 0.4)
		if slow_left > 0.0:
			c = c.lerp(Color(0.86, 0.78, 0.62), 0.55)
	elif kpi_flash > 0.0:
		c = Color(1.0, 0.55, 0.5)
	body_sprite.modulate = c


func _physics_process(delta: float) -> void:
	if Net.go_match():
		global_position = global_position.lerp(_remote_pos, 1.0 - exp(-12.0 * delta))
		if carried_by >= 0:
			var carrier := Match.actors.get(carried_by) as Actor
			if carrier != null:
				global_position = carrier.global_position
		_update_visual(delta)
		queue_redraw()
		return
	if Net.is_enet_server() and Match.playing:
		_server_tick(delta)
		_sync_acc += delta
		if _sync_acc >= 1.0 / SNAP_HZ:
			_sync_acc = 0.0
			_broadcast_state()
	elif not Net.is_enet_server():
		global_position = global_position.lerp(_remote_pos, 1.0 - exp(-12.0 * delta))
	if carried_by >= 0:
		var carrier := Match.actors.get(carried_by) as Actor
		if carrier != null:
			global_position = carrier.global_position
	_update_visual(delta)
	queue_redraw()


func _server_tick(delta: float) -> void:
	carry_recovery = maxf(0.0, carry_recovery - delta)
	bike_cd = maxf(0.0, bike_cd - delta)
	stand_lock = max(0.0, stand_lock - delta)
	catch_chain = max(0.0, catch_chain - delta)
	coffee_buff = max(0.0, coffee_buff - delta)
	boost_left = max(0.0, boost_left - delta)
	slow_left = max(0.0, slow_left - delta)
	_slow_flash = max(0.0, _slow_flash - delta)
	meeting_cd = max(0.0, meeting_cd - delta)
	kpi_cd = max(0.0, kpi_cd - delta)
	dash_cd = max(0.0, dash_cd - delta)
	dash_left = max(0.0, dash_left - delta)
	report_cd = max(0.0, report_cd - delta)
	fan_cd = max(0.0, fan_cd - delta)
	throw_flash = max(0.0, throw_flash - delta)
	kpi_flash = max(0.0, kpi_flash - delta)
	play_lock = max(0.0, play_lock - delta)
	incident_cd = max(0.0, incident_cd - delta)
	blame_timer = max(0.0, blame_timer - delta)
	delivery_boost_left = max(0.0, delivery_boost_left - delta)
	invisible_left = max(0.0, invisible_left - delta)
	flash_reveal_left = max(0.0, flash_reveal_left - delta)
	for k in item_active_cds.keys():
		item_active_cds[k] = max(0.0, item_active_cds[k] - delta)
	if kind == Rules.Kind.EMPLOYEE:
		_tick_cells(delta)
	trade_cd = max(0.0, trade_cd - delta)
	if kind == Rules.Kind.BOSS:
		_boss_tick(delta)
	else:
		_employee_tick(delta)
	want_interact = false
	want_slack = false
	want_meeting = false
	want_kpi = false
	want_dash = false
	want_report = false
	want_fan = false
	want_incident = false
	want_blame = false
	want_shop = false
	want_active = -1


func _employee_tick(delta: float) -> void:
	if carried_by >= 0:
		var carrier: Actor = Match.actors.get(carried_by) as Actor
		if carrier != null:
			global_position = carrier.global_position
			velocity = Vector2.ZERO
			if want_interact and not is_bot() and carrier.carry_windup <= 0.0:
				Match.release_carry(carrier)
		return
	if carrying_slot >= 0:
		carry_left -= delta
		carry_windup = maxf(0.0, carry_windup - delta)
		if emp_state != Rules.EmpState.WALK or hours <= 0.0:
			Match.release_carry(self, true)
		elif carry_left <= 0.0 or (want_interact and carry_windup <= 0.0):
			Match.release_carry(self)
			want_interact = false
		else:
			_try_start_emp_dash()
			if dash_left > 0.0:
				velocity = dash_dir * _slowed(Rules.EMP_DASH_SPEED)
			else:
				velocity = input_dir.limit_length() * _slowed(Rules.EMPLOYEE_SPEED * 0.88) if carry_windup <= 0.0 else Vector2.ZERO
			move_and_slide()
			if velocity.length() > 8.0:
				_facing = velocity.normalized()
			return
	if emp_state == Rules.EmpState.LEFT:
		visible = false
		velocity = Vector2.ZERO
		return
	if hours <= 0.0 and emp_state != Rules.EmpState.CLOCKING and emp_state != Rules.EmpState.TALK and emp_state != Rules.EmpState.TRADE:
		_begin_clocking()
	if play_kind != "" and emp_state != Rules.EmpState.TALK and emp_state != Rules.EmpState.MEETING and emp_state != Rules.EmpState.CARRIED:
		_tick_energy_play(delta)
		return
	match emp_state:
		Rules.EmpState.TALK:
			_tick_talk(delta)
			return
		Rules.EmpState.TRADE:
			_tick_trade(delta)
			return
		Rules.EmpState.MEETING:
			meeting_left -= delta
			velocity = Vector2.ZERO
			if meeting_left <= 0.0:
				emp_state = Rules.EmpState.WALK
			return
		Rules.EmpState.CLOCKING:
			if want_slack:
				_try_toggle_bike()
			var target: Vector2 = office().nearest_punch(global_position)
			var blocked = office().nearest_door(global_position, 56.0)
			if blocked != null and blocked.closed and not _is_riding():
				office().try_door(self)
			_try_start_emp_dash()
			var clock_speed := _slowed(Rules.EMPLOYEE_SPEED * (Rules.BIKE_SPEED_MUL if bike_left > 0.0 else 1.0))
			if dash_left > 0.0:
				clock_speed = _slowed(Rules.EMP_DASH_SPEED)
			_move_towards(office().path_to(global_position, target), clock_speed, delta)
			if global_position.distance_to(target) < Rules.CLOCK_RANGE:
				_clock_out()
			return
		Rules.EmpState.WORK:
			if want_slack and not tasking:
				emp_state = Rules.EmpState.SLACK
				_sit_work(delta, true)
				return
			if input_dir.length() > 0.12:
				_abort_task("中途离席，这单废了")
				_stand_up()
				return
			if want_interact:
				if tasking:
					_abort_task("自己撤了，这单废了")
					_stand_up()
				elif energy_cells >= 1:
					_start_task()
				else:
					say("没精力 · 先去找咖啡", 1.2)
				return
			_sit_work(delta, false)
			return
		Rules.EmpState.SLACK:
			if want_slack:
				emp_state = Rules.EmpState.WORK
				_sit_work(delta, false)
				return
			if want_interact or input_dir.length() > 0.12:
				_stand_up()
				if want_interact:
					Match.try_rescue(self)
					return
			else:
				_sit_work(delta, true)
				return
		Rules.EmpState.COFFEE:
			_tick_energy_play(delta)
			return
		Rules.EmpState.TOILET:
			_tick_energy_play(delta)
			return
	# walk
	if fixing:
		velocity = Vector2.ZERO
		if want_interact or input_dir.length() > 0.12:
			fixing = false
			fix_progress = 0.0
		return
	if want_slack:
		_try_toggle_bike()
	# 事故期间，责任人按 F 尝试甩锅给附近员工
	if want_blame and is_blame_target and Match.incident_active:
		Match.try_pass_blame(self)
	if rescue_left > 0.0:
		if input_dir.length() > 0.12:
			clear_rescue()
		elif Match.tick_rescue(self, delta):
			velocity = Vector2.ZERO
			return
	if _try_start_emp_dash():
		clear_rescue()
	var speed := Rules.EMPLOYEE_SPEED
	if boost_left > 0.0:
		speed *= Rules.RESCUE_BOOST_MUL
	if bike_left > 0.0:
		speed *= Rules.BIKE_SPEED_MUL
	if delivery_boost_left > 0.0:
		speed *= Rules.DELIVERY_BOOST_MUL
	if Match.intranet_boost_left > 0.0:
		speed *= Rules.INTRANET_BOOST_MUL
	var item_spd := item_buff("speed")
	if item_spd > 0.0:
		speed *= (1.0 + item_spd)
	if item_has("sprint_threshold") and tasks_done >= Rules.TASK_COUNT - 1:
		speed *= 1.25
	speed = _slowed(speed)
	if dash_left > 0.0:
		velocity = dash_dir * _slowed(Rules.EMP_DASH_SPEED)
	elif is_bot():
		velocity = input_dir.normalized() * speed if input_dir.length() > 0.1 else Vector2.ZERO
	else:
		velocity = input_dir.limit_length(1.0) * speed
	move_and_slide()
	if velocity.length() > 8.0:
		_facing = velocity.normalized()
	if want_interact:
		_try_employee_interact()


func _sit_work(delta: float, slack: bool) -> void:
	velocity = Vector2.ZERO
	var supervised := Match.is_supervised(self)
	if slack:
		var slack_d := Rules.SLACK_CATCH_DELAY
		var slack_extra := item_buff("slack_delay")
		if slack_extra > 0.0:
			slack_d += slack_extra
		if supervised:
			slack_seen += delta
			if slack_seen >= slack_d:
				Match.catch_employee(self)
		else:
			slack_seen = 0.0
		return
	if not tasking:
		return
	var mul := 1.0
	if coffee_buff > 0.0:
		mul *= Rules.COFFEE_BUFF_MUL
	# 装备：工作速度
	var work_spd := item_buff("work_speed")
	if work_spd > 0.0:
		mul *= (1.0 + work_spd)
	# 装备：番茄钟（连续工作 8s 后加速）
	var tomato := item_buff("tomato_bonus")
	if tomato > 0.0 and task_progress > 0.0:
		var worked_sec := task_progress * Rules.TASK_TIME
		if worked_sec >= 8.0:
			mul *= (1.0 + tomato)
	# 装备：被抓后工速叠加
	var stack_bonus := item_buff("catch_stack_work")
	if stack_bonus > 0.0 and catch_stack > 0:
		mul *= (1.0 + stack_bonus * mini(catch_stack, 3))
	# 装备：<15h 时加速
	var low_thresh := item_buff("low_hours_threshold")
	if low_thresh > 0.0 and hours < low_thresh:
		mul *= (1.0 + item_buff("low_hours_boost"))
	if supervised:
		mul *= Rules.TIGER_SUPERVISE_MUL
		# Boss 装备：监督区工速 -15%
		if Match.actors.has(Rules.Slot.BOSS):
			var boss: Actor = Match.actors[Rules.Slot.BOSS]
			var sup_slow := boss.item_buff("supervise_slow")
			if sup_slow > 0.0:
				mul *= (1.0 - sup_slow)
	task_progress = minf(1.0, task_progress + delta * mul / Rules.TASK_TIME)
	_refresh_legacy()
	if task_progress >= 1.0:
		tasking = false
		task_progress = 0.0
		tasks_done = mini(tasks_done + 1, Rules.TASK_COUNT)
		add_coins(ItemDB.COIN_TASK_DONE)
		say("「%s」交了" % Rules.task_name(tasks_done - 1), 1.1)
		_refresh_legacy()
		if tasks_done >= Rules.TASK_COUNT:
			_begin_clocking()


func _try_employee_interact() -> void:
	if stand_lock > 0.0:
		return
	if _is_riding():
		say("先 F 下车", 0.9)
		return
	# 事故期间，靠近事故终端按 E 修 Bug
	if Match.incident_active and not fixing:
		if Match.try_start_fix(self):
			return
	# 外卖
	if not Match.delivery_spots.is_empty():
		if Match.try_grab_delivery(slot):
			say(Rules.DELIVERY_QUIPS[randi() % Rules.DELIVERY_QUIPS.size()], 1.5)
			return
	# 贩卖机
	if Match.elapsed >= ItemDB.SHOP_UNLOCK_TIME and want_shop:
		var map := office()
		if map:
			for key in ["shop_0", "shop_1"]:
				if map.points.has(key) and global_position.distance_to(map.points[key]) < Rules.INTERACT_RANGE + 16.0:
					want_shop = true
					return
	if Match.try_carry(self):
		return
	if Match.try_rescue(self):
		return
	var map := office()
	if map.try_door(self):
		return
	var seat := map.nearest_spot("seat", global_position, Rules.INTERACT_RANGE)
	if seat != "":
		if Match.intranet_down:
			say("内网崩了，坐下也没用", 1.2)
			return
		if Match.blackout_active:
			say("停电了，啥也干不了", 1.2)
			return
		if map.take_spot(seat, slot):
			_dismount_bike()
			emp_state = Rules.EmpState.WORK
			global_position = map.points[seat]
			occupy_id = seat
			last_seat = int(seat.get_slice("_", 1))
		return
	var coffee := map.nearest_free("coffee", global_position)
	if coffee != "" and global_position.distance_to(map.points[coffee]) < Rules.INTERACT_RANGE:
		if map.take_spot(coffee, slot):
			_dismount_bike()
			occupy_id = coffee
			emp_state = Rules.EmpState.COFFEE
			global_position = map.points[coffee]
			_begin_play("brew")
		return
	var toilet := map.nearest_free("toilet", global_position)
	if toilet != "" and global_position.distance_to(map.points[toilet]) < Rules.INTERACT_RANGE:
		if map.take_spot(toilet, slot):
			_dismount_bike()
			occupy_id = toilet
			emp_state = Rules.EmpState.TOILET
			global_position = map.points[toilet]
			_begin_play("flush")
		return
	var loot := map.nearest_energy(global_position, Rules.INTERACT_RANGE)
	if loot != "":
		if map.take_energy(loot, slot):
			_dismount_bike()
			occupy_id = loot
			emp_state = Rules.EmpState.WALK
			global_position = map.energy_pos(loot)
			_begin_play(map.energy_kind(loot), loot)
		return
	var stock := map.nearest_spot("stock", global_position, Rules.INTERACT_RANGE)
	if stock != "":
		if trade_cd > 0.05:
			return
		if map.take_spot(stock, slot):
			_begin_trade(stock)
		return
	return


func _stand_up() -> void:
	if emp_state == Rules.EmpState.TRADE and not _trade_settling:
		_reset_trade()
	_abort_task("")
	_cancel_play()
	var map := office()
	if map:
		map.free_spot(occupy_id, slot)
		map.free_energy(occupy_id, slot)
	occupy_id = ""
	emp_state = Rules.EmpState.WALK
	slack_seen = 0.0


func _refresh_legacy() -> void:
	var left := float(Rules.TASK_COUNT - tasks_done) - task_progress
	hours = maxf(0.0, left * (Rules.HOURS_START / float(Rules.TASK_COUNT)))
	energy = (float(energy_cells) + energy_charge) * (Rules.ENERGY_MAX / float(Rules.ENERGY_CELLS))


func _tick_cells(delta: float) -> void:
	if emp_state == Rules.EmpState.LEFT or emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.CARRIED or carried_by >= 0:
		_refresh_legacy()
		return
	if energy_cells >= Rules.ENERGY_CELLS:
		energy_charge = 0.0
		_refresh_legacy()
		return
	if tasking or play_kind != "" or emp_state == Rules.EmpState.MEETING or emp_state == Rules.EmpState.TALK:
		_refresh_legacy()
		return
	var sec := Rules.ENERGY_CHARGE_SEC
	if emp_state == Rules.EmpState.SLACK:
		sec = Rules.ENERGY_SLACK_SEC
	energy_charge = minf(1.0, energy_charge + delta / sec)
	if energy_charge >= 1.0:
		energy_cells += 1
		energy_charge = 0.0
		say("回了一格精力", 0.9)
	_refresh_legacy()


func _start_task() -> void:
	if tasking or energy_cells < 1 or tasks_done >= Rules.TASK_COUNT:
		return
	energy_cells -= 1
	tasking = true
	task_progress = 0.0
	emp_state = Rules.EmpState.WORK
	say("开工「%s」" % Rules.task_name(tasks_done), 1.1)
	_refresh_legacy()


func _abort_task(msg: String) -> void:
	if not tasking:
		return
	tasking = false
	task_progress = 0.0
	if msg != "":
		say(msg, 1.2)
	_refresh_legacy()


func _add_energy(n: int, msg: String) -> void:
	if n <= 0:
		if msg != "":
			say(msg, 1.0)
		return
	energy_cells = mini(Rules.ENERGY_CELLS, energy_cells + n)
	if energy_cells >= Rules.ENERGY_CELLS:
		energy_charge = 0.0
	if msg != "":
		say(msg, 1.1)
	_refresh_legacy()


func lose_task() -> void:
	_abort_task("被加塞，这单废了")
	if tasks_done > 0:
		tasks_done -= 1
		say("KPI 又多了一单", 1.2)
	_refresh_legacy()


func _begin_play(kind: String, loot := "") -> void:
	play_kind = kind
	play_t = 0.0
	play_hits = 0
	play_lock = 0.0
	play_msg = ""
	play_mark = randf_range(0.28, 0.62)
	if loot != "":
		occupy_id = loot
	if kind == "snack":
		play_msg = "连按拆开"
	elif kind == "water":
		play_msg = "接到刚好满"


func _cancel_play() -> void:
	play_kind = ""
	play_t = 0.0
	play_hits = 0
	play_msg = ""
	play_lock = 0.0


func _tick_energy_play(delta: float) -> void:
	velocity = Vector2.ZERO
	if play_kind == "":
		return
	if want_interact or input_dir.length() > 0.12:
		_stand_up()
		return
	if is_bot() and play_lock <= 0.0 and randf() < 0.025:
		want_slack = true
	match play_kind:
		"brew", "flush", "vend", "rummage":
			play_t = 0.5 + 0.5 * sin(Time.get_ticks_msec() * (0.006 if play_kind == "flush" else 0.009) + float(slot))
			if play_kind == "vend":
				play_t = pingpong(Time.get_ticks_msec() * 0.0022 + float(slot), 1.0)
			if play_kind == "rummage":
				play_t = pingpong(Time.get_ticks_msec() * 0.0034 + float(slot) * 1.7, 1.0)
			if want_slack and play_lock <= 0.0:
				_resolve_timing()
		"snack":
			if want_slack:
				play_hits += 1
				play_msg = "撕包装  %d/5" % play_hits
				if play_hits >= 5:
					_finish_play(1, "垫了一口过期的")
		"water":
			play_t = pingpong(Time.get_ticks_msec() * 0.0018 + float(slot), 1.0)
			if want_slack and play_lock <= 0.0:
				_resolve_timing()
	if Match.is_supervised(self) and (emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET):
		slack_seen += delta
		if slack_seen >= Rules.SLACK_CATCH_DELAY + 0.4:
			Match.catch_employee(self)


func _resolve_timing() -> void:
	play_lock = 0.45
	var hit := absf(play_t - play_mark)
	var gain := 0
	var msg := "空了"
	if play_kind == "brew":
		if hit < 0.06:
			gain = 2
			msg = "出杯完美 · 精力 +2"
			coffee_buff = Rules.COFFEE_BUFF_TIME
		elif hit < 0.12:
			gain = 1
			msg = "能喝 · 精力 +1"
		else:
			msg = "洒了 · 再来"
	elif play_kind == "flush":
		if hit < 0.10:
			gain = 2
			msg = "缓过来了 · 精力 +2"
		elif hit < 0.18:
			gain = 1
			msg = "还行 · 精力 +1"
		else:
			msg = "没缓住"
	elif play_kind == "vend":
		if play_t < 0.34:
			gain = 2
			msg = "功能饮料 · 精力 +2"
		elif play_t < 0.72:
			gain = 1
			msg = "难喝的罐装咖啡 · +1"
		else:
			msg = "过期矿泉水 · 0"
	elif play_kind == "rummage":
		if hit < 0.12:
			gain = 1
			msg = "摸到巧克力 · +1"
		else:
			msg = "一抽屉订书钉"
	elif play_kind == "water":
		if play_t > 0.62 and play_t < 0.88:
			gain = 1
			msg = "接得刚好 · +1"
		elif play_t >= 0.88:
			msg = "满溢 · 鞋湿了"
		else:
			msg = "就几滴"
	play_msg = msg
	if gain > 0:
		_finish_play(gain, msg)
	else:
		say(msg, 0.8)


func _finish_play(gain: int, msg: String) -> void:
	var kind := play_kind
	var loot := occupy_id
	_add_energy(gain, msg)
	var map := office()
	if map and (kind == "snack" or kind == "rummage"):
		map.consume_energy(loot)
	_cancel_play()
	if map:
		map.free_spot(loot, slot)
		map.free_energy(loot, slot)
	occupy_id = ""
	emp_state = Rules.EmpState.WALK
	if kind == "brew":
		coffee_buff = Rules.COFFEE_BUFF_TIME


func trade_value() -> float:
	return trade_cash + trade_shares * trade_price


func apply_trade(left: float, price: float, cash: float, shares: float, holding: bool, hist: PackedFloat32Array) -> void:
	trade_left = left
	trade_price = price
	trade_cash = cash
	trade_shares = shares
	trade_holding = holding
	trade_history = hist


func _begin_trade(spot: String) -> void:
	_dismount_bike()
	occupy_id = spot
	emp_state = Rules.EmpState.TRADE
	global_position = office().points[spot]
	_facing = Vector2.RIGHT
	trade_left = Rules.STOCK_TIME
	trade_price = Rules.STOCK_START
	trade_cash = Rules.STOCK_START
	trade_shares = 0.0
	trade_holding = false
	trade_tick = 0.0
	trade_history = PackedFloat32Array([Rules.STOCK_START])
	Match.sync_trade.rpc(slot, trade_left, trade_price, trade_cash, trade_shares, trade_holding, trade_history)


func _tick_trade(delta: float) -> void:
	velocity = Vector2.ZERO
	_facing = Vector2.RIGHT
	trade_left = maxf(0.0, trade_left - delta)
	trade_tick += delta
	if trade_tick >= Rules.STOCK_TICK:
		trade_tick = 0.0
		var step := randf_range(-1.15, 1.15)
		step = signf(step) * (0.35 + absf(step) * 3.4)
		if randf() < 0.10:
			step *= 2.2
		trade_price = clampf(trade_price + step, 48.0, 168.0)
		trade_history.append(trade_price)
		if trade_history.size() > 96:
			trade_history.remove_at(0)
		Match.sync_trade.rpc(slot, trade_left, trade_price, trade_cash, trade_shares, trade_holding, trade_history)
	if want_slack:
		_toggle_trade()
	if want_interact or trade_left <= 0.0:
		_finish_trade()


func _toggle_trade() -> void:
	if trade_holding:
		trade_cash = trade_shares * trade_price
		trade_shares = 0.0
		trade_holding = false
	else:
		if trade_cash < 0.01:
			return
		trade_shares = trade_cash / maxf(trade_price, 0.01)
		trade_cash = 0.0
		trade_holding = true
	Match.sync_trade.rpc(slot, trade_left, trade_price, trade_cash, trade_shares, trade_holding, trade_history)


func _finish_trade() -> void:
	if trade_holding:
		trade_cash = trade_shares * trade_price
		trade_shares = 0.0
		trade_holding = false
	var pnl := trade_cash - Rules.STOCK_START
	_trade_settling = true
	var won := pnl > Rules.STOCK_WIN
	_reset_trade()
	_stand_up()
	_trade_settling = false
	trade_cd = Rules.STOCK_CD
	if won:
		_add_energy(Rules.STOCK_ENERGY_GAIN, "持股计划 %+0.0f · 精力 +%d" % [pnl, Rules.STOCK_ENERGY_GAIN])
		coffee_buff = maxf(coffee_buff, Rules.COFFEE_BUFF_TIME)
		Match.apply_stock_boost(slot, pnl)
	elif pnl < -Rules.STOCK_WIN:
		Match.notify_stock.rpc(slot, pnl, 0.0, false)
		say("亏了，精力还在", 1.2)
	else:
		Match.notify_stock.rpc(slot, pnl, 0.0, false)
		say("平盘", 1.1)


func _reset_trade() -> void:
	trade_left = 0.0
	trade_shares = 0.0
	trade_holding = false
	trade_tick = 0.0
	trade_history = PackedFloat32Array()
	trade_price = Rules.STOCK_START
	trade_cash = Rules.STOCK_START


func _begin_clocking() -> void:
	tasks_done = Rules.TASK_COUNT
	tasking = false
	task_progress = 0.0
	_stand_up()
	hours = 0.0
	emp_state = Rules.EmpState.CLOCKING


func _clock_out() -> void:
	_dismount_bike()
	emp_state = Rules.EmpState.LEFT
	visible = false
	Match.on_clock_out(slot)


func _tick_talk(delta: float) -> void:
	velocity = Vector2.ZERO
	var watched := Match.is_watched(self)
	var dur := Rules.TALK_WATCH_TIME if watched else Rules.TALK_ALONE_TIME
	talk_progress = min(1.0, talk_progress + delta / dur)
	if talk_progress >= 1.0:
		Match.finish_talk(self)


func begin_talk() -> void:
	Match.release_actor_carry(self, true)
	_dismount_bike()
	_stand_up()
	emp_state = Rules.EmpState.TALK
	talk_progress = 0.0
	clear_rescue()


func end_talk_rescued() -> void:
	emp_state = Rules.EmpState.WALK
	talk_progress = 0.0
	slack_seen = 0.0


func clear_rescue() -> void:
	rescue_left = 0.0
	rescue_slot = -1


func apply_catch(repeat: bool, extra_stun: float) -> void:
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	# 卷王工牌：任务 >80% 免疫一次抓捕
	var immune_thresh := item_buff("catch_immune_threshold")
	if immune_thresh > 0.0 and task_progress >= immune_thresh:
		say("还差一点就交了！", 1.0)
		return
	_dismount_bike()
	_stand_up()
	if repeat and tasks_done > 0:
		tasks_done -= 1
	# 装备：站立惩罚减少
	var lock_reduce := item_buff("stand_lock_reduce")
	stand_lock = (Rules.CATCH_STAND_LOCK + extra_stun) * (1.0 - lock_reduce)
	catch_chain = Rules.CATCH_CHAIN_WINDOW
	slack_seen = 0.0
	talk_progress = 0.0
	rescue_left = 0.0
	rescue_slot = -1
	# 弹性工时：被抓后叠层
	if item_buff("catch_stack_work") > 0.0:
		catch_stack = mini(catch_stack + 1, 3)
	# Boss PUA 圣经：扣精力
	if Match.actors.has(Rules.Slot.BOSS):
		var boss: Actor = Match.actors[Rules.Slot.BOSS]
		var drain := int(boss.item_buff("catch_drain_energy"))
		if drain > 0:
			energy_cells = maxi(0, energy_cells - drain)
	_refresh_legacy()


func send_to_meeting(seconds: float, meeting_pos: Vector2) -> void:
	Match.release_actor_carry(self, true)
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	_dismount_bike()
	_stand_up()
	emp_state = Rules.EmpState.MEETING
	meeting_left = seconds
	talk_progress = 0.0
	clear_rescue()
	global_position = meeting_pos


func facing_dir() -> Vector2:
	if input_dir.length() > 0.12:
		return input_dir.normalized()
	if _facing.length() > 0.12:
		return _facing.normalized()
	return Vector2.DOWN


func throw_hand_offset() -> Vector2:
	var face := facing_dir()
	var side := 1.0 if _facing.x >= 0.0 else -1.0
	if absf(face.x) >= 0.25:
		side = signf(face.x)
	return Vector2(side * 22.0, -50.0)


func throw_origin() -> Vector2:
	var face := facing_dir()
	return global_position + Vector2(throw_hand_offset().x, 0.0) + face * 10.0


func _slowed(speed: float) -> float:
	if slow_left > 0.0:
		return speed * Rules.REPORT_SLOW_MUL
	return speed


func apply_report_hit() -> bool:
	if kind != Rules.Kind.EMPLOYEE:
		return false
	if emp_state in [Rules.EmpState.LEFT, Rules.EmpState.TALK, Rules.EmpState.MEETING, Rules.EmpState.CARRIED]:
		return false
	slow_left = Rules.REPORT_SLOW_TIME
	_slow_flash = 0.55
	if energy_charge > 0.12:
		energy_charge = 0.0
	elif energy_cells > 0:
		energy_cells -= 1
	_refresh_legacy()
	say("请查收", 1.25)
	return true


func _emp_can_dash() -> bool:
	if bike_left > 0.0 or carried_by >= 0 or stand_lock > 0.0:
		return false
	if carry_windup > 0.0:
		return false
	return emp_state == Rules.EmpState.WALK or emp_state == Rules.EmpState.CLOCKING


func _try_start_emp_dash() -> bool:
	if not want_dash or not _emp_can_dash():
		return false
	return _start_dash(Rules.EMP_DASH_CD, Rules.EMP_DASH_TIME)


func _start_dash(cd: float, dur: float) -> bool:
	if dash_cd > 0.0 or dash_left > 0.0:
		return false
	var d := input_dir
	if d.length() < 0.12:
		d = _facing
	if d.length() < 0.12:
		return false
	dash_dir = d.normalized()
	dash_left = dur
	dash_cd = cd
	return true


func _boss_tick(delta: float) -> void:
	var dash_cd_r := item_buff("dash_cd_reduce")
	if want_dash:
		var cd := Rules.TIGER_DASH_CD * (1.0 - dash_cd_r)
		_start_dash(cd, Rules.TIGER_DASH_TIME)
	var speed := Rules.BOSS_BASE_SPEED * Rules.TIGER_SPEED_MUL
	var boss_spd := item_buff("speed")
	if boss_spd > 0.0:
		speed *= (1.0 + boss_spd)
	if dash_left > 0.0:
		velocity = dash_dir * Rules.TIGER_DASH_SPEED
	else:
		velocity = input_dir.limit_length(1.0) * speed
	move_and_slide()
	if velocity.length() > 8.0:
		_facing = velocity.normalized()
	# 门禁卡：自动开门
	if item_has("auto_door") and office():
		var door = office().nearest_door(global_position, Rules.DOOR_RANGE)
		if door != null and door.closed:
			office().try_door(self)
	if want_interact:
		if not Match.delivery_spots.is_empty():
			Match.try_grab_delivery(slot)
		if not Match.try_catch(self) and office():
			office().try_door(self)
	if office():
		var stuck = office().nearest_door(global_position, 52.0)
		if stuck != null and stuck.closed:
			office().try_door(self)
	if want_meeting and meeting_cd <= 0.0:
		if Match.try_meeting(self):
			meeting_cd = Rules.TIGER_MEETING_CD
	if want_kpi and kpi_cd <= 0.0 and Match.elapsed >= Rules.KPI_UNLOCK:
		Match.cast_kpi()
		kpi_cd = Rules.KPI_CD
		kpi_flash = 1.6
	if want_report and report_cd <= 0.0:
		var rcd_r := item_buff("report_cd_reduce")
		if Match.try_throw_reports(self, false):
			report_cd = Rules.REPORT_CD * (1.0 - rcd_r)
			throw_flash = 0.16
	if want_fan and fan_cd <= 0.0:
		if Match.try_throw_reports(self, true):
			fan_cd = Rules.REPORT_FAN_CD
			throw_flash = 0.16
	if want_incident and incident_cd <= 0.0 and Match.elapsed >= Rules.INCIDENT_UNLOCK and not Match.incident_active:
		if Match.cast_incident(self):
			incident_cd = Rules.INCIDENT_CD
			say(Rules.INCIDENT_BOSS_QUIPS[randi() % Rules.INCIDENT_BOSS_QUIPS.size()], 1.8)


func _move_towards(target: Vector2, speed: float, delta: float) -> void:
	var d := target - global_position
	if d.length() < 4.0:
		velocity = Vector2.ZERO
		return
	velocity = d.normalized() * speed
	move_and_slide()
	_facing = velocity.normalized()


func apply_input(x: float, y: float, interact: bool, slack: bool, meeting: bool, kpi: bool, dash: bool, report := false, fan := false, incident := false, blame := false) -> void:
	input_dir = Vector2(x, y)
	if interact:
		want_interact = true
	if slack:
		want_slack = true
	if meeting:
		want_meeting = true
	if kpi:
		want_kpi = true
	if dash:
		want_dash = true
	if report:
		want_report = true
	if fan:
		want_fan = true
	if incident:
		want_incident = true
	if blame:
		want_blame = true


@rpc("any_peer", "unreliable")
func recv_input(x: float, y: float, interact: bool, slack: bool, meeting: bool, kpi: bool, dash: bool, report := false, fan := false, incident := false, blame := false) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	apply_input(x, y, interact, slack, meeting, kpi, dash, report, fan, incident, blame)


func apply_snapshot(px: float, py: float, st: int, h: float, e: float, vis: bool, mcd: float, kcd: float, dcd: float, talk: float = 0.0, rescue: float = 0.0, bike: float = 0.0, slow: float = 0.0, rcd: float = 0.0, fcd: float = 0.0) -> void:
	_remote_pos = Vector2(px, py)
	emp_state = st
	hours = h
	energy = e
	visible = vis
	meeting_cd = mcd
	kpi_cd = kcd
	dash_cd = dcd
	talk_progress = talk
	rescue_left = rescue
	bike_left = bike
	slow_left = slow
	report_cd = rcd
	fan_cd = fcd
	if name_label:
		name_label.text = display_name


func _broadcast_state() -> void:
	Match.sync_actor.rpc(slot, global_position.x, global_position.y, emp_state, hours, energy, visible, meeting_cd, kpi_cd, dash_cd, occupy_id, talk_progress, rescue_left, bike_left, slow_left, report_cd, fan_cd)
	Match.sync_cells.rpc(slot, tasks_done, task_progress, energy_cells, energy_charge, play_kind, play_t, play_mark, play_hits, play_msg, 1 if tasking else 0, occupy_id)
	if emp_state == Rules.EmpState.TRADE:
		Match.sync_trade.rpc(slot, trade_left, trade_price, trade_cash, trade_shares, trade_holding, trade_history)


func _show_resource_bars() -> bool:
	if kind != Rules.Kind.EMPLOYEE or emp_state == Rules.EmpState.LEFT:
		return false
	var my := Match.my_slot()
	if my == Rules.Slot.BOSS:
		return false
	return Rules.slot_is_employee(my)


func _draw() -> void:
	if carried_by >= 0:
		return
	# 事故责任人红色脉冲标记
	if is_blame_target and Match.incident_active:
		var pulse := 0.65 + 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
		draw_circle(Vector2(0, -18), 58.0 * pulse, Color(0.95, 0.08, 0.06, 0.28 * pulse))
		draw_arc(Vector2(0, -18), 62.0 * pulse, 0, TAU, 32, Color(1.0, 0.15, 0.10, 0.72), 2.8)
	# 修 Bug 进度条
	if fixing and fix_progress > 0.0:
		var w := 48.0
		var ty := -108.0
		draw_rect(Rect2(-w * 0.5, ty, w, 6), Color(0.14, 0.14, 0.16, 0.9))
		draw_rect(Rect2(-w * 0.5, ty, w * clampf(fix_progress, 0.0, 1.0), 6), Color(0.22, 0.88, 0.42))
	if kind == Rules.Kind.EMPLOYEE and emp_state == Rules.EmpState.TALK:
		var watched := Match.is_watched(self)
		var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
		var col := Color(0.85, 0.10, 0.08, (0.22 if watched else 0.13) * pulse)
		draw_circle(Vector2(0, -18), 52.0 * pulse, col)
		draw_arc(Vector2(0, -18), 56.0 * pulse, 0, TAU, 32, Color(0.92, 0.18, 0.14, 0.62 if watched else 0.34), 2.2)
	if kind == Rules.Kind.EMPLOYEE and (rescue_left > 0.0 or boost_left > 0.0):
		var a := 0.35 if rescue_left > 0.0 else 0.22
		draw_line(Vector2(-28, -8), Vector2(-8, -20), Color(1, 1, 0.7, a), 2.0)
		draw_line(Vector2(-24, 6), Vector2(-4, -4), Color(1, 1, 0.7, a), 2.0)
	if kind == Rules.Kind.EMPLOYEE and slow_left > 0.0:
		var t := Time.get_ticks_msec() * 0.006
		var ring := 0.55 + 0.45 * (slow_left / Rules.REPORT_SLOW_TIME)
		draw_arc(Vector2(0, -10), 22.0 + sin(t) * 2.0, 0, TAU, 24, Color(0.72, 0.55, 0.22, 0.28 + 0.22 * ring), 2.0)
		if _slow_flash > 0.0:
			draw_circle(Vector2(0, -12), 36.0, Color(0.95, 0.86, 0.62, _slow_flash * 0.35))
	if kind != Rules.Kind.EMPLOYEE:
		return
	if _show_resource_bars():
		var y := -78.0
		if name_label:
			y = name_label.position.y + 16.0
		_draw_cells(Vector2(-28, y), tasks_done, Rules.TASK_COUNT, task_progress if tasking else 0.0, Color(0.24, 0.86, 0.94))
		_draw_cells(Vector2(-28, y + 10), energy_cells, Rules.ENERGY_CELLS, energy_charge, Color(0.96, 0.78, 0.29))
	if emp_state != Rules.EmpState.TALK:
		return
	var w := 42.0
	var ty := -100.0
	if name_label:
		ty = name_label.position.y - 10.0
	draw_rect(Rect2(-w * 0.5, ty, w, 6), Color(0.14, 0.14, 0.16, 0.9))
	var fill := Color(0.86, 0.22, 0.18) if Match.is_watched(self) else Color(0.95, 0.62, 0.22)
	draw_rect(Rect2(-w * 0.5, ty, w * clampf(talk_progress, 0.0, 1.0), 6), fill)


func _draw_cells(pos: Vector2, filled: int, total: int, partial: float, accent: Color) -> void:
	var n := maxi(total, 1)
	var w := 9.0
	for i in n:
		var p := pos + Vector2(float(i) * (w + 2.0), 0)
		draw_rect(Rect2(p, Vector2(w, 7)), Color(0.16, 0.18, 0.22, 0.72))
		if i < filled:
			draw_rect(Rect2(p, Vector2(w, 7)), accent)
		elif i == filled and partial > 0.04:
			draw_rect(Rect2(p, Vector2(w * clampf(partial, 0.0, 1.0), 7)), accent.lerp(Color.WHITE, 0.25))


func _draw_meter(pos: Vector2, width: float, height: float, ratio: float, accent: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.16, 0.18, 0.22, 0.72))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0.0, 1.0), height)), accent)
