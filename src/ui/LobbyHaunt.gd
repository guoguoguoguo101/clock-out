extends Node
class_name LobbyHaunt

const WARP_SHADER := preload("res://src/ui/lobby_warp.gdshader")
const HAUNT_SHADER := preload("res://src/ui/lobby_haunt.gdshader")
const SCAN_SHADER := preload("res://src/ui/lobby_scan.gdshader")
const CHROMA_SHADER := preload("res://src/ui/lobby_chroma.gdshader")
const VIGNETTE_SHADER := preload("res://src/ui/lobby_vignette.gdshader")
const HauntTextScript := preload("res://src/ui/HauntText.gd")

const TITLE_GLITCH := ["六点下班", "六点下班", "六点下班", "不准下班", "六点未到", "还没到点", "不许走", "自愿留下"]
const TAG_GLITCH := ["谁准你下班", "谁准你下班", "未打卡视为自愿", "监控覆盖全楼", "加班须知第三条", "内部资料 严禁外传"]
const MOODS := [
	"白灯还亮着。走廊那头有人站着。",
	"打卡机响了一声。没有人。",
	"请勿与玻璃后的同事对视。",
	"未打卡者，视为自愿留下。",
	"监控在看你。不要回头。",
	"时针停在六点。门还没开。",
	"工牌掉在电梯里。电梯停在负一。",
	"你还有一封未读。发件人是你自己。",
]
const TICKER := "　　关于严格执行六点下班制度的通知　　未打卡视为自愿留下　　全楼监控已覆盖　　请勿与玻璃后的同事对视　　内部资料严禁外传　　天眼系统运行中　　工号0006已注销　　如见到本人请勿搭话　　电梯停在负一层　　你还有一封未读　　"
const BTN_ALTS := {
	"打卡上班": ["打卡上班", "打卡上班", "不准下班", "还没到点", "插入工卡"],
	"接入监控": ["接入监控", "接入监控", "你正在被看", "全楼覆盖"],
	"身份核验": ["身份核验", "身份核验", "请勿对视", "人像比对"],
	"进入单位": ["进入单位", "进入单位", "已记录面容"],
	"开设加班": ["开设加班", "开设加班", "自愿留下"],
	"返回": ["返回", "返回", "走廊还在"],
	"返回走廊": ["返回走廊", "返回走廊", "灯还亮着"],
}

var lobby: Control
var bg: TextureRect
var hero: TextureRect
var cam: TextureRect
var clock: TextureRect
var punch: TextureRect
var dim: ColorRect
var title: Control
var tag: Control
var mood: Control
var rec: Control
var lcd: Control
var led: ColorRect
var ticker: Control
var ghost: TextureRect
var static_fx: ColorRect
var unread: Control
var exit_sign: Control
var drip: ColorRect
var bg_mat: ShaderMaterial
var hero_mat: ShaderMaterial
var _t := 0.0
var _glitch := 0.0
var _mood_i := 0
var _mood_t := 0.0
var _title_base := "六点下班"
var _tag_base := "谁准你下班"
var _ticker_x := 0.0


func bind(nodes: Dictionary) -> void:
	lobby = nodes.get("lobby")
	bg = nodes.get("bg")
	hero = nodes.get("hero")
	cam = nodes.get("cam")
	clock = nodes.get("clock")
	punch = nodes.get("punch")
	dim = nodes.get("dim")
	title = nodes.get("title")
	tag = nodes.get("tag")
	mood = nodes.get("mood")
	rec = nodes.get("rec")
	lcd = nodes.get("lcd")
	led = nodes.get("led")
	if bg:
		bg_mat = ShaderMaterial.new()
		bg_mat.shader = HAUNT_SHADER
		bg.material = bg_mat
	if hero:
		hero_mat = ShaderMaterial.new()
		hero_mat.shader = HAUNT_SHADER
		hero.material = hero_mat
	if title:
		_title_base = str(title.get("text"))
	if tag:
		_tag_base = str(tag.get("text"))
	_chroma(clock)
	_chroma(punch)
	_chroma(cam)


func dress(parent: Control) -> void:
	make_dust(parent)
	_vignette(parent)
	_make_ticker(parent)
	_make_ghost(parent)
	_make_unread(parent)
	_make_exit(parent)
	_make_drip(parent)
	make_scan(parent)
	_make_static(parent)


func warp_control(c: Control, amp := 0.012, chroma := 0.0) -> void:
	_warp(c, amp, chroma)


func _chroma(c: CanvasItem) -> void:
	if c == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CHROMA_SHADER
	c.material = mat


func _warp(c: Control, amp: float, chroma: float) -> void:
	if c == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = WARP_SHADER
	mat.set_shader_parameter("amp", amp)
	mat.set_shader_parameter("chroma", chroma)
	c.material = mat


func make_scan(parent: Control) -> void:
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = SCAN_SHADER
	scan.material = mat
	parent.add_child(scan)


func make_dust(parent: Control) -> void:
	var dust := CPUParticles2D.new()
	dust.position = Vector2(720, 360)
	dust.amount = 42
	dust.lifetime = 9.0
	dust.preprocess = 4.0
	dust.z_index = 1
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(640, 380)
	dust.direction = Vector2(0.15, -1)
	dust.spread = 70.0
	dust.gravity = Vector2(8, 12)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 18.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.6
	dust.color = Color(0.78, 0.82, 0.7, 0.22)
	parent.add_child(dust)
	if parent.get_child_count() > 3:
		parent.move_child(dust, 2)


func _vignette(parent: Control) -> void:
	var v := ColorRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	v.material = mat
	parent.add_child(v)


func _make_ticker(parent: Control) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.12, 0.03, 0.03, 0.82)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 22
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	ticker = HauntTextScript.new()
	ticker.text = TICKER + TICKER
	ticker.font_size = 13
	ticker.amp = 1.6
	ticker.chroma = 0.8
	ticker.base_color = Color(0.92, 0.78, 0.62)
	ticker.position = Vector2(0, 2)
	ticker.size = Vector2(2800, 20)
	bar.add_child(ticker)


func _make_ghost(parent: Control) -> void:
	ghost = TextureRect.new()
	ghost.texture = load("res://assets/game/chars/horse/idle_0.png")
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.position = Vector2(520, 140)
	ghost.size = Vector2(220, 320)
	ghost.modulate = Color(0.04, 0.03, 0.04, 0.0)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ghost)


func _make_unread(parent: Control) -> void:
	unread = HauntTextScript.new()
	unread.text = "未读 1　发件人：你"
	unread.font_size = 14
	unread.amp = 2.8
	unread.base_color = Color(0.95, 0.86, 0.72)
	unread.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	unread.offset_left = -240
	unread.offset_top = -86
	unread.offset_right = -28
	unread.offset_bottom = -54
	unread.modulate.a = 0.0
	parent.add_child(unread)


func _make_exit(parent: Control) -> void:
	exit_sign = HauntTextScript.new()
	exit_sign.text = "EXIT"
	exit_sign.font_size = 22
	exit_sign.amp = 3.4
	exit_sign.align = HORIZONTAL_ALIGNMENT_CENTER
	exit_sign.base_color = Color(0.95, 0.18, 0.14)
	exit_sign.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	exit_sign.offset_left = -170
	exit_sign.offset_top = 108
	exit_sign.offset_right = -40
	exit_sign.offset_bottom = 140
	parent.add_child(exit_sign)


func _make_drip(parent: Control) -> void:
	drip = ColorRect.new()
	drip.color = Color(0.42, 0.04, 0.05, 0.55)
	drip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	drip.offset_left = 86
	drip.offset_top = 0
	drip.offset_right = 94
	drip.offset_bottom = 8
	drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(drip)


func _make_static(parent: Control) -> void:
	static_fx = ColorRect.new()
	static_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_fx.color = Color(0.82, 0.84, 0.78, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SCAN_SHADER
	static_fx.material = mat
	parent.add_child(static_fx)


func _set_txt(n: Control, s: String) -> void:
	if n == null:
		return
	n.set("text", s)


func _process(delta: float) -> void:
	if lobby == null or not is_inside_tree() or not lobby.visible:
		return
	var tree := get_tree()
	if tree == null:
		return
	_t += delta
	_mood_t += delta
	_glitch = maxf(0.0, _glitch - delta * 2.2)
	if randf() < 0.018:
		_glitch = randf_range(0.5, 1.0)
	if bg_mat:
		bg_mat.set_shader_parameter("flicker", 0.78 + 0.22 * sin(_t * 7.4) * sin(_t * 1.3))
		bg_mat.set_shader_parameter("glitch", _glitch)
	if hero_mat:
		hero_mat.set_shader_parameter("flicker", 0.88 + 0.12 * sin(_t * 2.1))
		hero_mat.set_shader_parameter("glitch", _glitch * 0.85)
	if hero:
		hero.pivot_offset = hero.size * 0.5
		var z := 1.0 + 0.045 * sin(_t * 0.22)
		hero.scale = Vector2(z, z)
	if dim:
		var out := 1.0 if _glitch > 0.82 else 0.0
		dim.color.a = 0.72 + 0.12 * sin(_t * 3.2) + out * 0.18
	if cam:
		cam.pivot_offset = cam.size * 0.5
		cam.rotation = sin(_t * 0.55) * 0.12
		cam.modulate = Color(1, 0.82 + 0.18 * sin(_t * 9.0), 0.82, 0.95)
	if clock:
		clock.rotation = sin(_t * 0.9) * 0.06 + (0.18 if _glitch > 0.6 else 0.0)
		clock.modulate = Color(1.15, 0.92, 0.88) if _glitch > 0.7 else Color.WHITE
	if punch:
		punch.rotation = sin(_t * 1.4) * 0.04
		punch.modulate = Color(1.0, 0.88, 0.84)
	if led:
		led.color.a = 0.2 + 0.8 * (0.5 + 0.5 * sin(_t * 11.0))
		led.scale = Vector2.ONE * (1.0 + 0.35 * sin(_t * 11.0))
	if rec:
		var sec := int(_t) % 60
		_set_txt(rec, "REC  ●  CAM-04  17:59:%02d" % sec)
		rec.modulate.a = 0.45 + 0.55 * (1.0 if sin(_t * 6.0) > 0.0 else 0.0)
	if lcd:
		var ticks := ["17:59", "17:59", "逾 时", "6:66", "ERROR", "未授权", "不要走"]
		_set_txt(lcd, ticks[int(_t * 1.8) % ticks.size()])
	if title:
		if _glitch > 0.55 and fmod(_t, 0.14) < delta:
			_set_txt(title, TITLE_GLITCH[randi() % TITLE_GLITCH.size()])
		elif _glitch <= 0.55:
			_set_txt(title, _title_base)
		title.rotation = sin(_t * 1.7) * 0.03
	if tag:
		if _glitch > 0.7 and fmod(_t, 0.16) < delta:
			_set_txt(tag, TAG_GLITCH[randi() % TAG_GLITCH.size()])
		elif _glitch <= 0.7:
			_set_txt(tag, _tag_base)
		tag.rotation = -0.04 + sin(_t * 1.1) * 0.03
	if mood and _mood_t > 3.4:
		_mood_t = 0.0
		_mood_i = (_mood_i + 1) % MOODS.size()
		_set_txt(mood, MOODS[_mood_i])
	if ticker:
		_ticker_x -= delta * 42.0
		if _ticker_x < -1400.0:
			_ticker_x = 0.0
		ticker.position.x = _ticker_x
	if ghost:
		if lobby:
			ghost.position = Vector2(lobby.size.x * 0.38, lobby.size.y * 0.18)
			ghost.size = Vector2(lobby.size.x * 0.16, lobby.size.y * 0.5)
		var show := _glitch > 0.62 or sin(_t * 0.21) > 0.92
		ghost.modulate.a = lerpf(ghost.modulate.a, 0.72 if show else 0.0, delta * 3.5)
		if show and randf() < 0.04:
			ghost.texture = load("res://assets/game/chars/tiger/idle_0.png") if randf() < 0.5 else load("res://assets/game/chars/horse/idle_0.png")
	if unread:
		var ping := fmod(_t, 11.0) > 7.2
		unread.modulate.a = lerpf(unread.modulate.a, 0.95 if ping else 0.0, delta * 4.0)
		if ping and _glitch > 0.5:
			_set_txt(unread, "未读 1　发件人：六点下班")
	if exit_sign:
		_set_txt(exit_sign, "不准走" if _glitch > 0.6 else "EXIT")
		exit_sign.rotation = sin(_t * 0.8) * 0.05
	if drip:
		drip.offset_bottom = 10.0 + abs(sin(_t * 0.35)) * 90.0
	if static_fx:
		static_fx.color.a = _glitch * 0.22
	for b in tree.get_nodes_in_group("haunt_btn"):
		if not (b is Control):
			continue
		var c := b as Control
		c.pivot_offset = c.size * 0.5
		c.rotation = sin(_t * 1.15 + float(c.get_instance_id() % 97)) * 0.035
		c.scale = Vector2.ONE * (1.0 + 0.012 * sin(_t * 2.2 + float(c.get_instance_id() % 13)))
		var cap := c.get_node_or_null("HauntCap")
		var base := str(c.get_meta("haunt_base", c.get("text")))
		if cap:
			var alts: Variant = BTN_ALTS.get(base, [base])
			if _glitch > 0.58 and alts is Array:
				cap.set("text", str((alts as Array)[randi() % (alts as Array).size()]))
			else:
				cap.set("text", base)
