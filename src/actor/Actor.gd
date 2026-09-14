extends CharacterBody2D
class_name Actor

const SNAP_HZ := 15.0
const Kit := preload("res://src/actor/CharKit.gd")
const SCARF_SHADER := preload("res://src/actor/scarf.gdshader")
const PAPER_TEX := preload("res://assets/game/props/paper.png")
const COFFEE_TEX := preload("res://assets/game/props/coffee.png")

@onready var name_label: Label = $Name

var body_sprite: Sprite2D
var zzz_label: Label
var hold_sprite: Sprite2D
var hours_chip: Label
var energy_chip: Label
var prompt_bg: ColorRect
var prompt_lab: Label
var bubble_bg: ColorRect
var bubble_lab: Label
var bubble_t := 0.0

var slot := 0
var peer_id := 0
var kind := Rules.Kind.EMPLOYEE
var skin := Rules.CharSkin.HORSE
var display_name := ""

var hours := Rules.HOURS_START
var energy := Rules.ENERGY_START
var emp_state := Rules.EmpState.WALK
var coffee_buff := 0.0
var stand_lock := 0.0
var meeting_left := 0.0
var catch_chain := 0.0
var slack_seen := 0.0
var occupy_id := ""
var last_seat := 0
var left_clock := ""
var talk_progress := 0.0
var rescue_left := 0.0
var rescue_slot := -1
var boost_left := 0.0
var carrying_slot := -1
var carried_by := -1
var carry_left := 0.0
var carry_windup := 0.0
var carry_recovery := 0.0
var carry_saved_talk := -1.0
var carry_visual: Node2D
var landing_left := 0.0

var meeting_cd := 0.0
var kpi_cd := 0.0
var dash_cd := 0.0
var dash_left := 0.0
var match_elapsed := 0.0
var kpi_flash := 0.0

var input_dir := Vector2.ZERO
var want_interact := false
var want_slack := false
var want_meeting := false
var want_kpi := false
var want_dash := false

var _sync_acc := 0.0
var _remote_pos := Vector2.ZERO
var _facing := Vector2.DOWN
var _anim_acc := 0.0


func setup(p_slot: int, p_peer: int, p_name: String) -> void:
	slot = p_slot
	peer_id = p_peer
	display_name = p_name
	kind = Rules.Kind.BOSS if p_slot == Rules.Slot.BOSS else Rules.Kind.EMPLOYEE
	skin = Rules.SKIN_FOR_SLOT[p_slot]
	name = "actor_%d" % p_slot
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var cs := get_node("Collision") as CollisionShape2D
	var sh := CircleShape2D.new()
	sh.radius = 11
	cs.shape = sh
	var nl := get_node("Name") as Label
	nl.position = Vector2(-36, -78)
	nl.size = Vector2(72, 18)
	nl.add_theme_font_size_override("font_size", 11)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ensure_sprite()


func is_local() -> bool:
	return peer_id != 0 and peer_id == multiplayer.get_unique_id()


func is_bot() -> bool:
	return peer_id == 0


func office() -> OfficeMap:
	return get_parent() as OfficeMap


func nearby_action() -> String:
	if kind == Rules.Kind.BOSS:
		return _boss_nearby_action()
	if carried_by >= 0:
		return "顺风嘴 · E 主动下来"
	if carrying_slot >= 0:
		return "跨部门捞人 · E 放下同事（%.0fs）" % ceilf(carry_left)
	if skin == Rules.CharSkin.PELICAN and emp_state == Rules.EmpState.WALK and stand_lock <= 0.0:
		var passenger: Actor = Match.nearest_carry_target(self)
		if passenger != null:
			return "E 叼走「%s」" % passenger.display_name
	if emp_state == Rules.EmpState.TALK:
		if Match.is_watched(self):
			return "约谈中 · 老板盯着，捞不走"
		return "约谈中 · 等同事捞人"
	if rescue_left > 0.0:
		return "正在捞人…"
	if emp_state == Rules.EmpState.WORK or emp_state == Rules.EmpState.SLACK:
		return "E 起身    F 摸鱼"
	if emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET:
		return "E 撤了"
	if emp_state == Rules.EmpState.CLOCKING:
		return "润了 · 去打卡"
	if emp_state == Rules.EmpState.MEETING:
		return "被拉去开会 · 救不了"
	if stand_lock > 0.0:
		return "刚复盘完 · 先站一会儿"
	var map := office()
	if map == null:
		return ""
	var door = map.nearest_door(global_position, Rules.DOOR_RANGE)
	if door != null:
		return door.prompt_text(kind)
	var talk := Match.nearest_talk(global_position, Rules.RESCUE_RANGE)
	if talk != null:
		if Match.is_watched(talk):
			return "老板盯着 · 捞不走"
		return "E 捞人"
	var seat := map.nearest_spot("seat", global_position, Rules.INTERACT_RANGE)
	if seat != "":
		var who: int = map.occupiers.get(seat, -1)
		if who != -1 and who != slot:
			return "这个位子有人"
		return "E 坐下干活"
	var coffee := map.nearest_free("coffee", global_position)
	if coffee != "" and global_position.distance_to(map.points[coffee]) < Rules.INTERACT_RANGE:
		return "E 续命（咖啡）"
	var toilet := map.nearest_free("toilet", global_position)
	if toilet != "" and global_position.distance_to(map.points[toilet]) < Rules.INTERACT_RANGE:
		return "E 暂时离线"
	return ""


func _boss_nearby_action() -> String:
	var talk := Match.nearest_talk(global_position, 220.0)
	if talk != null and Match.is_watched(talk):
		return "现场督导中 · 复盘加速"
	for a in Match.actors.values():
		var e := a as Actor
		if not Match.is_catchable(e):
			continue
		if global_position.distance_to(e.global_position) <= Rules.CATCH_RANGE:
			if e.rescue_left > 0.0:
				return "E 约谈（捞人的也别跑）"
			return "E 约谈"
	var map := office()
	if map:
		var door = map.nearest_door(global_position, Rules.DOOR_RANGE)
		if door != null:
			return door.prompt_text(kind)
	return ""


func remaining_work_sec() -> float:
	return hours / Rules.WORK_HOURS_PER_SEC


func _skin_tex() -> Texture2D:
	return Kit.tex(skin, "idle_0")


func _ready() -> void:
	_remote_pos = global_position
	if name_label:
		name_label.text = display_name
	_ensure_sprite()
	_update_visual(0.0)


func _ensure_sprite() -> void:
	if body_sprite != null:
		return
	body_sprite = Sprite2D.new()
	body_sprite.name = "Body"
	body_sprite.texture = _skin_tex()
	body_sprite.centered = false
	body_sprite.z_index = 1
	_apply_scarf()
	add_child(body_sprite)
	if skin == Rules.CharSkin.PELICAN:
		carry_visual = preload("res://src/fx/PelicanCarry.gd").new()
		carry_visual.z_index = 3
		add_child(carry_visual)
	zzz_label = Label.new()
	zzz_label.text = "z z"
	zzz_label.visible = false
	zzz_label.position = Vector2(10, -64)
	zzz_label.add_theme_font_size_override("font_size", 12)
	zzz_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	add_child(zzz_label)
	hold_sprite = Sprite2D.new()
	hold_sprite.centered = true
	hold_sprite.z_index = 2
	hold_sprite.visible = false
	add_child(hold_sprite)
	hours_chip = _make_chip(Color(0.22, 0.48, 0.58))
	energy_chip = _make_chip(Color(0.62, 0.48, 0.12))
	prompt_bg = ColorRect.new()
	prompt_bg.color = Color(0.12, 0.14, 0.18, 0.86)
	prompt_bg.visible = false
	prompt_bg.z_index = 6
	prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_bg)
	prompt_lab = Label.new()
	prompt_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lab.add_theme_font_size_override("font_size", 11)
	prompt_lab.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	prompt_lab.z_index = 7
	add_child(prompt_lab)
	bubble_bg = ColorRect.new()
	bubble_bg.color = Color(1, 1, 1, 0.92)
	bubble_bg.visible = false
	bubble_bg.z_index = 6
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble_bg)
	bubble_lab = Label.new()
	bubble_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_lab.add_theme_font_size_override("font_size", 12)
	bubble_lab.add_theme_color_override("font_color", Color(0.18, 0.18, 0.20))
	bubble_lab.z_index = 7
	add_child(bubble_lab)


func say(text: String, hold := 1.7) -> void:
	if bubble_lab == null:
		return
	bubble_lab.text = text
	bubble_t = hold
	bubble_bg.visible = true
	bubble_lab.visible = true


func _apply_scarf() -> void:
	if body_sprite == null:
		return
	if kind != Rules.Kind.EMPLOYEE:
		body_sprite.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = SCARF_SHADER
	mat.set_shader_parameter("scarf_color", Rules.scarf_color(skin))
	body_sprite.material = mat


func _make_chip(color: Color) -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 10)
	lab.add_theme_color_override("font_color", color)
	lab.position = Vector2(-44, 8)
	lab.size = Vector2(88, 14)
	add_child(lab)
	return lab


func _update_visual(delta := 0.0) -> void:
	if body_sprite == null:
		return
	_anim_acc += delta
	if velocity.x > 10.0:
		_facing.x = 1.0
	elif velocity.x < -10.0:
		_facing.x = -1.0
	var sitting := emp_state == Rules.EmpState.WORK or emp_state == Rules.EmpState.SLACK or emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET or emp_state == Rules.EmpState.MEETING
	var pose := _anim_pose()
	var tex: Texture2D = Kit.tex(skin, pose)
	if tex != null:
		body_sprite.texture = tex
	var sz := body_sprite.texture.get_size() if body_sprite.texture else Vector2(1024, 1024)
	var sc := Rules.BOSS_SPRITE if kind == Rules.Kind.BOSS else Rules.SPRITE_SCALE
	if sitting:
		sc *= 0.92
	sc *= 1024.0 / maxf(sz.y, 1.0)
	body_sprite.position = Vector2.ZERO
	body_sprite.rotation = 0.0
	body_sprite.scale = Vector2(sc, sc)
	landing_left = maxf(0.0, landing_left - delta)
	if landing_left > 0.0:
		var bounce := sin((1.0 - landing_left / 0.4) * PI)
		body_sprite.position.y = -bounce * 12.0
		body_sprite.scale *= Vector2(1.0 + bounce * 0.12, 1.0 - bounce * 0.1)
	if carrying_slot >= 0:
		var lean := sin(clampf(carry_windup / Rules.CARRY_WINDUP, 0.0, 1.0) * PI)
		body_sprite.scale *= Vector2(1.0 + lean * 0.18, 1.0 - lean * 0.1)
		body_sprite.position.x = (1.0 if _facing.x >= 0.0 else -1.0) * lean * 7.0
		body_sprite.position.y = sin(_anim_acc * 12.0) * 1.5
	body_sprite.visible = carried_by < 0
	body_sprite.offset = Vector2(-sz.x * 0.5, -sz.y + 22.0)
	body_sprite.flip_h = (not sitting) and _facing.x < 0.0
	if zzz_label:
		if emp_state == Rules.EmpState.TALK:
			zzz_label.visible = true
			zzz_label.text = "复盘中" if Match.is_watched(self) else "救命"
			zzz_label.add_theme_color_override("font_color", Color(0.92, 0.18, 0.14))
		elif emp_state == Rules.EmpState.CLOCKING:
			zzz_label.visible = true
			zzz_label.text = "润"
			zzz_label.add_theme_color_override("font_color", Color(0.45, 0.82, 0.42))
		else:
			zzz_label.visible = false
			zzz_label.text = "z z"
			zzz_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	if name_label:
		name_label.position = Vector2(-40, -sz.y * sc - 18.0)
	_update_chips(sz.y * sc)
	_update_world_text(sz.y * sc, delta)
	_update_hold()
	_update_threat_modulate()
	if carried_by >= 0:
		name_label.visible = false
		zzz_label.visible = false
		hold_sprite.visible = false
	else:
		name_label.visible = true


func _anim_pose() -> String:
	var anim := "idle"
	match emp_state:
		Rules.EmpState.WORK:
			anim = "work"
		Rules.EmpState.SLACK:
			anim = "sleep"
		Rules.EmpState.COFFEE:
			anim = "work"
		Rules.EmpState.MEETING:
			anim = "work"
		Rules.EmpState.TALK:
			anim = "idle"
		Rules.EmpState.TOILET:
			anim = "toilet"
		Rules.EmpState.CLOCKING:
			anim = "run"
		_:
			if velocity.length() > 24.0:
				anim = "run" if dash_left > 0.0 else "walk"
			else:
				anim = "idle"
	var frames: PackedStringArray = Kit.loop_frames(anim)
	var fps := 10.0 if anim == "run" else (8.0 if anim == "walk" else 5.0)
	if anim == "sleep":
		fps = 4.0
	var i: int = int(_anim_acc * fps) % frames.size()
	return frames[i]


func _update_chips(body_h: float) -> void:
	if hours_chip:
		hours_chip.visible = false
	if energy_chip:
		energy_chip.visible = false
	if prompt_bg:
		prompt_bg.position.y = -body_h - 36.0


func _update_world_text(body_h: float, delta: float) -> void:
	if bubble_t > 0.0:
		bubble_t = maxf(0.0, bubble_t - delta)
		if bubble_t <= 0.0:
			if bubble_bg:
				bubble_bg.visible = false
			if bubble_lab:
				bubble_lab.visible = false
	if bubble_lab and bubble_lab.visible:
		var bw := maxf(72.0, bubble_lab.text.length() * 13.0)
		bubble_lab.size = Vector2(bw, 18)
		bubble_lab.position = Vector2(-bw * 0.5, -body_h - 58.0)
		bubble_bg.size = Vector2(bw + 12, 20)
		bubble_bg.position = Vector2(-bw * 0.5 - 6, -body_h - 60.0)
	if prompt_lab == null or prompt_bg == null:
		return
	var act := nearby_action() if is_local() else ""
	var show := act != ""
	prompt_lab.visible = show
	prompt_bg.visible = show
	if not show:
		return
	prompt_lab.text = act
	var pw := maxf(56.0, act.length() * 12.0)
	prompt_lab.size = Vector2(pw, 16)
	prompt_lab.position = Vector2(-pw * 0.5, -body_h - 36.0)
	prompt_bg.size = Vector2(pw + 12, 18)
	prompt_bg.position = Vector2(-pw * 0.5 - 6, -body_h - 38.0)


func _update_hold() -> void:
	if hold_sprite == null:
		return
	if emp_state == Rules.EmpState.TALK:
		hold_sprite.texture = PAPER_TEX
		hold_sprite.visible = true
		hold_sprite.position = Vector2(18, -10)
		hold_sprite.scale = Vector2(0.035, 0.035)
		hold_sprite.modulate = Color(1, 0.85, 0.82)
	elif emp_state == Rules.EmpState.COFFEE:
		hold_sprite.texture = COFFEE_TEX
		hold_sprite.visible = true
		hold_sprite.position = Vector2(16, -8)
		hold_sprite.scale = Vector2(0.03, 0.03)
		hold_sprite.modulate = Color.WHITE
	else:
		hold_sprite.visible = false


func _update_threat_modulate() -> void:
	if body_sprite == null:
		return
	var c := Color.WHITE
	if kind == Rules.Kind.EMPLOYEE:
		var map := office()
		var threat := map.threat_for(self) if map else 0.0
		if emp_state == Rules.EmpState.TALK:
			c = Color(1.0, 0.58, 0.54)
		elif emp_state == Rules.EmpState.CLOCKING:
			c = Color(0.72, 1.0, 0.78)
		elif Match.is_supervised(self):
			c = Color(0.82, 0.78, 0.78)
		elif threat > 0.18:
			c = Color.WHITE.lerp(Color(0.90, 0.70, 0.68), clampf(threat, 0.0, 1.0))
		if boost_left > 0.0:
			c = c.lerp(Color(0.75, 1.0, 0.82), 0.4)
	elif kpi_flash > 0.0:
		c = Color(1.0, 0.55, 0.5)
	body_sprite.modulate = c


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and Match.playing:
		_server_tick(delta)
		_sync_acc += delta
		if _sync_acc >= 1.0 / SNAP_HZ:
			_sync_acc = 0.0
			_broadcast_state()
	elif not multiplayer.is_server():
		global_position = global_position.lerp(_remote_pos, 1.0 - exp(-12.0 * delta))
	if carried_by >= 0:
		var carrier := Match.actors.get(carried_by) as Actor
		if carrier != null:
			global_position = carrier.global_position
	_update_visual(delta)
	queue_redraw()


func _server_tick(delta: float) -> void:
	carry_recovery = maxf(0.0, carry_recovery - delta)
	stand_lock = max(0.0, stand_lock - delta)
	catch_chain = max(0.0, catch_chain - delta)
	coffee_buff = max(0.0, coffee_buff - delta)
	boost_left = max(0.0, boost_left - delta)
	meeting_cd = max(0.0, meeting_cd - delta)
	kpi_cd = max(0.0, kpi_cd - delta)
	dash_cd = max(0.0, dash_cd - delta)
	dash_left = max(0.0, dash_left - delta)
	kpi_flash = max(0.0, kpi_flash - delta)
	if kind == Rules.Kind.BOSS:
		_boss_tick(delta)
	else:
		_employee_tick(delta)
	want_interact = false
	want_slack = false
	want_meeting = false
	want_kpi = false
	want_dash = false


func _employee_tick(delta: float) -> void:
	if carried_by >= 0:
		var carrier: Actor = Match.actors.get(carried_by) as Actor
		if carrier != null:
			global_position = carrier.global_position
			velocity = Vector2.ZERO
			if want_interact and not is_bot() and carrier.carry_windup <= 0.0:
				Match.release_carry(carrier)
		return
	if carrying_slot >= 0:
		carry_left -= delta
		carry_windup = maxf(0.0, carry_windup - delta)
		if emp_state != Rules.EmpState.WALK or hours <= 0.0:
			Match.release_carry(self, true)
		elif carry_left <= 0.0 or (want_interact and carry_windup <= 0.0):
			Match.release_carry(self)
			want_interact = false
		else:
			velocity = input_dir.limit_length() * Rules.EMPLOYEE_SPEED * 0.88 if carry_windup <= 0.0 else Vector2.ZERO
			move_and_slide()
			return
	if emp_state == Rules.EmpState.LEFT:
		visible = false
		velocity = Vector2.ZERO
		return
	if hours <= 0.0 and emp_state != Rules.EmpState.CLOCKING and emp_state != Rules.EmpState.TALK:
		_begin_clocking()
	match emp_state:
		Rules.EmpState.TALK:
			_tick_talk(delta)
			return
		Rules.EmpState.MEETING:
			meeting_left -= delta
			energy = max(0.0, energy - Rules.MEETING_ENERGY_PER_SEC * delta)
			velocity = Vector2.ZERO
			if meeting_left <= 0.0:
				emp_state = Rules.EmpState.WALK
			return
		Rules.EmpState.CLOCKING:
			var target: Vector2 = office().nearest_punch(global_position)
			var blocked = office().nearest_door(global_position, 56.0)
			if blocked != null and blocked.closed:
				office().try_door(self)
			_move_towards(office().path_to(global_position, target), Rules.EMPLOYEE_SPEED, delta)
			if global_position.distance_to(target) < Rules.CLOCK_RANGE:
				_clock_out()
			return
		Rules.EmpState.WORK:
			if want_slack:
				emp_state = Rules.EmpState.SLACK
				_sit_work(delta, true)
				return
			if want_interact or input_dir.length() > 0.12:
				_stand_up()
				if want_interact:
					Match.try_rescue(self)
					return
			else:
				_sit_work(delta, false)
				return
		Rules.EmpState.SLACK:
			if want_slack:
				emp_state = Rules.EmpState.WORK
				_sit_work(delta, false)
				return
			if want_interact or input_dir.length() > 0.12:
				_stand_up()
				if want_interact:
					Match.try_rescue(self)
					return
			else:
				_sit_work(delta, true)
				return
		Rules.EmpState.COFFEE:
			energy = min(Rules.ENERGY_MAX, energy + Rules.COFFEE_ENERGY_PER_SEC * delta)
			velocity = Vector2.ZERO
			if energy >= Rules.ENERGY_MAX - 0.2 or want_interact or input_dir.length() > 0.12:
				coffee_buff = Rules.COFFEE_BUFF_TIME
				_stand_up()
			else:
				return
		Rules.EmpState.TOILET:
			energy = min(Rules.ENERGY_MAX, energy + Rules.TOILET_ENERGY_PER_SEC * delta)
			velocity = Vector2.ZERO
			if energy >= Rules.ENERGY_MAX - 0.2 or want_interact or input_dir.length() > 0.12:
				_stand_up()
			else:
				return
	# walk
	if rescue_left > 0.0:
		if input_dir.length() > 0.12:
			clear_rescue()
		elif Match.tick_rescue(self, delta):
			velocity = Vector2.ZERO
			return
	var speed := Rules.EMPLOYEE_SPEED
	if boost_left > 0.0:
		speed *= Rules.RESCUE_BOOST_MUL
	if is_bot():
		velocity = input_dir.normalized() * speed if input_dir.length() > 0.1 else Vector2.ZERO
	else:
		velocity = input_dir.limit_length(1.0) * speed
	move_and_slide()
	if velocity.length() > 8.0:
		_facing = velocity.normalized()
	if want_interact:
		_try_employee_interact()


func _sit_work(delta: float, slack: bool) -> void:
	velocity = Vector2.ZERO
	var supervised := Match.is_supervised(self)
	if slack:
		energy = min(Rules.ENERGY_MAX, energy + Rules.SLACK_ENERGY_PER_SEC * delta)
		if supervised:
			slack_seen += delta
			if slack_seen >= Rules.SLACK_CATCH_DELAY:
				Match.catch_employee(self)
		else:
			slack_seen = 0.0
		return
	var mul := 1.0
	if coffee_buff > 0.0:
		mul *= Rules.COFFEE_BUFF_MUL
	if supervised:
		mul *= Rules.TIGER_SUPERVISE_MUL
	if energy <= 0.0:
		hours = max(0.0, hours - Rules.EMPTY_HOURS_PER_SEC * delta)
	else:
		hours = max(0.0, hours - Rules.WORK_HOURS_PER_SEC * mul * delta)
		energy = max(0.0, energy - Rules.WORK_ENERGY_PER_SEC * delta)


func _try_employee_interact() -> void:
	if stand_lock > 0.0:
		return
	if Match.try_carry(self):
		return
	if Match.try_rescue(self):
		return
	var map := office()
	if map.try_door(self):
		return
	var seat := map.nearest_spot("seat", global_position, Rules.INTERACT_RANGE)
	if seat != "":
		if map.take_spot(seat, slot):
			emp_state = Rules.EmpState.WORK
			global_position = map.points[seat]
			occupy_id = seat
			last_seat = int(seat.get_slice("_", 1))
		return
	var coffee := map.nearest_free("coffee", global_position)
	if coffee != "" and global_position.distance_to(map.points[coffee]) < Rules.INTERACT_RANGE:
		if map.take_spot(coffee, slot):
			occupy_id = coffee
			emp_state = Rules.EmpState.COFFEE
			global_position = map.points[coffee]
		return
	var toilet := map.nearest_free("toilet", global_position)
	if toilet != "" and global_position.distance_to(map.points[toilet]) < Rules.INTERACT_RANGE:
		if map.take_spot(toilet, slot):
			occupy_id = toilet
			emp_state = Rules.EmpState.TOILET
			global_position = map.points[toilet]


func _stand_up() -> void:
	office().free_spot(occupy_id, slot)
	occupy_id = ""
	emp_state = Rules.EmpState.WALK
	slack_seen = 0.0


func _begin_clocking() -> void:
	_stand_up()
	hours = 0.0
	emp_state = Rules.EmpState.CLOCKING


func _clock_out() -> void:
	emp_state = Rules.EmpState.LEFT
	visible = false
	Match.on_clock_out(slot)


func _tick_talk(delta: float) -> void:
	velocity = Vector2.ZERO
	var watched := Match.is_watched(self)
	var dur := Rules.TALK_WATCH_TIME if watched else Rules.TALK_ALONE_TIME
	talk_progress = min(1.0, talk_progress + delta / dur)
	if talk_progress >= 1.0:
		Match.finish_talk(self)


func begin_talk() -> void:
	Match.release_actor_carry(self, true)
	_stand_up()
	emp_state = Rules.EmpState.TALK
	talk_progress = 0.0
	clear_rescue()


func end_talk_rescued() -> void:
	emp_state = Rules.EmpState.WALK
	talk_progress = 0.0
	slack_seen = 0.0


func clear_rescue() -> void:
	rescue_left = 0.0
	rescue_slot = -1


func apply_catch(repeat: bool, extra_stun: float) -> void:
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	_stand_up()
	hours += Rules.CATCH_HOURS_REPEAT if repeat else Rules.CATCH_HOURS_FIRST
	stand_lock = Rules.CATCH_STAND_LOCK + extra_stun
	catch_chain = Rules.CATCH_CHAIN_WINDOW
	slack_seen = 0.0
	talk_progress = 0.0
	rescue_left = 0.0
	rescue_slot = -1


func send_to_meeting(seconds: float, meeting_pos: Vector2) -> void:
	Match.release_actor_carry(self, true)
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	_stand_up()
	emp_state = Rules.EmpState.MEETING
	meeting_left = seconds
	talk_progress = 0.0
	clear_rescue()
	global_position = meeting_pos


func _boss_tick(delta: float) -> void:
	var speed := Rules.BOSS_BASE_SPEED * Rules.TIGER_SPEED_MUL
	if dash_left > 0.0:
		speed = Rules.TIGER_DASH_SPEED
	if want_dash and dash_cd <= 0.0:
		dash_left = Rules.TIGER_DASH_TIME
		dash_cd = Rules.TIGER_DASH_CD
	velocity = input_dir.limit_length(1.0) * speed
	move_and_slide()
	if velocity.length() > 8.0:
		_facing = velocity.normalized()
	if want_interact:
		if not Match.try_catch(self) and office():
			office().try_door(self)
	if office():
		var stuck = office().nearest_door(global_position, 52.0)
		if stuck != null and stuck.closed:
			office().try_door(self)
	if want_meeting and meeting_cd <= 0.0:
		if Match.try_meeting(self):
			meeting_cd = Rules.TIGER_MEETING_CD
	if want_kpi and kpi_cd <= 0.0 and Match.elapsed >= Rules.KPI_UNLOCK:
		Match.cast_kpi()
		kpi_cd = Rules.KPI_CD
		kpi_flash = 1.6


func _move_towards(target: Vector2, speed: float, delta: float) -> void:
	var d := target - global_position
	if d.length() < 4.0:
		velocity = Vector2.ZERO
		return
	velocity = d.normalized() * speed
	move_and_slide()
	_facing = velocity.normalized()


func apply_input(x: float, y: float, interact: bool, slack: bool, meeting: bool, kpi: bool, dash: bool) -> void:
	input_dir = Vector2(x, y)
	if interact:
		want_interact = true
	if slack:
		want_slack = true
	if meeting:
		want_meeting = true
	if kpi:
		want_kpi = true
	if dash:
		want_dash = true


@rpc("any_peer", "unreliable")
func recv_input(x: float, y: float, interact: bool, slack: bool, meeting: bool, kpi: bool, dash: bool) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	apply_input(x, y, interact, slack, meeting, kpi, dash)


func apply_snapshot(px: float, py: float, st: int, h: float, e: float, vis: bool, mcd: float, kcd: float, dcd: float, talk: float = 0.0, rescue: float = 0.0) -> void:
	_remote_pos = Vector2(px, py)
	emp_state = st
	hours = h
	energy = e
	visible = vis
	meeting_cd = mcd
	kpi_cd = kcd
	dash_cd = dcd
	talk_progress = talk
	rescue_left = rescue
	if name_label:
		name_label.text = display_name


func _broadcast_state() -> void:
	Match.sync_actor.rpc(slot, global_position.x, global_position.y, emp_state, hours, energy, visible, meeting_cd, kpi_cd, dash_cd, occupy_id, talk_progress, rescue_left)


func _show_resource_bars() -> bool:
	if kind != Rules.Kind.EMPLOYEE or emp_state == Rules.EmpState.LEFT:
		return false
	var my := Match.my_slot()
	if my == Rules.Slot.BOSS:
		return false
	return Rules.slot_is_employee(my)


func _draw() -> void:
	if carried_by >= 0:
		return
	if kind == Rules.Kind.EMPLOYEE and emp_state == Rules.EmpState.TALK:
		var watched := Match.is_watched(self)
		var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
		var col := Color(0.85, 0.10, 0.08, (0.22 if watched else 0.13) * pulse)
		draw_circle(Vector2(0, -18), 52.0 * pulse, col)
		draw_arc(Vector2(0, -18), 56.0 * pulse, 0, TAU, 32, Color(0.92, 0.18, 0.14, 0.62 if watched else 0.34), 2.2)
	if kind == Rules.Kind.EMPLOYEE and (rescue_left > 0.0 or boost_left > 0.0):
		var a := 0.35 if rescue_left > 0.0 else 0.22
		draw_line(Vector2(-28, -8), Vector2(-8, -20), Color(1, 1, 0.7, a), 2.0)
		draw_line(Vector2(-24, 6), Vector2(-4, -4), Color(1, 1, 0.7, a), 2.0)
	if kind != Rules.Kind.EMPLOYEE:
		return
	if _show_resource_bars():
		var y := -78.0
		if name_label:
			y = name_label.position.y + 16.0
		_draw_meter(Vector2(-24, y), 48, 5, hours / Rules.HOURS_START, Color(0.24, 0.86, 0.94))
		_draw_meter(Vector2(-24, y + 8), 48, 5, energy / Rules.ENERGY_MAX, Color(0.96, 0.78, 0.29))
	if emp_state != Rules.EmpState.TALK:
		return
	var w := 42.0
	var ty := -100.0
	if name_label:
		ty = name_label.position.y - 10.0
	draw_rect(Rect2(-w * 0.5, ty, w, 6), Color(0.14, 0.14, 0.16, 0.9))
	var fill := Color(0.86, 0.22, 0.18) if Match.is_watched(self) else Color(0.95, 0.62, 0.22)
	draw_rect(Rect2(-w * 0.5, ty, w * clampf(talk_progress, 0.0, 1.0), 6), fill)


func _draw_meter(pos: Vector2, width: float, height: float, ratio: float, accent: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.16, 0.18, 0.22, 0.72))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0.0, 1.0), height)), accent)
