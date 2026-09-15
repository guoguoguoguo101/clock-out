extends Control
class_name CellMeter

const TASK_ON := preload("res://assets/game/ui/cell_task_on.png")
const TASK_OFF := preload("res://assets/game/ui/cell_task_off.png")
const EN_ON := preload("res://assets/game/ui/cell_energy_on.png")
const EN_OFF := preload("res://assets/game/ui/cell_energy_off.png")

var cap_lab: Label
var hint_lab: Label
var cells: Array[TextureRect] = []
var charge: ColorRect
var kind := "task"
var cap := 5
var _filled := 0
var _charge := 0.0


func setup(title: String, p_kind: String, p_cap: int) -> void:
	kind = p_kind
	cap = p_cap
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(188, 52)
	size = Vector2(188, 52)
	cap_lab = Label.new()
	cap_lab.text = title
	cap_lab.position = Vector2(0, 0)
	cap_lab.add_theme_font_size_override("font_size", 11)
	cap_lab.add_theme_color_override("font_color", Color(0.42, 0.50, 0.56))
	add_child(cap_lab)
	hint_lab = Label.new()
	hint_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lab.position = Vector2(88, -2)
	hint_lab.size = Vector2(96, 20)
	hint_lab.add_theme_font_size_override("font_size", 14)
	hint_lab.add_theme_color_override("font_color", Color(0.16, 0.18, 0.20))
	add_child(hint_lab)
	for i in cap:
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(i * 34, 18)
		pic.size = Vector2(32, 32)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		cells.append(pic)
	charge = ColorRect.new()
	charge.color = Color(0.96, 0.78, 0.29, 0.85) if kind == "energy" else Color(0.24, 0.86, 0.94, 0.85)
	charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(charge)
	set_cells(0, 0.0)


func set_cells(filled: int, partial := 0.0, extra := "") -> void:
	_filled = clampi(filled, 0, cap)
	_charge = clampf(partial, 0.0, 1.0)
	if kind == "task":
		hint_lab.text = extra if extra != "" else "%d/%d" % [_filled, cap]
	else:
		hint_lab.text = extra if extra != "" else ("%d 格" % _filled)
	var on_tex: Texture2D = TASK_ON if kind == "task" else EN_ON
	var off_tex: Texture2D = TASK_OFF if kind == "task" else EN_OFF
	for i in cells.size():
		cells[i].texture = on_tex if i < _filled else off_tex
		cells[i].modulate = Color.WHITE if i < _filled else Color(1, 1, 1, 0.72)
	var slot := mini(_filled, cap - 1)
	if _filled >= cap or _charge <= 0.02:
		charge.visible = false
		return
	charge.visible = _filled < cap and _charge > 0.02
	charge.position = Vector2(slot * 34 + 6, 46)
	charge.size = Vector2(20.0 * _charge, 3)
