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
	game._pick_slot(rules.Slot.EMP_A)
	game._enter_test_room()
	await physics_frame
	match_node.bots.clear()
	var horse = match_node.actors[rules.Slot.EMP_A]
	var rabbit = match_node.actors[rules.Slot.EMP_B]
	var cow = match_node.actors[rules.Slot.EMP_C]
	var pelican = match_node.actors[rules.Slot.EMP_D]
	var kangaroo = match_node.actors[rules.Slot.EMP_E]
	var employees := [horse, rabbit, cow, pelican, kangaroo]
	for emp in employees:
		emp._stand_up()
		emp.global_position = game.office.points["corridor"] + Vector2(emp.slot * 40.0, 0)
		emp.input_dir = Vector2.ZERO
		emp.dash_cd = 0.0
		emp.dash_left = 0.0
	await physics_frame

	horse.apply_input(1.0, 0.0, false, false, false, false, true)
	await physics_frame
	check(horse.dash_left > 0.2, "walking employee starts dash")
	check(is_equal_approx(horse.dash_cd, rules.EMP_DASH_CD) or horse.dash_cd > rules.EMP_DASH_CD - 0.05, "dash starts 8s cooldown")
	check(absf(horse.velocity.length() - rules.EMP_DASH_SPEED) < 12.0, "dash uses burst speed")
	check(horse.dash_dir.x > 0.8, "dash follows held direction")

	var saved_cd: float = horse.dash_cd
	horse.apply_input(0.0, -1.0, false, false, false, false, true)
	await physics_frame
	check(horse.dash_cd <= saved_cd, "cooldown blocks a second dash")
	check(horse.dash_dir.x > 0.8, "active dash keeps original direction")

	await create_timer(rules.EMP_DASH_TIME + 0.08).timeout
	horse.global_position = game.office.points["corridor"]
	horse.input_dir = Vector2.RIGHT
	horse.want_dash = false
	horse._employee_tick(1.0 / 60.0)
	check(horse.dash_left <= 0.0, "dash ends after burst time")
	check(absf(horse.velocity.length() - rules.EMPLOYEE_SPEED) < 12.0, "walk speed returns after dash")
	check(horse.dash_cd > 6.0, "cooldown remains after dash ends")

	rabbit._stand_up()
	rabbit.emp_state = rules.EmpState.WALK
	rabbit.bike_left = 0.0
	rabbit.stand_lock = 0.0
	rabbit.dash_cd = 0.0
	rabbit.dash_left = 0.0
	rabbit.input_dir = Vector2.ZERO
	rabbit._facing = Vector2.LEFT
	rabbit.want_dash = true
	rabbit._employee_tick(1.0 / 60.0)
	check(rabbit.dash_left > 0.2, "idle employee dashes facing direction")
	check(rabbit.dash_dir.x < -0.8, "no WASD uses last facing")

	cow.emp_state = rules.EmpState.WORK
	cow.occupy_id = "seat_3"
	cow.input_dir = Vector2.ZERO
	cow.apply_input(0.0, 0.0, false, false, false, false, true)
	await physics_frame
	check(cow.dash_left <= 0.0, "sitting employee cannot dash")
	check(cow.emp_state == rules.EmpState.WORK, "shift does not stand up from desk")

	pelican.begin_talk()
	pelican.apply_input(1.0, 0.0, false, false, false, false, true)
	await physics_frame
	check(pelican.dash_left <= 0.0, "talking employee cannot dash")

	kangaroo._stand_up()
	kangaroo.global_position = game.office.points["corridor"]
	kangaroo.dash_cd = 0.0
	kangaroo.bike_left = rules.BIKE_DURATION
	kangaroo.apply_input(1.0, 0.0, false, false, false, false, true)
	await physics_frame
	check(kangaroo.dash_left <= 0.0, "riding employee cannot dash")
	check(absf(kangaroo.velocity.length() - rules.EMPLOYEE_SPEED * rules.BIKE_SPEED_MUL) < 12.0, "bike speed unchanged by shift")

	print("DASH CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
