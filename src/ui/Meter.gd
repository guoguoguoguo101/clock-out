extends Control

var cap: Label
var num: Label
var track: ColorRect
var fill: ColorRect
var icon: TextureRect
var _w := 196.0


func setup(title: String, accent: Color, width := 196.0, icon_path := "") -> void:
	_w = width
	custom_minimum_size = Vector2(width + 40, 44)
	size = Vector2(width + 40, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x0 := 0.0
	if icon_path != "":
		icon = TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(0, 4)
		icon.size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		x0 = 36.0
	cap = Label.new()
	cap.text = title
	cap.position = Vector2(x0, 0)
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.42, 0.50, 0.56))
	add_child(cap)
	num = Label.new()
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.position = Vector2(x0 + width - 96, -2)
	num.size = Vector2(96, 22)
	num.add_theme_font_size_override("font_size", 18)
	num.add_theme_color_override("font_color", Color(0.12, 0.16, 0.20))
	add_child(num)
	track = ColorRect.new()
	track.color = Color(0.88, 0.93, 0.96)
	track.position = Vector2(x0, 26)
	track.size = Vector2(width, 4)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	fill = ColorRect.new()
	fill.color = accent
	fill.position = Vector2(x0, 26)
	fill.size = Vector2(0, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)


func set_amount(value: float, maximum := 100.0) -> void:
	var v := clampf(value, 0.0, maximum)
	num.text = "%d/%d" % [int(round(v)), int(round(maximum))]
	fill.size.x = _w * (v / maxf(maximum, 1.0))
