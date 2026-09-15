extends Node
class_name LobbyPointer

const TIGER_UV := Rect2(0.52, 0.15, 0.16, 0.42)
const IDLE := "idle"
const TEXT := "text"
const UI := "ui"
const START := "start"
const JOIN := "join"
const VERIFY := "verify"
const PUNCH := "punch"
const CAM := "cam"
const EXIT := "exit"
const TIGER := "tiger"
const CURSOR_SIZE := 32

var haunt
var lobby: Control
var hero: TextureRect
var home_page: Control
var join_page: Control
var char_page: Control
var punch: Control
var cam: Control
var exit_sign: Control
var focus_id := IDLE
var _applied := false
var _arrow_mode := ""
var _tex_idle: Texture2D
var _tex_operate: Texture2D
var _tex_inspect: Texture2D
var _tex_text: Texture2D


static func aspect_cover_rect(view: Vector2, tex: Vector2) -> Rect2:
	if view.x <= 1.0 or view.y <= 1.0 or tex.x <= 1.0 or tex.y <= 1.0:
		return Rect2(Vector2.ZERO, view)
	var scale := maxf(view.x / tex.x, view.y / tex.y)
	var drawn := tex * scale
	return Rect2((view - drawn) * 0.5, drawn)


static func uv_to_screen(view: Vector2, tex: Vector2, uv: Rect2) -> Rect2:
	var cover := aspect_cover_rect(view, tex)
	return Rect2(cover.position + uv.position * cover.size, uv.size * cover.size)


static func cursor_mode(id: String) -> String:
	match id:
		TEXT:
			return TEXT
		START, JOIN, VERIFY, UI:
			return "operate"
		PUNCH, CAM, EXIT, TIGER:
			return "inspect"
		_:
			return IDLE


static func owning_widget(node: Node, stop_at: Node) -> Control:
	var cur := node
	while cur != null and cur != stop_at:
		if cur is LineEdit or cur is TextEdit:
			return cur as Control
		if cur is Button or cur is CheckBox:
			return cur as Control
		cur = cur.get_parent()
	return null


static func make_cursor_image(mode: String) -> Image:
	var img := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.16, 0.20, 0.22, 0.96)
	var edge := Color(0.78, 0.86, 0.84, 0.95)
	var teal := Color(0.42, 0.90, 0.82, 1.0)
	match mode:
		"operate":
			_stroke_rect(img, Rect2i(8, 8, 16, 16), teal)
			_stroke_rect(img, Rect2i(11, 11, 10, 10), Color(edge.r, edge.g, edge.b, 0.7))
			_fill_dot(img, 16, 16, 1, teal)
		"inspect":
			_stroke_rect(img, Rect2i(7, 7, 18, 18), teal)
			_line(img, Vector2i(5, 16), Vector2i(11, 16), teal)
			_line(img, Vector2i(21, 16), Vector2i(27, 16), teal)
			_line(img, Vector2i(16, 5), Vector2i(16, 11), teal)
			_line(img, Vector2i(16, 21), Vector2i(16, 27), teal)
			_fill_dot(img, 16, 16, 1, teal)
		TEXT:
			_line(img, Vector2i(16, 6), Vector2i(16, 26), edge)
			_line(img, Vector2i(12, 6), Vector2i(20, 6), teal)
			_line(img, Vector2i(12, 26), Vector2i(20, 26), teal)
		_:
			var pts := PackedVector2Array([
				Vector2(1, 1), Vector2(2, 18), Vector2(7, 14), Vector2(11, 23),
				Vector2(14, 22), Vector2(9, 13), Vector2(17, 13),
			])
			_fill_poly(img, pts, ink)
			for i in pts.size():
				_line(img, Vector2i(pts[i]), Vector2i(pts[(i + 1) % pts.size()]), edge)
			_fill_dot(img, 2, 2, 1, teal)
	return img


func bind(haunt_node, nodes: Dictionary) -> void:
	haunt = haunt_node
	lobby = nodes.get("lobby")
	hero = nodes.get("hero")
	home_page = nodes.get("home_page")
	join_page = nodes.get("join_page")
	char_page = nodes.get("char_page")
	punch = nodes.get("punch")
	cam = nodes.get("cam")
	exit_sign = nodes.get("exit_sign")
	_tex_idle = ImageTexture.create_from_image(make_cursor_image(IDLE))
	_tex_operate = ImageTexture.create_from_image(make_cursor_image("operate"))
	_tex_inspect = ImageTexture.create_from_image(make_cursor_image("inspect"))
	_tex_text = ImageTexture.create_from_image(make_cursor_image(TEXT))


func _exit_tree() -> void:
	_clear_cursors()


func _input(event: InputEvent) -> void:
	if not _live():
		return
	if event is InputEventMouseMotion:
		_sync_focus()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var id := resolve(get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO)
		if cursor_mode(id) != "inspect":
			return
		if haunt != null:
			haunt.trigger_pointer(id)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _live():
		if not _applied:
			_apply_cursors()
			_sync_focus()
		return
	_clear_cursors()


func _live() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return lobby != null and lobby.is_visible_in_tree()


func _sync_focus() -> void:
	var id := resolve(_mouse_pos())
	if id != focus_id:
		focus_id = id
		_apply_arrow_for_mode(cursor_mode(id))
		if haunt != null:
			haunt.set_pointer_focus(id)


func _apply_cursors() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_custom_mouse_cursor(_tex_idle, Input.CURSOR_ARROW, Vector2(1, 1))
	Input.set_custom_mouse_cursor(_tex_operate, Input.CURSOR_POINTING_HAND, Vector2(16, 16))
	Input.set_custom_mouse_cursor(_tex_text, Input.CURSOR_IBEAM, Vector2(16, 16))
	Input.set_custom_mouse_cursor(_tex_inspect, Input.CURSOR_CROSS, Vector2(16, 16))
	_applied = true
	_arrow_mode = ""
	_apply_arrow_for_mode(cursor_mode(focus_id))


func _apply_arrow_for_mode(mode: String) -> void:
	if mode == _arrow_mode:
		return
	_arrow_mode = mode
	if not _applied or DisplayServer.get_name() == "headless":
		return
	if mode == "inspect":
		Input.set_custom_mouse_cursor(_tex_inspect, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(_tex_idle, Input.CURSOR_ARROW, Vector2(1, 1))


func _clear_cursors() -> void:
	if not _applied:
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_applied = false
	_arrow_mode = ""
	focus_id = IDLE
	if haunt != null:
		haunt.set_pointer_focus(IDLE)


func resolve(global_pos: Vector2) -> String:
	var hovered := get_viewport().gui_get_hovered_control() if get_viewport() != null else null
	var widget := owning_widget(hovered, lobby)
	if widget is LineEdit or widget is TextEdit:
		return TEXT
	if widget is Button or widget is CheckBox:
		return str(widget.get_meta("pointer_id", UI))
	if _blocked_page(global_pos):
		return IDLE
	if _hot_rect(punch, 6.0).has_point(global_pos):
		return PUNCH
	if _hot_rect(cam, 10.0).has_point(global_pos):
		return CAM
	if _hot_rect(exit_sign, 14.0).has_point(global_pos):
		return EXIT
	if tiger_rect().has_point(global_pos):
		return TIGER
	return IDLE


func tiger_rect() -> Rect2:
	if hero == null or not hero.is_visible_in_tree() or hero.texture == null:
		return Rect2()
	var local := uv_to_screen(hero.size, Vector2(hero.texture.get_size()), TIGER_UV)
	var xf := hero.get_global_transform()
	var p0 := xf * local.position
	var p1 := xf * (local.position + Vector2(local.size.x, 0))
	var p2 := xf * (local.position + local.size)
	var p3 := xf * (local.position + Vector2(0, local.size.y))
	var min_p := Vector2(minf(minf(p0.x, p1.x), minf(p2.x, p3.x)), minf(minf(p0.y, p1.y), minf(p2.y, p3.y)))
	var max_p := Vector2(maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x)), maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y)))
	return Rect2(min_p, max_p - min_p)


func _blocked_page(global_pos: Vector2) -> bool:
	if char_page != null and char_page.visible and char_page.get_global_rect().has_point(global_pos):
		return true
	if join_page != null and join_page.visible and join_page.get_global_rect().has_point(global_pos):
		return true
	return false


func _hot_rect(node: Control, pad: float) -> Rect2:
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	return node.get_global_rect().grow(pad)


func _mouse_pos() -> Vector2:
	if get_viewport() == null:
		return Vector2.ZERO
	return get_viewport().get_mouse_position()


static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= CURSOR_SIZE or y >= CURSOR_SIZE:
		return
	img.set_pixel(x, y, color)


static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	if steps <= 0:
		_put(img, a.x, a.y, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_put(img, int(round(lerpf(float(a.x), float(b.x), t))), int(round(lerpf(float(a.y), float(b.y), t))), color)


static func _stroke_rect(img: Image, r: Rect2i, color: Color) -> void:
	_line(img, r.position, Vector2i(r.end.x - 1, r.position.y), color)
	_line(img, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.end.x - 1, r.end.y - 1), color)
	_line(img, Vector2i(r.end.x - 1, r.end.y - 1), Vector2i(r.position.x, r.end.y - 1), color)
	_line(img, Vector2i(r.position.x, r.end.y - 1), r.position, color)


static func _fill_dot(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if Vector2(x - cx, y - cy).length() <= float(radius) + 0.2:
				_put(img, x, y, color)


static func _fill_poly(img: Image, pts: PackedVector2Array, color: Color) -> void:
	var min_x := CURSOR_SIZE
	var min_y := CURSOR_SIZE
	var max_x := 0
	var max_y := 0
	for p in pts:
		min_x = mini(min_x, int(floor(p.x)))
		min_y = mini(min_y, int(floor(p.y)))
		max_x = maxi(max_x, int(ceil(p.x)))
		max_y = maxi(max_y, int(ceil(p.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_poly(pts, Vector2(float(x) + 0.5, float(y) + 0.5)):
				_put(img, x, y, color)


static func _point_in_poly(pts: PackedVector2Array, point: Vector2) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if ((a.y > point.y) != (b.y > point.y)) and (point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y + 0.0001) + a.x):
			inside = not inside
		j = i
	return inside
