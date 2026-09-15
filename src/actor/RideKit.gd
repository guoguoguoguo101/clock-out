extends RefCounted
class_name RideKit

const BACK_PATH := "res://assets/game/props/ebike_back.png"
const FRONT_PATH := "res://assets/game/props/ebike_front.png"
const PAINT_SHADER := preload("res://src/actor/ebike.gdshader")
const FOOT_PAD := 22.0
const BIKE_SCALE_MUL := 1.36
const RIDER_SCALE_MUL := 0.96
const SIT_SINK := 4.0
# Rump on the cushion; legs drop into the step-through.
const SEAT_PX := Vector2(370, 415)
const HIP_UV := Vector2(0.46, 0.36)
const HIP_FOR_SKIN := {
	Rules.CharSkin.HORSE: Vector2(0.52, 0.36),
	Rules.CharSkin.RABBIT: Vector2(0.50, 0.34),
	Rules.CharSkin.COW: Vector2(0.50, 0.38),
	Rules.CharSkin.PELICAN: Vector2(0.48, 0.36),
	Rules.CharSkin.KANGAROO: Vector2(0.46, 0.36),
	Rules.CharSkin.DOG: Vector2(0.50, 0.34),
}

static var _used: Dictionary = {}
static var _back: Texture2D
static var _front: Texture2D


static func back_tex() -> Texture2D:
	if _back == null:
		_back = _load_tex(BACK_PATH)
	return _back


static func front_tex() -> Texture2D:
	if _front == null:
		_front = _load_tex(FRONT_PATH)
	return _front


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


static func used_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key: String = tex.resource_path
	if key == "":
		key = str(tex.get_instance_id())
	if _used.has(key):
		return _used[key]
	var img: Image = tex.get_image()
	var rect: Rect2 = Rect2(Vector2.ZERO, tex.get_size())
	if img != null:
		rect = Rect2(img.get_used_rect())
	_used[key] = rect
	return rect


static func hip_uv(skin: int) -> Vector2:
	return HIP_FOR_SKIN.get(skin, HIP_UV) as Vector2


static func setup(back: Sprite2D, front: Sprite2D, paint: Color) -> void:
	_setup_layer(back, back_tex(), 0, paint)
	_setup_layer(front, front_tex(), 3, paint)


static func apply(body: Sprite2D, back: Sprite2D, front: Sprite2D, skin: int, facing: float, body_scale: float, bob: float) -> void:
	if body == null or back == null or front == null:
		return
	var face := 1.0 if facing >= 0.0 else -1.0
	var rider_sc := body.scale.x
	var bike_sc := body_scale * BIKE_SCALE_MUL
	_place_bike(back, bike_sc, face, body_scale)
	_place_bike(front, bike_sc, face, body_scale)
	back.visible = true
	front.visible = true
	var hip := _anchor_uv(body.texture, body.offset, rider_sc, hip_uv(skin))
	var seat := _anchor_px(back.offset, bike_sc, SEAT_PX)
	body.position.x += (seat.x - hip.x) * face
	body.position.y += seat.y - hip.y + bob + SIT_SINK
	back.position.y += bob
	front.position.y += bob
	back.flip_h = face < 0.0
	front.flip_h = face < 0.0


static func hide(back: Sprite2D, front: Sprite2D) -> void:
	if back:
		back.visible = false
	if front:
		front.visible = false


static func _setup_layer(sprite: Sprite2D, tex: Texture2D, z: int, paint: Color) -> void:
	if sprite == null or tex == null:
		return
	sprite.texture = tex
	sprite.centered = false
	sprite.z_index = z
	sprite.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("body_color", paint)
	sprite.material = mat


static func _place_bike(sprite: Sprite2D, bike_sc: float, _face: float, body_scale: float) -> void:
	var tex: Texture2D = sprite.texture
	if tex == null:
		return
	var sz := tex.get_size()
	var used := used_rect(tex)
	sprite.scale = Vector2(bike_sc, bike_sc)
	sprite.offset = Vector2(-sz.x * 0.5, -used.end.y)
	sprite.position = Vector2(0.0, FOOT_PAD * body_scale)
	sprite.rotation = 0.0


static func _anchor_uv(tex: Texture2D, offset: Vector2, sc: float, uv: Vector2) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var used := used_rect(tex)
	var px := used.position.x + used.size.x * uv.x
	var py := used.position.y + used.size.y * (1.0 - uv.y)
	return _anchor_px(offset, sc, Vector2(px, py))


static func _anchor_px(offset: Vector2, sc: float, px: Vector2) -> Vector2:
	return Vector2((offset.x + px.x) * sc, (offset.y + px.y) * sc)
