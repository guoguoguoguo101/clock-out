extends Control
class_name CampusHUD

const MapOverlay := preload("res://src/ui/CampusMap.gd")
const ThinBar := preload("res://src/ui/ThinBar.gd")
const INK := Color("#eef0e7")
const MUTED := Color("#c3cecc")
const MINT := Color("#91c8c4")
const GOLD := Color("#d2b66e")
const PACKS := ["horse", "pelican", "kangaroo", "dog"]
const NICKS := ["小马", "鹈鹕", "袋鼠", "小狗"]

var time_label: Label
var watch_label: Label
var room_warn: Label
var kpi_label: Label
var catch_banner: Label
var catch_veil: ColorRect
var hint_label: Label
var location_label: Label
var you_role: Label
var state_label: Label
var hours_bar
var energy_bar
var perf_bar
var task_card: Panel
var roster: Panel
var energy: Panel
var clock_card: Panel
var key_e: Panel
var key_f: Panel
var key_e_lab: Label
var key_f_lab: Label
var rec_label: Label
var cam_id_label: Label
var task_count: Label
var task_caption: Label
var energy_num: Label
var task_steps: Label
var rows: Array[Dictionary] = []
var cells: Array[ColorRect] = []
var docs: Array[ColorRect] = []
var mate_box: Array[ColorRect] = []
var mate_lab: Array[Label] = []
var mate_snow: Array[ColorRect] = []
var power_pips_ui: Array = []
var map_overlay: Control
var office: OfficeMap


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(self, "六点下班", Vector2(24, 16), 21, Color("#415766"))
	location_label = _label(self, "3F / 产品研发中心", Vector2(24, 46), 11, Color("#516777"))
	rec_label = _label(self, "● REC", Vector2(148, 18), 13, Color(0.92, 0.16, 0.14, 0.0))
	cam_id_label = _label(self, "CAM 07", Vector2(24, 64), 10, Color(0.45, 0.52, 0.56, 0.7))
	clock_card = _panel(self, Vector2(224, 66), 0.76)
	time_label = _label(clock_card, "17:50", Vector2(14, 12), 28)
	watch_label = _label(clock_card, "还有 10:00", Vector2(118, 25), 12)
	_label(clock_card, "考勤系统", Vector2(120, 8), 10, MUTED)
	room_warn = _label(self, "", Vector2.ZERO, 12, Color("#a53e38"))
	room_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_warn.size.x = 320
	task_card = _panel(self, Vector2(220, 168), 0.71)
	_label(task_card, "今日任务 / DAILY", Vector2(14, 10), 15)
	task_caption = _label(task_card, "交完 5 单才能打卡下班", Vector2(14, 34), 11, MUTED)
	for i in Rules.TASK_COUNT:
		var doc := ColorRect.new()
		doc.position = Vector2(14 + i * 38, 56)
		doc.size = Vector2(30, 22)
		doc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		doc.color = Color(0.7, 0.75, 0.75, 0.22)
		task_card.add_child(doc)
		docs.append(doc)
	task_steps = _label(task_card, "日报  周报  对齐  复盘  纪要", Vector2(14, 80), 10, MUTED)
	task_count = _label(task_card, "进度 0 / 5        0%", Vector2(14, 100), 12)
	hours_bar = _bar(task_card, Vector2(14, 124), Vector2(192, 6), MINT)
	state_label = _label(task_card, "在岗", Vector2(14, 136), 10, MUTED)
	roster = _panel(self, Vector2(198, 194), 0.59)
	perf_bar = roster
	_label(roster, "同事 / 绩效", Vector2(10, 8), 10, MUTED)
	for i in 4:
		var y := 30.0 + i * 40.0
		var box := ColorRect.new()
		box.color = Color(0.11, 0.16, 0.18, 0.0)
		box.position = Vector2(6, y - 2)
		box.size = Vector2(186, 38)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster.add_child(box)
		mate_box.append(box)
		var snow := ColorRect.new()
		snow.color = Color(0.78, 0.80, 0.82, 0.0)
		snow.position = Vector2.ZERO
		snow.size = box.size
		snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(snow)
		mate_snow.append(snow)
		var portrait := TextureRect.new()
		portrait.texture = _head_tex(PACKS[i])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(8, y)
		portrait.size = Vector2(30, 34)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster.add_child(portrait)
		var name_tag := _label(roster, NICKS[i], Vector2(44, y), 11)
		mate_lab.append(name_tag)
		var status := _label(roster, "●", Vector2(108, y), 10, MINT)
		var number := _label(roster, "100", Vector2(160, y), 10)
		var bar := _bar(roster, Vector2(44, y + 23), Vector2(140, 3), MINT)
		rows.append({"name": name_tag, "status": status, "number": number, "bar": bar})
	energy = _panel(self, Vector2(286, 34), 0.66)
	energy_bar = energy
	you_role = _label(energy, "精力", Vector2(12, 8), 12)
	for i in Rules.ENERGY_CELLS:
		var cell := ColorRect.new()
		cell.position = Vector2(58 + i * 28, 13)
		cell.size = Vector2(24, 8)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy.add_child(cell)
		cells.append(cell)
	for i in 3:
		var pip := TextureRect.new()
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.position = Vector2(58 + i * 28, 6)
		pip.size = Vector2(22, 22)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		energy.add_child(pip)
		power_pips_ui.append(pip)
	energy_num = _label(energy, "50%", Vector2(232, 8), 12)
	key_e = _chip(self, "E  交互")
	key_f = _chip(self, "F  摸鱼")
	key_e_lab = key_e.get_child(0) as Label
	key_f_lab = key_f.get_child(0) as Label
	hint_label = _label(self, "E 交互   F 摸鱼   Tab 导览", Vector2.ZERO, 11, Color("#415766"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.size = Vector2(520, 18)
	kpi_label = _label(self, "全员 KPI · 再加一单", Vector2.ZERO, 17, Color("#ad443d"))
	kpi_label.visible = false
	catch_banner = _label(self, "", Vector2.ZERO, 14, Color("#ad443d"))
	catch_banner.visible = false
	catch_veil = ColorRect.new()
	catch_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catch_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_veil.color = Color(0.55, 0.05, 0.05, 0.0)
	add_child(catch_veil)
	map_overlay = MapOverlay.new()
	add_child(map_overlay)
	resized.connect(_layout)
	_layout()


func _panel(parent: Control, dimensions: Vector2, alpha: float) -> Panel:
	var panel := Panel.new()
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.16, 0.18, alpha)
	box.border_color = Color(0.8, 0.87, 0.85, 0.38)
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	return panel


func _chip(parent: Control, text: String) -> Panel:
	var chip := _panel(parent, Vector2(76, 28), 0.62)
	var lab := _label(chip, text, Vector2(8, 5), 11)
	lab.size = Vector2(60, 18)
	return chip


func _label(parent: Control, text: String, pos: Vector2, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _bar(parent: Control, pos: Vector2, dimensions: Vector2, color: Color) -> Control:
	var bar := ThinBar.new()
	bar.position = pos
	bar.size = dimensions
	bar.accent = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _head_tex(pack: String) -> Texture2D:
	var source: Texture2D = load("res://assets/game/chars/%s/idle_0.png" % pack)
	if source == null:
		return null
	var img := source.get_image()
	if img == null:
		return source
	var used := img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return source
	var head := AtlasTexture.new()
	head.atlas = source
	head.region = Rect2(used.position, Vector2(used.size.x, used.size.y * 0.58))
	return head


func _layout() -> void:
	if clock_card == null:
		return
	clock_card.position = Vector2((size.x - 224.0) / 2.0, 14)
	room_warn.position = Vector2((size.x - 320.0) / 2.0, 84)
	task_card.position = Vector2(size.x - 240.0, 76)
	roster.position = Vector2(20, size.y - 214.0)
	energy.position = Vector2((size.x - 286.0) / 2.0, size.y - 54.0)
	key_e.position = Vector2(size.x - 172.0, size.y - 48.0)
	key_f.position = Vector2(size.x - 88.0, size.y - 48.0)
	hint_label.position = Vector2((size.x - 520.0) / 2.0, size.y - 86.0)
	kpi_label.position = Vector2((size.x - 240.0) / 2.0, 109)
	catch_banner.position = Vector2((size.x - 350.0) / 2.0, 136)


func refresh(actor: Actor) -> void:
	if Match.phase == "countdown":
		time_label.text = "17:50"
		watch_label.text = "入场 %d" % ceili(Match.countdown)
	else:
		time_label.text = Rules.office_clock_text(Match.day_progress())
		watch_label.text = "还有 %d:%02d" % [int(Match.time_left) / 60, int(Match.time_left) % 60]
	if actor == null:
		you_role.text = "旁观"
		task_caption.text = "等待入场"
		task_count.text = "进度 —"
		state_label.text = "工牌 · 旁观"
		energy.visible = false
		hours_bar.visible = false
		_set_keys("E  交互", "F  摸鱼")
		refresh_roster(null)
		return
	if office:
		var room := office.room_id(actor.global_position)
		office.discovered[room] = true
		location_label.text = "3F / " + office.room_title(actor.global_position)
	var boss := actor.kind == Rules.Kind.BOSS
	energy.visible = true
	hours_bar.visible = not boss
	if boss:
		_refresh_boss(actor)
	else:
		_refresh_employee(actor)
	refresh_roster(actor)


func _refresh_employee(actor: Actor) -> void:
	you_role.text = "精力"
	var done := actor.tasks_done
	var partial := actor.task_progress if actor.tasking else 0.0
	var progress := clampf((float(done) + partial) / float(Rules.TASK_COUNT), 0.0, 1.0)
	hours_bar.value = progress * 100.0
	task_count.text = "进度 %d / %d        %d%%" % [done, Rules.TASK_COUNT, floori(progress * 100.0)]
	var names := Rules.TASK_NAMES
	var step := ""
	for i in Rules.TASK_COUNT:
		var mark := "■" if i < done else ("◆" if i == done and actor.tasking else "□")
		var title := str(names[i]) if i < names.size() else "单"
		step += mark + title + "  "
		if i < docs.size():
			if i < done:
				docs[i].color = MINT
			elif i == done and actor.tasking:
				docs[i].color = GOLD
			else:
				docs[i].color = Color(0.7, 0.75, 0.75, 0.22)
	task_steps.text = step.strip_edges()
	if done >= Rules.TASK_COUNT:
		task_caption.text = "已完成 · 前往门厅打卡"
	elif actor.tasking:
		task_caption.text = "正在写「%s」" % Rules.task_name(done)
	else:
		task_caption.text = "下一单「%s」 · 坐下即开工" % Rules.task_name(done)
	state_label.text = _employee_state(actor)
	var amount := clampf(float(actor.energy_cells) + actor.energy_charge, 0.0, float(Rules.ENERGY_CELLS))
	var low := amount <= 1.5
	energy_num.text = "%d%%" % roundi(amount / float(Rules.ENERGY_CELLS) * 100.0)
	for i in cells.size():
		cells[i].visible = true
		if amount >= float(i + 1):
			cells[i].color = Color("#d78674") if low else GOLD
		elif amount > float(i):
			var a := amount - float(i)
			cells[i].color = (Color("#d78674") if low else GOLD).lerp(Color(0.7, 0.75, 0.75, 0.22), 1.0 - a)
		else:
			cells[i].color = Color(0.7, 0.75, 0.75, 0.22)
	for pip in power_pips_ui:
		pip.visible = false
	_set_keys("E  交互", "F  摸鱼")


func _refresh_boss(actor: Actor) -> void:
	you_role.text = "势力"
	task_caption.text = "E 约谈 · Q 开会 · R KPI"
	task_count.text = "周报 %.0fs / 扇形 %.0fs" % [actor.report_cd, actor.fan_cd]
	task_steps.text = "空格短扑 · KPI %.0fs" % actor.kpi_cd
	var stun := "硬直 %.1fs" % actor.lunge_stun if actor.lunge_stun > 0.05 else "在岗督导"
	state_label.text = "势力 %d/3 · %s" % [actor.power_pips, stun]
	hours_bar.visible = false
	for doc in docs:
		doc.color = Color("#d78674") if actor.power_pips >= 3 else Color(0.7, 0.75, 0.75, 0.22)
	var ready := actor.dash_cd <= 0.05
	energy_num.text = "冲刺" if ready else "%.0fs" % actor.dash_cd
	for cell in cells:
		cell.visible = false
	for i in power_pips_ui.size():
		var pip: TextureRect = power_pips_ui[i]
		pip.visible = true
		var on := i < actor.power_pips
		pip.texture = Rules.tex(Rules.UI_POWER_ON if on else Rules.UI_POWER_OFF)
		pip.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
	_set_keys("空格 扑", "F  周报")


func _employee_state(actor: Actor) -> String:
	if actor.dizzy and actor.emp_state == Rules.EmpState.WALK:
		return "头晕目眩 · %.0fs" % actor.dizzy_left
	if actor.emp_state == Rules.EmpState.TALK:
		return "复盘恢复 %.0f%%" % (actor.talk_progress * 100.0)
	if actor.emp_state == Rules.EmpState.DRAGGED:
		return "被拖去开会"
	if actor.emp_state == Rules.EmpState.MEETING:
		return "绑在会议室 · 等捞"
	if actor.emp_state == Rules.EmpState.FIRED:
		return "已被开除"
	var st := str(Rules.STATE_NAMES.get(actor.emp_state, ""))
	if actor.tasking:
		st = "在写「%s」" % Rules.task_name(actor.tasks_done)
	if actor.energy_cells <= 0:
		st += " · 没精力"
	return st


func refresh_roster(me: Actor) -> void:
	var boss := me != null and me.kind == Rules.Kind.BOSS
	for i in rows.size():
		var slot: int = Rules.EMPLOYEE_SLOTS[i] if i < Rules.EMPLOYEE_SLOTS.size() else -1
		var row := rows[i]
		var name_lab: Label = row.name
		var status: Label = row.status
		var number: Label = row.number
		var bar = row.bar
		var box := mate_box[i]
		box.color = Color(0.11, 0.16, 0.18, 0.0)
		name_lab.text = NICKS[i] if i < NICKS.size() else "?"
		if slot < 0 or not Match.actors.has(slot):
			status.text = "空位"
			status.add_theme_color_override("font_color", MUTED)
			number.text = ""
			bar.visible = false
			continue
		var employee: Actor = Match.actors[slot] as Actor
		if employee == null:
			continue
		if slot == (me.slot if me else -1):
			name_lab.text = NICKS[i] + "·我"
		var seen := me == null or office == null or office.same_view(me.global_position, employee.global_position)
		if boss:
			seen = true
		bar.visible = not boss and seen
		number.visible = not boss and seen
		if employee.emp_state == Rules.EmpState.LEFT:
			status.text = "下班"
			status.add_theme_color_override("font_color", MINT)
			box.color = Color(0.16, 0.28, 0.18, 0.28)
		elif employee.emp_state == Rules.EmpState.FIRED:
			status.text = "开除"
			status.add_theme_color_override("font_color", Color("#e69a85"))
			box.color = Color(0.32, 0.08, 0.08, 0.32)
		elif not seen:
			status.text = "—"
			status.add_theme_color_override("font_color", MUTED)
			bar.visible = false
			number.visible = false
		elif employee.emp_state == Rules.EmpState.TALK:
			status.text = "复盘"
			status.add_theme_color_override("font_color", Color("#e69a85"))
			box.color = Color(0.42, 0.12, 0.10, 0.38)
		elif employee.emp_state == Rules.EmpState.DRAGGED:
			status.text = "拖走"
			status.add_theme_color_override("font_color", Color("#e69a85"))
		elif employee.emp_state == Rules.EmpState.MEETING:
			status.text = "开会"
			status.add_theme_color_override("font_color", Color("#e69a85"))
		elif employee.dizzy:
			status.text = "头晕"
			status.add_theme_color_override("font_color", GOLD)
		else:
			status.text = str(Rules.STATE_NAMES.get(employee.emp_state, ""))
			status.add_theme_color_override("font_color", MINT)
		if not boss and seen:
			bar.value = clampf(employee.perf_hp, 0.0, 100.0)
			bar.accent = Color("#d78674") if employee.perf_hp <= Rules.PERF_FIRE else MINT
			number.text = str(roundi(employee.perf_hp))
		else:
			number.text = ""


func _set_keys(left: String, right: String) -> void:
	if key_e_lab:
		key_e_lab.text = left
	if key_f_lab:
		key_f_lab.text = right


func _process(_delta: float) -> void:
	if not visible:
		return
	if map_overlay:
		map_overlay.office = office
		map_overlay.actor = Match.actors.get(Match.my_slot()) as Actor
		map_overlay.visible = Input.is_physical_key_pressed(KEY_TAB)
		if map_overlay.visible:
			move_child(map_overlay, get_child_count() - 1)
			map_overlay.queue_redraw()
