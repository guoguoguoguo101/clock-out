extends Control
class_name HauntText

var text: String = "":
	set(v):
		if text == v:
			return
		text = v
		queue_redraw()

var font_size: int = 16
var base_color := Color(0.92, 0.84, 0.76)
var amp := 2.4
var chroma := 1.15
var wrap := false
var align := HORIZONTAL_ALIGNMENT_LEFT
var _t := 0.0
var _glitch_ch := -1
var _glitch_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_glitch_t -= delta
	if _glitch_t <= 0.0 and text.length() > 0 and randf() < 0.035:
		_glitch_ch = randi() % text.length()
		_glitch_t = randf_range(0.06, 0.18)
	if _glitch_t <= 0.0:
		_glitch_ch = -1
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null or text.is_empty():
		return
	var y := font_size * 0.92
	var line_h := font_size * 1.28
	var lines := _lines(font)
	for li in lines.size():
		_draw_line(font, lines[li], y + float(li) * line_h, li)


func _lines(font: Font) -> PackedStringArray:
	var raw := text.split("\n")
	if not wrap or size.x < 12.0:
		return raw
	var out := PackedStringArray()
	for part in raw:
		var cur := ""
		for i in part.length():
			var ch := part.substr(i, 1)
			var trial := cur + ch
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x:
				if not cur.is_empty():
					out.append(cur)
				cur = ch
			else:
				cur = trial
		out.append(cur)
	return out


func _draw_line(font: Font, line: String, y: float, line_i: int) -> void:
	var full := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - full) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - full
	var cursor := 0
	for i in line.length():
		var ch := line.substr(i, 1)
		if line_i == 0 and i == _glitch_ch:
			ch = _swap(ch)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ox := sin(_t * 2.35 + float(cursor) * 1.7 + float(line_i)) * amp
		var oy := cos(_t * 1.65 + float(cursor) * 2.1) * amp * 0.55
		var rot := sin(_t * 1.4 + float(cursor) * 0.9) * 0.11
		var pos := Vector2(x + ox, y + oy)
		draw_set_transform(pos, rot, Vector2.ONE)
		var ink := Color(0.08, 0.05, 0.04, 0.7)
		draw_string(font, Vector2(1, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		if chroma > 0.01:
			draw_string(font, Vector2(chroma, -0.4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.86, 0.08, 0.1, 0.55))
			draw_string(font, Vector2(-chroma, 0.6), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.18, 0.62, 0.72, 0.42))
		draw_string(font, Vector2.ZERO, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, base_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w
		cursor += 1


func _swap(ch: String) -> String:
	var pool := ["不", "准", "六", "点", "走", "看", "死", "盯", "卡", "逾", "时", "□", "／"]
	if pool.has(ch):
		return pool[randi() % pool.size()]
	return pool[randi() % pool.size()]
