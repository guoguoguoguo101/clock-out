extends StaticBody2D
class_name OfficeDoor

var door_id := ""
var title := ""
var closed := false
var opening := false
var open_left := 0.0
var sprite: Sprite2D
var blocker: CollisionShape2D
var jamb_l: ColorRect
var jamb_r: ColorRect
var plate: Label


func setup(id: String, pos: Vector2, p_title: String) -> void:
	door_id = id
	title = p_title
	name = "door_%s" % id
	position = pos
	collision_layer = 0
	collision_mask = 0
	z_index = 3
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 18)
	cs.shape = shape
	cs.disabled = true
	add_child(cs)
	blocker = cs
	jamb_l = _jamb(Vector2(-56, -28), Vector2(10, 56))
	jamb_r = _jamb(Vector2(46, -28), Vector2(10, 56))
	_lintel()
	sprite = Sprite2D.new()
	sprite.texture = null
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/game/props/horror/door.png"))
	if img != null and not img.is_empty():
		sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = true
	sprite.position = Vector2(0, -6)
	if sprite.texture:
		var sz := sprite.texture.get_size()
		if sz.x > 0.0:
			sprite.scale = Vector2.ONE * (46.0 / sz.x)
	add_child(sprite)
	plate = Label.new()
	plate.text = title
	plate.position = Vector2(-28, -52)
	plate.size = Vector2(56, 14)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override("font_size", 10)
	plate.add_theme_color_override("font_color", Color(0.86, 0.88, 0.90))
	plate.z_index = 4
	add_child(plate)
	_apply_visual()


func _jamb(pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.18, 0.16, 0.16)
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 2
	add_child(r)
	return r


func _lintel() -> void:
	var cap := ColorRect.new()
	cap.color = Color(0.22, 0.12, 0.12)
	cap.position = Vector2(-56, -34)
	cap.size = Vector2(112, 10)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)
	var exit := ColorRect.new()
	exit.color = Color(0.72, 0.12, 0.14)
	exit.position = Vector2(-22, -50)
	exit.size = Vector2(44, 12)
	exit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exit)


func prompt_text(kind: int) -> String:
	if opening:
		return "门在开… %.1fs" % open_left
	if closed:
		return "E 开门"
	if kind == Rules.Kind.EMPLOYEE:
		return "E 关门挡住老板"
	return "门开着"


func slam() -> void:
	closed = true
	opening = false
	open_left = 0.0
	collision_layer = 1
	blocker.disabled = false
	_apply_visual()


func begin_open() -> bool:
	if not closed or opening:
		return false
	opening = true
	open_left = Rules.DOOR_OPEN_TIME
	_apply_visual()
	return true


func force_open() -> void:
	closed = false
	opening = false
	open_left = 0.0
	collision_layer = 0
	blocker.disabled = true
	_apply_visual()


func tick(delta: float) -> void:
	if not opening:
		return
	open_left = maxf(0.0, open_left - delta)
	_apply_visual()
	if open_left <= 0.0:
		force_open()


func apply_state(p_closed: bool, p_opening: bool, p_left: float) -> void:
	closed = p_closed
	opening = p_opening
	open_left = p_left
	collision_layer = 1 if closed else 0
	blocker.disabled = not closed
	_apply_visual()


func _apply_visual() -> void:
	if sprite == null:
		return
	if opening:
		var t := 1.0 - clampf(open_left / Rules.DOOR_OPEN_TIME, 0.0, 1.0)
		sprite.rotation_degrees = lerpf(0.0, -68.0, t)
		sprite.position = Vector2(lerpf(0.0, 28.0, t), -6)
		sprite.modulate = Color(0.72, 0.74, 0.76)
	elif closed:
		sprite.rotation_degrees = 0.0
		sprite.position = Vector2(0, -6)
		sprite.modulate = Color(0.82, 0.84, 0.86)
	else:
		sprite.rotation_degrees = -68.0
		sprite.position = Vector2(28, -6)
		sprite.modulate = Color(0.62, 0.64, 0.66)
	if plate:
		plate.modulate = Color(1, 0.45, 0.42) if closed else Color(0.86, 0.88, 0.90)
