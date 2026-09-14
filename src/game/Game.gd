extends Node2D

const MeterScript := preload("res://src/ui/Meter.gd")

var office: OfficeMap
var camera: Camera2D
var ui: CanvasLayer
var lobby: Control
var hud: Control
var result_panel: Control
var kpi_label: Label
var status_label: Label
var slot_box: HBoxContainer
var name_edit: LineEdit
var ip_edit: LineEdit
var short_check: CheckBox
var hint_label: Label
var hours_bar
var energy_bar
var hours_num: Label
var energy_num: Label
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
var watch_label: Label
var home_page: Control
var join_page: Control
var char_page: Control

var wanted_slot := Rules.Slot.EMP_A
var _pulse_interact := false
var _pulse_slack := false
var _pulse_meeting := false
var _pulse_kpi := false
var _pulse_dash := false
var _e_down := false
var _f_down := false
var _q_down := false
var _r_down := false
var _shift_down := false
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


func _ready() -> void:
	var dedicated := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--server" or arg == "--dedicated":
			dedicated = true
	if dedicated:
		var err := Net.host_dedicated()
		if err != OK:
			push_error(Net.last_error)
			get_tree().quit(1)
			return
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
	Net.status_changed.connect(_refresh_lobby)
	Net.peer_list_changed.connect(_refresh_lobby)
	if Net.is_dedicated:
		lobby.visible = false
		status_label.text = "专用服 %d · 等客户端加入后点开始" % Net.listen_port
	_refresh_lobby()
	print("[Game] ready dedicated=%s port=%d" % [Net.is_dedicated, Net.listen_port])
	if not Net.is_dedicated:
		for arg in OS.get_cmdline_user_args():
			if arg == "--test":
				_enter_test_room.call_deferred()
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
	hours_bar = MeterScript.new()
	hours_bar.position = Vector2(18, 116)
	hours_bar.setup("工时", Color(0.24, 0.86, 0.94), 148, "res://assets/game/ui/hours.png")
	_style_watch_meter(hours_bar)
	hud.add_child(hours_bar)
	energy_bar = MeterScript.new()
	energy_bar.position = Vector2(18, 160)
	energy_bar.setup("精力", Color(0.96, 0.78, 0.29), 148, "res://assets/game/ui/energy.png")
	_style_watch_meter(energy_bar)
	hud.add_child(energy_bar)
	hours_num = hours_bar.num
	energy_num = energy_bar.num
	lamps = HBoxContainer.new()
	lamps.position = Vector2(20, 208)
	lamps.add_theme_constant_override("separation", 6)
	hud.add_child(lamps)
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
	kpi_label.text = "全员 KPI  工时 +10"
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
	back.pressed.connect(func(): Match.back_to_lobby())
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

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.08, 0.10, 0.78)
	dim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	dim.offset_left = 0
	dim.offset_right = 500
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(dim)

	var cam := TextureRect.new()
	cam.texture = _lobby_tex("res://assets/game/ui/lobby/cam.png")
	cam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cam.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cam.position = Vector2(1180, 18)
	cam.size = Vector2(72, 48)
	cam.modulate = Color(1, 1, 1, 0.9)
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(cam)

	_build_home_page()
	_build_join_page()
	_build_char_page()
	_show_lobby_page("home")


func _build_home_page() -> void:
	home_page = Control.new()
	home_page.position = Vector2(40, 48)
	home_page.size = Vector2(430, 640)
	lobby.add_child(home_page)

	var clock := TextureRect.new()
	clock.texture = _lobby_tex("res://assets/game/ui/lobby/clock.png")
	clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clock.position = Vector2(0, 0)
	clock.size = Vector2(56, 56)
	home_page.add_child(clock)

	var punch := TextureRect.new()
	punch.texture = _lobby_tex("res://assets/game/ui/lobby/punch.png")
	punch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	punch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	punch.position = Vector2(360, 0)
	punch.size = Vector2(44, 58)
	home_page.add_child(punch)

	var title := Label.new()
	title.text = "六点下班"
	title.position = Vector2(64, 4)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	home_page.add_child(title)

	var tag := Label.new()
	tag.text = "谁准你下班"
	tag.position = Vector2(66, 52)
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color("00B8D4"))
	home_page.add_child(tag)

	var mood := Label.new()
	mood.text = "白灯还亮着。走廊那头有人站着。"
	mood.position = Vector2(0, 92)
	mood.size = Vector2(400, 24)
	mood.add_theme_font_size_override("font_size", 13)
	mood.add_theme_color_override("font_color", Color(0.72, 0.76, 0.80, 0.9))
	home_page.add_child(mood)

	var start_btn := _lobby_btn("开始游戏", true)
	start_btn.position = Vector2(0, 140)
	start_btn.pressed.connect(_click_start)
	home_page.add_child(start_btn)

	var join_btn := _lobby_btn("参加游戏", false)
	join_btn.position = Vector2(0, 204)
	join_btn.pressed.connect(func(): _show_lobby_page("join"))
	home_page.add_child(join_btn)

	var char_btn := _lobby_btn("我的角色", false)
	char_btn.position = Vector2(0, 268)
	char_btn.pressed.connect(func(): _show_lobby_page("char"))
	home_page.add_child(char_btn)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "你的名字"
	name_edit.text = "玩家"
	name_edit.position = Vector2(0, 344)
	name_edit.size = Vector2(300, 36)
	home_page.add_child(name_edit)

	short_check = CheckBox.new()
	short_check.text = "短局 3 分钟"
	short_check.button_pressed = true
	short_check.position = Vector2(0, 392)
	short_check.add_theme_color_override("font_color", Color(0.86, 0.88, 0.90))
	home_page.add_child(short_check)

	status_label = Label.new()
	status_label.position = Vector2(0, 440)
	status_label.size = Vector2(400, 72)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	home_page.add_child(status_label)

	var hint := Label.new()
	hint.text = "员工：小马 / 兔子 / 牛 / 鹈鹕    老板：老虎\nE 坐下或捞人    F 摸鱼    工时扣完才能打卡润"
	hint.position = Vector2(0, 530)
	hint.size = Vector2(410, 70)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70, 0.9))
	home_page.add_child(hint)


func _build_join_page() -> void:
	join_page = _panel(Rect2(360, 150, 560, 400), Color(0.10, 0.12, 0.14, 0.94))
	join_page.visible = false
	lobby.add_child(join_page)
	var t := Label.new()
	t.text = "参加游戏"
	t.position = Vector2(28, 20)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	join_page.add_child(t)
	var d := Label.new()
	d.text = "输入房间 IP。也可以自己开一间等人。"
	d.position = Vector2(28, 58)
	d.size = Vector2(500, 24)
	d.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78))
	join_page.add_child(d)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "服务器 IP"
	ip_edit.text = "127.0.0.1"
	ip_edit.position = Vector2(28, 100)
	ip_edit.size = Vector2(500, 40)
	join_page.add_child(ip_edit)
	var join_btn := _lobby_btn("加入房间", true)
	join_btn.position = Vector2(28, 164)
	join_btn.size = Vector2(240, 48)
	join_btn.pressed.connect(_join)
	join_page.add_child(join_btn)
	var host_btn := _lobby_btn("创建房间", false)
	host_btn.position = Vector2(288, 164)
	host_btn.size = Vector2(240, 48)
	host_btn.pressed.connect(_host)
	join_page.add_child(host_btn)
	var back := _lobby_btn("返回", false)
	back.position = Vector2(28, 320)
	back.size = Vector2(140, 44)
	back.pressed.connect(func(): _show_lobby_page("home"))
	join_page.add_child(back)


func _build_char_page() -> void:
	char_page = _panel(Rect2(140, 90, 1000, 540), Color(0.10, 0.12, 0.14, 0.95))
	char_page.visible = false
	lobby.add_child(char_page)
	var t := Label.new()
	t.text = "我的角色"
	t.position = Vector2(28, 18)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	char_page.add_child(t)
	var d := Label.new()
	d.text = "四名员工靠物种认人。老板是老虎。选好后回大厅点开始。"
	d.position = Vector2(28, 56)
	d.size = Vector2(900, 24)
	d.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78))
	char_page.add_child(d)
	slot_box = HBoxContainer.new()
	slot_box.position = Vector2(28, 100)
	slot_box.size = Vector2(944, 320)
	slot_box.add_theme_constant_override("separation", 14)
	char_page.add_child(slot_box)
	var back := _lobby_btn("返回大厅", true)
	back.position = Vector2(28, 460)
	back.size = Vector2(180, 48)
	back.pressed.connect(func(): _show_lobby_page("home"))
	char_page.add_child(back)


func _show_lobby_page(page: String) -> void:
	if home_page:
		home_page.visible = page == "home"
	if join_page:
		join_page.visible = page == "join"
	if char_page:
		char_page.visible = page == "char"
	if page == "char":
		_refresh_lobby()


func _click_start() -> void:
	if Net.is_server:
		Match.start_local(short_check.button_pressed, false)
	else:
		_enter_test_room()


func _lobby_btn(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(12)
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 10
	hover.content_margin_bottom = 10
	if primary:
		sb.bg_color = Color("00B8D4")
		hover.bg_color = Color("3EE0F2")
		b.add_theme_color_override("font_color", Color(0.06, 0.10, 0.12))
		b.add_theme_color_override("font_hover_color", Color(0.06, 0.10, 0.12))
	else:
		sb.bg_color = Color(1, 1, 1, 0.92)
		hover.bg_color = Color(1, 1, 1, 1)
		b.add_theme_color_override("font_color", Color(0.12, 0.14, 0.16))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


func _lobby_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


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
		_:
			return "horse"


func _panel(rect: Rect2, color: Color) -> ColorRect:
	var p := ColorRect.new()
	p.color = color
	p.position = rect.position
	p.size = rect.size
	return p


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


func _join() -> void:
	if Net.join(ip_edit.text) != OK:
		status_label.text = Net.last_error
		_show_lobby_page("home")
		return
	await Net.status_changed
	Match.claim_local(wanted_slot, name_edit.text)
	_show_lobby_page("home")
	_refresh_lobby()


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
	Match.start_local(true, true)


func _pick_slot(slot: int) -> void:
	wanted_slot = slot
	if Net.is_server or Net.connected:
		Match.claim_local(slot, name_edit.text)
	_refresh_lobby()


func _refresh_lobby() -> void:
	var returning := lobby != null and not lobby.visible
	if Match.phase == "lobby":
		lobby.visible = not Net.is_dedicated
		hud.visible = false
		result_panel.visible = false
		exit_btn.visible = false
		if returning:
			_show_lobby_page("home")
	if Net.is_server:
		status_label.text = "房间已开  127.0.0.1:%d\n选好角色后点「开始游戏」" % Net.listen_port
	elif Net.connected:
		status_label.text = "已进大厅，先选角色，等房主开局"
	else:
		status_label.text = "直接开始会进测试房。也可以参加别人的房间。"
	if slot_box == null:
		return
	for c in slot_box.get_children():
		c.queue_free()
	for s in [Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D, Rules.Slot.BOSS]:
		var pid := int(Match.slots.get(s, -1))
		var who := "空位"
		if pid == 0:
			who = "Bot"
		elif pid > 0:
			who = str(Match.names.get(pid, "玩家%d" % pid))
		var picked: int = int(s)
		var card := Button.new()
		card.custom_minimum_size = Vector2(176, 300)
		card.toggle_mode = true
		card.button_pressed = picked == wanted_slot
		card.pressed.connect(func(): _pick_slot(picked))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.bg_color = Color(0.16, 0.18, 0.21, 0.96) if picked != wanted_slot else Color(0.08, 0.28, 0.32, 0.96)
		sb.border_width_bottom = 4
		sb.border_color = Color("00B8D4") if picked == wanted_slot else Color(0.22, 0.24, 0.28)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", sb)
		card.add_theme_stylebox_override("pressed", sb)
		var pic := TextureRect.new()
		pic.texture = load("res://assets/game/chars/%s/idle_0.png" % _char_pack(picked))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(18, 16)
		pic.size = Vector2(140, 180)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		var nm := Label.new()
		nm.text = str(Rules.SLOT_NAMES[s])
		nm.position = Vector2(8, 204)
		nm.size = Vector2(160, 24)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
		card.add_child(nm)
		var st := Label.new()
		st.text = who
		st.position = Vector2(8, 232)
		st.size = Vector2(160, 22)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", Color(0.70, 0.76, 0.80))
		card.add_child(st)
		slot_box.add_child(card)


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
	get_tree().create_timer(1.8).timeout.connect(func(): kpi_label.visible = false)


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


func _on_caught(slot: int, _repeat: bool, add_hours: float) -> void:
	var my := Match.my_slot()
	var vic: Actor = Match.actors.get(slot) as Actor
	if vic:
		vic.say("工时 +%d" % int(add_hours), 1.5)
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
	var nicks := ["小马", "兔子", "牛", "鹈鹕"]
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
		hours_bar.set_amount(actor.hours)
		energy_bar.set_amount(actor.energy)
		state_label.text = str(Rules.STATE_NAMES.get(actor.emp_state, ""))
		if actor.emp_state == Rules.EmpState.TALK:
			state_label.text = "约谈中 · 督导中" if Match.is_watched(actor) else "约谈中 · 可捞"
		if actor.emp_state == Rules.EmpState.TALK:
			hint_label.text = "约谈中 · 等同事捞人    老板在这间屋就捞不走"
		elif actor.emp_state == Rules.EmpState.WORK or actor.emp_state == Rules.EmpState.SLACK:
			hint_label.text = "WASD 起身    E 起身    F 摸鱼    同事被约谈时走过去 E 捞人"
		else:
			hint_label.text = "E 坐下 / 续命 / 捞人    F 摸鱼    WASD 走动"
	elif actor != null and actor.kind == Rules.Kind.BOSS:
		you_role.text = "工牌 · 老板"
		state_label.text = "开会 %.0fs  KPI %.0fs  冲刺 %.0fs" % [actor.meeting_cd, actor.kpi_cd, actor.dash_cd]
		hint_label.text = "E 约谈    盯着复盘加速    Q 开会    R KPI    Shift 冲刺"
	hint_label.modulate.a = clampf(_help_t / 2.0, 0.0, 1.0)
	_refresh_lamps()


func _refresh_lamps() -> void:
	while lamps.get_child_count() < 4:
		var l := ColorRect.new()
		l.custom_minimum_size = Vector2(10, 10)
		lamps.add_child(l)
	for i in 4:
		var slot := Rules.Slot.EMP_A + i
		var c := Color(0.75, 0.75, 0.75)
		if Match.actors.has(slot):
			var e: Actor = Match.actors[slot]
			if e.emp_state == Rules.EmpState.LEFT:
				c = Color(0.6, 0.85, 0.55)
			elif e.emp_state == Rules.EmpState.WORK:
				c = Color(0.35, 0.75, 0.45)
			elif e.emp_state == Rules.EmpState.SLACK:
				c = Color(0.95, 0.7, 0.2)
			elif e.emp_state == Rules.EmpState.TALK:
				c = Color(0.9, 0.22, 0.18)
			else:
				c = Rules.scarf_color(e.skin)
		(lamps.get_child(i) as ColorRect).color = c


func _local_actor() -> Actor:
	var my := Match.my_slot()
	if my < 0:
		return null
	return Match.actors.get(my) as Actor


func _leave_room() -> void:
	Match.back_to_lobby()


func _process(delta: float) -> void:
	_edge_keys()
	_update_camera(delta)
	var actor := _local_actor()
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
	if multiplayer.is_server():
		actor.apply_input(dir.x, dir.y, _pulse_interact, _pulse_slack, _pulse_meeting, _pulse_kpi, _pulse_dash)
	else:
		actor.recv_input.rpc_id(1, dir.x, dir.y, _pulse_interact, _pulse_slack, _pulse_meeting, _pulse_kpi, _pulse_dash)
	_pulse_interact = false
	_pulse_slack = false
	_pulse_meeting = false
	_pulse_kpi = false
	_pulse_dash = false


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
	if actor != null and Match.playing:
		var boss: Actor = Match.actors.get(Rules.Slot.BOSS) as Actor
		if actor.kind == Rules.Kind.EMPLOYEE and boss != null:
			var here := office.same_view(actor.global_position, boss.global_position)
			if here:
				veil_a = 0.07
				warn = "老板在这间屋"
				if not _boss_seen:
					_shake = maxf(_shake, 0.14)
					_boss_seen = true
			else:
				_boss_seen = false
			if _catch_t > 0.0:
				veil_a = 0.22
	_catch_t = maxf(0.0, _catch_t - delta)
	_banner_t = maxf(0.0, _banner_t - delta)
	_shake = maxf(0.0, _shake - delta)
	if _banner_t <= 0.0 and catch_banner != null:
		catch_banner.visible = false
	if room_warn:
		room_warn.text = warn
	if catch_veil:
		var c := catch_veil.color
		c.a = lerpf(c.a, veil_a, 1.0 - exp(-8.0 * delta))
		catch_veil.color = c
	_cam_z = lerpf(_cam_z, target_z, 1.0 - exp(-5.0 * delta))
	camera.zoom = Vector2(_cam_z, _cam_z)
	var shake_off := Vector2.ZERO
	if _shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 10.0
	camera.position = camera.position.lerp(target, 1.0 - exp(-6.0 * delta)) + shake_off


func _camera_goal(actor: Actor) -> Dictionary:
	if actor == null:
		return {"pos": OfficeMap.DESK_RECT.get_center(), "zoom": _frame_room(OfficeMap.DESK_RECT).x}
	if office.is_desk_area(actor.global_position):
		var rect := OfficeMap.DESK_RECT.grow_individual(8, 8, 8, 8)
		var z := _frame_room(rect).x
		var center := rect.get_center()
		var bias := (actor.global_position - center) * 0.20
		bias.x = clampf(bias.x, -86.0, 86.0)
		bias.y = clampf(bias.y, -54.0, 54.0)
		return {"pos": center + bias, "zoom": z}
	var look := actor.velocity * 0.16
	var pos := actor.global_position + look + Vector2(0, -28)
	var z2 := 1.10 if actor.kind == Rules.Kind.EMPLOYEE else 0.92
	return {"pos": pos, "zoom": z2}


func _edge_keys() -> void:
	var e := Input.is_physical_key_pressed(KEY_E)
	var f := Input.is_physical_key_pressed(KEY_F)
	var q := Input.is_physical_key_pressed(KEY_Q)
	var r := Input.is_physical_key_pressed(KEY_R)
	var sh := Input.is_physical_key_pressed(KEY_SHIFT)
	var esc := Input.is_physical_key_pressed(KEY_ESCAPE)
	if e and not _e_down:
		_pulse_interact = true
	if f and not _f_down:
		_pulse_slack = true
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
	_esc_down = esc


func _fmt(sec: float) -> String:
	var s := int(max(sec, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
