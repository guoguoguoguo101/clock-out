extends Control
class_name HazardOverlay

var art: TextureRect
var veil: ColorRect
var title: Label
var sub: Label
var _kind := ""
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.55, 0.04, 0.04, 0.0)
	add_child(veil)
	art = TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1, 1, 1, 0.0)
	add_child(art)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 64
	title.offset_bottom = 110
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.18, 0.04, 0.04, 0.85))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	sub = Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 108
	sub.offset_bottom = 148
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(1.0, 0.76, 0.66))
	sub.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.03, 0.8))
	sub.add_theme_constant_override("outline_size", 4)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	var beat := 0.5 + 0.5 * sin(_pulse * 5.2)
	if art:
		art.modulate.a = 0.78 + beat * 0.16
	if veil:
		var base := 0.10
		if _kind == "drag":
			base = 0.16
		elif _kind == "meeting":
			base = 0.14
		veil.color.a = base + beat * 0.05


func bind(actor: Actor) -> void:
	if actor == null or actor.kind != Rules.Kind.EMPLOYEE:
		_hide()
		return
	match actor.emp_state:
		Rules.EmpState.TALK:
			_hide()
		Rules.EmpState.DRAGGED:
			_show("drag", "正在被拖去会议室", "你无法操作    叫同事拦截老板    绩效持续掉")
		Rules.EmpState.MEETING:
			_show("meeting", "强制开会 · 绑在椅子上", "不能自救    大面板里连按 E 减慢扣绩效    等队友来捞")
		_:
			_hide()


func _show(kind: String, headline: String, hint: String) -> void:
	if _kind != kind:
		_pulse = 0.0
	_kind = kind
	visible = true
	var path := Rules.UI_OVERLAY_REVIEW
	if kind == "drag":
		path = Rules.UI_OVERLAY_DRAG
	elif kind == "meeting":
		path = Rules.UI_OVERLAY_MEETING
	art.texture = Rules.tex(path)
	art.modulate = Color(1, 1, 1, 0.86)
	title.text = headline
	sub.text = hint


func _hide() -> void:
	_kind = ""
	visible = false
	if art:
		art.modulate.a = 0.0
	if veil:
		veil.color.a = 0.0
	if title:
		title.text = ""
	if sub:
		sub.text = ""
