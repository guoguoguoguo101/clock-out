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
	check(nxt.distance_to(from) > 8.0, "desk path starts moving")
	check(nxt.distance_to(office.points["coffee_0"]) < from.distance_to(office.points["coffee_0"]) + 8.0, "first hop makes progress toward tea")
	game._pick_slot(rules.Slot.EMP_A)
	game._enter_test_room()
	await physics_frame
	await physics_frame
	var walk_bots := 0
	var start_pos: Dictionary = {}
	for s in match_node.actors.keys():
		var actor = match_node.actors[s]
		if actor == null or not actor.is_bot() or actor.kind != rules.Kind.EMPLOYEE:
			continue
		walk_bots += 1
		start_pos[s] = actor.global_position
		check(actor.emp_state == rules.EmpState.WALK, "bot %d starts on the floor" % s)
		check(str(actor.occupy_id) == "", "bot %d has not sat down yet" % s)
		check(actor.energy_cells == rules.ENERGY_START_CELLS, "bot %d starts with 3 energy" % s)
	check(walk_bots >= 3, "test room filled employee bots")
	await create_timer(0.45).timeout
	for s in start_pos.keys():
		var actor = match_node.actors[s]
		if actor == null:
			continue
		var drift: float = actor.global_position.distance_to(start_pos[s])
		check(drift > 6.0, "floor bot %d starts walking to a desk (drift %.1f)" % [s, drift])
	print("BOT NAV CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
