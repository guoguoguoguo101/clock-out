extends Control
class_name FxSandbox

const Catalog := preload("res://src/fx/EventFx.gd")

signal play_requested(id: String)
signal stop_requested

var _open := false
var _loop := false
var _current := ""
var _panel: Panel
var _list: VBoxContainer
var _hint: Label
var _loop_box: CheckBox
var _btns: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_panel = Panel.new()
	_panel.position = Vector2(16, 16)
	_panel.size = Vector2(272, 520)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.92)
	sb.border_color = Color(0.22, 0.28, 0.34, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 12
	sb.content_margin_top = 12
	sb.content_margin_right = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var title := Label.new()
	title.text = "过场调试"
	title.position = Vector2(12, 10)
	title.size = Vector2(180, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
	_panel.add_child(title)
	var sub := Label.new()
	sub.text = "F8 开关 · 点条目重播"
	sub.position = Vector2(12, 32)
	sub.size = Vector2(248, 18)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.62, 0.68, 0.74))
	_panel.add_child(sub)
	var replay := _mini_btn("重播", Vector2(12, 56))
	replay.pressed.connect(_replay)
	_panel.add_child(replay)
	var stop_btn := _mini_btn("停止", Vector2(96, 56))
	stop_btn.pressed.connect(func(): stop_requested.emit())
	_panel.add_child(stop_btn)
	_loop_box = CheckBox.new()
	_loop_box.text = "循环"
	_loop_box.position = Vector2(180, 56)
	_loop_box.size = Vector2(80, 28)
	_loop_box.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	_loop_box.toggled.connect(func(on: bool): _loop = on)
	_panel.add_child(_loop_box)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 92)
	scroll.size = Vector2(256, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_hint = Label.new()
	_hint.position = Vector2(12, 458)
	_hint.size = Vector2(248, 48)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78))
	_panel.add_child(_hint)
	_fill_clips()
	_hint.text = "大厅或对局里都能播。新过场加到 EventFx.clips。"


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	visible = true
	move_to_front()


func close() -> void:
	_open = false
	visible = false
	stop_requested.emit()


func notify_finished() -> void:
	if not _open:
		return
	if _loop and _current != "":
		play_requested.emit(_current)
		return
	_set_current("")


func _replay() -> void:
	if _current == "":
		var first := _first_ready()
		if first != "":
			_ask_play(first)
		return
	play_requested.emit(_current)


func _ask_play(id: String) -> void:
	_set_current(id)
	play_requested.emit(id)


func _first_ready() -> String:
	for clip in Catalog.clips():
		if bool(clip.get("ready", false)):
			return str(clip["id"])
	return ""


func _fill_clips() -> void:
	var last_group := ""
	for clip in Catalog.clips():
		var group := str(clip.get("group", ""))
		if group != last_group:
			var cap := Label.new()
			cap.text = group
			cap.add_theme_font_size_override("font_size", 11)
			cap.add_theme_color_override("font_color", Color(0.42, 0.78, 0.82))
			_list.add_child(cap)
			last_group = group
		var id := str(clip["id"])
		var ready: bool = bool(clip.get("ready", false))
		var b := Button.new()
		b.text = str(clip["title"])
		b.custom_minimum_size = Vector2(240, 32)
		b.disabled = not ready
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		var hint := str(clip.get("hint", ""))
		if ready:
			b.pressed.connect(_ask_play.bind(id))
		else:
			b.tooltip_text = hint
		_list.add_child(b)
		_btns[id] = b
		if hint != "" and ready:
			b.tooltip_text = hint


func _set_current(id: String) -> void:
	_current = id
	for key in _btns.keys():
		var b: Button = _btns[key]
		if str(key) == id:
			b.modulate = Color(1.0, 0.82, 0.72)
		else:
			b.modulate = Color.WHITE
	if id == "":
		return
	for clip in Catalog.clips():
		if str(clip["id"]) == id:
			_hint.text = str(clip.get("hint", ""))
			break


func _mini_btn(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(76, 28)
	b.add_theme_font_size_override("font_size", 12)
	return b
