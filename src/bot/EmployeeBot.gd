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
	think -= delta
	if actor.rescue_left > 0.0:
		actor.input_dir = Vector2.ZERO
		return
	if actor.emp_state == Rules.EmpState.COFFEE or actor.emp_state == Rules.EmpState.TOILET:
		if actor.energy > 92.0:
			actor.want_interact = true
		return
	if actor.emp_state == Rules.EmpState.WORK:
		if actor.energy < 18.0:
			actor.want_interact = true
		elif actor.energy < 40.0 and think <= 0.0:
			actor.want_slack = true
			think = 2.0
		return
	if actor.emp_state == Rules.EmpState.SLACK:
		if actor.energy > 78.0:
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
	if actor.energy < 22.0:
		var id := map.nearest_free("coffee", actor.global_position)
		if id == "":
			id = map.nearest_free("toilet", actor.global_position)
		if id != "":
			_go(map.points[id], delta)
			if actor.global_position.distance_to(map.points[id]) < Rules.INTERACT_RANGE:
				actor.want_interact = true
			return
	var seat_id := map.nearest_free("seat", actor.global_position)
	if seat_id == "":
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
	if actor.energy < 26.0 or actor.hours < 14.0:
		return null
	var best: Actor = null
	var best_d := 520.0
	for a in Match.actors.values():
		var e := a as Actor
		if e == actor or e.kind != Rules.Kind.EMPLOYEE:
			continue
		if e.emp_state != Rules.EmpState.TALK:
			continue
		if Match.is_watched(e):
			continue
		var d := actor.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
