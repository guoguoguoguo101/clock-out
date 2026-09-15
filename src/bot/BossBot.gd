extends Node
class_name BossBot

var actor: Actor
var map: OfficeMap
var patrol := 0
var wait := 0.0
var watching := false


func _init(p_actor: Actor, p_map: OfficeMap) -> void:
	actor = p_actor
	map = p_map


func tick(delta: float) -> void:
	wait -= delta
	var door = map.nearest_door(actor.global_position, 70.0)
	if door != null and (door.closed or door.opening):
		var dd = door.global_position - actor.global_position
		actor.input_dir = dd.normalized() if dd.length() > 10.0 else Vector2.ZERO
		if door.closed:
			actor.want_interact = true
		return
	var talk := _talk_here()
	if talk != null:
		if watching:
			actor.input_dir = Vector2.ZERO
			if wait <= 0.0:
				watching = false
			return
		if wait <= 0.0:
			watching = true
			wait = 3.4
			actor.input_dir = Vector2.ZERO
			return
	else:
		watching = false
	var prey := _find_prey()
	if prey != null:
		var d := prey.global_position - actor.global_position
		actor.input_dir = d.normalized()
		if d.length() < Rules.CATCH_RANGE + 8.0:
			actor.want_interact = true
		if wait <= 0.0 and d.length() < 280.0:
			if d.length() > 88.0:
				if d.length() > 130.0 and actor.fan_cd <= 0.0:
					actor.want_fan = true
				else:
					actor.want_report = true
				wait = 1.1
			else:
				actor.want_meeting = true
				wait = 4.0
		return
	var spots := [
		map.points["sup_1"],
		map.points["coffee_0"],
		map.points["sup_3"],
		map.points["punch_0"],
		map.points["toilet_0"],
		map.points["stock_0"],
		map.points["sup_2"],
	]
	var target: Vector2 = spots[patrol % spots.size()]
	var d2 := map.path_to(actor.global_position, target) - actor.global_position
	actor.input_dir = d2.normalized() if d2.length() > 12.0 else Vector2.ZERO
	if d2.length() < 18.0:
		patrol += 1
	if Match.elapsed > Rules.KPI_UNLOCK + 2.0 and actor.kpi_cd <= 0.0 and wait <= 0.0:
		actor.want_kpi = true
		wait = 8.0


func _talk_here() -> Actor:
	for a in Match.actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE or e.emp_state != Rules.EmpState.TALK:
			continue
		if map.same_view(actor.global_position, e.global_position):
			return e
	return null


func _find_prey() -> Actor:
	var best: Actor = null
	var best_d := 220.0
	for a in Match.actors.values():
		var e := a as Actor
		if e.kind != Rules.Kind.EMPLOYEE:
			continue
		if e.emp_state != Rules.EmpState.SLACK and e.emp_state != Rules.EmpState.COFFEE and e.emp_state != Rules.EmpState.TOILET and e.emp_state != Rules.EmpState.TRADE:
			continue
		var d := e.global_position.distance_to(actor.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
