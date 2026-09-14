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
	"夜班系统已连接。大厅仍有 4 名员工在线。",
	"考勤服务同步完成。请在离开前确认工牌状态。",
	"CAM-04 正在巡检公共区域。",
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
var office_lights: Array[ColorRect] = []
var monitor_panel: Panel
var monitor_feed: Control
var monitor_scan: ColorRect
var access_panel: Panel
var access_state: Control
var presence_state: Control
var event_card: Panel
var event_title: Control
var event_detail: Control
var _event_kind := -1
var _event_left := 0.0
var _event_wait := 13.0
var _monitor_line := 0
var scenery: Array[TextureRect] = []
var office_actors: Array[Sprite2D] = []
var rain_streaks: Array[ColorRect] = []


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
	var supplied_layers: Variant = nodes.get("layers", [])
	if supplied_layers is Array:
		for item in supplied_layers:
			if item is TextureRect:
				scenery.append(item)
	var supplied_actors: Variant = nodes.get("actors", [])
	if supplied_actors is Array:
		for item in supplied_actors:
			if item is Sprite2D:
				office_actors.append(item)
	# Keep the illustration clean. Motion and sparse office signals provide the
	# atmosphere; a permanently broken CRT treatment makes the menu tiring to read.
	if title:
		_title_base = str(title.get("text"))
	if tag:
		_tag_base = str(tag.get("text"))
	_chroma(clock)
	_chroma(punch)
	_chroma(cam)


func dress(parent: Control) -> void:
	_make_office_lights(parent)
	_make_office_signals(parent)
	_make_rain(parent)
	make_dust(parent)
	_vignette(parent)
	_make_ticker(parent)
	_make_ghost(parent)
	_make_unread(parent)
	_make_exit(parent)
	_make_drip(parent)
	make_scan(parent)
	_make_static(parent)


func _make_rain(parent: Control) -> void:
	# Thin individual streaks are moved every frame, so the rain is genuinely
	# falling rather than a static weather card sliding under the UI.
	for i in 56:
		var drop := ColorRect.new()
		drop.color = Color(0.48, 0.72, 0.86, randf_range(0.08, 0.22))
		drop.position = Vector2(randf_range(-80.0, 1450.0), randf_range(-720.0, 720.0))
		drop.size = Vector2(1.2, randf_range(16.0, 42.0))
		drop.rotation = -0.16
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop.set_meta("rain_speed", randf_range(210.0, 460.0))
		parent.add_child(drop)
		rain_streaks.append(drop)


func _make_office_lights(parent: Control) -> void:
	for i in 4:
		var light := ColorRect.new()
		light.color = Color(0.52, 0.68, 0.78, 0.0)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.position = Vector2(650.0 + float(i) * 150.0, 82.0 + float(i % 2) * 88.0)
		light.size = Vector2(96, 8)
		parent.add_child(light)
		office_lights.append(light)


func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _office_label(text: String, size_px: int, color: Color) -> Control:
	var label := HauntTextScript.new()
	label.text = text
	label.font_size = size_px
	label.amp = 0.0
	label.chroma = 0.0
	label.base_color = color
	return label


func _make_office_signals(parent: Control) -> void:
	# Normal-looking internal tools are more unsettling than a permanent horror filter.
	monitor_panel = Panel.new()
	monitor_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	monitor_panel.offset_left = -264
	monitor_panel.offset_top = 146
	monitor_panel.offset_right = -28
	monitor_panel.offset_bottom = 252
	monitor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.075, 0.10, 0.90), Color(0.18, 0.50, 0.56, 0.72)))
	parent.add_child(monitor_panel)
	var head := _office_label("CAM-04  ·  公共办公区", 12, Color(0.54, 0.83, 0.82))
	head.position = Vector2(10, 8)
	head.size = Vector2(214, 18)
	monitor_panel.add_child(head)
	monitor_feed = _office_label("座位占用：04 / 04\n考勤同步：正常\n画面延迟：0.2s", 13, Color(0.74, 0.84, 0.82))
	monitor_feed.position = Vector2(10, 31)
	monitor_feed.size = Vector2(216, 54)
	monitor_panel.add_child(monitor_feed)
	monitor_scan = ColorRect.new()
	monitor_scan.color = Color(0.34, 0.88, 0.82, 0.10)
	monitor_scan.position = Vector2(8, 29)
	monitor_scan.size = Vector2(220, 2)
	monitor_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_panel.add_child(monitor_scan)

	access_panel = Panel.new()
	access_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	access_panel.offset_left = -264
	access_panel.offset_top = -142
	access_panel.offset_right = -28
	access_panel.offset_bottom = -96
	access_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	access_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.10, 0.12, 0.88), Color(0.20, 0.42, 0.46, 0.60)))
	parent.add_child(access_panel)
	access_state = _office_label("门禁 A 区  ·  已解锁", 13, Color(0.66, 0.86, 0.76))
	access_state.position = Vector2(10, 5)
	access_state.size = Vector2(216, 18)
	access_panel.add_child(access_state)
	presence_state = _office_label("在岗 04  ·  访客 00", 12, Color(0.55, 0.70, 0.72))
	presence_state.position = Vector2(10, 24)
	presence_state.size = Vector2(216, 17)
	access_panel.add_child(presence_state)

	event_card = Panel.new()
	event_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	event_card.offset_left = -380
	event_card.offset_top = -230
	event_card.offset_right = -28
	event_card.offset_bottom = -156
	event_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_card.modulate.a = 0.0
	event_card.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.11, 0.14, 0.96), Color(0.40, 0.72, 0.70, 0.82)))
	parent.add_child(event_card)
	event_title = _office_label("系统通知", 14, Color(0.74, 0.94, 0.86))
	event_title.position = Vector2(12, 10)
	event_title.size = Vector2(328, 20)
	event_card.add_child(event_title)
	event_detail = _office_label("", 12, Color(0.72, 0.80, 0.80))
	event_detail.position = Vector2(12, 31)
	event_detail.size = Vector2(328, 34)
	event_detail.set("wrap", true)
	event_card.add_child(event_detail)


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
	dust.amount = 24
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
	dust.color = Color(0.78, 0.82, 0.7, 0.12)
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
	bar.color = Color(0.035, 0.07, 0.10, 0.76)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 22
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	ticker = HauntTextScript.new()
	ticker.text = TICKER + TICKER
	ticker.font_size = 13
	ticker.amp = 0.25
	ticker.chroma = 0.0
	ticker.base_color = Color(0.68, 0.76, 0.80)
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
	unread.amp = 0.5
	unread.chroma = 0.0
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
	exit_sign.amp = 0.0
	exit_sign.chroma = 0.0
	exit_sign.align = HORIZONTAL_ALIGNMENT_CENTER
	exit_sign.base_color = Color(0.70, 0.86, 0.78)
	exit_sign.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	exit_sign.offset_left = -170
	exit_sign.offset_top = 108
	exit_sign.offset_right = -40
	exit_sign.offset_bottom = 140
	parent.add_child(exit_sign)


func _make_drip(parent: Control) -> void:
	drip = ColorRect.new()
	drip.color = Color(0.12, 0.22, 0.28, 0.10)
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


func _begin_office_event() -> void:
	_event_kind = randi() % 4
	_event_left = randf_range(4.0, 5.8)
	_event_wait = randf_range(16.0, 29.0)
	match _event_kind:
		0:
			_set_txt(event_title, "考勤系统 · 异常记录")
			_set_txt(event_detail, "工号 0006 于 18:00 完成打卡。\n该工号未在本日排班名单中。")
		1:
			_set_txt(event_title, "未读邮件 · 人力资源")
			_set_txt(event_detail, "主题：离职手续已完成\n收件人：仍在岗的员工")
		2:
			_set_txt(event_title, "门禁提示 · B1 通道")
			_set_txt(event_detail, "18:00 后门禁已自动关闭。\n检测到一次无工牌通行请求。")
		_:
			_set_txt(event_title, "会议纪要 · 自动保存")
			_set_txt(event_detail, "参会人数：05    应到人数：04\n第 5 位参会者未显示姓名。")


func _update_office_event(delta: float) -> void:
	_event_wait -= delta
	if _event_left <= 0.0 and _event_wait <= 0.0:
		_begin_office_event()
	if _event_left > 0.0:
		_event_left -= delta
		var life := clampf(_event_left, 0.0, 1.0)
		if event_card:
			event_card.modulate.a = minf(1.0, life * 3.0)
		if _event_kind == 0:
			_set_txt(monitor_feed, "座位占用：05 / 04\n考勤同步：需复核\n画面延迟：0.2s")
			_set_txt(presence_state, "在岗 04  ·  访客 01")
		elif _event_kind == 2:
			_set_txt(access_state, "门禁 B1  ·  复核中")
	elif event_card:
		event_card.modulate.a = lerpf(event_card.modulate.a, 0.0, minf(delta * 4.0, 1.0))


func _normalise_office_signals() -> void:
	if _event_left > 0.0:
		return
	_set_txt(monitor_feed, "座位占用：04 / 04\n考勤同步：正常\n画面延迟：0.2s")
	_set_txt(access_state, "门禁 A 区  ·  已解锁")
	_set_txt(presence_state, "在岗 04  ·  访客 00")


func _process(delta: float) -> void:
	if lobby == null or not is_inside_tree() or not lobby.visible:
		return
	var tree := get_tree()
	if tree == null:
		return
	_t += delta
	_mood_t += delta
	_update_office_event(delta)
	_normalise_office_signals()
	_glitch = maxf(0.0, _glitch - delta * 4.4)
	if randf() < 0.0025:
		_glitch = randf_range(0.58, 0.88)
	if bg_mat:
		bg_mat.set_shader_parameter("flicker", 0.78 + 0.22 * sin(_t * 7.4) * sin(_t * 1.3))
		bg_mat.set_shader_parameter("glitch", _glitch * 0.28)
	if hero_mat:
		hero_mat.set_shader_parameter("flicker", 0.88 + 0.12 * sin(_t * 2.1))
		hero_mat.set_shader_parameter("glitch", _glitch * 0.18)
	if bg:
		bg.position = Vector2(sin(_t * 0.09) * 3.0, cos(_t * 0.07) * 2.0)
	if hero:
		hero.pivot_offset = hero.size * 0.5
		var z := 1.0 + 0.045 * sin(_t * 0.22)
		hero.scale = Vector2(z, z)
	if dim:
		dim.color.a = 0.38 + 0.035 * sin(_t * 1.8)
	if cam:
		cam.pivot_offset = cam.size * 0.5
		cam.rotation = sin(_t * 0.55) * 0.025
		cam.modulate = Color(0.88, 0.95, 1.0, 0.92)
	if clock:
		clock.rotation = sin(_t * 0.9) * 0.012 + (0.04 if _glitch > 0.78 else 0.0)
		clock.modulate = Color(1.04, 0.98, 0.96) if _glitch > 0.82 else Color.WHITE
	if punch:
		punch.rotation = sin(_t * 1.4) * 0.04
		punch.modulate = Color(0.96, 0.98, 1.0)
	for i in office_lights.size():
		var light := office_lights[i]
		light.color.a = 0.07 + 0.11 * maxf(0.0, sin(_t * (0.7 + float(i) * 0.11) + float(i)))
		light.scale.x = 0.82 + 0.28 * (0.5 + 0.5 * sin(_t * 0.45 + float(i)))
	for i in scenery.size():
		var layer := scenery[i]
		layer.position = Vector2(sin(_t * (0.05 + float(i) * 0.012)) * (1.5 + float(i)), cos(_t * (0.04 + float(i) * 0.009)) * 1.5)
		if i == 1:
			layer.modulate.a = 0.32 + 0.12 * (0.5 + 0.5 * sin(_t * 1.4))
		elif i == 2:
			layer.modulate.a = 0.36 + 0.12 * (0.5 + 0.5 * sin(_t * 0.45))
	for i in office_actors.size():
		var actor := office_actors[i]
		var tempo := 0.9 + float(i) * 0.17
		var frames: Variant = actor.get_meta("lobby_frames", [])
		if frames is Array and not (frames as Array).is_empty():
			actor.texture = (frames as Array)[int(_t * tempo) % (frames as Array).size()]
		actor.position.y += sin(_t * (0.8 + float(i) * 0.12)) * delta * 1.3
		if i == 1 and fmod(_t, 11.0) > 2.0:
			actor.frame = 0
		if i == 3 and fmod(_t, 13.0) < 9.0:
			actor.frame = 0
		if i == 4:
			var fifth_visible := _event_left > 0.0 and (_event_kind == 0 or _event_kind == 3)
			actor.modulate.a = lerpf(actor.modulate.a, 0.42 if fifth_visible else 0.0, delta * 1.8)
			if frames is Array and not (frames as Array).is_empty():
				actor.texture = (frames as Array)[int(_t * 0.55) % (frames as Array).size()]
	for drop in rain_streaks:
		drop.position.y += float(drop.get_meta("rain_speed", 320.0)) * delta
		drop.position.x -= 34.0 * delta
		if drop.position.y > lobby.size.y + 54.0:
			drop.position = Vector2(randf_range(-40.0, lobby.size.x + 40.0), randf_range(-80.0, -20.0))
	if monitor_scan:
		monitor_scan.position.y = 29.0 + fmod(_t * 22.0, 54.0)
		monitor_scan.color.a = 0.06 + 0.08 * (0.5 + 0.5 * sin(_t * 3.2))
	if monitor_panel:
		monitor_panel.modulate = Color(0.96 + 0.04 * sin(_t * 2.2), 1.0, 1.0, 1.0)
	if access_panel:
		access_panel.modulate.a = 0.82 + 0.18 * (0.5 + 0.5 * sin(_t * 1.3))
	if led:
		led.color.a = 0.2 + 0.8 * (0.5 + 0.5 * sin(_t * 11.0))
		led.scale = Vector2.ONE * (1.0 + 0.35 * sin(_t * 11.0))
	if rec:
		var sec := int(_t) % 60
		_set_txt(rec, "REC  ●  CAM-04  17:59:%02d" % sec)
		rec.modulate.a = 0.45 + 0.55 * (1.0 if sin(_t * 6.0) > 0.0 else 0.0)
	if lcd:
		var ticks := ["17:59", "17:59", "18:00", "18:00", "18:01"]
		_set_txt(lcd, ticks[int(_t * 1.8) % ticks.size()])
	if title:
		_set_txt(title, _title_base)
		title.rotation = sin(_t * 1.7) * 0.006
	if tag:
		_set_txt(tag, _tag_base)
		tag.rotation = -0.01 + sin(_t * 1.1) * 0.006
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
		var show := _event_left > 0.0 and (_event_kind == 0 or _event_kind == 3)
		ghost.modulate.a = lerpf(ghost.modulate.a, 0.24 if show else 0.0, delta * 2.6)
		ghost.position.x += sin(_t * 1.1) * delta * 5.0
		if show:
			ghost.texture = load("res://assets/game/chars/horse/idle_0.png")
	if unread:
		var ping := _event_left > 0.0 and _event_kind == 1
		unread.modulate.a = lerpf(unread.modulate.a, 0.95 if ping else 0.0, delta * 4.0)
		if ping:
			_set_txt(unread, "未读 1　发件人：人力资源")
	if exit_sign:
		_set_txt(exit_sign, "NIGHT SHIFT  ·  18:00")
		exit_sign.rotation = sin(_t * 0.8) * 0.012
	if drip:
		drip.offset_bottom = 4.0 + abs(sin(_t * 0.35)) * 6.0
	if static_fx:
		static_fx.color.a = _glitch * 0.06
	for b in tree.get_nodes_in_group("haunt_btn"):
		if not (b is Control):
			continue
		var c := b as Control
		c.pivot_offset = c.size * 0.5
		c.rotation = 0.0
		c.scale = Vector2.ONE
		var cap := c.get_node_or_null("HauntCap")
		var base := str(c.get_meta("haunt_base", c.get("text")))
		if cap:
			var alts: Variant = BTN_ALTS.get(base, [base])
			cap.set("text", base)
