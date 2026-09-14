extends Node2D

var office: OfficeMap
var camera: Camera2D
var ui: CanvasLayer
var lobby: Control
var hud: Control
var result_panel: Control
var kpi_label: Label
var status_label: Label
var slot_box: VBoxContainer
var name_edit: LineEdit
var ip_edit: LineEdit
var short_check: CheckBox
var hint_label: Label
var hours_bar: ProgressBar
var energy_bar: ProgressBar
var time_label: Label
var state_label: Label
var you_role: Label
var prompt_label: Label
var team_card: ColorRect
var team_lines: Array[Label] = []
var team_hours: Array[ProgressBar] = []
var team_energy: Array[ProgressBar] = []
var lamps: HBoxContainer
var you_label: Label
var boss_label: Label
var log_label: Label
var exit_btn: Button

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
	Net.status_changed.connect(_refresh_lobby)
	Net.peer_list_changed.connect(_refresh_lobby)
	if Net.is_dedicated:
		lobby.visible = false
		status_label.text = "专用服 %d · 等客户端加入后点开始" % Net.listen_port
	_refresh_lobby()
	print("[Game] ready dedicated=%s port=%d" % [Net.is_dedicated, Net.listen_port])
	get_tree().set_auto_accept_quit(false)
	if not Net.is_dedicated:
		for arg in OS.get_cmdline_user_args():
			if arg == "--test":
				_enter_test_room.call_deferred()
				break


func _build_world() -> void:
	office = OfficeMap.new()
	office.name = "Office"
	add_child(office)
	camera = Camera2D.new()
	add_child(camera)
	if DisplayServer.get_name() != "headless":
		camera.make_current()
		_fit_camera()


func _fit_camera() -> void:
	if camera == null or DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var map := Rules.MAP_SIZE
	var z := minf(vp.x / map.x, vp.y / map.y)
	camera.zoom = Vector2(z, z)
	camera.position = map * 0.5


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	lobby = _panel(Rect2(32, 32, 440, 640), Color(1, 1, 1, 0.96))
	ui.add_child(lobby)
	var title := Label.new()
	title.text = "游戏大厅"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 28)
	lobby.add_child(title)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "名字"
	name_edit.text = "玩家"
	name_edit.position = Vector2(20, 56)
	name_edit.size = Vector2(180, 32)
	lobby.add_child(name_edit)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "服务器 IP"
	ip_edit.text = "127.0.0.1"
	ip_edit.position = Vector2(210, 56)
	ip_edit.size = Vector2(200, 32)
	lobby.add_child(ip_edit)
	_btn("测试房间 · 直接进办公室", Vector2(20, 100), func(): _enter_test_room(), Vector2(390, 44))
	_btn("创建房间", Vector2(20, 154), func(): _host())
	_btn("加入房间", Vector2(150, 154), func(): _join())
	status_label = Label.new()
	status_label.position = Vector2(20, 198)
	status_label.size = Vector2(400, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.add_child(status_label)
	var id_lab := Label.new()
	id_lab.text = "选身份（老板 / 员工）"
	id_lab.position = Vector2(20, 240)
	lobby.add_child(id_lab)
	slot_box = VBoxContainer.new()
	slot_box.position = Vector2(20, 268)
	slot_box.size = Vector2(400, 200)
	lobby.add_child(slot_box)
	short_check = CheckBox.new()
	short_check.text = "短局 3 分钟"
	short_check.button_pressed = true
	short_check.position = Vector2(20, 478)
	lobby.add_child(short_check)
	_btn("开始游戏", Vector2(20, 516), func(): Match.start_local(short_check.button_pressed, false), Vector2(160, 36))
	var help := Label.new()
	help.position = Vector2(20, 560)
	help.size = Vector2(400, 70)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	help.text = "测试房间会在本机自己开房，不用先开服务端。默认是员工黑猫，大厅里可改成老板。WASD 走动，坐着时 WASD 也会起身。"
	lobby.add_child(help)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	ui.add_child(hud)
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.86)
	card.position = Vector2(16, 16)
	card.size = Vector2(338, 176)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(card)
	you_role = Label.new()
	you_role.position = Vector2(12, 8)
	you_role.add_theme_font_size_override("font_size", 16)
	card.add_child(you_role)
	time_label = Label.new()
	time_label.position = Vector2(12, 32)
	time_label.add_theme_font_size_override("font_size", 22)
	card.add_child(time_label)
	state_label = Label.new()
	state_label.position = Vector2(12, 62)
	card.add_child(state_label)
	hours_bar = _bar(card, Vector2(12, 90), Color(0.35, 0.55, 0.95))
	energy_bar = _bar(card, Vector2(12, 116), Color(0.95, 0.72, 0.2))
	var hcap := Label.new()
	hcap.text = "工时"
	hcap.position = Vector2(220, 88)
	card.add_child(hcap)
	var ecap := Label.new()
	ecap.text = "精力"
	ecap.position = Vector2(220, 114)
	card.add_child(ecap)
	lamps = HBoxContainer.new()
	lamps.position = Vector2(12, 144)
	card.add_child(lamps)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_left = 20
	prompt_label.offset_top = -78
	prompt_label.offset_right = -20
	prompt_label.offset_bottom = -42
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
	hud.add_child(prompt_label)
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 20
	hint_label.offset_top = -36
	hint_label.offset_right = -20
	hint_label.offset_bottom = -12
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22))
	hud.add_child(hint_label)
	team_card = ColorRect.new()
	team_card.color = Color(1, 1, 1, 0.86)
	team_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	team_card.offset_left = -360
	team_card.offset_top = 64
	team_card.offset_right = -20
	team_card.offset_bottom = 372
	team_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	team_card.visible = false
	hud.add_child(team_card)
	var team_title := Label.new()
	team_title.text = "同事 工时 / 精力"
	team_title.position = Vector2(12, 8)
	team_title.add_theme_font_size_override("font_size", 16)
	team_card.add_child(team_title)
	for i in 4:
		var y := 36 + i * 68
		var lab := Label.new()
		lab.position = Vector2(12, y)
		lab.size = Vector2(310, 22)
		team_card.add_child(lab)
		team_lines.append(lab)
		var hb := _bar(team_card, Vector2(12, y + 24), Color(0.35, 0.55, 0.95))
		hb.size = Vector2(150, 14)
		team_hours.append(hb)
		var eb := _bar(team_card, Vector2(172, y + 24), Color(0.95, 0.72, 0.2))
		eb.size = Vector2(150, 14)
		team_energy.append(eb)
	kpi_label = Label.new()
	kpi_label.text = "全员 KPI +10"
	kpi_label.visible = false
	kpi_label.position = Vector2(480, 280)
	kpi_label.add_theme_font_size_override("font_size", 36)
	kpi_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	hud.add_child(kpi_label)

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


func _panel(rect: Rect2, color: Color) -> ColorRect:
	var p := ColorRect.new()
	p.color = color
	p.position = rect.position
	p.size = rect.size
	return p


func _bar(parent: Control, pos: Vector2, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(196, 18)
	b.max_value = 100
	b.show_percentage = false
	b.modulate = fill
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			return
	Match.claim_local(wanted_slot, name_edit.text)
	_refresh_lobby()


func _join() -> void:
	if Net.join(ip_edit.text) != OK:
		status_label.text = Net.last_error
		return
	await Net.status_changed
	Match.claim_local(wanted_slot, name_edit.text)


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
	if Match.phase == "lobby":
		lobby.visible = not Net.is_dedicated
		hud.visible = false
		result_panel.visible = false
		exit_btn.visible = false
	if Net.is_server:
		status_label.text = "房间已开  127.0.0.1:%d" % Net.listen_port
	elif Net.connected:
		status_label.text = "已进大厅，选身份后等房主开始"
	else:
		status_label.text = "先选身份，点「测试房间」马上进办公室"
	for c in slot_box.get_children():
		c.queue_free()
	for s in [Rules.Slot.BOSS, Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D]:
		var row := Button.new()
		var pid := int(Match.slots.get(s, -1))
		var who := "空"
		if pid == 0:
			who = "Bot"
		elif pid > 0:
			who = str(Match.names.get(pid, "玩家%d" % pid))
		var mark := "  ← 当前" if int(s) == wanted_slot else ""
		row.text = "%s    %s%s" % [Rules.SLOT_NAMES[s], who, mark]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var picked: int = int(s)
		row.pressed.connect(func(): _pick_slot(picked))
		slot_box.add_child(row)


func _on_started() -> void:
	lobby.visible = false
	hud.visible = true
	result_panel.visible = false
	exit_btn.visible = true
	_refresh_hud()


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


func _refresh_hud() -> void:
	if not hud.visible:
		return
	var t := Match.time_left
	if Match.phase == "countdown":
		time_label.text = "即将开始  %d" % ceili(Match.countdown)
	else:
		time_label.text = "剩余 %s" % _fmt(t)
	var actor := _local_actor()
	hours_bar.visible = false
	energy_bar.visible = false
	you_role.text = "你：旁观"
	prompt_label.text = ""
	team_card.visible = false
	if actor != null and actor.kind == Rules.Kind.EMPLOYEE:
		you_role.text = "你：%s" % Rules.SLOT_NAMES.get(actor.slot, "员工")
		hours_bar.visible = true
		energy_bar.visible = true
		hours_bar.value = actor.hours
		energy_bar.value = actor.energy
		state_label.text = "%s    剩余工时约 %s" % [Rules.STATE_NAMES.get(actor.emp_state, ""), _fmt(actor.remaining_work_sec())]
		var act := actor.nearby_action()
		prompt_label.text = act
		if actor.emp_state == Rules.EmpState.WORK or actor.emp_state == Rules.EmpState.SLACK:
			hint_label.text = "WASD 起身走动    E 起身    F 摸鱼    Esc 退出"
		else:
			hint_label.text = "走到工位旁会提示「E 坐下」    WASD 出门    Esc 退出"
		_refresh_team(actor.slot)
	elif actor != null and actor.kind == Rules.Kind.BOSS:
		you_role.text = "你：老板"
		state_label.text = "开会 %.0fs   KPI %.0fs   冲刺 %.0fs" % [actor.meeting_cd, actor.kpi_cd, actor.dash_cd]
		hint_label.text = "WASD 移动    E 抓包    Q 开会    R KPI    Shift 冲刺    Esc 退出"
	_refresh_lamps()


func _refresh_team(my_slot: int) -> void:
	team_card.visible = true
	for i in 4:
		var slot := Rules.Slot.EMP_A + i
		var e: Actor = Match.actors.get(slot) as Actor
		var nicks: PackedStringArray = ["黑猫", "兔子", "企鹅", "熊猫"]
		var nick := nicks[i]
		if e == null:
			team_lines[i].text = "%s  —" % nick
			team_hours[i].value = 0
			team_energy[i].value = 0
			continue
		var mark := "（你）" if slot == my_slot else ""
		var st := str(Rules.STATE_NAMES.get(e.emp_state, ""))
		team_lines[i].text = "%s%s  %s  工时约 %s" % [nick, mark, st, _fmt(e.remaining_work_sec())]
		team_hours[i].value = e.hours
		team_energy[i].value = e.energy


func _refresh_lamps() -> void:
	while lamps.get_child_count() < 4:
		var l := ColorRect.new()
		l.custom_minimum_size = Vector2(22, 22)
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
			else:
				c = Color(0.85, 0.35, 0.35)
		(lamps.get_child(i) as ColorRect).color = c


func _local_actor() -> Actor:
	var my := Match.my_slot()
	if my < 0:
		return null
	return Match.actors.get(my) as Actor


func _leave_room() -> void:
	Match.back_to_lobby()


func _process(_delta: float) -> void:
	_edge_keys()
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
