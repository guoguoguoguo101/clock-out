extends Control
class_name EnergyPlay

var dim: ColorRect
var panel: ColorRect
var title: Label
var hint: Label
var flash: Label
var art: TextureRect
var needle: ColorRect
var zone: ColorRect
var track: ColorRect
var fill: ColorRect
var _kind := ""
var _t := 0.0
var _mark := 0.5
var _hits := 0
var _lock := 0.0
var _msg := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = ColorRect.new()
	panel.color = Color(0.10, 0.09, 0.08, 0.94)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)
	title = _lab(26, Color(0.96, 0.90, 0.78))
	hint = _lab(16, Color(0.78, 0.74, 0.66))
	flash = _lab(22, Color(1.0, 0.82, 0.42))
	track = ColorRect.new()
	track.color = Color(0.18, 0.16, 0.14, 0.95)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	zone = ColorRect.new()
	zone.color = Color(0.42, 0.72, 0.38, 0.55)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(zone)
	needle = ColorRect.new()
	needle.color = Color(0.96, 0.86, 0.42)
	needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(needle)
	fill = ColorRect.new()
	fill.color = Color(0.96, 0.78, 0.29)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill)
	resized.connect(_layout)
	_layout()


func _lab(size: int, color: Color) -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lab)
	return lab


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 8.0:
		return
	var w := minf(vp.x * 0.64, 760.0)
	var h := 300.0
	panel.position = Vector2((vp.x - w) * 0.5, vp.y * 0.52)
	panel.size = Vector2(w, h)
	art.position = Vector2(24, 48)
	art.size = Vector2(120, 120)
	title.position = Vector2(160, 20)
	title.size = Vector2(w - 184, 36)
	hint.position = Vector2(24, h - 44)
	hint.size = Vector2(w - 48, 28)
	flash.position = Vector2(160, 62)
	flash.size = Vector2(w - 184, 32)
	track.position = Vector2(160, 118)
	track.size = Vector2(w - 200, 28)
	zone.size = Vector2(88, 28)
	needle.size = Vector2(8, 36)
	fill.position = Vector2(160, 164)
	fill.size = Vector2(0, 16)


func bind(actor: Actor) -> void:
	if actor == null or actor.play_kind == "":
		visible = false
		return
	visible = true
	_kind = actor.play_kind
	_t = actor.play_t
	_mark = actor.play_mark
	_hits = actor.play_hits
	_lock = actor.play_lock
	_msg = actor.play_msg
	_layout()
	flash.text = _msg
	match _kind:
		"brew":
			title.text = "续命 · 手冲咖啡"
			hint.text = "指针进棕色带时按 F 出杯    E 撤"
			art.texture = Rules.tex("res://assets/game/props/energy/brew_cup.png")
			_show_timing(Color(0.62, 0.42, 0.22, 0.7))
		"flush":
			title.text = "暂时离线 · 深呼吸"
			hint.text = "指针进冷静带时按 F    E 撤"
			art.texture = Rules.tex("res://assets/game/props/energy/water_cup.png")
			_show_timing(Color(0.32, 0.62, 0.52, 0.7))
		"vend":
			title.text = "非法加餐 · 投币柜"
			hint.text = "F 停格    停在能喝的格子才算出货"
			art.texture = Rules.tex("res://assets/game/props/energy/vending.png")
			_show_timing(Color(0.86, 0.62, 0.22, 0.7))
		"rummage":
			var fridge := actor != null and str(actor.occupy_id).begins_with("fridge")
			title.text = "翻冰箱 · 不是你的也先垫一口" if fridge else "翻抽屉 · 不是你的也先垫一口"
			hint.text = "食物闪出来时按 F    订书钉不要吃"
			art.texture = Rules.tex("res://assets/game/props/energy/fridge.png") if fridge else Rules.tex("res://assets/game/props/energy/drawer.png")
			_show_timing(Color(0.86, 0.48, 0.22, 0.7))
		"snack":
			title.text = "桌面搜刮 · 过期也算热量"
			hint.text = "连按 F 拆包装  %d / 5" % _hits
			art.texture = _snack_tex()
			_hide_timing()
			fill.visible = true
			fill.size = Vector2((panel.size.x - 200.0) * (float(_hits) / 5.0), 16)
		"water":
			title.text = "饮水机 · 接一杯清醒"
			hint.text = "水位晃到刚好满时按 F    满溢就洒了"
			art.texture = Rules.tex("res://assets/game/props/energy/water_cup.png")
			_hide_timing()
			fill.visible = true
			fill.size = Vector2((panel.size.x - 200.0) * clampf(_t, 0.0, 1.0), 16)
		_:
			visible = false


func _snack_tex() -> Texture2D:
	var n := _hits % 3
	if n == 1:
		return Rules.tex("res://assets/game/props/energy/snack_noodle.png")
	if n == 2:
		return Rules.tex("res://assets/game/props/energy/can_drink.png")
	return Rules.tex("res://assets/game/props/energy/snack_choco.png")


func _show_timing(zone_col: Color) -> void:
	track.visible = true
	zone.visible = true
	needle.visible = true
	fill.visible = false
	var tw: float = track.size.x
	zone.color = zone_col
	var z0 := clampf(_mark - 0.11, 0.04, 0.72)
	zone.position = track.position + Vector2(tw * z0, 0)
	zone.size = Vector2(tw * 0.22, 28)
	needle.position = track.position + Vector2(tw * clampf(_t, 0.0, 1.0) - 4.0, -4)


func _hide_timing() -> void:
	track.visible = false
	zone.visible = false
	needle.visible = false
