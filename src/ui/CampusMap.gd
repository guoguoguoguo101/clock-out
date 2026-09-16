extends Control
## Hold Tab: an exploration map, without leaking opponent positions.
var office: OfficeMap
var actor: Actor


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _draw() -> void:
	if office == null:
		return
	var factor := minf((size.x - 180.0) / Rules.MAP_SIZE.x, (size.y - 160.0) / Rules.MAP_SIZE.y)
	if factor <= 0.001:
		return
	var origin := (size - Rules.MAP_SIZE * factor) * 0.5
	var frame := Rect2(origin - Vector2(20, 45), Rules.MAP_SIZE * factor + Vector2(40, 70))
	draw_style_box(_back(), frame)
	var font := ThemeDB.fallback_font
	draw_string(font, origin + Vector2(0, -18), "3F  /  园区导览     松开 Tab 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#edf0e8"))
	for room in OfficeMap.ROOMS:
		var rect: Rect2 = room.rect
		var visited: bool = office.discovered.has(room.id)
		var box := Rect2(origin + rect.position * factor, rect.size * factor)
		draw_rect(box, Color("#789c9f") if visited else Color("#45565d"))
		draw_rect(box, Color("#91b4b1"), false, 1.0)
		var title: String = str(room.title) if visited else "未到访"
		draw_string(font, box.position + Vector2(8, 22), title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 10, 12, Color("#ecede4"))
	if actor:
		var point := origin + actor.global_position * factor
		draw_circle(point, 7, Color("#edcd80"))
		draw_arc(point, 12, 0, TAU, 24, Color("#edcd80"), 1.0)


func _back() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.18, 0.96)
	style.set_corner_radius_all(8)
	return style
