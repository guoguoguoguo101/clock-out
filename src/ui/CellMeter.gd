extends Control
class_name CellMeter

var cap_lab: Label
var hint_lab: Label
var mean_lab: Label
var icon: TextureRect
var rail: ColorRect
var stripe: ColorRect
var cells: Array[TextureRect] = []
var slots: Array[ColorRect] = []
var glows: Array[ColorRect] = []
var charge: ColorRect
var hp_track: ColorRect
var hp_fill: ColorRect
var hp_shine: ColorRect
var hp_tick: ColorRect
var hp_tick_lab: Label
var kind := "task"
var cap := 5
var _filled := 0
var _charge := 0.0


func setup(title: String, p_kind: String, p_cap: int) -> void:
	kind = p_kind
	cap = p_cap
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell_w := 44.0
	var width := maxf(272.0, 18.0 + float(cap) * cell_w)
	custom_minimum_size = Vector2(width, 92)
	size = Vector2(width, 92)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = _panel_color()
	add_child(bg)
	stripe = ColorRect.new()
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(6, 92)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.color = _title_color()
	add_child(stripe)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(14, 8)
	icon.size = Vector2(26, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = Rules.tex(_icon_path())
	add_child(icon)
	cap_lab = Label.new()
	cap_lab.text = title
	cap_lab.position = Vector2(44, 6)
	cap_lab.add_theme_font_size_override("font_size", 16)
	cap_lab.add_theme_color_override("font_color", _title_color())
	add_child(cap_lab)
	hint_lab = Label.new()
	hint_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lab.position = Vector2(width - 128, 6)
	hint_lab.size = Vector2(118, 22)
	hint_lab.add_theme_font_size_override("font_size", 15)
	hint_lab.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	add_child(hint_lab)
	mean_lab = Label.new()
	mean_lab.position = Vector2(44, 26)
	mean_lab.size = Vector2(width - 56, 16)
	mean_lab.add_theme_font_size_override("font_size", 11)
	mean_lab.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	mean_lab.text = _meaning()
	add_child(mean_lab)
	rail = ColorRect.new()
	rail.position = Vector2(12, 46)
	rail.size = Vector2(width - 24, 38)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.color = Color(0.05, 0.06, 0.08, 0.55)
	add_child(rail)
	for i in cap:
		var slot := ColorRect.new()
		slot.position = Vector2(16 + i * cell_w, 50)
		slot.size = Vector2(38, 30)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.color = Color(0.10, 0.11, 0.13, 0.9)
		add_child(slot)
		slots.append(slot)
		var glow := ColorRect.new()
		glow.position = Vector2(16 + i * cell_w, 50)
		glow.size = Vector2(38, 30)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.color = Color(_title_color(), 0.0)
		add_child(glow)
		glows.append(glow)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(16 + i * cell_w, 48)
		pic.size = Vector2(38, 34)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		cells.append(pic)
	charge = ColorRect.new()
	charge.color = _charge_color()
	charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(charge)
	hp_track = ColorRect.new()
	hp_track.position = Vector2(12, 50)
	hp_track.size = Vector2(width - 24, 28)
	hp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_track.color = Color(0.10, 0.06, 0.06, 0.95)
	hp_track.visible = kind == "perf"
	add_child(hp_track)
	hp_fill = ColorRect.new()
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.visible = kind == "perf"
	add_child(hp_fill)
	hp_shine = ColorRect.new()
	hp_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_shine.color = Color(1, 1, 1, 0.10)
	hp_shine.visible = kind == "perf"
	add_child(hp_shine)
	hp_tick = ColorRect.new()
	hp_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_tick.color = Color(1.0, 0.92, 0.45, 0.95)
	hp_tick.visible = kind == "perf"
	add_child(hp_tick)
	hp_tick_lab = Label.new()
	hp_tick_lab.text = "开除"
	hp_tick_lab.add_theme_font_size_override("font_size", 10)
	hp_tick_lab.add_theme_color_override("font_color", Color(1.0, 0.78, 0.62))
	hp_tick_lab.visible = kind == "perf"
	add_child(hp_tick_lab)
	if kind == "perf":
		for pic in cells:
			pic.visible = false
		for slot in slots:
			slot.visible = false
		for glow in glows:
			glow.visible = false
		charge.visible = false
	set_cells(0, 0.0)


func set_cells(filled: int, partial := 0.0, extra := "") -> void:
	if kind == "perf":
		set_hp(float(filled) / float(maxi(cap, 1)) * Rules.PERF_MAX + partial * (Rules.PERF_MAX / float(maxi(cap, 1))), Rules.PERF_MAX, extra)
		return
	_filled = clampi(filled, 0, cap)
	_charge = clampf(partial, 0.0, 1.0)
	if extra != "":
		hint_lab.text = extra
	elif kind == "task":
		hint_lab.text = "%d/%d 单" % [_filled, cap]
	elif kind == "perf":
		hint_lab.text = "%d" % roundi(float(_filled) / float(maxi(cap, 1)) * Rules.PERF_MAX)
	else:
		hint_lab.text = "%d/%d 格" % [_filled, cap]
	var on_tex: Texture2D = Rules.tex(_on_path())
	var off_tex: Texture2D = Rules.tex(_off_path())
	for i in cells.size():
		var on := i < _filled
		cells[i].texture = on_tex if on else off_tex
		cells[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.72)
		glows[i].color = Color(_title_color(), 0.22 if on else 0.0)
		slots[i].color = Color(_title_color() * 0.18, 0.95) if on else Color(0.10, 0.11, 0.13, 0.9)
		if kind == "perf" and i == 0:
			slots[i].color = Color(0.42, 0.08, 0.08, 0.95)
			if _filled <= 1:
				cells[i].modulate = Color(1.0, 0.55, 0.45)
				glows[i].color = Color(1.0, 0.28, 0.18, 0.35)
	var slot := mini(_filled, cap - 1)
	if _filled >= cap or _charge <= 0.02:
		charge.visible = false
		return
	charge.visible = true
	charge.position = Vector2(18 + slot * 44, 82)
	charge.size = Vector2(34.0 * _charge, 5)


func set_hp(cur: float, mx: float, extra := "") -> void:
	var ratio := clampf(cur / maxf(mx, 1.0), 0.0, 1.0)
	if extra != "":
		hint_lab.text = extra
	else:
		hint_lab.text = "%d" % roundi(cur)
	if hp_track == null:
		return
	hp_fill.position = hp_track.position
	hp_fill.size = Vector2(hp_track.size.x * ratio, hp_track.size.y)
	if ratio <= Rules.PERF_FIRE / maxf(mx, 1.0):
		hp_fill.color = Color(0.92, 0.16, 0.12, 0.98)
	elif ratio <= 0.5:
		hp_fill.color = Color(0.96, 0.42, 0.16, 0.98)
	else:
		hp_fill.color = Color(0.86, 0.22, 0.18, 0.96)
	hp_shine.position = hp_track.position + Vector2(0, 2)
	hp_shine.size = Vector2(hp_fill.size.x, 6)
	var fire_x := hp_track.position.x + hp_track.size.x * (Rules.PERF_FIRE / maxf(mx, 1.0))
	hp_tick.position = Vector2(fire_x - 1.0, hp_track.position.y - 4.0)
	hp_tick.size = Vector2(3, hp_track.size.y + 8.0)
	hp_tick_lab.position = Vector2(fire_x - 16.0, hp_track.position.y + hp_track.size.y + 1.0)
	hp_tick_lab.size = Vector2(40, 14)


func set_meaning(text: String) -> void:
	if mean_lab:
		mean_lab.text = text if text != "" else _meaning()


func _meaning() -> String:
	match kind:
		"task":
			return "交完 5 单才能打卡下班"
		"energy":
			return "开局 3 格 · 一单大约 3 格"
		"perf":
			return "绩效血条 · 低于 25 被抓即开除"
	return ""


func _panel_color() -> Color:
	match kind:
		"task":
			return Color(0.08, 0.14, 0.16, 0.90)
		"energy":
			return Color(0.16, 0.12, 0.06, 0.90)
		"perf":
			return Color(0.16, 0.06, 0.06, 0.92)
	return Color(0.12, 0.14, 0.16, 0.8)


func _title_color() -> Color:
	match kind:
		"task":
			return Color(0.45, 0.94, 0.98)
		"energy":
			return Color(1.0, 0.84, 0.32)
		"perf":
			return Color(1.0, 0.48, 0.40)
	return Color(0.86, 0.88, 0.90)


func _charge_color() -> Color:
	match kind:
		"energy":
			return Color(0.96, 0.78, 0.29, 0.95)
		"perf":
			return Color(0.92, 0.28, 0.22, 0.95)
	return Color(0.24, 0.86, 0.94, 0.95)


func _icon_path() -> String:
	match kind:
		"energy":
			return Rules.UI_ICON_ENERGY
		"perf":
			return Rules.UI_ICON_PERF
	return Rules.UI_ICON_TASK


func _on_path() -> String:
	match kind:
		"energy":
			return Rules.UI_ENERGY_ON
		"perf":
			return Rules.UI_PERF_ON
	return Rules.UI_TASK_ON


func _off_path() -> String:
	match kind:
		"energy":
			return Rules.UI_ENERGY_OFF
		"perf":
			return Rules.UI_PERF_OFF
	return Rules.UI_TASK_OFF
