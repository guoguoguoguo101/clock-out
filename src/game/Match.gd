extends Node

signal lobby_changed
signal match_started
signal match_ended
signal hud_dirty
signal kpi_popup
signal caught(slot: int, repeat: bool, add_hours: float)
signal talked(slot: int)
signal rescued(slot: int, by_slot: int)

var phase := "lobby"
var playing := false
var short_match := false
var elapsed := 0.0
var time_left := Rules.MATCH_SECONDS
var countdown := 0.0

var slots: Dictionary = {
	Rules.Slot.BOSS: -1,
	Rules.Slot.EMP_A: -1,
	Rules.Slot.EMP_B: -1,
	Rules.Slot.EMP_C: -1,
	Rules.Slot.EMP_D: -1,
}
var names: Dictionary = {}
var clock_log: Dictionary = {}
var result: Dictionary = {}

var actors: Dictionary = {}
var office: OfficeMap
var world: Node2D
var bots: Array = []

var _actor_scene: PackedScene = preload("res://src/actor/Actor.tscn")


func _ready() -> void:
	Net.peer_list_changed.connect(_on_peers)
	set_process(true)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if phase == "countdown":
		countdown -= delta
		_sync_clock.rpc(phase, elapsed, time_left, countdown)
		if countdown <= 0.0:
			phase = "playing"
			playing = true
			match_started.emit()
	elif phase == "playing":
		elapsed += delta
		time_left = max(0.0, time_left - delta)
		for bot in bots:
			bot.tick(delta)
		_sync_clock.rpc(phase, elapsed, time_left, 0.0)
		hud_dirty.emit()
		if time_left <= 0.0 or _all_punched():
			_finish()


func bind_world(p_world: Node2D, p_office: OfficeMap) -> void:
	world = p_world
	office = p_office


func day_progress() -> float:
	var dur := Rules.SHORT_MATCH_SECONDS if short_match else Rules.MATCH_SECONDS
	if phase == "lobby" or phase == "countdown" or dur <= 0.01:
		return 0.0
	return clampf(1.0 - time_left / dur, 0.0, 1.0)


func my_slot() -> int:
	var id := multiplayer.get_unique_id()
	for s in slots.keys():
		if int(slots[s]) == id:
			return int(s)
	return -1


@rpc("any_peer", "reliable")
func request_claim(slot: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = multiplayer.get_unique_id()
	_claim(pid, slot, player_name)


func claim_local(slot: int, player_name: String) -> void:
	if multiplayer.is_server():
		_claim(multiplayer.get_unique_id(), slot, player_name)
	else:
		request_claim.rpc_id(1, slot, player_name)


func _claim(pid: int, slot: int, player_name: String) -> void:
	if phase != "lobby":
		return
	if not slots.has(slot):
		return
	for s in slots.keys():
		if int(slots[s]) == pid:
			slots[s] = -1
	if int(slots[slot]) != -1 and int(slots[slot]) != pid:
		return
	slots[slot] = pid
	names[pid] = player_name
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func request_start(p_short: bool, instant: bool = false) -> void:
	if not multiplayer.is_server():
		return
	_start(p_short, instant)


func start_local(p_short: bool, instant: bool = false) -> void:
	if multiplayer.is_server():
		_start(p_short, instant)
	else:
		request_start.rpc_id(1, p_short, instant)


func _start(p_short: bool, instant: bool = false) -> void:
	if phase != "lobby":
		return
	short_match = p_short
	time_left = Rules.SHORT_MATCH_SECONDS if p_short else Rules.MATCH_SECONDS
	elapsed = 0.0
	clock_log.clear()
	bots.clear()
	for s in slots.keys():
		if int(slots[s]) == -1:
			slots[s] = 0
			names[0] = "Bot"
	_spawn_all()
	_broadcast_lobby()
	begin_match.rpc(p_short, instant)


@rpc("authority", "call_local", "reliable")
func begin_match(p_short: bool, instant: bool = false) -> void:
	short_match = p_short
	time_left = Rules.SHORT_MATCH_SECONDS if p_short else Rules.MATCH_SECONDS
	elapsed = 0.0
	if office:
		office.reset_shift()
	if instant:
		phase = "playing"
		playing = true
		countdown = 0.0
	else:
		phase = "countdown"
		playing = false
		countdown = Rules.COUNTDOWN
	match_started.emit()


func _spawn_all() -> void:
	for a in actors.values():
		(a as Node).queue_free()
	actors.clear()
	if office == null:
		return
	office.reset_shift()
	for k in office.occupiers.keys():
		office.occupiers[k] = -1
	for s in slots.keys():
		var pid := int(slots[s])
		var actor: Actor = _actor_scene.instantiate()
		var pname := _name_for(pid, int(s))
		actor.setup(int(s), pid, pname)
		office.add_child(actor, true)
		if int(s) == Rules.Slot.BOSS:
			actor.global_position = office.points["boss_spawn"]
		else:
			actor.global_position = office.seat_for_slot(int(s))
			actor.emp_state = Rules.EmpState.WORK
			actor.occupy_id = "seat_%d" % (Rules.employee_index(int(s)) + 1)
			actor.last_seat = Rules.employee_index(int(s)) + 1
			office.take_spot(actor.occupy_id, int(s))
		actors[int(s)] = actor
		spawn_actor.rpc(int(s), pid, pname, actor.global_position.x, actor.global_position.y, actor.emp_state)
		if pid == 0:
			if int(s) == Rules.Slot.BOSS:
				bots.append(BossBot.new(actor, office))
			else:
				bots.append(EmployeeBot.new(actor, office))


@rpc("authority", "reliable")
func spawn_actor(slot: int, pid: int, pname: String, x: float, y: float, st: int) -> void:
	if multiplayer.is_server():
		return
	if office == null:
		return
	if office.has_node("actor_%d" % slot):
		office.get_node("actor_%d" % slot).queue_free()
	var actor: Actor = _actor_scene.instantiate()
	actor.setup(slot, pid, pname)
	office.add_child(actor, true)
	actor.global_position = Vector2(x, y)
	actor.emp_state = st
	actors[slot] = actor


@rpc("authority", "unreliable")
func sync_actor(slot: int, x: float, y: float, st: int, h: float, e: float, vis: bool, mcd: float, kcd: float, dcd: float, _occ: String, talk: float = 0.0, rescue: float = 0.0) -> void:
	if multiplayer.is_server():
		return
	if not actors.has(slot):
		return
	(actors[slot] as Actor).apply_snapshot(x, y, st, h, e, vis, mcd, kcd, dcd, talk, rescue)


@rpc("authority", "unreliable")
func _sync_clock(p_phase: String, p_elapsed: float, p_left: float, p_cd: float) -> void:
	phase = p_phase
	elapsed = p_elapsed
	time_left = p_left
	countdown = p_cd
	playing = p_phase == "playing"
	hud_dirty.emit()


func is_supervised(emp: Actor) -> bool:
	if not actors.has(Rules.Slot.BOSS):
		return false
	var boss: Actor = actors[Rules.Slot.BOSS]
	if boss.global_position.distance_to(emp.global_position) <= Rules.SUPERVISE_DIST:
		return true
	var sid := emp.occupy_id
	if sid == "" or not sid.begins_with("seat_"):
		if emp.last_seat > 0:
			sid = "seat_%d" % emp.last_seat
		else:
			return false
	var key := "sup_%s" % sid.get_slice("_", 1)
	if not office.points.has(key):
		return false
	return boss.global_position.distance_to(office.points[key]) <= Rules.SUPERVISE_DIST


func is_watched(emp: Actor) -> bool:
	if office == null or not actors.has(Rules.Slot.BOSS):
		return false
	var boss: Actor = actors[Rules.Slot.BOSS]
	if boss == null:
		return false
	return office.same_view(boss.global_position, emp.global_position)


func is_catchable(emp: Actor) -> bool:
	if emp.kind != Rules.Kind.EMPLOYEE:
		return false
	if emp.emp_state == Rules.EmpState.SLACK or emp.emp_state == Rules.EmpState.COFFEE or emp.emp_state == Rules.EmpState.TOILET:
		return true
	return emp.rescue_left > 0.0


func nearest_talk(from: Vector2, max_d: float) -> Actor:
	var best: Actor = null
	var best_d := max_d
	for a in actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE or e.emp_state != Rules.EmpState.TALK:
			continue
		var d := from.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func try_catch(boss: Actor) -> bool:
	for a in actors.values():
		var e := a as Actor
		if not is_catchable(e):
			continue
		if boss.global_position.distance_to(e.global_position) > Rules.CATCH_RANGE:
			continue
		catch_employee(e)
		return true
	return false


func catch_employee(emp: Actor) -> void:
	start_talk(emp)


func start_talk(emp: Actor) -> void:
	if not multiplayer.is_server():
		return
	if emp.emp_state == Rules.EmpState.CLOCKING or emp.emp_state == Rules.EmpState.LEFT:
		return
	if emp.emp_state == Rules.EmpState.TALK or emp.emp_state == Rules.EmpState.MEETING:
		return
	emp.begin_talk()
	notify_talked.rpc(emp.slot)


func finish_talk(emp: Actor) -> void:
	if not multiplayer.is_server():
		return
	if emp.emp_state != Rules.EmpState.TALK:
		return
	var repeat := emp.catch_chain > 0.0
	var add := Rules.CATCH_HOURS_REPEAT if repeat else Rules.CATCH_HOURS_FIRST
	emp.apply_catch(repeat, 0.0)
	notify_caught.rpc(emp.slot, repeat, add)


func try_rescue(rescuer: Actor) -> bool:
	if rescuer.stand_lock > 0.0 or rescuer.rescue_left > 0.0:
		return false
	if rescuer.emp_state != Rules.EmpState.WALK:
		return false
	var vic := nearest_talk(rescuer.global_position, Rules.RESCUE_RANGE)
	if vic == null:
		return false
	if is_watched(vic):
		var boss: Actor = actors.get(Rules.Slot.BOSS) as Actor
		if boss != null and boss.global_position.distance_to(rescuer.global_position) <= Rules.CATCH_RANGE:
			start_talk(rescuer)
		return true
	rescuer.rescue_slot = vic.slot
	rescuer.rescue_left = Rules.RESCUE_TIME
	return true


func tick_rescue(rescuer: Actor, delta: float) -> bool:
	if not actors.has(rescuer.rescue_slot):
		rescuer.clear_rescue()
		return false
	var vic: Actor = actors[rescuer.rescue_slot]
	if vic.emp_state != Rules.EmpState.TALK:
		rescuer.clear_rescue()
		return false
	if is_watched(vic):
		rescuer.clear_rescue()
		return false
	if rescuer.global_position.distance_to(vic.global_position) > Rules.RESCUE_RANGE + 16.0:
		rescuer.clear_rescue()
		return false
	rescuer.rescue_left -= delta
	if rescuer.rescue_left <= 0.0:
		complete_rescue(rescuer, vic)
		return false
	return true


func complete_rescue(rescuer: Actor, vic: Actor) -> void:
	vic.end_talk_rescued()
	rescuer.clear_rescue()
	vic.boost_left = Rules.RESCUE_BOOST_TIME
	rescuer.boost_left = Rules.RESCUE_BOOST_TIME
	notify_rescued.rpc(vic.slot, rescuer.slot)


@rpc("authority", "call_local", "reliable")
func notify_caught(slot: int, repeat: bool, add_hours: float) -> void:
	caught.emit(slot, repeat, add_hours)


@rpc("authority", "call_local", "reliable")
func notify_talked(slot: int) -> void:
	talked.emit(slot)


@rpc("authority", "call_local", "reliable")
func notify_rescued(slot: int, by_slot: int) -> void:
	rescued.emit(slot, by_slot)


func try_meeting(boss: Actor) -> bool:
	var best: Actor = null
	var best_d := 420.0
	for a in actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE:
			continue
		if e.emp_state == Rules.EmpState.LEFT or e.emp_state == Rules.EmpState.CLOCKING:
			continue
		var d := boss.global_position.distance_to(e.global_position)
		if d > best_d:
			continue
		if not _can_see(boss.global_position, e.global_position):
			continue
		best = e
		best_d = d
	if best == null:
		return false
	best.send_to_meeting(Rules.TIGER_MEETING_TIME, office.points["meeting"])
	return true


func _can_see(from: Vector2, to: Vector2) -> bool:
	var space := office.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func cast_kpi() -> void:
	for a in actors.values():
		var e := a as Actor
		if e.kind == Rules.Kind.EMPLOYEE and e.emp_state != Rules.EmpState.LEFT:
			e.hours += Rules.KPI_HOURS
	show_kpi.rpc()


@rpc("authority", "call_local", "reliable")
func show_kpi() -> void:
	kpi_popup.emit()


func on_clock_out(slot: int) -> void:
	clock_log[slot] = elapsed
	if _all_punched():
		_finish()


func _all_punched() -> bool:
	for s in [Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D]:
		if not actors.has(s):
			return false
		if (actors[s] as Actor).emp_state != Rules.EmpState.LEFT:
			return false
	return true


func _finish() -> void:
	if phase == "result":
		return
	playing = false
	phase = "result"
	var punched := 0
	var people: Array = []
	for s in [Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D]:
		var actor: Actor = actors[s]
		var win := actor.emp_state == Rules.EmpState.LEFT
		if win:
			punched += 1
		people.append({
			"slot": s,
			"name": actor.display_name,
			"win": win,
			"time": clock_log.get(s, -1.0),
		})
	var boss_verdict := "胜"
	if punched == 3:
		boss_verdict = "平"
	elif punched >= 4:
		boss_verdict = "负"
	result = {"punched": punched, "boss": boss_verdict, "people": people}
	finish_match.rpc(result)
	match_ended.emit()


@rpc("authority", "call_local", "reliable")
func finish_match(p_result: Dictionary) -> void:
	result = p_result
	playing = false
	phase = "result"
	match_ended.emit()


func _broadcast_lobby() -> void:
	sync_lobby.rpc(slots, names, short_match, phase)


@rpc("authority", "call_local", "reliable")
func sync_lobby(p_slots: Dictionary, p_names: Dictionary, p_short: bool, p_phase: String) -> void:
	slots = {
		Rules.Slot.BOSS: -1,
		Rules.Slot.EMP_A: -1,
		Rules.Slot.EMP_B: -1,
		Rules.Slot.EMP_C: -1,
		Rules.Slot.EMP_D: -1,
	}
	for k in p_slots.keys():
		slots[int(k)] = int(p_slots[k])
	names = {}
	for k in p_names.keys():
		names[int(k)] = str(p_names[k])
	short_match = p_short
	if phase == "lobby" or p_phase == "lobby":
		phase = p_phase
	lobby_changed.emit()


func _on_peers() -> void:
	if not multiplayer.is_server():
		return
	var alive: Dictionary = {}
	alive[1] = true
	for id in multiplayer.get_peers():
		alive[int(id)] = true
	for s in slots.keys():
		var pid := int(slots[s])
		if pid > 0 and not alive.has(pid):
			slots[s] = -1
	_broadcast_lobby()


func _name_for(pid: int, slot: int) -> String:
	if pid == 0:
		return "Bot·" + str(Rules.SLOT_NAMES[slot])
	if names.has(pid):
		return str(names[pid])
	return Rules.SLOT_NAMES[slot]


func back_to_lobby() -> void:
	if multiplayer.is_server():
		_reset_lobby()
	else:
		request_reset.rpc_id(1)


@rpc("any_peer", "reliable")
func request_reset() -> void:
	if multiplayer.is_server():
		_reset_lobby()


func _reset_lobby() -> void:
	if office != null:
		for k in office.occupiers.keys():
			office.occupiers[k] = -1
	for s in slots.keys():
		if int(slots[s]) == 0:
			slots[s] = -1
	reset_lobby.rpc()
	_broadcast_lobby()


@rpc("authority", "call_local", "reliable")
func reset_lobby() -> void:
	playing = false
	phase = "lobby"
	countdown = 0.0
	clock_log.clear()
	result = {}
	for a in actors.values():
		if is_instance_valid(a):
			(a as Node).queue_free()
	actors.clear()
	bots.clear()
	lobby_changed.emit()
