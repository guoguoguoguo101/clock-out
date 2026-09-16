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
	match_node.elapsed = rules.CATCH_GRACE + 1.0
	var boss = match_node.actors[rules.Slot.BOSS]
	var emp = match_node.actors[rules.Slot.EMP_A]
	emp._stand_up()
	emp.tasking = false
	emp.global_position = game.office.points["corridor"]
	boss.global_position = emp.global_position + Vector2(-40, 0)
	boss._facing = Vector2.RIGHT
	boss.input_dir = Vector2.RIGHT
	boss.power_pips = 0
	await physics_frame
	check(match_node.is_lunge_target(emp), "walking employee is a lunge target")
	emp.tasking = true
	check(not match_node.is_lunge_target(emp), "working employee cannot be lunged")
	emp.tasking = false
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
	check(helper.rescue_left > 10.0, "review help stays attached instead of a 2.5s yank")
	helper.rescue_left = 0.01
	match_node.tick_rescue(helper, 0.02)
	check(emp.emp_state == rules.EmpState.TALK, "helping review does not yank them up")
	check(helper.rescue_left > 0.0, "review helpers keep channeling")
	emp.audit_hit_left = 0.0
	var helped: float = emp.talk_progress
	emp._tick_talk(1.0)
	check(emp.talk_progress > helped + 0.12, "a helper speeds the review bar")
	helper.clear_rescue()
	emp.end_talk_deflected()
	emp.audit_hit_left = 0.0
	check(emp.apply_report_hit(Vector2.RIGHT), "weekly report still applies its normal slow")
	check(emp.audit_hit_left > 0.0 and emp.audit_hit_dir == Vector2.RIGHT, "weekly report supplies the visual impact direction")
	emp.begin_talk()
	emp.audit_hit_left = 0.0
	emp.play_lock = 0.0
	emp.talk_progress = 0.0
	emp.play_t = emp.play_mark
	emp.want_interact = true
	emp.input_dir = Vector2.ZERO
	emp._tick_talk(0.0)
	check(emp.talk_progress >= rules.REVIEW_QTE_BOOST - 0.01, "a successful QTE jumps a chunk of the bar")
	emp.talk_progress = 0.99
	emp.want_interact = false
	emp._tick_talk(0.2)
	check(emp.emp_state == rules.EmpState.WALK, "filling the review bar deflects the review")
	check(emp.slow_left >= 1.0, "self-deflected review leaves a brief recovery slow")
	boss.lunge_stun = 0.0
	boss.power_pips = 3
	boss.global_position = emp.global_position + Vector2(-60, 0)
	emp.emp_state = rules.EmpState.WALK
	check(not match_node.try_meeting(boss), "Q does nothing unless someone nearby is in review")
	emp.emp_state = rules.EmpState.TALK
	check(match_node.try_meeting(boss), "Q spends 3 pips and starts dragging a nearby reviewing employee")
	check(boss.power_pips == 0, "Q empties power")
	check(boss.dragging_slot == emp.slot, "Q marks the review victim for a drag")
	check(boss.drag_windup >= rules.TIGER_DRAG_WINDUP - 0.05, "drag has a short windup")
	check(emp.emp_state == rules.EmpState.TALK, "windup does not teleport yet")
	boss.drag_windup = 0.0
	match_node.attach_drag(boss, emp)
	check(emp.emp_state == rules.EmpState.DRAGGED, "after windup the employee is dragged")
	check(emp.global_position.distance_to(game.office.points["meeting"]) > 40.0, "drag does not teleport to the meeting room")
	boss.input_dir = Vector2.ZERO
	var drag_from: Vector2 = boss.global_position
	var meet_pos: Vector2 = game.office.points["meeting"]
	if drag_from.distance_to(meet_pos) < 160.0:
		boss.global_position = meet_pos + Vector2(-220.0, 0.0)
		drag_from = boss.global_position
	for _i in 8:
		boss._tick_boss_drag(0.05)
	check(boss.global_position.distance_to(drag_from) > 8.0, "boss walks while dragging")
	check(boss.global_position.distance_to(meet_pos) < drag_from.distance_to(meet_pos), "boss walks toward the meeting room")
	check(str(boss._anim_pose()).begins_with("walk"), "dragging boss plays a walk cycle")
	match_node.bind_meeting(boss, emp)
	check(emp.emp_state == rules.EmpState.MEETING, "arriving binds them to a meeting chair")
	check(emp.global_position.distance_to(game.office.points["meeting"]) < 8.0, "chair bind seats them at the meeting point")
	check(boss.dragging_slot < 0, "boss is free after seating them")
	helper.clear_rescue()
	helper.global_position = emp.global_position + Vector2(16, 0)
	check(match_node.try_rescue(helper), "meeting victims can be rescued the same way")
	print("LUNGE CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
