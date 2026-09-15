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
	check(match_node.start_lunge(boss), "space starts a short lunge")
	check(boss.lunge_left > 0.0, "lunge timer is armed")
	var hit = match_node.lunge_victim(boss, boss.global_position, emp.global_position)
	check(hit == emp, "sweep or landing overlap counts as a catch")
	match_node.grab_lunge(boss, emp)
	check(emp.emp_state == rules.EmpState.TALK, "caught employee reviews in place")
	check(emp.audit_hit_left > 0.0, "caught employee enters the readable audit-hit pose")
	check(emp._anim_pose() == "audit_hit_0", "audit-hit pose takes priority over the review idle pose")
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
	emp.audit_hit_left = 0.0
	check(emp.apply_report_hit(Vector2.RIGHT), "weekly report still applies its normal slow")
	check(emp.audit_hit_left > 0.0 and emp.audit_hit_dir == Vector2.RIGHT, "weekly report supplies the visual impact direction")
	emp.begin_talk()
	emp.audit_hit_left = 0.0
	for i in rules.REVIEW_STEPS:
		emp.review_delay_left = 0.0
		emp.review_window_left = 0.5
		emp.want_interact = true
		emp._tick_talk(0.0)
	check(emp.emp_state == rules.EmpState.WALK, "three timed review replies let an employee deflect the review")
	check(emp.slow_left >= 1.0, "self-deflected review leaves a brief recovery slow")
	boss.lunge_stun = 0.0
	boss.power_pips = 3
	boss.global_position = emp.global_position + Vector2(-60, 0)
	emp.emp_state = rules.EmpState.WALK
	check(not match_node.try_meeting(boss), "Q does nothing unless someone nearby is in review")
	emp.emp_state = rules.EmpState.TALK
	check(match_node.try_meeting(boss), "Q spends 3 pips and sends a nearby reviewing employee")
	check(boss.power_pips == 0, "Q empties power")
	check(emp.emp_state == rules.EmpState.MEETING, "Q sends them to the meeting room")
	check(emp.global_position.distance_to(game.office.points["meeting"]) < 8.0, "Q teleports to meeting seat")
	check(is_equal_approx(emp.meeting_left, rules.TIGER_MEETING_TIME), "meeting lock is 30s")
	check(boss.ult_flash >= rules.TIGER_ULT_POSE - 0.05, "Q plays the ult pose")
	helper.global_position = emp.global_position + Vector2(16, 0)
	check(match_node.try_rescue(helper), "meeting victims can be rescued the same way")
	print("LUNGE CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
