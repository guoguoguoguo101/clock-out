extends Control
class_name FireStampOverlay

signal finished
signal impacted

const STAMP_PATH := "res://assets/game/ui/fired/stamp.png"
const IMPRINT_PATH := "res://assets/game/ui/fired/imprint.png"
const NOTICE_PATH := "res://assets/game/ui/fired/notice.png"
const SHARD_PATH := "res://assets/game/ui/fired/shard.png"
const BANG_PATH := "res://assets/game/ui/fired/bang.png"
const DEBRIS_PATH := "res://assets/game/ui/fired/debris.png"
const SHADOW_PATH := "res://assets/game/ui/fired/shadow.png"
const NEXT_PATH := "res://assets/game/ui/fired/next.png"
const REACT_PATH := "res://assets/game/ui/fired/react.png"

enum Kind { VICTIM, BOSS }

var veil: ColorRect
var flash: ColorRect
var cluster: Control
var paper: TextureRect
var header: Label
var imprint: TextureRect
var title: Label
var fire_lab: Label
var bang: TextureRect
var dream: Label
var shadow: TextureRect
var next_bub: TextureRect
var react: TextureRect
var debris: TextureRect
var stamp: TextureRect
var shards_root: Control

var _playing := false
var _hit := false
var _kind := Kind.VICTIM
var _t := 0.0
var _jolt := 0.0
var _cluster_base := Vector2.ZERO
var _stamp_land := Vector2.ZERO
var _imprint_center := Vector2.ZERO
var _tween: Tween
var _rings: Array[Dictionary] = []
var _bits: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.12, 0.02, 0.03, 0.0)
	add_child(veil)
	shadow = _tex(SHADOW_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	shadow.z_index = 0
	add_child(shadow)
	cluster = Control.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.z_index = 2
	add_child(cluster)
	paper = _tex(NOTICE_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	cluster.add_child(paper)
	header = _lab("辞退通知", 22, Color(0.72, 0.10, 0.10))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cluster.add_child(header)
	imprint = _tex(IMPRINT_PATH, TextureRect.STRETCH_SCALE)
	imprint.z_index = 2
	cluster.add_child(imprint)
	title = _lab("你被开除了！", 64, Color(0.92, 0.08, 0.08))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.28, 0.02, 0.02, 0.95))
	title.add_theme_constant_override("outline_size", 14)
	title.z_index = 4
	cluster.add_child(title)
	fire_lab = _lab("FIRE", 28, Color(0.78, 0.05, 0.06))
	fire_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fire_lab.add_theme_color_override("font_outline_color", Color(0.22, 0.02, 0.02, 0.9))
	fire_lab.add_theme_constant_override("outline_size", 8)
	fire_lab.z_index = 4
	cluster.add_child(fire_lab)
	stamp = _tex(STAMP_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	stamp.z_index = 5
	add_child(stamp)
	bang = _tex(BANG_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	bang.z_index = 8
	bang.rotation = -0.22
	add_child(bang)
	dream = _lab("梦想…\n到此为止", 18, Color(0.86, 0.16, 0.14))
	dream.rotation = -0.18
	dream.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02, 0.9))
	dream.add_theme_constant_override("outline_size", 5)
	dream.z_index = 7
	add_child(dream)
	next_bub = _tex(NEXT_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	next_bub.z_index = 6
	add_child(next_bub)
	react = _tex(REACT_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	react.z_index = 6
	add_child(react)
	debris = _tex(DEBRIS_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	debris.z_index = 7
	add_child(debris)
	shards_root = Control.new()
	shards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shards_root.z_index = 7
	add_child(shards_root)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.82, 0.78, 0.0)
	flash.z_index = 12
	add_child(flash)
	resized.connect(_layout)
	_layout()


func play(kind: int, who: String = "") -> void:
	_kind = kind
	_playing = true
	_hit = false
	_t = 0.0
	_jolt = 0.0
	_rings.clear()
	_clear_bits()
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP if kind == Kind.VICTIM else Control.MOUSE_FILTER_IGNORE
	if title:
		title.text = "你被开除了！" if kind == Kind.VICTIM else "%s 被开除" % who
	if fire_lab:
		fire_lab.text = "FIRE" if kind == Kind.VICTIM else "已从编制移除"
	_layout()
	_reset_pose()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(veil, "color:a", 0.72 if kind == Kind.VICTIM else 0.42, 0.18)
	_tween.tween_property(cluster, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cluster, "modulate:a", 1.0, 0.12)
	_tween.tween_property(shadow, "modulate:a", 0.82 if kind == Kind.VICTIM else 0.4, 0.35)
	_tween.tween_property(stamp, "position", _stamp_land, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(stamp, "scale", Vector2(1.06, 1.06), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(stamp, "rotation", -0.10, 0.34)
	_tween.chain().tween_callback(_slam)


func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_playing = false
	_hit = false
	_rings.clear()
	_clear_bits()
	visible = false
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not _playing or _kind != Kind.VICTIM:
		return
	if event is InputEventMouseButton and event.pressed:
		_skip()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8:
			return
		_skip()


func _skip() -> void:
	if not _hit:
		if _tween:
			_tween.kill()
		stamp.position = _stamp_land
		stamp.scale = Vector2.ONE
		stamp.rotation = -0.10
		_slam()
	else:
		_begin_out()


func _reset_pose() -> void:
	cluster.scale = Vector2(0.86, 0.86)
	cluster.modulate.a = 0.0
	cluster.rotation = 0.04
	veil.color.a = 0.0
	flash.color.a = 0.0
	imprint.modulate.a = 0.0
	imprint.scale = Vector2(0.72, 0.72)
	title.modulate.a = 0.0
	title.scale = Vector2(0.2, 0.2)
	fire_lab.modulate.a = 0.0
	fire_lab.scale = Vector2(0.2, 0.2)
	bang.modulate.a = 0.0
	bang.scale = Vector2(0.35, 0.35)
	dream.modulate.a = 0.0
	next_bub.modulate.a = 0.0
	next_bub.scale = Vector2(0.4, 0.4)
	react.modulate.a = 0.0
	react.scale = Vector2(0.7, 0.7)
	shadow.modulate.a = 0.0
	debris.modulate.a = 0.0
	debris.scale = Vector2(0.8, 0.8)
	var start_sc := 2.4 if _kind == Kind.VICTIM else 1.6
	stamp.scale = Vector2(start_sc, start_sc)
	stamp.rotation = -0.32
	stamp.modulate.a = 1.0
	stamp.position = Vector2(_stamp_land.x + 48.0, -stamp.size.y * 0.4)


func _slam() -> void:
	if not _playing or _hit:
		return
	_hit = true
	_jolt = 1.0
	impacted.emit()
	_spawn_rings()
	_spawn_bits()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(stamp, "scale", Vector2(1.14, 0.80), 0.05)
	_tween.tween_property(flash, "color:a", 0.5 if _kind == Kind.VICTIM else 0.24, 0.04)
	_tween.tween_property(bang, "modulate:a", 1.0, 0.04)
	_tween.tween_property(bang, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(debris, "modulate:a", 0.95, 0.06)
	_tween.tween_property(debris, "scale", Vector2.ONE, 0.18)
	_tween.chain().tween_callback(_after_squash)


func _after_squash() -> void:
	if not _playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(stamp, "scale", Vector2.ONE, 0.10)
	_tween.tween_property(flash, "color:a", 0.0, 0.16)
	_tween.tween_property(bang, "scale", Vector2.ONE, 0.10)
	_tween.tween_property(cluster, "rotation", 0.0, 0.12)
	_tween.tween_property(dream, "modulate:a", 1.0, 0.12)
	_tween.chain().tween_callback(_brand)


func _brand() -> void:
	if not _playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(imprint, "modulate:a", 1.0, 0.08)
	_tween.tween_property(imprint, "scale", Vector2(1.08, 1.08), 0.10)
	_tween.tween_property(title, "modulate:a", 1.0, 0.08)
	_tween.tween_property(title, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(fire_lab, "modulate:a", 1.0, 0.10)
	_tween.tween_property(fire_lab, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(next_bub, "modulate:a", 1.0, 0.10)
	_tween.tween_property(next_bub, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(react, "modulate:a", 1.0, 0.12)
	_tween.tween_property(react, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_hold)


func _hold() -> void:
	if not _playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(imprint, "scale", Vector2.ONE, 0.08)
	_tween.tween_property(title, "scale", Vector2.ONE, 0.08)
	_tween.tween_property(debris, "modulate:a", 0.35, 0.4)
	var hold := 1.15 if _kind == Kind.VICTIM else 0.7
	_tween.chain().tween_interval(hold)
	_tween.chain().tween_callback(_begin_out)


func _begin_out() -> void:
	if not _playing:
		return
	if _kind == Kind.VICTIM:
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(stamp, "modulate:a", 0.0, 0.35)
		_tween.tween_property(stamp, "position:y", stamp.position.y - 36.0, 0.35)
		_tween.tween_property(bang, "modulate:a", 0.0, 0.22)
		_tween.tween_property(dream, "modulate:a", 0.55, 0.22)
		_tween.tween_property(veil, "color:a", 0.48, 0.35)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tween.chain().tween_callback(func(): finished.emit())
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.chain().tween_callback(func():
		stop()
		finished.emit()
	)


func _process(delta: float) -> void:
	if not _playing or not visible:
		return
	_t += delta
	_jolt = maxf(0.0, _jolt - delta * 3.6)
	if _jolt > 0.02:
		var amp := _jolt * (18.0 if _kind == Kind.VICTIM else 10.0)
		cluster.position = _cluster_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp
		stamp.position = _stamp_land + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp * 0.45
	else:
		cluster.position = _cluster_base
	for i in range(_bits.size() - 1, -1, -1):
		var bit: Dictionary = _bits[i]
		var node: TextureRect = bit["node"]
		bit["v"] = bit["v"] + Vector2(0.0, 980.0 * delta)
		node.position += bit["v"] * delta
		node.rotation += bit["spin"] * delta
		bit["life"] = float(bit["life"]) - delta
		node.modulate.a = clampf(float(bit["life"]) / 0.7, 0.0, 1.0)
		if float(bit["life"]) <= 0.0:
			node.queue_free()
			_bits.remove_at(i)
	for ring in _rings:
		ring["r"] = float(ring["r"]) + float(ring["spd"]) * delta
		ring["a"] = float(ring["a"]) - delta * 1.6
	if not _rings.is_empty() and float(_rings[0]["a"]) <= 0.0:
		_rings.clear()
	queue_redraw()


func _draw() -> void:
	if not _playing:
		return
	for ring in _rings:
		var a := clampf(float(ring["a"]), 0.0, 1.0)
		if a <= 0.01:
			continue
		draw_arc(_stamp_land + stamp.size * 0.5, float(ring["r"]), 0.0, TAU, 56, Color(0.92, 0.10, 0.08, a), 9.0, true)


func _spawn_rings() -> void:
	_rings = [
		{"r": 18.0, "spd": 720.0, "a": 0.85},
		{"r": 8.0, "spd": 980.0, "a": 0.55},
	]


func _spawn_bits() -> void:
	_clear_bits()
	var origin := _stamp_land + stamp.size * 0.5
	var n := 16 if _kind == Kind.VICTIM else 8
	for i in n:
		var node := _tex(SHARD_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		var sc := randf_range(0.18, 0.46)
		node.size = Vector2(90, 90) * sc
		node.pivot_offset = node.size * 0.5
		node.position = origin - node.size * 0.5
		node.rotation = randf_range(-PI, PI)
		node.modulate.a = 1.0
		shards_root.add_child(node)
		var ang := randf_range(-PI, PI)
		_bits.append({
			"node": node,
			"v": Vector2.from_angle(ang) * randf_range(240.0, 580.0) + Vector2(0, -200.0),
			"spin": randf_range(-8.0, 8.0),
			"life": randf_range(0.6, 1.15),
		})


func _clear_bits() -> void:
	for bit in _bits:
		var node: TextureRect = bit.get("node")
		if node:
			node.queue_free()
	_bits.clear()
	if shards_root:
		for child in shards_root.get_children():
			child.queue_free()


func _layout() -> void:
	var vs := size
	if vs.x < 8.0:
		vs = get_viewport_rect().size
	var ph := minf(vs.y * 0.82, 660.0)
	var pw := minf(ph * 0.70, vs.x * 0.42)
	cluster.size = Vector2(pw, ph)
	cluster.pivot_offset = cluster.size * 0.5
	_cluster_base = Vector2(vs.x * 0.22, (vs.y - ph) * 0.5)
	cluster.position = _cluster_base
	paper.size = cluster.size
	paper.pivot_offset = paper.size * 0.5
	header.size = Vector2(pw * 0.7, 34.0)
	header.position = Vector2(pw * 0.15, ph * 0.05)
	var iw := minf(pw * 1.16, vs.x * 0.50)
	var font_px := int(clampf(iw * 0.168, 54.0, 78.0))
	var fire_px := int(font_px * 0.46)
	var ih := float(font_px) * 2.42
	imprint.size = Vector2(iw, ih)
	imprint.pivot_offset = imprint.size * 0.5
	imprint.position = Vector2((pw - iw) * 0.5, ph * 0.60)
	imprint.rotation = -0.08
	title.add_theme_font_size_override("font_size", font_px)
	title.add_theme_constant_override("outline_size", maxi(8, int(font_px * 0.18)))
	title.size = Vector2(iw * 0.86, float(font_px) * 1.18)
	title.pivot_offset = title.size * 0.5
	title.position = imprint.position + Vector2(iw * 0.07, ih * 0.16)
	title.rotation = -0.08
	fire_lab.add_theme_font_size_override("font_size", fire_px)
	fire_lab.add_theme_constant_override("outline_size", maxi(5, int(fire_px * 0.22)))
	fire_lab.size = Vector2(iw * 0.50, float(fire_px) * 1.25)
	fire_lab.pivot_offset = fire_lab.size * 0.5
	fire_lab.position = imprint.position + Vector2(iw * 0.25, ih * 0.58)
	fire_lab.rotation = -0.08
	var ss := minf(vs.x, vs.y) * (0.46 if _kind == Kind.VICTIM else 0.34)
	stamp.size = Vector2(ss, ss)
	stamp.pivot_offset = stamp.size * 0.5
	_imprint_center = _cluster_base + imprint.position + imprint.size * 0.5
	_stamp_land = _cluster_base + Vector2(pw * 0.46, ph * -0.06) - stamp.size * Vector2(0.18, 0.08)
	var bang_s := minf(vs.x, vs.y) * 0.38
	bang.size = Vector2(bang_s, bang_s)
	bang.pivot_offset = bang.size * 0.5
	bang.position = Vector2(vs.x * 0.02, vs.y * 0.22)
	dream.size = Vector2(140, 52)
	dream.pivot_offset = Vector2(0, 0)
	dream.position = Vector2(vs.x * 0.05, vs.y * 0.52)
	shadow.size = Vector2(vs.x * 0.28, vs.y * 0.92)
	shadow.position = Vector2(vs.x * 0.72, vs.y * 0.08)
	next_bub.size = Vector2(180, 96)
	next_bub.pivot_offset = next_bub.size * 0.5
	next_bub.position = Vector2(vs.x * 0.70, vs.y * 0.10)
	react.size = Vector2(150, 168)
	react.pivot_offset = react.size * 0.5
	react.position = Vector2(vs.x * 0.04, vs.y * 0.68)
	debris.size = Vector2(vs.x * 0.7, vs.y * 0.7)
	debris.pivot_offset = debris.size * 0.5
	debris.position = Vector2(vs.x * 0.18, vs.y * 0.12)
	if not _playing:
		stamp.position = _stamp_land


func _tex(path: String, stretch: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture = Rules.tex(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = stretch
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _lab(text: String, size_px: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	return node
