extends Node2D

const MeterScript := preload("res://src/ui/Meter.gd")
const CellMeterScript := preload("res://src/ui/CellMeter.gd")
const EnergyPlayScript := preload("res://src/ui/EnergyPlay.gd")
const LobbyHauntScript := preload("res://src/ui/LobbyHaunt.gd")
const HauntTextScript := preload("res://src/ui/HauntText.gd")
const StockDeskScript := preload("res://src/ui/StockDesk.gd")
const BODY_SHADER := preload("res://src/actor/body.gdshader")

var office: OfficeMap
var camera: Camera2D
var ui: CanvasLayer
var lobby: Control
var hud: Control
var result_panel: Control
var kpi_label: Label
var status_label: Label
var slot_box: Control
var name_edit: LineEdit
var ip_edit: LineEdit
var short_check: CheckBox
var hint_label: Label
var hours_bar
var energy_bar
var energy_play
var time_label: Label
var state_label: Label
var you_role: Label
var prompt_label: Label
var lamps: HBoxContainer
var you_label: Label
var boss_label: Label
var log_label: Label
var exit_btn: Button
var catch_veil: ColorRect
var catch_banner: Label
var room_warn: Label
var rec_label: Label
var cam_id_label: Label
var fear_fx: ColorRect
var kpi_fx: ColorRect
var kpi_body: Label
var mate_box: Array[ColorRect] = []
var mate_lab: Array[Label] = []
var mate_snow: Array[ColorRect] = []
var watch_label: Label
var home_page: Control
var join_page: Control
var char_page: Control
var haunt
var room_code_edit: LineEdit
var room_list_box: VBoxContainer
var enter_char_btn: Button
var join_status: Label
var fill_bots_btn: Button
var stock_desk

var wanted_slot := Rules.Slot.EMP_A
var _pulse_interact := false
var _pulse_slack := false
var _pulse_meeting := false
var _pulse_kpi := false
var _pulse_dash := false
var _pulse_report := false
var _pulse_fan := false
var _e_down := false
var _f_down := false
var _q_down := false
var _r_down := false
var _shift_down := false
var _g_down := false
var _esc_down := false
var _cam_z := 1.1
var _shake := 0.0
var _catch_t := 0.0
var _banner_t := 0.0
var _boss_seen := false
var _cam_punch := 0.0
var _breath_t := 0.0
var _help_t := 0.0
var _last_state := -1
var _go_input_t := 0.0


func _ready() -> void:
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_fit_camera)
	Match.bind_world(self, office)
	Match.lobby_changed.connect(_refresh_lobby)
	Match.match_started.connect(_on_started)
	Match.match_ended.connect(_on_ended)
	Match.hud_dirty.connect(_refresh_hud)
	Match.kpi_popup.connect(_on_kpi)
	Match.caught.connect(_on_caught)
	Match.talked.connect(_on_talked)
	Match.rescued.connect(_on_rescued)
	Match.stock_played.connect(_on_stock)
	Net.status_changed.connect(_refresh_lobby)
	Net.peer_list_changed.connect(_refresh_lobby)
	Net.room_ready.connect(_on_room_ready)
	Net.room_list_changed.connect(_refresh_room_list)
	Net.go_error.connect(_on_go_error)
	_refresh_lobby()
	print("[Game] ready")
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			_show_lobby_page.call_deferred("char")
			break


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _build_world() -> void:
	office = OfficeMap.new()
	office.name = "Office"
	add_child(office)
	camera = Camera2D.new()
	add_child(camera)
	if DisplayServer.get_name() != "headless":
		camera.make_current()
		camera.zoom = Vector2(_cam_z, _cam_z)
		camera.position = Vector2(1120, 1130)


func _fit_camera() -> void:
	pass


func _frame_room(rect: Rect2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return Vector2(_cam_z, _cam_z)
	var z := minf(vp.x / maxf(rect.size.x, 8.0), vp.y / maxf(rect.size.y, 8.0))
	z = clampf(z, 0.72, 1.35)
	return Vector2(z, z)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	_build_lobby()

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	ui.add_child(hud)
	var card := ColorRect.new()
	card.color = Color(0.12, 0.14, 0.16, 0.78)
	card.position = Vector2(18, 16)
	card.size = Vector2(168, 92)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(card)
	you_role = Label.new()
	you_role.position = Vector2(14, 8)
	you_role.add_theme_font_size_override("font_size", 12)
	you_role.add_theme_color_override("font_color", Color(0.78, 0.84, 0.88))
	card.add_child(you_role)
	time_label = Label.new()
	time_label.position = Vector2(14, 26)
	time_label.add_theme_font_size_override("font_size", 26)
	time_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	card.add_child(time_label)
	watch_label = Label.new()
	watch_label.position = Vector2(14, 56)
	watch_label.add_theme_font_size_override("font_size", 11)
	watch_label.add_theme_color_override("font_color", Color(0.62, 0.70, 0.74))
	card.add_child(watch_label)
	state_label = Label.new()
	state_label.position = Vector2(14, 72)
	state_label.size = Vector2(140, 16)
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.80))
	card.add_child(state_label)
	hours_bar = CellMeterScript.new()
	hours_bar.position = Vector2(18, 112)
	hours_bar.setup("任务", "task", Rules.TASK_COUNT)
	hud.add_child(hours_bar)
	energy_bar = CellMeterScript.new()
	energy_bar.position = Vector2(18, 164)
	energy_bar.setup("精力", "energy", Rules.ENERGY_CELLS)
	hud.add_child(energy_bar)
	energy_play = EnergyPlayScript.new()
	hud.add_child(energy_play)
	lamps = HBoxContainer.new()
	lamps.position = Vector2(18, 226)
	lamps.add_theme_constant_override("separation", 8)
	hud.add_child(lamps)
	_build_monitors()
	fear_fx = ColorRect.new()
	fear_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fear_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fear_fx.color = Color(1, 1, 1, 1)
	var fear_mat := ShaderMaterial.new()
	fear_mat.shader = load("res://src/fx/fear.gdshader")
	fear_fx.material = fear_mat
	hud.add_child(fear_fx)
	rec_label = Label.new()
	rec_label.text = "● REC"
	rec_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec_label.offset_left = -210
	rec_label.offset_top = 62
	rec_label.offset_right = -24
	rec_label.offset_bottom = 84
	rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec_label.add_theme_font_size_override("font_size", 16)
	rec_label.add_theme_color_override("font_color", Color(0.92, 0.16, 0.14, 0.0))
	hud.add_child(rec_label)
	cam_id_label = Label.new()
	cam_id_label.text = "CAM 07"
	cam_id_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_id_label.offset_left = -210
	cam_id_label.offset_top = 82
	cam_id_label.offset_right = -24
	cam_id_label.offset_bottom = 100
	cam_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cam_id_label.add_theme_font_size_override("font_size", 11)
	cam_id_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.80, 0.55))
	hud.add_child(cam_id_label)
	kpi_fx = ColorRect.new()
	kpi_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	kpi_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kpi_fx.color = Color(1, 1, 1, 1)
	kpi_fx.visible = false
	var kpi_mat := ShaderMaterial.new()
	kpi_mat.shader = load("res://src/fx/fear.gdshader")
	kpi_mat.set_shader_parameter("threat", 1.0)
	kpi_mat.set_shader_parameter("vignette", 0.72)
	kpi_mat.set_shader_parameter("grain", 0.34)
	kpi_mat.set_shader_parameter("scan", 0.28)
	kpi_fx.material = kpi_mat
	hud.add_child(kpi_fx)
	kpi_body = Label.new()
	kpi_body.text = "内部邮件  KPI 暴击\n全员再加一单\n立即打开"
	kpi_body.set_anchors_preset(Control.PRESET_CENTER)
	kpi_body.offset_left = -180
	kpi_body.offset_top = -48
	kpi_body.offset_right = 180
	kpi_body.offset_bottom = 48
	kpi_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kpi_body.add_theme_font_size_override("font_size", 22)
	kpi_body.add_theme_color_override("font_color", Color(0.95, 0.32, 0.22))
	kpi_fx.add_child(kpi_body)
	prompt_label = Label.new()
	prompt_label.visible = false
	hud.add_child(prompt_label)
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 20
	hint_label.offset_top = -28
	hint_label.offset_right = -20
	hint_label.offset_bottom = -8
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42, 0.85))
	hud.add_child(hint_label)
	kpi_label = Label.new()
	kpi_label.text = "全员 KPI  再加一单"
	kpi_label.visible = false
	kpi_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	kpi_label.offset_top = 18
	kpi_label.offset_bottom = 42
	kpi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kpi_label.add_theme_font_size_override("font_size", 16)
	kpi_label.add_theme_color_override("font_color", Color(0.82, 0.22, 0.18))
	hud.add_child(kpi_label)
	catch_veil = ColorRect.new()
	catch_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	catch_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_veil.color = Color(0.55, 0.05, 0.05, 0.0)
	hud.add_child(catch_veil)
	room_warn = Label.new()
	room_warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	room_warn.offset_left = -160
	room_warn.offset_top = 14
	room_warn.offset_right = 160
	room_warn.offset_bottom = 34
	room_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_warn.add_theme_font_size_override("font_size", 13)
	room_warn.add_theme_color_override("font_color", Color(0.62, 0.18, 0.16, 0.9))
	room_warn.text = ""
	hud.add_child(room_warn)
	catch_banner = Label.new()
	catch_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	catch_banner.offset_top = 44
	catch_banner.offset_bottom = 68
	catch_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_banner.add_theme_font_size_override("font_size", 15)
	catch_banner.add_theme_color_override("font_color", Color(0.82, 0.22, 0.18))
	catch_banner.visible = false
	hud.add_child(catch_banner)
	stock_desk = StockDeskScript.new()
	hud.add_child(stock_desk)
	hours_bar.z_index = 24
	energy_bar.z_index = 24
	energy_play.z_index = 40
	hud.move_child(fear_fx, 0)
	hud.move_child(catch_veil, 1)

	exit_btn = Button.new()
	exit_btn.text = "退出房间  Esc"
	exit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	exit_btn.offset_left = -188
	exit_btn.offset_top = 16
	exit_btn.offset_right = -20
	exit_btn.offset_bottom = 52
	exit_btn.visible = false
	exit_btn.pressed.connect(_leave_room)
	ui.add_child(exit_btn)

	result_panel = _panel(Rect2(360, 140, 560, 420), Color(1, 1, 1, 0.97))
	result_panel.visible = false
	ui.add_child(result_panel)
	you_label = Label.new()
	you_label.position = Vector2(28, 24)
	you_label.add_theme_font_size_override("font_size", 26)
	result_panel.add_child(you_label)
	boss_label = Label.new()
	boss_label.position = Vector2(28, 68)
	boss_label.add_theme_font_size_override("font_size", 26)
	result_panel.add_child(boss_label)
	log_label = Label.new()
	log_label.position = Vector2(28, 120)
	log_label.size = Vector2(500, 200)
	result_panel.add_child(log_label)
	var back := Button.new()
	back.text = "返回大厅"
	back.position = Vector2(28, 360)
	back.size = Vector2(140, 36)
	back.pressed.connect(_result_back)
	result_panel.add_child(back)


func _build_lobby() -> void:
	lobby = Control.new()
	lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(lobby)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _lobby_tex("res://assets/game/ui/lobby/bg.png")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(bg)

	var hero := TextureRect.new()
	hero.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.texture = _lobby_tex("res://assets/game/ui/lobby/hero.png")
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(hero)

	# The lobby is a small after-hours office stage, not a single flat key art.
	# These transparent layers and two-frame employees are animated by LobbyHaunt.
	var lobby_layers: Array[TextureRect] = []
	lobby_layers.append(_lobby_layer("res://assets/game/ui/lobby/layers/window-rain-city.png", 0.60))
	lobby_layers.append(_lobby_layer("res://assets/game/ui/lobby/layers/monitor-glow.png", 0.42))
	lobby_layers.append(_lobby_layer("res://assets/game/ui/lobby/layers/glass-lights-dust.png", 0.48))
	for layer in lobby_layers:
		lobby.add_child(layer)

	var dim := ColorRect.new()
	dim.name = "HauntDim"
	dim.color = Color(0.025, 0.05, 0.075, 0.40)
	dim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	dim.offset_left = 0
	dim.offset_right = 520
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(dim)
	var lobby_actors := _make_lobby_actors()
	for actor in lobby_actors:
		lobby.add_child(actor)
	var desk_layer := _lobby_layer("res://assets/game/ui/lobby/layers/desk-cctv-props.png", 0.64)
	lobby.add_child(desk_layer)
	lobby_layers.append(desk_layer)

	var cam := TextureRect.new()
	cam.texture = _lobby_tex("res://assets/game/ui/lobby/cam.png")
	cam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cam.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cam.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam.offset_left = -118
	cam.offset_top = 30
	cam.offset_right = -22
	cam.offset_bottom = 86
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(cam)

	var rec := HauntTextScript.new()
	rec.text = "REC  ●  CAM-04  17:59:00"
	rec.font_size = 14
	rec.amp = 0.0
	rec.align = HORIZONTAL_ALIGNMENT_RIGHT
	rec.base_color = Color(0.62, 0.88, 0.80)
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.offset_left = -300
	rec.offset_top = 90
	rec.offset_right = -24
	rec.offset_bottom = 114
	lobby.add_child(rec)
	var cam_lab := HauntTextScript.new()
	cam_lab.text = "内部监控  严禁外传"
	cam_lab.font_size = 12
	cam_lab.amp = 0.0
	cam_lab.align = HORIZONTAL_ALIGNMENT_RIGHT
	cam_lab.base_color = Color(0.64, 0.74, 0.78)
	cam_lab.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_lab.offset_left = -240
	cam_lab.offset_top = 112
	cam_lab.offset_right = -24
	cam_lab.offset_bottom = 132
	lobby.add_child(cam_lab)

	_build_home_page()
	_build_join_page()
	_build_char_page()
	haunt = LobbyHauntScript.new()
	lobby.add_child(haunt)
	haunt.bind({
		"lobby": lobby,
		"bg": bg,
		"hero": hero,
		"cam": cam,
		"dim": dim,
		"clock": home_page.get_node_or_null("HauntClock"),
		"punch": home_page.get_node_or_null("HauntPunch"),
		"title": home_page.get_node_or_null("HauntTitle"),
		"tag": home_page.get_node_or_null("HauntTag"),
		"mood": home_page.get_node_or_null("HauntMood"),
		"rec": rec,
		"lcd": home_page.get_node_or_null("HauntLcd"),
		"led": home_page.get_node_or_null("HauntLed"),
		"layers": lobby_layers,
		"actors": lobby_actors,
	})
	haunt.dress(lobby)
	_show_lobby_page("home")


func _lobby_layer(path: String, alpha: float) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = _lobby_tex(path)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.modulate = Color(1, 1, 1, alpha)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


func _make_lobby_actors() -> Array[Sprite2D]:
	var frames := [
		["res://assets/game/chars/horse/work_0.png", "res://assets/game/chars/horse/work_1.png", "res://assets/game/chars/horse/work_2.png", "res://assets/game/chars/horse/work_3.png"],
		["res://assets/game/chars/rabbit/work_0.png", "res://assets/game/chars/rabbit/work_1.png", "res://assets/game/chars/rabbit/work_2.png", "res://assets/game/chars/rabbit/work_3.png"],
		["res://assets/game/chars/cow/work_0.png", "res://assets/game/chars/cow/work_1.png", "res://assets/game/chars/cow/work_2.png", "res://assets/game/chars/cow/work_3.png"],
		["res://assets/game/chars/pelican/work_0.png", "res://assets/game/chars/pelican/work_1.png", "res://assets/game/chars/pelican/work_2.png", "res://assets/game/chars/pelican/work_3.png"],
		["res://assets/game/chars/tiger/idle_0.png", "res://assets/game/chars/tiger/idle_1.png", "res://assets/game/chars/tiger/idle_2.png", "res://assets/game/chars/tiger/idle_3.png"],
	]
	var at := [Vector2(700, 510), Vector2(890, 440), Vector2(1080, 525), Vector2(1200, 390), Vector2(1030, 250)]
	var out: Array[Sprite2D] = []
	for i in frames.size():
		var actor := Sprite2D.new()
		var actor_frames: Array[Texture2D] = []
		for path in frames[i]:
			actor_frames.append(_lobby_tex(path))
		actor.texture = actor_frames[0]
		actor.position = at[i]
		actor.scale = Vector2.ONE * (0.15 if i < 4 else 0.13)
		actor.modulate = Color(0.78, 0.88, 0.94, 0.78 if i < 4 else 0.0)
		actor.z_index = 2
		actor.set_meta("lobby_actor", i)
		actor.set_meta("lobby_frames", actor_frames)
		if i == 0:
			var scarf_frames: Array[Texture2D] = []
			for pose in ["work_0", "work_1", "work_2", "work_3"]:
				scarf_frames.append(_lobby_tex("res://assets/game/chars/horse/scarf/%s.png" % pose))
			var scarf := Sprite2D.new()
			scarf.name = "Scarf"
			scarf.texture = scarf_frames[0]
			scarf.modulate = Rules.scarf_color(Rules.CharSkin.HORSE)
			actor.add_child(scarf)
			actor.set_meta("lobby_scarf_frames", scarf_frames)
		out.append(actor)
	return out


func _build_home_page() -> void:
	home_page = Control.new()
	home_page.position = Vector2(36, 36)
	home_page.size = Vector2(460, 660)
	lobby.add_child(home_page)

	var clock := TextureRect.new()
	clock.name = "HauntClock"
	clock.texture = _lobby_tex("res://assets/game/ui/lobby/clock.png")
	clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clock.position = Vector2(0, 0)
	clock.size = Vector2(64, 64)
	clock.pivot_offset = Vector2(32, 32)
	home_page.add_child(clock)

	var punch := TextureRect.new()
	punch.name = "HauntPunch"
	punch.texture = _lobby_tex("res://assets/game/ui/lobby/punch.png")
	punch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	punch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	punch.position = Vector2(308, 72)
	punch.size = Vector2(148, 196)
	punch.pivot_offset = Vector2(74, 98)
	home_page.add_child(punch)
	var lcd_bg := ColorRect.new()
	lcd_bg.color = Color(0.04, 0.12, 0.08, 0.88)
	lcd_bg.position = Vector2(328, 118)
	lcd_bg.size = Vector2(108, 42)
	lcd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_page.add_child(lcd_bg)
	var tape := ColorRect.new()
	tape.color = Color(0.07, 0.12, 0.15, 0.88)
	tape.position = Vector2(322, 214)
	tape.size = Vector2(122, 22)
	tape.rotation = -0.04
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_page.add_child(tape)
	var tape_lab := HauntTextScript.new()
	tape_lab.text = "未授权离开"
	tape_lab.font_size = 11
	tape_lab.amp = 0.0
	tape_lab.position = Vector2(4, 2)
	tape_lab.size = Vector2(114, 18)
	tape_lab.base_color = Color(0.78, 0.72, 0.64)
	tape.add_child(tape_lab)
	var stamp := Panel.new()
	stamp.position = Vector2(392, 168)
	stamp.size = Vector2(58, 58)
	stamp.rotation = 0.28
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamp_sb := StyleBoxFlat.new()
	stamp_sb.bg_color = Color(0.12, 0.30, 0.32, 0.08)
	stamp_sb.border_color = Color(0.34, 0.70, 0.66, 0.75)
	stamp_sb.set_border_width_all(3)
	stamp_sb.set_corner_radius_all(29)
	stamp.add_theme_stylebox_override("panel", stamp_sb)
	home_page.add_child(stamp)
	var stamp_lab := HauntTextScript.new()
	stamp_lab.text = "不准\n离岗"
	stamp_lab.font_size = 12
	stamp_lab.amp = 0.0
	stamp_lab.wrap = true
	stamp_lab.align = HORIZONTAL_ALIGNMENT_CENTER
	stamp_lab.base_color = Color(0.48, 0.84, 0.76)
	stamp_lab.position = Vector2(4, 10)
	stamp_lab.size = Vector2(50, 40)
	stamp.add_child(stamp_lab)
	var led := ColorRect.new()
	led.name = "HauntLed"
	led.color = Color(0.46, 0.92, 0.72, 1)
	led.position = Vector2(430, 108)
	led.size = Vector2(10, 10)
	led.pivot_offset = Vector2(5, 5)
	led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_page.add_child(led)
	var lcd := HauntTextScript.new()
	lcd.name = "HauntLcd"
	lcd.text = "17:59"
	lcd.position = Vector2(328, 124)
	lcd.size = Vector2(108, 28)
	lcd.font_size = 16
	lcd.amp = 0.0
	lcd.align = HORIZONTAL_ALIGNMENT_CENTER
	lcd.base_color = Color(0.55, 0.95, 0.42)
	home_page.add_child(lcd)
	var over := HauntTextScript.new()
	over.text = "今日状态"
	over.position = Vector2(328, 88)
	over.size = Vector2(108, 22)
	over.font_size = 13
	over.amp = 0.0
	over.align = HORIZONTAL_ALIGNMENT_CENTER
	over.base_color = Color(0.9, 0.78, 0.7)
	home_page.add_child(over)

	var title := HauntTextScript.new()
	title.name = "HauntTitle"
	title.text = "六点下班"
	title.position = Vector2(72, 8)
	title.size = Vector2(240, 48)
	title.font_size = 40
	title.amp = 0.0
	title.chroma = 0.0
	title.base_color = Color(0.88, 0.94, 0.92)
	home_page.add_child(title)

	var tag := HauntTextScript.new()
	tag.name = "HauntTag"
	tag.text = "夜班办公系统  ·  18:00 后仍在运行"
	tag.position = Vector2(74, 54)
	tag.size = Vector2(230, 24)
	tag.font_size = 16
	tag.amp = 0.0
	tag.base_color = Color(0.48, 0.76, 0.76)
	home_page.add_child(tag)

	var mood := HauntTextScript.new()
	mood.name = "HauntMood"
	mood.text = "今晚的工位仍亮着灯。请完成打卡，再决定是否离开。"
	mood.position = Vector2(0, 96)
	mood.size = Vector2(300, 44)
	mood.font_size = 13
	mood.amp = 0.0
	mood.wrap = true
	mood.base_color = Color(0.72, 0.64, 0.56)
	home_page.add_child(mood)

	var paper := ColorRect.new()
	paper.color = Color(0.10, 0.16, 0.18, 0.94)
	paper.position = Vector2(0, 508)
	paper.size = Vector2(300, 96)
	paper.rotation = -0.045
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_page.add_child(paper)
	var head := ColorRect.new()
	head.color = Color(0.22, 0.52, 0.54, 1)
	head.position = Vector2(0, 0)
	head.size = Vector2(300, 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(head)
	var paper_lab := HauntTextScript.new()
	paper_lab.text = "某某单位办公室　〔夜〕字第6号\n关于严格执行六点下班的通知\n未打卡者视为自愿留下。请勿对视。"
	paper_lab.position = Vector2(10, 12)
	paper_lab.size = Vector2(280, 80)
	paper_lab.font_size = 13
	paper_lab.amp = 0.0
	paper_lab.wrap = true
	paper_lab.base_color = Color(0.96, 0.86, 0.76)
	paper.add_child(paper_lab)

	var poster := ColorRect.new()
	poster.color = Color(0.78, 0.72, 0.58, 0.92)
	poster.position = Vector2(318, 278)
	poster.size = Vector2(128, 86)
	poster.rotation = 0.06
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_page.add_child(poster)
	var poster_lab := HauntTextScript.new()
	poster_lab.text = "寻人启事\n工号 0006\n如见到请勿搭话"
	poster_lab.position = Vector2(8, 8)
	poster_lab.size = Vector2(112, 72)
	poster_lab.font_size = 12
	poster_lab.amp = 0.0
	poster_lab.wrap = true
	poster_lab.base_color = Color(0.22, 0.12, 0.1)
	poster.add_child(poster_lab)

	var start_btn := _lobby_btn("打卡上班", true)
	start_btn.position = Vector2(0, 148)
	start_btn.pressed.connect(_click_start)
	home_page.add_child(start_btn)

	var join_btn := _lobby_btn("接入监控", false)
	join_btn.position = Vector2(0, 212)
	join_btn.pressed.connect(func(): _show_lobby_page("join"))
	home_page.add_child(join_btn)

	var char_btn := _lobby_btn("身份核验", false)
	char_btn.position = Vector2(0, 276)
	char_btn.pressed.connect(func(): _show_lobby_page("char"))
	home_page.add_child(char_btn)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "工牌姓名 · 真名勿填"
	name_edit.text = "玩家"
	name_edit.position = Vector2(0, 344)
	name_edit.size = Vector2(300, 36)
	_style_field(name_edit)
	home_page.add_child(name_edit)

	short_check = CheckBox.new()
	short_check.text = "试用期 · 未满勤不得走"
	short_check.button_pressed = true
	short_check.position = Vector2(0, 392)
	short_check.add_theme_color_override("font_color", Color(0.78, 0.62, 0.54))
	home_page.add_child(short_check)

	status_label = Label.new()
	status_label.position = Vector2(0, 436)
	status_label.size = Vector2(300, 64)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.7, 0.58, 0.52))
	home_page.add_child(status_label)

	var hint := HauntTextScript.new()
	hint.text = "员工：小马 / 兔子 / 牛 / 鹈鹕 / 袋鼠 / 小狗    老板：老虎\n工时扣完才能打卡。未打卡，视为自愿加班。"
	hint.position = Vector2(0, 612)
	hint.size = Vector2(430, 48)
	hint.font_size = 12
	hint.amp = 1.5
	hint.wrap = true
	hint.base_color = Color(0.55, 0.46, 0.42)
	home_page.add_child(hint)


func _build_join_page() -> void:
	join_page = _panel(Rect2(300, 70, 680, 560), Color(0.07, 0.04, 0.04, 0.96))
	join_page.visible = false
	lobby.add_child(join_page)
	var t := HauntTextScript.new()
	t.name = "HauntH"
	t.text = "接入监控"
	t.position = Vector2(28, 20)
	t.size = Vector2(400, 36)
	t.font_size = 26
	t.amp = 3.0
	t.base_color = Color(0.92, 0.82, 0.72)
	join_page.add_child(t)
	var d := HauntTextScript.new()
	d.name = "HauntD"
	d.text = "连上 Go 服务端后，开自己的房间或输入房间码加入。"
	d.position = Vector2(28, 58)
	d.size = Vector2(620, 28)
	d.font_size = 15
	d.amp = 2.0
	d.base_color = Color(0.72, 0.58, 0.5)
	join_page.add_child(d)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "监控主机 IP"
	ip_edit.text = "127.0.0.1"
	ip_edit.position = Vector2(28, 96)
	ip_edit.size = Vector2(360, 40)
	_style_field(ip_edit)
	join_page.add_child(ip_edit)
	var join_btn := _lobby_btn("连接服务器", true)
	join_btn.position = Vector2(400, 92)
	join_btn.size = Vector2(240, 48)
	join_btn.pressed.connect(_join)
	join_page.add_child(join_btn)
	join_status = Label.new()
	join_status.position = Vector2(28, 140)
	join_status.size = Vector2(612, 28)
	join_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	join_status.add_theme_font_size_override("font_size", 15)
	join_status.add_theme_color_override("font_color", Color(0.82, 0.68, 0.58))
	join_status.text = "尚未连接服务端"
	join_page.add_child(join_status)
	var create_btn := _lobby_btn("开设房间", true)
	create_btn.position = Vector2(28, 176)
	create_btn.size = Vector2(240, 48)
	create_btn.pressed.connect(_create_go_room)
	join_page.add_child(create_btn)
	room_code_edit = LineEdit.new()
	room_code_edit.placeholder_text = "房间码"
	room_code_edit.position = Vector2(284, 180)
	room_code_edit.size = Vector2(160, 40)
	_style_field(room_code_edit)
	join_page.add_child(room_code_edit)
	var code_btn := _lobby_btn("加入", false)
	code_btn.position = Vector2(456, 176)
	code_btn.size = Vector2(184, 48)
	code_btn.pressed.connect(_join_go_room)
	join_page.add_child(code_btn)
	var list_lab := HauntTextScript.new()
	list_lab.text = "公开房间"
	list_lab.position = Vector2(28, 238)
	list_lab.size = Vector2(200, 24)
	list_lab.font_size = 16
	list_lab.amp = 1.0
	list_lab.base_color = Color(0.82, 0.7, 0.6)
	join_page.add_child(list_lab)
	var sc := ScrollContainer.new()
	sc.position = Vector2(28, 268)
	sc.size = Vector2(612, 196)
	join_page.add_child(sc)
	room_list_box = VBoxContainer.new()
	room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_list_box.add_theme_constant_override("separation", 6)
	sc.add_child(room_list_box)
	var back := _lobby_btn("返回", false)
	back.position = Vector2(28, 480)
	back.size = Vector2(140, 44)
	back.pressed.connect(func(): _show_lobby_page("home"))
	join_page.add_child(back)
	var refresh := _lobby_btn("刷新列表", false)
	refresh.position = Vector2(188, 480)
	refresh.size = Vector2(180, 44)
	refresh.pressed.connect(func(): Net.list_rooms())
	join_page.add_child(refresh)


func _build_char_page() -> void:
	char_page = _panel(Rect2(40, 40, 1200, 640), Color(0.07, 0.04, 0.04, 0.96))
	char_page.visible = false
	char_page.z_index = 24
	lobby.add_child(char_page)
	var t := HauntTextScript.new()
	t.name = "HauntH"
	t.text = "身份核验"
	t.position = Vector2(28, 18)
	t.size = Vector2(400, 36)
	t.font_size = 26
	t.amp = 3.0
	t.base_color = Color(0.92, 0.82, 0.72)
	char_page.add_child(t)
	var d := HauntTextScript.new()
	d.name = "HauntD"
	d.text = "点卡选自己；空位可加 Bot。测试房会把剩下空位补齐。"
	d.position = Vector2(28, 56)
	d.size = Vector2(900, 28)
	d.font_size = 15
	d.amp = 2.0
	d.base_color = Color(0.72, 0.58, 0.5)
	char_page.add_child(d)
	slot_box = Control.new()
	slot_box.position = Vector2(16, 88)
	slot_box.size = Vector2(1168, 420)
	slot_box.mouse_filter = Control.MOUSE_FILTER_PASS
	char_page.add_child(slot_box)
	var back := _lobby_btn("返回走廊", false)
	back.position = Vector2(16, 516)
	back.size = Vector2(180, 48)
	back.pressed.connect(func(): _show_lobby_page("home"))
	char_page.add_child(back)
	fill_bots_btn = _lobby_btn("空位全补 Bot", false)
	fill_bots_btn.position = Vector2(208, 516)
	fill_bots_btn.size = Vector2(220, 48)
	fill_bots_btn.pressed.connect(_fill_bots)
	char_page.add_child(fill_bots_btn)
	var enter := _lobby_btn("确认身份 · 打卡上班", true)
	enter.position = Vector2(860, 516)
	enter.pressed.connect(_confirm_start)
	char_page.add_child(enter)
	enter_char_btn = enter


func _show_lobby_page(page: String) -> void:
	if home_page:
		home_page.visible = page == "home"
	if join_page:
		join_page.visible = page == "join"
	if char_page:
		char_page.visible = page == "char"
		if page == "char":
			char_page.move_to_front()
	if join_page and page == "join":
		join_page.move_to_front()
	if page == "char":
		_refresh_lobby()


func _click_start() -> void:
	_show_lobby_page("char")


func _confirm_start() -> void:
	if Net.using_go:
		Net.claim(wanted_slot, name_edit.text)
		if Net.is_captain():
			Net.start_match(short_check.button_pressed)
		return
	if Net.connected and not Net.is_server:
		Match.claim_local(wanted_slot, name_edit.text)
		_show_lobby_page("home")
		return
	if Net.is_server:
		Match.start_local(short_check.button_pressed, false)
	else:
		_enter_test_room()


func _lobby_btn(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = ""
	b.size = Vector2(300, 52)
	b.clip_contents = false
	b.add_to_group("haunt_btn")
	b.set_meta("haunt_base", text)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 3
	sb.corner_radius_bottom_left = 11
	sb.border_width_left = 1
	sb.border_width_top = 2
	sb.border_width_right = 1
	sb.border_width_bottom = 3
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var hover := sb.duplicate() as StyleBoxFlat
	var cap_col := Color(0.82, 0.74, 0.66)
	if primary:
		sb.bg_color = Color(0.10, 0.34, 0.34, 0.94)
		sb.border_color = Color(0.38, 0.78, 0.70)
		hover.bg_color = Color(0.14, 0.46, 0.44, 0.96)
		hover.border_color = Color(0.62, 0.94, 0.82)
		cap_col = Color(0.90, 0.98, 0.94)
	else:
		sb.bg_color = Color(0.06, 0.12, 0.16, 0.92)
		sb.border_color = Color(0.20, 0.44, 0.50)
		hover.bg_color = Color(0.09, 0.20, 0.24, 0.96)
		hover.border_color = Color(0.42, 0.72, 0.74)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	var cap := HauntTextScript.new()
	cap.name = "HauntCap"
	cap.text = text
	cap.font_size = 18
	cap.amp = 0.0
	cap.chroma = 0.0
	cap.align = HORIZONTAL_ALIGNMENT_CENTER
	cap.base_color = cap_col
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(cap)
	return b


func _style_field(e: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.94)
	sb.border_color = Color(0.46, 0.16, 0.12)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 1
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 2
	sb.corner_radius_bottom_left = 7
	sb.content_margin_left = 10
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	e.add_theme_color_override("font_color", Color(0.62, 0.86, 0.48))
	e.add_theme_color_override("font_placeholder_color", Color(0.48, 0.38, 0.34))
	e.add_theme_color_override("caret_color", Color(0.82, 0.2, 0.16))


func _lobby_tex(path: String) -> Texture2D:
	if path == "":
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded
	return null


func _portrait_rect(tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = pos
	pic.size = size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


func _add_slot_portrait(card: Control, slot: int, rect: Rect2) -> void:
	var pack := _char_pack(slot)
	var skin: int = int(Rules.SKIN_FOR_SLOT.get(slot, Rules.CharSkin.HORSE))
	var plate := ColorRect.new()
	plate.color = Color(0.91, 0.87, 0.78)
	plate.position = rect.position
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plate)
	var body := _portrait_rect(_lobby_tex("res://assets/game/chars/%s/idle_0.png" % pack), rect.position, rect.size)
	var scarf_tex := _lobby_tex("res://assets/game/chars/%s/scarf/idle_0.png" % pack)
	if pack == "horse":
		var body_mat := ShaderMaterial.new()
		body_mat.shader = BODY_SHADER
		body_mat.set_shader_parameter("body_color", Rules.body_color(skin))
		body.material = body_mat
	elif scarf_tex == null:
		var haunt := ShaderMaterial.new()
		haunt.shader = preload("res://src/ui/lobby_haunt.gdshader")
		body.material = haunt
	card.add_child(body)
	if scarf_tex != null:
		var scarf := _portrait_rect(scarf_tex, rect.position, rect.size)
		scarf.modulate = Rules.scarf_color(skin)
		card.add_child(scarf)


func _char_pack(slot: int) -> String:
	match slot:
		Rules.Slot.BOSS:
			return "tiger"
		Rules.Slot.EMP_B:
			return "rabbit"
		Rules.Slot.EMP_C:
			return "cow"
		Rules.Slot.EMP_D:
			return "pelican"
		Rules.Slot.EMP_E:
			return "kangaroo"
		Rules.Slot.EMP_F:
			return "dog"
		_:
			return "horse"


func _panel(rect: Rect2, color: Color) -> ColorRect:
	var p := ColorRect.new()
	p.color = color
	p.position = rect.position
	p.size = rect.size
	return p


func _build_monitors() -> void:
	var nicks := ["马", "兔", "牛", "鹈", "袋", "狗"]
	for i in 6:
		var box := ColorRect.new()
		box.color = Color(0.08, 0.09, 0.10, 0.88)
		box.custom_minimum_size = Vector2(36, 28)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamps.add_child(box)
		mate_box.append(box)
		var snow := ColorRect.new()
		snow.color = Color(0.7, 0.72, 0.74, 0.0)
		snow.set_anchors_preset(Control.PRESET_FULL_RECT)
		snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(snow)
		mate_snow.append(snow)
		var lab := Label.new()
		lab.text = nicks[i] if i < nicks.size() else "?"
		lab.position = Vector2(4, 6)
		lab.size = Vector2(28, 16)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 10)
		lab.add_theme_color_override("font_color", Color(0.78, 0.82, 0.84))
		box.add_child(lab)
		mate_lab.append(lab)


func _style_watch_meter(m) -> void:
	if m.cap:
		m.cap.add_theme_color_override("font_color", Color(0.70, 0.78, 0.82))
	if m.num:
		m.num.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	if m.track:
		m.track.color = Color(0.18, 0.22, 0.24, 0.85)


func _bar(parent: Control, pos: Vector2, fill: Color, size := Vector2(118, 8)) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.max_value = 100
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.9, 0.9, 0.91, 0.95)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b


func _btn(text: String, pos: Vector2, cb: Callable, size := Vector2(120, 32)) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.pressed.connect(cb)
	lobby.add_child(b)


func _host() -> void:
	if not Net.is_server:
		if Net.connected:
			Net.leave()
		if Net.host_listen() != OK:
			status_label.text = Net.last_error
			_show_lobby_page("home")
			return
	Match.claim_local(wanted_slot, name_edit.text)
	_show_lobby_page("home")
	_refresh_lobby()


func _set_join_status(text: String, ok: bool = false) -> void:
	if join_status == null:
		return
	join_status.text = text
	join_status.add_theme_color_override("font_color", Color(0.62, 0.92, 0.72) if ok else Color(0.92, 0.62, 0.52))


func _join() -> void:
	if Net.connect_go(ip_edit.text) != OK:
		_set_join_status(Net.last_error)
		return
	_set_join_status(Net.last_error)
	_refresh_room_list()


func _create_go_room() -> void:
	if not Net.using_go or not Net.connected:
		_set_join_status("先连接服务器")
		return
	Net.create_room()


func _join_go_room() -> void:
	if not Net.using_go or not Net.connected:
		_set_join_status("先连接服务器")
		return
	Net.join_room(room_code_edit.text)


func _on_room_ready() -> void:
	_show_lobby_page("char")
	_refresh_lobby()


func _on_go_error() -> void:
	_set_join_status(Net.last_error)


func _refresh_room_list() -> void:
	if room_list_box == null:
		return
	for c in room_list_box.get_children():
		c.queue_free()
	for item in Net.rooms:
		var code := str(item.get("code", ""))
		var phase := str(item.get("phase", "lobby"))
		var n := int(item.get("players", 0))
		var label := "%s  ·  %d人  ·  %s" % [code, n, "进行中" if phase != "lobby" else "大厅"]
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(580, 36)
		b.disabled = phase != "lobby"
		var captured := code
		b.pressed.connect(func():
			room_code_edit.text = captured
			Net.join_room(captured)
		)
		room_list_box.add_child(b)


func _enter_test_room() -> void:
	if Net.is_dedicated:
		return
	if Match.phase != "lobby":
		Match.back_to_lobby()
		await get_tree().process_frame
	if not Net.is_server:
		if Net.connected:
			Net.leave()
		if Net.host_listen() != OK:
			status_label.text = Net.last_error
			return
	Match.claim_local(wanted_slot, name_edit.text)
	Match.fill_empty_bots_local()
	Match.start_local(true, true)


func _pick_slot(slot: int) -> void:
	wanted_slot = slot
	if Net.using_go:
		Net.claim(slot, name_edit.text)
	elif Net.is_server or Net.connected:
		Match.claim_local(slot, name_edit.text)
	call_deferred("_rebuild_slot_cards")


func _can_assign_bot() -> bool:
	if Net.using_go:
		return Net.connected and Net.room_code != ""
	return true


func _set_slot_bot(slot: int, on: bool) -> void:
	if Net.using_go:
		if not _can_assign_bot():
			return
		Net.set_bot(slot, on)
		return
	Match.set_bot_local(slot, on)
	_refresh_lobby()


func _fill_bots() -> void:
	if Net.using_go:
		if not _can_assign_bot():
			_set_join_status("先进入房间")
			return
		Net.fill_bots()
		return
	Match.fill_empty_bots_local()
	_refresh_lobby()


func _refresh_lobby() -> void:
	if Match == null:
		return
	var returning := lobby != null and not lobby.visible
	if Match.phase == "lobby":
		lobby.visible = not Net.is_dedicated
		if hud:
			hud.visible = false
		if result_panel:
			result_panel.visible = false
		if exit_btn:
			exit_btn.visible = false
		if returning:
			_show_lobby_page("home")
	if Net.using_go:
		if Net.room_code != "":
			var role := "主管" if Net.is_captain() else "到岗"
			var room_txt := "房间 %s · 你是%s\n选身份后，主管点打卡开局" % [Net.room_code, role]
			status_label.text = room_txt
			_set_join_status("已进房 %s（%s）" % [Net.room_code, role], true)
		elif Net.connected:
			status_label.text = "已接入。开设房间或输入房间码。"
			_set_join_status("已连接  #%d。可以开设房间或输入房间码。" % Net.go_peer_id, true)
		else:
			var pending := Net.last_error if Net.last_error != "" else "正在连接服务端…"
			status_label.text = pending
			_set_join_status(pending)
	elif Net.is_server:
		status_label.text = "单位已开  127.0.0.1:%d\n核验身份后，点「打卡上班」" % Net.listen_port
	elif Net.connected:
		status_label.text = "已接入监控。核验身份，等主管开局。"
	else:
		status_label.text = "打卡上班：先选员工或 Boss，再进入测试房。空位由 Bot 补齐。"
		if Net.last_error != "":
			_set_join_status(Net.last_error)
		else:
			_set_join_status("尚未连接服务端")
	if enter_char_btn:
		var cap = enter_char_btn.get_node_or_null("HauntCap")
		if Net.using_go and Net.is_captain():
			enter_char_btn.set_meta("haunt_base", "确认身份 · 打卡开局")
			if cap:
				cap.text = "确认身份 · 打卡开局"
		elif Net.using_go:
			enter_char_btn.set_meta("haunt_base", "确认占位 · 等主管开局")
			if cap:
				cap.text = "确认占位 · 等主管开局"
	if fill_bots_btn:
		fill_bots_btn.visible = _can_assign_bot()
	_rebuild_slot_cards()


func _rebuild_slot_cards() -> void:
	if slot_box == null:
		return
	for c in slot_box.get_children():
		slot_box.remove_child(c)
		c.free()
	var picks: Array[int] = [Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D, Rules.Slot.EMP_E, Rules.Slot.EMP_F, Rules.Slot.BOSS]
	var n := picks.size()
	var w := 152.0
	var h := 300.0
	var gap := 10.0
	var total := float(n) * w + float(n - 1) * gap
	var x0 := maxf(0.0, (slot_box.size.x - total) * 0.5)
	for i in n:
		var s: int = picks[i]
		var pid := int(Match.slots.get(s, -1))
		var who := "缺编"
		if pid == 0:
			who = "编外"
		elif pid > 0:
			who = str(Match.names.get(pid, "工号%d" % pid))
		var x := x0 + float(i) * (w + gap)
		var card := Button.new()
		card.position = Vector2(x, 0)
		card.size = Vector2(w, h)
		card.toggle_mode = true
		card.button_pressed = s == wanted_slot
		card.clip_contents = false
		var pick := s
		card.pressed.connect(func(): _pick_slot(pick))
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 16
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 12
		sb.bg_color = Color(0.12, 0.08, 0.08, 0.96) if s != wanted_slot else Color(0.28, 0.08, 0.08, 0.96)
		sb.border_width_bottom = 4
		sb.border_width_left = 1
		sb.border_color = Color(0.72, 0.16, 0.12) if s == wanted_slot else Color(0.28, 0.16, 0.14)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", sb)
		card.add_theme_stylebox_override("pressed", sb)
		_add_slot_portrait(card, s, Rect2(16, 8, 120, 168))
		var nm := HauntTextScript.new()
		nm.text = str(Rules.SLOT_NAMES.get(s, "工位"))
		nm.position = Vector2(4, 180)
		nm.size = Vector2(w - 8.0, 26)
		nm.font_size = 14
		nm.amp = 2.4
		nm.align = HORIZONTAL_ALIGNMENT_CENTER
		nm.base_color = Color(0.94, 0.86, 0.78)
		card.add_child(nm)
		var st := HauntTextScript.new()
		st.text = who if s != Rules.Slot.BOSS else (who + " · 请勿对视")
		st.position = Vector2(4, 208)
		st.size = Vector2(w - 8.0, 44)
		st.font_size = 11
		st.amp = 2.0
		st.wrap = true
		st.align = HORIZONTAL_ALIGNMENT_CENTER
		st.base_color = Color(0.78, 0.32, 0.26) if s == Rules.Slot.BOSS else Color(0.7, 0.58, 0.52)
		card.add_child(st)
		slot_box.add_child(card)
		if _can_assign_bot() and pid <= 0:
			var bot_on := pid == 0
			var bot_btn := Button.new()
			bot_btn.text = "移出 Bot" if bot_on else "加 Bot"
			bot_btn.position = Vector2(x, h + 8.0)
			bot_btn.size = Vector2(w, 32)
			bot_btn.pressed.connect(func(): _set_slot_bot(pick, not bot_on))
			slot_box.add_child(bot_btn)


func _on_started() -> void:
	lobby.visible = false
	hud.visible = true
	result_panel.visible = false
	exit_btn.visible = true
	_catch_t = 0.0
	_banner_t = 0.0
	_shake = 0.0
	_boss_seen = false
	_cam_punch = 0.0
	_help_t = 10.0
	_last_state = -1
	if catch_banner:
		catch_banner.visible = false
	_refresh_hud()
	var actor := _local_actor()
	if actor != null:
		var goal := _camera_goal(actor)
		camera.position = goal["pos"]
		_cam_z = goal["zoom"]
		camera.zoom = Vector2(_cam_z, _cam_z)


func _on_ended() -> void:
	hud.visible = true
	result_panel.visible = true
	exit_btn.visible = true
	var r: Dictionary = Match.result
	var my := Match.my_slot()
	var you := "你：—"
	if my == Rules.Slot.BOSS:
		you = "你：%s（老板）" % r.get("boss", "")
	elif my >= Rules.Slot.EMP_A:
		for p in r.get("people", []):
			if int(p["slot"]) == my:
				you = "你：%s" % ("胜" if p["win"] else "负")
	you_label.text = you
	boss_label.text = "老板：%s    下班 %d 人" % [r.get("boss", ""), r.get("punched", 0)]
	var lines := PackedStringArray()
	for p in r.get("people", []):
		var t := "未打卡"
		if float(p["time"]) >= 0.0:
			t = "打卡 %s" % _fmt(float(p["time"]))
		lines.append("%s  %s  %s" % [p["name"], "胜" if p["win"] else "负", t])
	log_label.text = "\n".join(lines)


func _on_kpi() -> void:
	kpi_label.visible = true
	if kpi_fx:
		kpi_fx.visible = true
	_shake = maxf(_shake, 0.22)
	_cam_punch = maxf(_cam_punch, 0.35)
	get_tree().create_timer(1.8).timeout.connect(func():
		kpi_label.visible = false
		if kpi_fx:
			kpi_fx.visible = false
	)


func _flash_banner(text: String, color: Color, hold: float = 1.1) -> void:
	catch_banner.text = text
	catch_banner.add_theme_color_override("font_color", color)
	catch_banner.visible = true
	_banner_t = hold


func _on_talked(slot: int) -> void:
	var my := Match.my_slot()
	var who := _slot_nick(slot)
	var vic: Actor = Match.actors.get(slot) as Actor
	if vic:
		vic.say(Rules.talk_quip(slot), 1.8)
	if my == slot:
		_catch_t = 0.45
		_shake = 0.28
		_cam_punch = 0.4
		catch_veil.color = Color(0.7, 0.04, 0.04, 0.22)
	elif my == Rules.Slot.BOSS:
		_shake = 0.12
		_cam_punch = 0.22
	elif not _same_view_as(vic):
		var where := office.room_title(vic.global_position) if vic and office else ""
		_flash_banner("%s 被约谈 · %s" % [who, where], Color(0.72, 0.28, 0.18), 1.3)


func _on_rescued(slot: int, by_slot: int) -> void:
	var my := Match.my_slot()
	var who := _slot_nick(slot)
	var helper := _slot_nick(by_slot)
	var vic: Actor = Match.actors.get(slot) as Actor
	var sav: Actor = Match.actors.get(by_slot) as Actor
	if vic:
		vic.say("润了", 1.4)
	if sav:
		sav.say("走！", 1.2)
	if my == slot:
		_catch_t = 0.15
		_shake = 0.12
		_cam_punch = 0.28
	elif my == by_slot:
		_cam_punch = 0.22
	elif my == Rules.Slot.BOSS:
		_shake = 0.12
		if not _same_view_as(vic):
			_flash_banner("人被同事捞走了", Color(0.55, 0.22, 0.18), 1.0)
	elif not _same_view_as(vic):
		_flash_banner("%s 把 %s 捞走了" % [helper, who], Color(0.22, 0.52, 0.36), 1.0)


func _on_stock(slot: int, pnl: float, energy_loss: float, boosted: bool) -> void:
	var who := _slot_nick(slot)
	if boosted:
		_flash_banner("%s 持股进账 · 精力+1  全员加速（%+.0f）" % [who, pnl], Color(0.28, 0.82, 0.42), 1.7)
		_cam_punch = maxf(_cam_punch, 0.22)
		return
	if Match.my_slot() != slot:
		return
	if pnl < -Rules.STOCK_WIN:
		_flash_banner("亏了  精力还在  %+0.1f" % pnl, Color(0.78, 0.62, 0.42), 1.1)
	else:
		_flash_banner("平盘  %+0.1f" % pnl, Color(0.70, 0.72, 0.74), 0.9)


func _on_caught(slot: int, _repeat: bool, add_hours: float) -> void:
	var my := Match.my_slot()
	var vic: Actor = Match.actors.get(slot) as Actor
	if vic:
		vic.say("这单废了", 1.5)
	if my == slot:
		_catch_t = 0.8
		_shake = 0.4
		_cam_punch = 0.4
		catch_veil.color = Color(0.7, 0.04, 0.04, 0.32)
	elif my == Rules.Slot.BOSS:
		_shake = 0.16
		_cam_punch = 0.2
	elif not _same_view_as(vic):
		_flash_banner("%s 复盘完了" % _slot_nick(slot), Color(0.72, 0.22, 0.18), 1.0)


func _same_view_as(other: Actor) -> bool:
	var me := _local_actor()
	if me == null or other == null or office == null:
		return false
	return office.same_view(me.global_position, other.global_position)


func _slot_nick(slot: int) -> String:
	var nicks := ["小马", "兔子", "牛", "鹈鹕", "袋鼠", "小狗"]
	if Rules.slot_is_employee(slot):
		return nicks[Rules.employee_index(slot)]
	return "老板"


func _refresh_hud() -> void:
	if not hud.visible:
		return
	var clock := Rules.office_clock_text(Match.day_progress())
	if Match.phase == "countdown":
		time_label.text = "17:50"
		watch_label.text = "即将开始  %d" % ceili(Match.countdown)
	else:
		time_label.text = clock
		watch_label.text = "还有 %s" % _fmt(Match.time_left)
	var actor := _local_actor()
	you_role.text = "工牌 · 旁观"
	hours_bar.visible = false
	energy_bar.visible = false
	if actor != null and actor.kind == Rules.Kind.EMPLOYEE:
		you_role.text = "工牌 · %s" % Rules.SLOT_NAMES.get(actor.slot, "员工")
		hours_bar.visible = true
		energy_bar.visible = true
		hours_bar.set_cells(actor.tasks_done, actor.task_progress if actor.tasking else 0.0, Rules.task_name(actor.tasks_done) if actor.tasks_done < Rules.TASK_COUNT else "可打卡")
		var en_extra := "%d 格" % actor.energy_cells
		if actor.energy_cells < Rules.ENERGY_CELLS and actor.energy_charge > 0.04:
			en_extra = "回血 %.0f%%" % (actor.energy_charge * 100.0)
		energy_bar.set_cells(actor.energy_cells, actor.energy_charge, en_extra)
		var st := str(Rules.STATE_NAMES.get(actor.emp_state, ""))
		if actor.emp_state == Rules.EmpState.TALK:
			st = "约谈中 · 督导中" if Match.is_watched(actor) else "约谈中 · 可捞"
		if actor.slow_left > 0.05:
			st += "  被周报压住 %.0fs" % actor.slow_left
		if actor.dash_cd > 0.05:
			st += "  冲刺 %.0fs" % actor.dash_cd
		else:
			st += "  冲刺就绪"
		state_label.text = st
		if actor.emp_state == Rules.EmpState.TALK:
			hint_label.text = "约谈中 · 等同事捞人    老板在这间屋就捞不走"
		elif actor.emp_state == Rules.EmpState.TRADE:
			hint_label.text = "赚了 +1 精力、开工加速、全员加速    亏了不扣    页面发红就是老板近了    F 买/卖    E 撤"
		elif actor.emp_state == Rules.EmpState.WORK or actor.emp_state == Rules.EmpState.SLACK:
			if actor.tasking:
				hint_label.text = "正在写「%s」  WASD 会作废当前格    F 摸鱼无效" % Rules.task_name(actor.tasks_done)
			elif actor.energy_cells <= 0:
				hint_label.text = "没精力无法开工    F 摸鱼慢慢回    或去茶水间/抽屉/零食柜卡点续命"
			else:
				hint_label.text = "E 确认开工「%s」    F 摸鱼    WASD 起身" % Rules.task_name(actor.tasks_done)
		elif actor.play_kind != "":
			hint_label.text = "F 卡点 / 拆包装    E 放弃    老板靠近会被约谈"
		elif actor.skin == Rules.CharSkin.KANGAROO:
			hint_label.text = "先找精力再开工    F 骑车 / 下车    下车后才能交互    E 坐下后还要再确认开工    Shift 冲刺"
		else:
			hint_label.text = "先找精力：茶水间手冲、饮水机、零食、翻抽屉    E 坐下后还要再确认开工    Shift 冲刺"
	elif actor != null and actor.kind == Rules.Kind.BOSS:
		you_role.text = "工牌 · 老板"
		state_label.text = "开会 %.0fs  KPI %.0fs  冲刺 %.0fs  周报 %.0fs  扇形 %.0fs" % [actor.meeting_cd, actor.kpi_cd, actor.dash_cd, actor.report_cd, actor.fan_cd]
		hint_label.text = "E 约谈 / 开门    F 扔周报    G 扇形周报    Q 开会    R KPI    Shift 冲刺"
	hint_label.modulate.a = clampf(_help_t / 2.0, 0.0, 1.0)
	_refresh_lamps()


func _refresh_lamps() -> void:
	var me := _local_actor()
	var nicks := ["马", "兔", "牛", "鹈", "袋", "狗"]
	for i in mate_box.size():
		var slot := Rules.Slot.EMP_A + i
		var box := mate_box[i]
		var lab := mate_lab[i]
		var snow := mate_snow[i]
		var c := Color(0.10, 0.11, 0.12, 0.9)
		var snow_a := 0.0
		lab.text = nicks[i] if i < nicks.size() else "?"
		if Match.actors.has(slot):
			var e: Actor = Match.actors[slot]
			var seen := me != null and office != null and office.same_view(me.global_position, e.global_position)
			if e.emp_state == Rules.EmpState.LEFT:
				c = Color(0.16, 0.28, 0.18, 0.9)
				lab.text = "下班"
			elif not seen:
				c = Color(0.08, 0.08, 0.09, 0.92)
				snow_a = 0.22
				lab.text = "—"
			elif e.emp_state == Rules.EmpState.TALK:
				c = Color(0.32, 0.08, 0.08, 0.95)
				snow_a = 0.18
				lab.text = "救命"
			elif e.emp_state == Rules.EmpState.SLACK:
				c = Color(0.28, 0.20, 0.08, 0.9)
			elif e.emp_state == Rules.EmpState.TRADE:
				c = Color(0.28, 0.22, 0.08, 0.95)
				lab.text = "盘中"
			elif e.emp_state == Rules.EmpState.WORK:
				c = Color(0.10, 0.22, 0.14, 0.9)
			else:
				c = Color(0.12, 0.14, 0.16, 0.9)
		box.color = c
		snow.color = Color(0.78, 0.80, 0.82, snow_a)


func _local_actor() -> Actor:
	if Match == null:
		return null
	var my := Match.my_slot()
	if my < 0:
		return null
	return Match.actors.get(my) as Actor


func _leave_room() -> void:
	if Net.using_go:
		Net.leave_room()
		Match.go_clear_to_lobby()
		_show_lobby_page("join")
		return
	Match.back_to_lobby()


func _result_back() -> void:
	if Net.using_go:
		if Net.is_captain():
			Net.reset_match()
		else:
			_leave_room()
		return
	Match.back_to_lobby()


func _process(delta: float) -> void:
	_edge_keys()
	_update_camera(delta)
	var actor := _local_actor()
	if stock_desk:
		var threat := Match.trade_threat(actor) if actor != null and actor.emp_state == Rules.EmpState.TRADE else 0.0
		stock_desk.bind(actor, threat)
	if energy_play:
		energy_play.bind(actor)
	if actor == null or not Match.playing:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Net.using_go:
		_go_input_t += delta
		var pulsed := _pulse_interact or _pulse_slack or _pulse_meeting or _pulse_kpi or _pulse_dash or _pulse_report or _pulse_fan
		if pulsed or _go_input_t >= 0.05:
			_go_input_t = 0.0
			Net.send_input(dir.x, dir.y, _pulse_interact, _pulse_slack, _pulse_meeting, _pulse_kpi, _pulse_dash)
	elif Net.is_enet_server():
		actor.apply_input(dir.x, dir.y, _pulse_interact, _pulse_slack, _pulse_meeting, _pulse_kpi, _pulse_dash, _pulse_report, _pulse_fan)
	else:
		actor.recv_input.rpc_id(1, dir.x, dir.y, _pulse_interact, _pulse_slack, _pulse_meeting, _pulse_kpi, _pulse_dash, _pulse_report, _pulse_fan)
	_pulse_interact = false
	_pulse_slack = false
	_pulse_meeting = false
	_pulse_kpi = false
	_pulse_dash = false
	_pulse_report = false
	_pulse_fan = false


func _update_camera(delta: float) -> void:
	if camera == null or DisplayServer.get_name() == "headless" or office == null:
		return
	_breath_t += delta
	_help_t = maxf(0.0, _help_t - delta)
	_cam_punch = maxf(0.0, _cam_punch - delta)
	var actor := _local_actor()
	if actor != null and actor.emp_state != _last_state:
		if actor.emp_state == Rules.EmpState.CLOCKING or actor.emp_state == Rules.EmpState.TALK or actor.emp_state == Rules.EmpState.LEFT:
			_cam_punch = maxf(_cam_punch, 0.38)
		_last_state = actor.emp_state
	var goal := _camera_goal(actor)
	var target: Vector2 = goal["pos"]
	var target_z: float = goal["zoom"]
	var punch := smoothstep(0.0, 0.38, _cam_punch) * 0.10
	target_z *= 1.0 + punch
	var breath := Vector2(sin(_breath_t * 0.7) * 3.2, cos(_breath_t * 0.55) * 2.2)
	target += breath
	var veil_a := 0.0
	var warn := ""
	var threat := 0.0
	if actor != null and Match.playing and actor.kind == Rules.Kind.EMPLOYEE:
		threat = office.threat_for(actor)
		var boss: Actor = Match.actors.get(Rules.Slot.BOSS) as Actor
		var here := boss != null and office.same_view(actor.global_position, boss.global_position)
		if here:
			veil_a = 0.20
			warn = "老板在这间屋 · 收敛点"
			target_z *= 1.06
			if not _boss_seen:
				_shake = maxf(_shake, 0.26)
				_cam_punch = maxf(_cam_punch, 0.32)
				_boss_seen = true
		else:
			_boss_seen = false
			if threat > 0.58:
				warn = "走廊有脚步 · 别浪"
				veil_a = 0.10 * threat
				target_z *= 1.0 + threat * 0.04
			elif threat > 0.32:
				warn = "督导在附近"
				veil_a = 0.05 * threat
		if actor.emp_state == Rules.EmpState.TRADE:
			warn = ""
			veil_a = 0.0
		elif actor.emp_state == Rules.EmpState.TALK:
			veil_a = maxf(veil_a, 0.16)
			if warn == "":
				warn = "约谈中 · 对齐颗粒度"
		if _catch_t > 0.0:
			veil_a = 0.32
			threat = 1.0
		if threat > 0.35:
			var beat := pow(absf(sin(_breath_t * (4.6 + threat * 5.5))), 8.0)
			target += Vector2(0, -beat * (3.0 + threat * 7.0))
			target_z *= 1.0 + beat * 0.018 * threat
			_shake = maxf(_shake, beat * 0.08 * threat)
	_catch_t = maxf(0.0, _catch_t - delta)
	_banner_t = maxf(0.0, _banner_t - delta)
	_shake = maxf(0.0, _shake - delta)
	if _banner_t <= 0.0 and catch_banner != null:
		catch_banner.visible = false
	if room_warn:
		room_warn.text = warn
		room_warn.modulate.a = (0.55 + 0.45 * absf(sin(_breath_t * 2.4))) if warn != "" else 0.0
	if rec_label:
		var emp := actor != null and actor.kind == Rules.Kind.EMPLOYEE and Match.playing
		rec_label.visible = emp
		var rec_on := threat > 0.35 and int(_breath_t * 3.2) % 2 == 0
		var rec_a := 0.95 if rec_on else (0.28 if emp else 0.0)
		rec_label.add_theme_color_override("font_color", Color(0.92, 0.16, 0.14, rec_a))
	if cam_id_label:
		var emp_cam := actor != null and actor.kind == Rules.Kind.EMPLOYEE and Match.playing
		cam_id_label.visible = emp_cam
		if office and actor and emp_cam:
			cam_id_label.text = "CAM %02d" % office.room_id(actor.global_position)
	if fear_fx:
		var show_fear := actor != null and actor.kind == Rules.Kind.EMPLOYEE and Match.playing
		fear_fx.visible = show_fear
		var mat := fear_fx.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("threat", threat)
			mat.set_shader_parameter("vignette", 0.42 + threat * 0.32)
			mat.set_shader_parameter("grain", 0.20 + threat * 0.24)
			mat.set_shader_parameter("scan", 0.14 + threat * 0.10)
	if catch_veil:
		var c := catch_veil.color
		c.a = lerpf(c.a, veil_a, 1.0 - exp(-8.0 * delta))
		catch_veil.color = c
	for i in mate_snow.size():
		var snow := mate_snow[i]
		if snow.color.a > 0.04:
			snow.color.a = 0.10 + 0.16 * absf(sin(_breath_t * 12.0 + float(i) * 1.7))
	if mate_box.size() >= 5:
		for i in mate_box.size():
			var slot := Rules.Slot.EMP_A + i
			var e: Actor = Match.actors.get(slot) as Actor
			if e != null and e.emp_state == Rules.EmpState.TALK:
				var pulse := 0.75 + 0.25 * absf(sin(_breath_t * 6.0))
				mate_box[i].modulate = Color(pulse, 0.55, 0.55)
			else:
				mate_box[i].modulate = Color.WHITE
	_cam_z = lerpf(_cam_z, target_z, 1.0 - exp(-5.0 * delta))
	camera.zoom = Vector2(_cam_z, _cam_z)
	var shake_off := Vector2.ZERO
	if _shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 10.0
	camera.position = camera.position.lerp(target, 1.0 - exp(-6.0 * delta)) + shake_off


func _camera_goal(actor: Actor) -> Dictionary:
	if actor == null:
		return {"pos": OfficeMap.DESK_RECT.get_center(), "zoom": _frame_room(OfficeMap.DESK_RECT).x}
	var rect: Rect2 = office.view_rect_at(actor.global_position)
	var z := _frame_room(rect).x
	var center: Vector2 = rect.get_center()
	var bias: Vector2 = actor.global_position - center
	bias.x = clampf(bias.x * 0.22, -rect.size.x * 0.16, rect.size.x * 0.16)
	bias.y = clampf(bias.y * 0.22, -rect.size.y * 0.16, rect.size.y * 0.16)
	return {"pos": center + bias, "zoom": z}


func _edge_keys() -> void:
	var e := Input.is_physical_key_pressed(KEY_E)
	var f := Input.is_physical_key_pressed(KEY_F)
	var q := Input.is_physical_key_pressed(KEY_Q)
	var r := Input.is_physical_key_pressed(KEY_R)
	var sh := Input.is_physical_key_pressed(KEY_SHIFT)
	var g := Input.is_physical_key_pressed(KEY_G)
	var esc := Input.is_physical_key_pressed(KEY_ESCAPE)
	var actor := _local_actor()
	var boss := actor != null and actor.kind == Rules.Kind.BOSS
	if e and not _e_down:
		_pulse_interact = true
	if f and not _f_down:
		if boss:
			_pulse_report = true
		else:
			_pulse_slack = true
	if g and not _g_down and boss:
		_pulse_fan = true
	if q and not _q_down:
		_pulse_meeting = true
	if r and not _r_down:
		_pulse_kpi = true
	if sh and not _shift_down:
		_pulse_dash = true
	if esc and not _esc_down and Match.phase != "lobby":
		_leave_room()
	_e_down = e
	_f_down = f
	_q_down = q
	_r_down = r
	_shift_down = sh
	_g_down = g
	_esc_down = esc


func _fmt(sec: float) -> String:
	var s := int(max(sec, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
