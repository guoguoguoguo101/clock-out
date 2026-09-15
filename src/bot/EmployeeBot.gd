extends Node
class_name EmployeeBot

var actor: Actor
var map: OfficeMap
var think := 0.0


func _init(p_actor: Actor, p_map: OfficeMap) -> void:
	actor = p_actor
	map = p_map


func tick(delta: float) -> void:
	if actor.carried_by >= 0:
		actor.input_dir = Vector2.ZERO
		actor.want_interact = false
		return
	if actor.emp_state == Rules.EmpState.LEFT or actor.emp_state == Rules.EmpState.CLOCKING:
		actor.input_dir = Vector2.ZERO
		return
	if actor.emp_state == Rules.EmpState.MEETING or actor.emp_state == Rules.EmpState.TALK:
		actor.input_dir = Vector2.ZERO
		return
	# 事故期间，责任人 Bot 去修 Bug
	if Match.incident_active and actor.is_blame_target and not actor.fixing:
		_go(Match.incident_terminal_pos, delta)
		if actor.global_position.distance_to(Match.incident_terminal_pos) < Rules.INTERACT_RANGE:
			actor.want_interact = true
		return
	# 事故期间，非责任人有概率帮修
	if Match.incident_active and not actor.is_blame_target and not actor.fixing and randf() < 0.003:
		_go(Match.incident_terminal_pos, delta)
		if actor.global_position.distance_to(Match.incident_terminal_pos) < Rules.INTERACT_RANGE:
			actor.want_interact = true
		return
	if actor.fixing:
		actor.input_dir = Vector2.ZERO
		return
	# 抢外卖
	if not Match.delivery_spots.is_empty() and actor.energy_cells < 3:
		var best_key := -1
		var best_dist := 999999.0
		for k in Match.delivery_spots:
			var dd: float = actor.global_position.distance_to(Match.delivery_spots[k])
			if dd < best_dist:
				best_dist = dd
				best_key = k
		if best_key >= 0:
			_go(Match.delivery_spots[best_key], delta)
			if best_dist < 80.0:
				actor.want_interact = true
			return
	think -= delta
	if actor.rescue_left > 0.0:
		actor.input_dir = Vector2.ZERO
		return
	if actor.play_kind != "":
		actor.input_dir = Vector2.ZERO
		if think <= 0.0:
			actor.want_slack = true
			think = 0.42
		return
	if actor.emp_state == Rules.EmpState.TRADE:
		return
	if actor.tasking:
		actor.input_dir = Vector2.ZERO
		return
	if actor.emp_state == Rules.EmpState.WORK or actor.emp_state == Rules.EmpState.SLACK:
		if actor.energy_cells >= 1 and actor.emp_state == Rules.EmpState.WORK:
			actor.want_interact = true
			return
		if actor.energy_cells <= 0:
			actor.input_dir = Vector2.DOWN
			return
		if actor.emp_state == Rules.EmpState.SLACK:
			actor.want_slack = true
		return
	var blocked = map.nearest_door(actor.global_position, 56.0)
	if blocked != null and blocked.closed:
		_go(blocked.global_position, delta)
		actor.want_interact = true
		return
	var victim := _find_rescue()
	if victim != null:
		_go(victim.global_position, delta)
		if actor.global_position.distance_to(victim.global_position) < Rules.RESCUE_RANGE:
			actor.want_interact = true
		return
	if actor.energy_cells <= 0:
		var loot := map.nearest_energy(actor.global_position, 2400.0)
		if loot != "":
			_go(map.energy_pos(loot), delta)
			if actor.global_position.distance_to(map.energy_pos(loot)) < Rules.INTERACT_RANGE:
				actor.want_interact = true
			return
		var id := map.nearest_free("coffee", actor.global_position)
		if id == "":
			id = map.nearest_free("toilet", actor.global_position)
		if id != "":
			_go(map.points[id], delta)
			if actor.global_position.distance_to(map.points[id]) < Rules.INTERACT_RANGE:
				actor.want_interact = true
			return
		_go(map.points["corridor"], delta)
		return
	var seat_id := map.nearest_free("seat", actor.global_position)
	if seat_id == "" or Match.intranet_down or Match.blackout_active:
		_go(map.points["corridor"], delta)
		return
	_go(map.points[seat_id], delta)
	if actor.global_position.distance_to(map.points[seat_id]) < Rules.INTERACT_RANGE and actor.stand_lock <= 0.0:
		actor.want_interact = true


func _go(target: Vector2, _delta: float) -> void:
	var next: Vector2 = map.path_to(actor.global_position, target)
	var d := next - actor.global_position
	actor.input_dir = d.normalized() if d.length() > 6.0 else Vector2.ZERO


func _find_rescue() -> Actor:
	if actor.energy_cells < 1 or actor.tasks_done >= 4:
		return null
	for a in Match.actors.values():
		var e := a as Actor
		if not Match.is_hold_target(e):
			continue
		if actor.global_position.distance_to(e.global_position) < 420.0:
			return e
	return null
