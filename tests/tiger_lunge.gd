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
	game._pick_slot(rules.Slot.BOSS)
	game._enter_test_room()
	await physics_frame
	match_node.bots.clear()
	var boss = match_node.actors[rules.Slot.BOSS]
	var emp = match_node.actors[rules.Slot.EMP_A]
	emp._stand_up()
	emp.global_position = game.office.points["corridor"]
	boss.global_position = emp.global_position + Vector2(-40, 0)
	boss._facing = Vector2.RIGHT
	boss.input_dir = Vector2.RIGHT
	boss.power_pips = 0
	await physics_frame
	check(match_node.is_lunge_target(emp), "walking employee is a lunge target")
	emp.emp_state = rules.EmpState.CLOCKING
	check(not match_node.is_lunge_target(emp), "clocking employee cannot be lunged")
	emp.emp_state = rules.EmpState.WALK
	check(match_node.start_lunge(boss), "E starts a short lunge")
	check(boss.lunge_left > 0.0, "lunge timer is armed")
	var hit = match_node.lunge_victim(boss, boss.global_position, emp.global_position)
	check(hit == emp, "sweep or landing overlap counts as a catch")
	match_node.grab_lunge(boss, emp)
	check(emp.emp_state == rules.EmpState.TALK, "caught employee reviews in place")
	check(is_equal_approx(emp.global_position.x, game.office.points["corridor"].x) or emp.global_position.distance_to(game.office.points["meeting"]) > 80.0, "E does not teleport to meeting")
	check(boss.power_pips == 1, "successful lunge grants one power pip")
	check(boss.lunge_stun >= rules.TIGER_LUNGE_HIT_STUN - 0.05, "hit recovery is 0.4s")
	var helper = match_node.actors[rules.Slot.EMP_B]
	helper._stand_up()
	helper.global_position = emp.global_position + Vector2(20, 0)
	check(match_node.try_rescue(helper), "boss presence does not block rescue")
	check(is_equal_approx(helper.rescue_left, rules.RESCUE_TIME), "rescue channel is 2.5s")
	helper.rescue_left = 0.01
	match_node.tick_rescue(helper, 0.02)
	check(emp.emp_state == rules.EmpState.WALK, "rescue ends review")
	check(emp.slow_left >= rules.RESCUE_SLOW_TIME - 0.05, "rescued employee is slowed")
	boss.lunge_stun = 0.0
	boss.power_pips = 3
	boss.global_position = emp.global_position + Vector2(-60, 0)
	boss._facing = Vector2.RIGHT
	emp.emp_state = rules.EmpState.TALK
	check(match_node.try_meeting(boss), "Q spends 3 pips and pulls a reviewing employee")
	check(boss.power_pips == 0, "Q empties power")
	check(emp.emp_state == rules.EmpState.MEETING, "Q sends them to the meeting room")
	check(emp.global_position.distance_to(game.office.points["meeting"]) < 8.0, "Q teleports to meeting seat")
	check(is_equal_approx(emp.meeting_left, rules.TIGER_MEETING_TIME), "meeting lock is 30s")
	check(boss.ult_flash >= rules.TIGER_ULT_POSE - 0.05, "Q plays the ult pose")
	helper.global_position = emp.global_position + Vector2(16, 0)
	check(match_node.try_rescue(helper), "meeting victims can be rescued the same way")
	print("LUNGE CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
