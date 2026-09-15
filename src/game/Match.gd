extends Node

signal lobby_changed
signal match_started
signal match_ended
signal hud_dirty
signal kpi_popup
signal caught(slot: int, repeat: bool, add_hours: float)
signal talked(slot: int)
signal rescued(slot: int, by_slot: int)
signal stock_played(slot: int, pnl: float, energy_loss: float, boosted: bool)

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
	Rules.Slot.EMP_E: -1,
	Rules.Slot.EMP_F: -1,
}
var names: Dictionary = {}
var clock_log: Dictionary = {}
var result: Dictionary = {}

var actors: Dictionary = {}
var office: OfficeMap
var world: Node2D
var bots: Array = []
var reports: Dictionary = {}
var _next_report_id := 1

var _actor_scene: PackedScene = preload("res://src/actor/Actor.tscn")


func _ready() -> void:
	Net.peer_list_changed.connect(_on_peers)
	set_process(true)


func _process(delta: float) -> void:
	if Net.using_go:
		return
	if not Net.is_enet_server():
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
	var id := Net.go_peer_id if Net.using_go else (multiplayer.get_unique_id() if Net.has_peer() else 0)
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
	if int(slots[slot]) != -1 and int(slots[slot]) != pid and int(slots[slot]) != 0:
		return
	slots[slot] = pid
	names[pid] = player_name
	_broadcast_lobby()


func set_bot_local(slot: int, on: bool) -> void:
	if not Net.is_enet_server():
		return
	_set_bot(slot, on)


func _set_bot(slot: int, on: bool) -> void:
	if phase != "lobby" or not slots.has(slot):
		return
	var cur := int(slots[slot])
	if on:
		if cur > 0:
			return
		slots[slot] = 0
		names[0] = "Bot"
	else:
		if cur != 0:
			return
		slots[slot] = -1
	_broadcast_lobby()


func fill_empty_bots_local() -> void:
	if not Net.is_enet_server() or phase != "lobby":
		return
	for s in slots.keys():
		if int(slots[s]) == -1:
			slots[s] = 0
	names[0] = "Bot"
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
	_clear_reports()
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
		if pid < 0:
			continue
		var actor: Actor = _actor_scene.instantiate()
		var pname := _name_for(pid, int(s))
		actor.setup(int(s), pid, pname)
		office.add_child(actor, true)
		if int(s) == Rules.Slot.BOSS:
			actor.global_position = office.points["boss_spawn"]
		else:
			actor.global_position = office.seat_for_slot(int(s))
			actor.emp_state = Rules.EmpState.WALK
			actor.energy_cells = 0
			actor.energy_charge = 0.0
			actor.tasks_done = 0
			actor._refresh_legacy()
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
	if Rules.slot_is_employee(slot):
		actor.energy_cells = 0
		actor.energy_charge = 0.0
		actor.tasks_done = 0
		actor.tasking = false
		actor._refresh_legacy()
	actors[slot] = actor


@rpc("authority", "unreliable")
func sync_actor(slot: int, x: float, y: float, st: int, h: float, e: float, vis: bool, mcd: float, kcd: float, dcd: float, _occ: String, talk: float = 0.0, rescue: float = 0.0, bike: float = 0.0, slow: float = 0.0, rcd: float = 0.0, fcd: float = 0.0) -> void:
	if multiplayer.is_server():
		return
	if not actors.has(slot):
		return
	var actor := actors[slot] as Actor
	var state := Rules.EmpState.CARRIED if actor.carried_by >= 0 else (Rules.EmpState.WALK if st == Rules.EmpState.CARRIED else st)
	actor.apply_snapshot(x, y, state, h, e, vis, mcd, kcd, dcd, talk, rescue, bike, slow, rcd, fcd)


@rpc("authority", "unreliable")
func sync_cells(slot: int, done: int, progress: float, cells: int, charge: float, kind: String, t: float, mark: float, hits: int, msg: String, busy: int, occ := "") -> void:
	if multiplayer.is_server():
		return
	if not actors.has(slot):
		return
	var actor := actors[slot] as Actor
	actor.tasks_done = done
	actor.task_progress = progress
	actor.energy_cells = cells
	actor.energy_charge = charge
	actor.play_kind = kind
	actor.play_t = t
	actor.play_mark = mark
	actor.play_hits = hits
	actor.play_msg = msg
	actor.tasking = busy == 1
	if occ != "":
		actor.occupy_id = occ
	actor._refresh_legacy()


@rpc("authority", "unreliable")
func sync_trade(slot: int, left: float, price: float, cash: float, shares: float, holding: bool, hist: PackedFloat32Array) -> void:
	if not actors.has(slot):
		return
	(actors[slot] as Actor).apply_trade(left, price, cash, shares, holding, hist)


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
	if emp.emp_state == Rules.EmpState.SLACK or emp.emp_state == Rules.EmpState.COFFEE or emp.emp_state == Rules.EmpState.TOILET or emp.emp_state == Rules.EmpState.TRADE:
		return true
	if emp.play_kind != "":
		return true
	return emp.rescue_left > 0.0 or emp.carrying_slot >= 0


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


# Prototype interaction: any available employee can take the pelican shuttle.
func nearest_carry_target(carrier: Actor) -> Actor:
	if carrier.skin != Rules.CharSkin.PELICAN or carrier.carry_recovery > 0.0 or carrier.carrying_slot >= 0:
		return null
	var best: Actor = null
	var distance := Rules.CARRY_RANGE
	for value in actors.values():
		var candidate := value as Actor
		if candidate == carrier or candidate.kind != Rules.Kind.EMPLOYEE or candidate.carried_by >= 0:
			continue
		if candidate.emp_state in [Rules.EmpState.MEETING, Rules.EmpState.CLOCKING, Rules.EmpState.LEFT]:
			continue
		var d := carrier.global_position.distance_to(candidate.global_position)
		if d < distance and _can_see(carrier.global_position, candidate.global_position):
			best = candidate
			distance = d
	return best


func try_bike(rider: Actor) -> bool:
	if not multiplayer.is_server() or not playing or rider.is_bot():
		return false
	if rider.skin != Rules.CharSkin.KANGAROO:
		return false
	if rider.emp_state != Rules.EmpState.WALK or rider.stand_lock > 0.0:
		return false
	if rider.bike_left > 0.0 or rider.carrying_slot >= 0 or rider.carried_by >= 0:
		return false
	rider.bike_left = Rules.BIKE_DURATION
	bike_event.rpc(rider.slot, true)
	return true


func clear_bike(rider: Actor) -> void:
	if not multiplayer.is_server():
		return
	rider.bike_left = 0.0
	bike_event.rpc(rider.slot, false)


@rpc("authority", "call_local", "reliable")
func bike_event(slot: int, on: bool) -> void:
	var rider := actors.get(slot) as Actor
	if rider == null:
		return
	rider.bike_left = Rules.BIKE_DURATION if on else 0.0
	rider._update_bike_visual(on)
	if on:
		rider.say("电瓶车，走起！", 1.3)


func try_carry(carrier: Actor) -> bool:
	if not multiplayer.is_server() or not playing or carrier.is_bot():
		return false
	if carrier.emp_state != Rules.EmpState.WALK or carrier.stand_lock > 0.0 or carrier.carried_by >= 0:
		return false
	var passenger := nearest_carry_target(carrier)
	if passenger == null:
		return false
	passenger.carry_saved_talk = passenger.talk_progress if passenger.emp_state == Rules.EmpState.TALK else -1.0
	passenger._stand_up()
	passenger.clear_rescue()
	if passenger.bike_left > 0.0:
		clear_bike(passenger)
	carrier.clear_rescue()
	carrier._facing.x = 1.0 if passenger.global_position.x >= carrier.global_position.x else -1.0
	carry_event.rpc(carrier.slot, passenger.slot, true, passenger.global_position, false, carrier._facing.x)
	return true


func release_actor_carry(actor: Actor, interrupted := false) -> void:
	if actor.carrying_slot >= 0:
		release_carry(actor, interrupted)
	elif actor.carried_by >= 0:
		var carrier := actors.get(actor.carried_by) as Actor
		if carrier != null:
			release_carry(carrier, interrupted)


func release_carry(carrier: Actor, interrupted := false) -> void:
	if not multiplayer.is_server() or carrier.carrying_slot < 0:
		return
	var passenger := actors.get(carrier.carrying_slot) as Actor
	if passenger == null:
		carrier.carrying_slot = -1
		return
	# Use a swept body check; fallback to the carrier's safe foot position.
	var landing := carrier.global_position
	for direction in [Vector2(carrier._facing.x, 0).normalized(), Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		if direction == Vector2.ZERO:
			continue
		var movement: Vector2 = direction * 30.0
		if not passenger.test_move(Transform2D(0.0, carrier.global_position), movement):
			landing += movement
			break
	carry_event.rpc(carrier.slot, passenger.slot, false, landing, interrupted, carrier._facing.x)


@rpc("authority", "call_local", "reliable")
func carry_event(carrier_slot: int, passenger_slot: int, pickup: bool, pos: Vector2, interrupted: bool, facing: float) -> void:
	var carrier := actors.get(carrier_slot) as Actor
	var passenger := actors.get(passenger_slot) as Actor
	if carrier == null or passenger == null:
		return
	carrier._facing.x = facing
	if pickup:
		carrier.carrying_slot = passenger_slot
		carrier.carry_left = Rules.CARRY_DURATION
		carrier.carry_windup = Rules.CARRY_WINDUP
		passenger.carried_by = carrier_slot
		passenger.emp_state = Rules.EmpState.CARRIED
		passenger.velocity = Vector2.ZERO
		if carrier.carry_visual:
			carrier.carry_visual.pickup(passenger, pos)
		carrier.say("接活水，走你！", 1.5)
	else:
		carrier.carrying_slot = -1
		carrier.carry_left = 0.0
		carrier.carry_windup = 0.0
		carrier.carry_recovery = Rules.CARRY_RECOVERY
		passenger.carried_by = -1
		passenger.emp_state = Rules.EmpState.TALK if interrupted and passenger.carry_saved_talk >= 0.0 else Rules.EmpState.WALK
		passenger.talk_progress = maxf(0.0, passenger.carry_saved_talk) if interrupted else 0.0
		passenger.carry_saved_talk = -1.0
		passenger.global_position = pos
		passenger._remote_pos = pos
		passenger.landing_left = 0.4
		passenger.input_dir = Vector2.ZERO
		passenger.want_interact = false
		if carrier.carry_visual:
			carrier.carry_visual.release()
		passenger.say("谢谢顺风嘴！" if not interrupted else "转运中断！", 1.4)


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


func apply_stock_boost(from_slot: int, pnl: float) -> void:
	if not multiplayer.is_server():
		return
	for a in actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE:
			continue
		if e.emp_state == Rules.EmpState.LEFT:
			continue
		e.boost_left = maxf(e.boost_left, Rules.STOCK_BOOST_TIME)
	notify_stock.rpc(from_slot, pnl, 0.0, true)


@rpc("authority", "call_local", "reliable")
func notify_stock(slot: int, pnl: float, energy_loss: float, boosted: bool) -> void:
	if boosted:
		for a in actors.values():
			var e := a as Actor
			if e.kind != Rules.Kind.EMPLOYEE:
				continue
			if e.emp_state == Rules.EmpState.LEFT:
				continue
			e.boost_left = maxf(e.boost_left, Rules.STOCK_BOOST_TIME)
	stock_played.emit(slot, pnl, energy_loss, boosted)


func trade_threat(emp: Actor) -> float:
	if emp == null or office == null or not actors.has(Rules.Slot.BOSS):
		return 0.0
	var boss: Actor = actors[Rules.Slot.BOSS]
	if boss == null:
		return 0.0
	var d := emp.global_position.distance_to(boss.global_position)
	var t := 1.0 - clampf((d - Rules.CATCH_RANGE) / maxf(Rules.STOCK_NEAR - Rules.CATCH_RANGE, 1.0), 0.0, 1.0)
	if office.same_view(emp.global_position, boss.global_position):
		t = maxf(t, 0.58)
	return t


func try_meeting(boss: Actor) -> bool:
	var best: Actor = null
	var best_d := 420.0
	for a in actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE:
			continue
		if e.emp_state in [Rules.EmpState.LEFT, Rules.EmpState.CLOCKING, Rules.EmpState.CARRIED]:
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


func paper_blocked(from: Vector2, to: Vector2) -> bool:
	if office == null:
		return false
	var space := office.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = OfficeMap.PAPER_BLOCK
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


func report_hittable(emp: Actor) -> bool:
	if emp == null or emp.kind != Rules.Kind.EMPLOYEE:
		return false
	if emp.emp_state in [Rules.EmpState.LEFT, Rules.EmpState.TALK, Rules.EmpState.MEETING, Rules.EmpState.CARRIED]:
		return false
	return true


func report_victim(pos: Vector2) -> Actor:
	var best: Actor = null
	var best_d := Rules.REPORT_HIT_RADIUS
	for a in actors.values():
		var e := a as Actor
		if not report_hittable(e):
			continue
		var d := pos.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func try_throw_reports(boss: Actor, fan: bool) -> bool:
	if boss == null or office == null:
		return false
	var aim := boss.facing_dir()
	var origin := boss.throw_origin()
	var dirs: Array[Vector2] = []
	if fan:
		var n := Rules.REPORT_FAN_COUNT
		var spread := deg_to_rad(Rules.REPORT_FAN_SPREAD)
		for i in n:
			var t := 0.0 if n <= 1 else float(i) / float(n - 1)
			dirs.append(aim.rotated(-spread * 0.5 + spread * t))
	else:
		dirs.append(aim)
	for i in dirs.size():
		var id := _next_report_id
		_next_report_id += 1
		var speed_mul := 1.0 if not fan else randf_range(0.92, 1.08)
		spawn_report.rpc(id, origin.x, origin.y, dirs[i].x, dirs[i].y, speed_mul)
	return true


@rpc("authority", "call_local", "reliable")
func spawn_report(id: int, x: float, y: float, dx: float, dy: float, speed_mul: float = 1.0) -> void:
	if office == null:
		return
	var paper := WeeklyReport.new()
	paper.setup(id, Vector2(x, y), Vector2(dx, dy), multiplayer.is_server(), speed_mul)
	office.add_child(paper)
	reports[id] = paper


func end_report(id: int, slot: int) -> void:
	if not multiplayer.is_server():
		return
	if not reports.has(id):
		return
	var paper = reports[id]
	if paper == null or not paper.flying:
		return
	if slot >= 0:
		var emp: Actor = actors.get(slot) as Actor
		if emp != null and emp.apply_report_hit():
			notify_report_hit.rpc(slot)
		else:
			slot = -1
	finish_report.rpc(id, slot)


@rpc("authority", "call_local", "reliable")
func finish_report(id: int, slot: int) -> void:
	var paper = reports.get(id)
	if paper != null and is_instance_valid(paper):
		paper.begin_burst(slot >= 0)
	reports.erase(id)


@rpc("authority", "reliable")
func notify_report_hit(slot: int) -> void:
	if multiplayer.is_server():
		return
	var emp: Actor = actors.get(slot) as Actor
	if emp != null:
		emp.apply_report_hit()


func _clear_reports() -> void:
	for paper in reports.values():
		if is_instance_valid(paper):
			(paper as Node).queue_free()
	reports.clear()


func cast_kpi() -> void:
	for a in actors.values():
		var e := a as Actor
		if e.kind == Rules.Kind.EMPLOYEE and e.emp_state != Rules.EmpState.LEFT and e.emp_state != Rules.EmpState.CLOCKING:
			e.lose_task()
	show_kpi.rpc()


@rpc("authority", "call_local", "reliable")
func show_kpi() -> void:
	kpi_popup.emit()


func on_clock_out(slot: int) -> void:
	clock_log[slot] = elapsed
	if _all_punched():
		_finish()


func _all_punched() -> bool:
	var any := false
	for s in Rules.EMPLOYEE_SLOTS:
		if not actors.has(s):
			continue
		any = true
		if (actors[s] as Actor).emp_state != Rules.EmpState.LEFT:
			return false
	return any


func _finish() -> void:
	_clear_reports()
	for actor in actors.values():
		release_actor_carry(actor)
	if phase == "result":
		return
	playing = false
	phase = "result"
	var punched := 0
	var people: Array = []
	for s in Rules.EMPLOYEE_SLOTS:
		if not actors.has(s):
			continue
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
	if punched == 3 or punched == 4:
		boss_verdict = "平"
	elif punched >= 5:
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
		Rules.Slot.EMP_E: -1,
		Rules.Slot.EMP_F: -1,
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
	if Net.using_go or not Net.is_enet_server():
		return
	var alive: Dictionary = {}
	alive[1] = true
	for id in multiplayer.get_peers():
		alive[int(id)] = true
	for s in slots.keys():
		var pid := int(slots[s])
		if pid > 0 and not alive.has(pid):
			var disconnected := actors.get(s) as Actor
			if disconnected != null:
				release_actor_carry(disconnected, true)
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
	_clear_reports()
	lobby_changed.emit()


func apply_go_lobby(data: Dictionary, captain: int) -> void:
	var next_phase := str(data.get("phase", phase))
	slots = {
		Rules.Slot.BOSS: -1,
		Rules.Slot.EMP_A: -1,
		Rules.Slot.EMP_B: -1,
		Rules.Slot.EMP_C: -1,
		Rules.Slot.EMP_D: -1,
		Rules.Slot.EMP_E: -1,
	}
	var raw_slots: Dictionary = data.get("slots", {})
	for k in raw_slots.keys():
		slots[int(k)] = int(raw_slots[k])
	names = {}
	var raw_names: Dictionary = data.get("names", {})
	for k in raw_names.keys():
		names[int(k)] = str(raw_names[k])
	short_match = bool(data.get("short", short_match))
	if next_phase == "lobby" and phase != "lobby":
		_clear_actors()
	var prev := phase
	phase = next_phase
	playing = phase == "playing" or phase == "countdown"
	if prev == "lobby" and phase != "lobby" and phase != "result":
		match_started.emit()
	lobby_changed.emit()


func apply_go_snapshot(snap: Dictionary) -> void:
	var prev := phase
	phase = str(snap.get("phase", phase))
	elapsed = float(snap.get("elapsed", elapsed))
	time_left = float(snap.get("left", time_left))
	countdown = float(snap.get("cd", countdown))
	playing = phase == "playing" or phase == "countdown"
	if office:
		var occ: Dictionary = snap.get("occupiers", {})
		for k in occ.keys():
			office.occupiers[str(k)] = int(occ[k])
		var doors: Array = snap.get("doors", [])
		for d in doors:
			office._sync_door(str(d.get("id", "")), bool(d.get("closed", false)), bool(d.get("opening", false)), float(d.get("open_left", 0.0)))
	var list: Array = snap.get("actors", [])
	for item in list:
		_ingest_go_actor(item)
	if prev == "lobby" and phase != "lobby" and phase != "result":
		match_started.emit()
	if phase == "result" and prev != "result":
		playing = false
		match_ended.emit()
	hud_dirty.emit()


func apply_go_event(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	match kind:
		"talk":
			talked.emit(int(ev.get("slot", -1)))
		"catch":
			caught.emit(int(ev.get("slot", -1)), bool(ev.get("repeat", false)), float(ev.get("add_hours", 0.0)))
		"rescue":
			rescued.emit(int(ev.get("slot", -1)), int(ev.get("by_slot", -1)))
		"kpi":
			kpi_popup.emit()
		"result":
			result = ev.get("result", {})
			playing = false
			phase = "result"
			match_ended.emit()
		"bike":
			bike_event(int(ev.get("slot", -1)), bool(ev.get("on", false)))
		"carry":
			carry_event(
				int(ev.get("slot", -1)),
				int(ev.get("passenger", -1)),
				bool(ev.get("on", false)),
				Vector2(float(ev.get("x", 0.0)), float(ev.get("y", 0.0))),
				bool(ev.get("interrupted", false)),
				float(ev.get("facing", 1.0))
			)


func _ingest_go_actor(item: Dictionary) -> void:
	var slot := int(item.get("slot", -1))
	if slot < 0 or office == null:
		return
	var actor: Actor = actors.get(slot) as Actor
	if actor == null or not is_instance_valid(actor):
		if office.has_node("actor_%d" % slot):
			office.get_node("actor_%d" % slot).queue_free()
		actor = _actor_scene.instantiate()
		actor.setup(slot, int(item.get("peer", 0)), str(item.get("name", "")))
		office.add_child(actor, true)
		actors[slot] = actor
		actor.global_position = Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		actor._remote_pos = actor.global_position
	actor.peer_id = int(item.get("peer", actor.peer_id))
	actor.display_name = str(item.get("name", actor.display_name))
	actor.apply_snapshot(
		float(item.get("x", 0.0)),
		float(item.get("y", 0.0)),
		int(item.get("state", 0)),
		float(item.get("hours", 0.0)),
		float(item.get("energy", 0.0)),
		bool(item.get("visible", true)),
		float(item.get("mcd", 0.0)),
		float(item.get("kcd", 0.0)),
		float(item.get("dcd", 0.0)),
		float(item.get("talk", 0.0)),
		float(item.get("rescue", 0.0)),
		float(item.get("bike", 0.0))
	)
	actor.occupy_id = str(item.get("occupy", ""))
	actor.carrying_slot = int(item.get("carrying", -1))
	actor.carried_by = int(item.get("carried_by", -1))
	actor.stand_lock = float(item.get("stand_lock", 0.0))
	var fx := float(item.get("facing_x", 0.0))
	if abs(fx) > 0.01:
		actor._facing = Vector2(fx, actor._facing.y)
	if actor.name_label:
		actor.name_label.text = actor.display_name


func go_clear_to_lobby() -> void:
	playing = false
	phase = "lobby"
	countdown = 0.0
	clock_log.clear()
	result = {}
	if office != null:
		for k in office.occupiers.keys():
			office.occupiers[k] = -1
	for s in slots.keys():
		slots[s] = -1
	names.clear()
	_clear_actors()
	lobby_changed.emit()


func _clear_actors() -> void:
	for a in actors.values():
		if is_instance_valid(a):
			(a as Node).queue_free()
	actors.clear()
	bots.clear()
