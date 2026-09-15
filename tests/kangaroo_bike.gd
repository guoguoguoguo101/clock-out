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
	game._pick_slot(rules.Slot.EMP_E)
	game._enter_test_room()
	await physics_frame
	match_node.bots.clear()
	var rider = match_node.actors[rules.Slot.EMP_E]
	var horse = match_node.actors[rules.Slot.EMP_A]
	check(rider.skin == rules.CharSkin.KANGAROO, "EMP_E is kangaroo")
	check(game.office.points.has("seat_5"), "fifth desk exists")
	rider._stand_up()
	horse._stand_up()
	rider.global_position = game.office.points["corridor"]
	horse.global_position = rider.global_position + Vector2(80, 0)
	rider.input_dir = Vector2.ZERO
	rider.bike_cd = 0.0
	await physics_frame
	check(match_node.try_bike(horse) == false, "other employees cannot summon bike")
	check("电瓶车" in rider.nearby_action(), "empty corridor shows bike prompt")
	rider._try_employee_interact()
	check(rider.bike_left <= 0.0, "E does not summon bike")
	check(match_node.try_bike(rider), "F / try_bike summons bike")
	check(rider.bike_left > 0.0, "riding flag is on")
	check(rider._anim_pose().begins_with("ride"), "riding uses sit pose")
	check(rider.bike_front != null and rider.bike_front.visible, "front bars draw over rider")
	check(rider.bike_front.z_index > rider.body_sprite.z_index, "rider sits between bike layers")
	check(rider.bike_sprite.offset.y < -700.0, "bike wheels are grounded to the actor origin")
	check(match_node.try_bike(rider) == false, "cannot recast while riding")
	check("下车" in rider.nearby_action(), "riding prompt is dismount")
	rider.input_dir = Vector2.RIGHT
	await physics_frame
	var expected: float = rules.EMPLOYEE_SPEED * rules.BIKE_SPEED_MUL
	check(absf(rider.velocity.length() - expected) < 8.0, "bike multiplies walk speed")
	rider.input_dir = Vector2.ZERO
	rider.global_position = game.office.points["seat_5"]
	check("下车" in rider.nearby_action(), "seat is blocked until dismount")
	rider._try_employee_interact()
	check(rider.emp_state != rules.EmpState.WORK, "cannot sit while riding")
	check(rider.bike_left > 0.0, "E does not dismount")
	rider._try_toggle_bike()
	check(rider.bike_left <= 0.0, "F dismounts bike")
	check(rider.bike_cd >= rules.BIKE_CD - 0.05, "dismount starts remount CD")
	check("坐下" in rider.nearby_action(), "seat prompt after dismount")
	rider._try_employee_interact()
	check(rider.emp_state == rules.EmpState.WORK, "E sits after dismount")
	check(rider.bike_sprite == null or rider.bike_sprite.visible == false, "bike sprite hides after sit")
	check(rider.bike_front == null or rider.bike_front.visible == false, "front bars hide after sit")
	rider._stand_up()
	rider.global_position = game.office.points["corridor"]
	await physics_frame
	check(match_node.try_bike(rider) == false, "cannot remount during CD")
	rider.bike_cd = 0.0
	check(match_node.try_bike(rider), "can summon again after CD")
	print("BIKE CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
