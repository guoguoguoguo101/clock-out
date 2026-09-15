extends ColorRect
class_name RoomFog

const FOG_SHADER := preload("res://src/fx/room_fog.gdshader")

var hole := Rect2(520, 780, 1200, 700)
var _target := Rect2(520, 780, 1200, 700)


func _ready() -> void:
	z_index = 40
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(2560, 1520)
	color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	material = mat
	set_process(true)


func _process(delta: float) -> void:
	var map := get_parent() as OfficeMap
	if map == null:
		visible = false
		return
	if Match == null or (Match.phase != "playing" and Match.phase != "countdown"):
		visible = false
		return
	var me: Actor = Match.actors.get(Match.my_slot()) as Actor
	if me == null:
		visible = false
		return
	visible = true
	var threat: float = 0.0
	if me.kind == Rules.Kind.EMPLOYEE:
		threat = map.threat_for(me)
	var grow: float = 18.0 if me.kind == Rules.Kind.BOSS else (-8.0 - threat * 14.0)
	_target = map.view_rect_at(me.global_position).grow(grow)
	var k := 1.0 - exp(-9.0 * delta)
	hole.position = hole.position.lerp(_target.position, k)
	hole.size = hole.size.lerp(_target.size, k)
	var ink := 0.78
	var soft := 88.0
	if me.kind == Rules.Kind.EMPLOYEE:
		ink = 0.985
		soft = 58.0 - threat * 18.0
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("hole", Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y))
		mat.set_shader_parameter("map_size", Vector2(2560, 1520))
		mat.set_shader_parameter("softness", soft)
		mat.set_shader_parameter("ink_alpha", ink)
		mat.set_shader_parameter("threat", threat)
		mat.set_shader_parameter("grain", 0.28 if me.kind == Rules.Kind.EMPLOYEE else 0.08)
