extends Node2D
class_name TigerBurst

var _tex: Texture2D
var _life := 0.7
var _max_life := 0.7
var _spin := 0.0
var _scale0 := 0.09
var _lift := -28.0
var _additive := false


func setup(path: String, pos: Vector2, dur := 0.7, sc := 0.09, lift := -28.0) -> void:
	_tex = Rules.tex(path)
	global_position = pos
	_life = dur
	_max_life = maxf(dur, 0.05)
	_scale0 = sc
	_lift = lift
	_spin = randf_range(-0.4, 0.4)
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	if _tex == null:
		return
	var t := 1.0 - clampf(_life / _max_life, 0.0, 1.0)
	var a := clampf(1.15 - t * 1.25, 0.0, 1.0)
	var sc := _scale0 * (0.82 + t * 0.55)
	var sz := _tex.get_size()
	draw_set_transform(Vector2(0, _lift), _spin * t, Vector2(sc, sc))
	draw_texture(_tex, -sz * 0.5, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
