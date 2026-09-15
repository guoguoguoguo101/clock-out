extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func run_checks() -> void:
	var game = load("res://src/game/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var match_node = root.get_node("Match")
	var rules = root.get_node("Rules")
	var office = game.office
	var from: Vector2 = office.points["seat_1"]
	var nxt: Vector2 = office.path_to(from, office.points["coffee_0"])
	check(nxt.y >= 1000.0, "desk room leaves via aisle, not through tables")
	check(absf(nxt.x - office.DESK_DOOR.x) < 24.0 or absf(nxt.y - from.y) < 24.0, "first hop stays in south aisle")
	game._pick_slot(rules.Slot.EMP_A)
	game._enter_test_room()
	await physics_frame
	await physics_frame
	var seat_bots := 0
	var start_pos: Dictionary = {}
	for s in match_node.actors.keys():
		var actor = match_node.actors[s]
		if actor == null or not actor.is_bot() or actor.kind != rules.Kind.EMPLOYEE:
			continue
		seat_bots += 1
		start_pos[s] = actor.global_position
		check(actor.emp_state == rules.EmpState.WORK, "bot %d starts seated" % s)
		check(actor.occupy_id.begins_with("seat_"), "bot %d occupies a seat" % s)
		check(actor.energy_cells >= 1, "bot %d has energy to work" % s)
	check(seat_bots >= 4, "test room filled employee bots")
	await create_timer(0.45).timeout
	for s in start_pos.keys():
		var actor = match_node.actors[s]
		if actor == null:
			continue
		var drift: float = actor.global_position.distance_to(start_pos[s])
		check(drift < 28.0, "seated bot %d stays put (drift %.1f)" % [s, drift])
	print("BOT NAV CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
