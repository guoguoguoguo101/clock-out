extends Control
class_name KickoffBanner

signal finished

const CLOCK_PATH := "res://assets/game/ui/kickoff/clock.png"
const TITLE_10 := "res://assets/game/ui/kickoff/title_10.png"
const TITLE_3 := "res://assets/game/ui/kickoff/title_3.png"

var cluster: Control
var clock: TextureRect
var title: TextureRect
var sub: Label
var _playing := false
var _t := 0.0
var _clock_base := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	cluster = Control.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cluster)
	clock = _tex(CLOCK_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	clock.z_index = 1
	cluster.add_child(clock)
	title = _tex(TITLE_10, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	cluster.add_child(title)
	sub = Label.new()
	sub.text = "……但是，新的工作还在不断涌来……"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 0.92))
	sub.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.10, 0.8))
	sub.add_theme_constant_override("outline_size", 4)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_child(sub)
	resized.connect(_layout_cluster)
	_layout_cluster()


func play(minutes: int) -> void:
	if title:
		title.texture = Rules.tex(TITLE_3 if minutes <= 4 else TITLE_10)
	visible = true
	modulate.a = 1.0
	_playing = true
	_t = 0.0
	_layout_cluster()
	cluster.scale = Vector2(0.72, 0.72)
	cluster.modulate.a = 1.0
	if title:
		title.scale = Vector2.ONE
		title.modulate = Color.WHITE
	if clock:
		clock.rotation = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(cluster, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cluster, "scale", Vector2.ONE, 0.08)
	_tween.tween_interval(2.05)
	_tween.tween_callback(_begin_out)


func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_playing = false
	visible = false
	modulate.a = 1.0


func _begin_out() -> void:
	if not _playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(cluster, "scale", Vector2(0.94, 0.94), 0.5)
	_tween.tween_property(cluster, "position:y", cluster.position.y - 16.0, 0.5)
	_tween.chain().tween_callback(_end)


func _end() -> void:
	_playing = false
	visible = false
	modulate.a = 1.0
	if cluster:
		cluster.scale = Vector2.ONE
	finished.emit()


func _process(delta: float) -> void:
	if not _playing or not visible:
		return
	_t += delta
	if clock:
		var jig := sin(_t * 42.0) * 0.11 + sin(_t * 73.0) * 0.05
		clock.rotation = jig
		clock.position = _clock_base + Vector2(sin(_t * 58.0) * 1.8, cos(_t * 51.0) * 1.1)
	if title:
		var flash := 0.5 + 0.5 * sin(_t * 18.5)
		var hot := 0.82 + flash * 0.28
		title.modulate = Color(hot, 0.88 + flash * 0.12, 0.88 + flash * 0.08, 1.0)
		title.scale = Vector2(1.0 + flash * 0.012, 1.0 + flash * 0.012)
	if sub:
		sub.modulate.a = 0.72 + 0.18 * sin(_t * 3.2)


func _tex(path: String, stretch: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture = Rules.tex(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = stretch
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _layout_cluster() -> void:
	if cluster == null or title == null:
		return
	var vs := size
	if vs.x < 8.0:
		vs = get_viewport_rect().size
	var title_tex: Texture2D = title.texture
	var clock_tex: Texture2D = clock.texture if clock else null
	var tw := minf(vs.x * 0.74, 860.0)
	var th := 96.0
	if title_tex:
		th = tw * title_tex.get_size().y / maxf(title_tex.get_size().x, 1.0)
	var ch := clampf(th * 1.12, 72.0, 118.0)
	var cw := ch
	if clock_tex:
		cw = ch * clock_tex.get_size().x / maxf(clock_tex.get_size().y, 1.0)
	var sh := 22.0
	var sw := tw * 0.9
	var total_w := cw * 0.52 + tw
	var total_h := maxf(ch, th) + sh + 8.0
	cluster.size = Vector2(total_w, total_h)
	cluster.pivot_offset = Vector2(total_w * 0.5, total_h * 0.45)
	cluster.position = Vector2((vs.x - total_w) * 0.5, maxf(18.0, vs.y * 0.055))
	if clock:
		clock.size = Vector2(cw, ch)
		clock.pivot_offset = Vector2(cw * 0.5, ch * 0.42)
		_clock_base = Vector2(0.0, (maxf(ch, th) - ch) * 0.5)
		clock.position = _clock_base
	title.size = Vector2(tw, th)
	title.pivot_offset = Vector2(tw * 0.5, th * 0.5)
	title.position = Vector2(cw * 0.48, (maxf(ch, th) - th) * 0.5)
	if sub:
		sub.size = Vector2(sw, sh)
		sub.position = Vector2(title.position.x + (tw - sw) * 0.5, title.position.y + th + 2.0)
