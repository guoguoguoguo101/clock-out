extends CharacterBody2D
class_name Actor

const SNAP_HZ := 15.0

@onready var name_label: Label = $Name

var slot := 0
var peer_id := 0
var kind := Rules.Kind.EMPLOYEE
var skin := Rules.CharSkin.CAT
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
var left_clock := ""

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
	sh.radius = 16
	cs.shape = sh
	var nl := get_node("Name") as Label
	nl.position = Vector2(-72, -152)
	nl.size = Vector2(144, 28)
	nl.add_theme_font_size_override("font_size", 18)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func is_local() -> bool:
	return peer_id != 0 and peer_id == multiplayer.get_unique_id()


func is_bot() -> bool:
	return peer_id == 0


func office() -> OfficeMap:
	return get_parent() as OfficeMap


func nearby_action() -> String:
	if kind != Rules.Kind.EMPLOYEE:
		return ""
	if emp_state == Rules.EmpState.WORK or emp_state == Rules.EmpState.SLACK:
		return "E 起身    F 摸鱼"
	if emp_state == Rules.EmpState.COFFEE or emp_state == Rules.EmpState.TOILET:
		return "E 离开"
	if emp_state == Rules.EmpState.CLOCKING:
		return "正在去打卡"
	if emp_state == Rules.EmpState.MEETING:
		return "开会中"
	if stand_lock > 0.0:
		return ""
	var map := office()
	if map == null:
		return ""
	var idx := Rules.employee_index(slot) + 1
	if global_position.distance_to(map.points["seat_%d" % idx]) < Rules.INTERACT_RANGE:
		return "E 坐下上班"
	for i in 4:
		var other := i + 1
		if other == idx:
			continue
		if global_position.distance_to(map.points["seat_%d" % other]) < Rules.INTERACT_RANGE:
			return "别人的工位"
	var coffee := map.nearest_free("coffee", global_position)
	if coffee != "" and global_position.distance_to(map.points[coffee]) < Rules.INTERACT_RANGE:
		return "E 喝咖啡"
	var toilet := map.nearest_free("toilet", global_position)
	if toilet != "" and global_position.distance_to(map.points[toilet]) < Rules.INTERACT_RANGE:
		return "E 上厕所"
	return ""


func remaining_work_sec() -> float:
	return hours / Rules.WORK_HOURS_PER_SEC


func _ready() -> void:
	_remote_pos = global_position
	if name_label:
		name_label.text = display_name
	queue_redraw()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and Match.playing:
		_server_tick(delta)
		_sync_acc += delta
		if _sync_acc >= 1.0 / SNAP_HZ:
			_sync_acc = 0.0
			_broadcast_state()
	elif not multiplayer.is_server():
		global_position = global_position.lerp(_remote_pos, 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _server_tick(delta: float) -> void:
	stand_lock = max(0.0, stand_lock - delta)
	catch_chain = max(0.0, catch_chain - delta)
	coffee_buff = max(0.0, coffee_buff - delta)
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
	if emp_state == Rules.EmpState.LEFT:
		visible = false
		velocity = Vector2.ZERO
		return
	if hours <= 0.0 and emp_state != Rules.EmpState.CLOCKING:
		_begin_clocking()
	match emp_state:
		Rules.EmpState.MEETING:
			meeting_left -= delta
			energy = max(0.0, energy - Rules.MEETING_ENERGY_PER_SEC * delta)
			velocity = Vector2.ZERO
			if meeting_left <= 0.0:
				emp_state = Rules.EmpState.WALK
			return
		Rules.EmpState.CLOCKING:
			var target: Vector2 = office().nearest_punch(global_position)
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
	var speed := Rules.EMPLOYEE_SPEED
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
				Match.catch_employee(self, false)
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
	var map := office()
	var idx := Rules.employee_index(slot) + 1
	if global_position.distance_to(map.points["seat_%d" % idx]) < Rules.INTERACT_RANGE:
		emp_state = Rules.EmpState.WORK
		global_position = map.points["seat_%d" % idx]
		occupy_id = "seat_%d" % idx
		map.take_spot(occupy_id, slot)
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


func apply_catch(repeat: bool, extra_stun: float) -> void:
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	_stand_up()
	hours += Rules.CATCH_HOURS_REPEAT if repeat else Rules.CATCH_HOURS_FIRST
	stand_lock = Rules.CATCH_STAND_LOCK + extra_stun
	catch_chain = Rules.CATCH_CHAIN_WINDOW
	slack_seen = 0.0


func send_to_meeting(seconds: float, meeting_pos: Vector2) -> void:
	if emp_state == Rules.EmpState.CLOCKING or emp_state == Rules.EmpState.LEFT:
		return
	_stand_up()
	emp_state = Rules.EmpState.MEETING
	meeting_left = seconds
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
		Match.try_catch(self)
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


func apply_snapshot(px: float, py: float, st: int, h: float, e: float, vis: bool, mcd: float, kcd: float, dcd: float) -> void:
	_remote_pos = Vector2(px, py)
	emp_state = st
	hours = h
	energy = e
	visible = vis
	meeting_cd = mcd
	kpi_cd = kcd
	dash_cd = dcd
	if name_label:
		name_label.text = display_name


func _broadcast_state() -> void:
	Match.sync_actor.rpc(slot, global_position.x, global_position.y, emp_state, hours, energy, visible, meeting_cd, kpi_cd, dash_cd, occupy_id)


func _draw() -> void:
	var boss := kind == Rules.Kind.BOSS
	var s := Rules.BOSS_SCALE if boss else Rules.CHAR_SCALE
	var body := Color(0.12, 0.12, 0.12)
	var scarf := Color(0.89, 0.23, 0.23)
	match skin:
		Rules.CharSkin.CAT:
			body = Color(0.12, 0.12, 0.12)
			scarf = Color(0.89, 0.23, 0.23)
		Rules.CharSkin.RABBIT:
			body = Color(0.96, 0.94, 0.9)
			scarf = Color(0.96, 0.76, 0.29)
		Rules.CharSkin.PENGUIN:
			body = Color(0.15, 0.16, 0.18)
			scarf = Color(0.18, 0.77, 0.71)
		Rules.CharSkin.PANDA:
			body = Color(0.95, 0.95, 0.95)
			scarf = Color(0.96, 0.64, 0.38)
		Rules.CharSkin.TIGER:
			body = Color(0.93, 0.6, 0.22)
			scarf = Color(0.77, 0.12, 0.23)
	draw_circle(Vector2(0, 16) * s, 18 * s, Color(0, 0, 0, 0.1))
	draw_circle(Vector2(0, -8) * s, 20 * s, body)
	draw_circle(Vector2(0, 18) * s, 18 * s, body)
	if skin == Rules.CharSkin.CAT or skin == Rules.CharSkin.TIGER:
		draw_circle(Vector2(-12, -22) * s, 7 * s, body)
		draw_circle(Vector2(12, -22) * s, 7 * s, body)
	if skin == Rules.CharSkin.RABBIT:
		draw_rect(Rect2(Vector2(-13, -40) * s, Vector2(7, 22) * s), body)
		draw_rect(Rect2(Vector2(6, -40) * s, Vector2(7, 22) * s), body)
	if skin == Rules.CharSkin.PANDA:
		draw_circle(Vector2(-11, -22) * s, 7 * s, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(11, -22) * s, 7 * s, Color(0.1, 0.1, 0.1))
	if skin != Rules.CharSkin.RABBIT and skin != Rules.CharSkin.PANDA:
		draw_circle(Vector2(-7, -10) * s, 3.8 * s, Color.WHITE)
		draw_circle(Vector2(7, -10) * s, 3.8 * s, Color.WHITE)
	else:
		draw_circle(Vector2(-7, -10) * s, 3.8 * s, Color(0.12, 0.12, 0.12))
		draw_circle(Vector2(7, -10) * s, 3.8 * s, Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(Vector2(-14, 4) * s, Vector2(28, 7) * s), scarf)
	if emp_state == Rules.EmpState.SLACK:
		draw_circle(Vector2(18, -26) * s, 6 * s, Color(0.2, 0.2, 0.2, 0.5))
	if kpi_flash > 0.0 and boss:
		draw_arc(Vector2.ZERO, 38 * s, 0, TAU, 24, Color(0.9, 0.2, 0.2, kpi_flash), 4.0)
	if kind == Rules.Kind.EMPLOYEE and _show_resource_bars():
		_draw_stat_bar(Vector2(-28, -34) * s, hours, Color(0.35, 0.55, 0.95))
		_draw_stat_bar(Vector2(-28, -28) * s, energy, Color(0.95, 0.72, 0.2))
	if is_local() and emp_state == Rules.EmpState.WALK:
		var act := nearby_action()
		if act.begins_with("E"):
			draw_circle(Vector2(0, -58) * s, 12, Color(0.12, 0.12, 0.12, 0.88))
			draw_string(ThemeDB.fallback_font, Vector2(-5, -54) * s, "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _show_resource_bars() -> bool:
	var my := Match.my_slot()
	return Rules.slot_is_employee(my)


func _draw_stat_bar(pos: Vector2, value: float, color: Color) -> void:
	var w := 56.0
	var h := 5.0
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(pos, Vector2(w * clampf(value / 100.0, 0.0, 1.0), h)), color)
