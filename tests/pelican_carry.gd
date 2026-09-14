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
	game._pick_slot(rules.Slot.EMP_D)
	game._enter_test_room()
	await physics_frame
	match_node.bots.clear()
	var carrier = match_node.actors[rules.Slot.EMP_D]
	var passenger = match_node.actors[rules.Slot.EMP_A]
	var boss = match_node.actors[rules.Slot.BOSS]
	carrier._stand_up()
	carrier.global_position = game.office.points["corridor"]
	passenger.global_position = carrier.global_position + Vector2(40, 0)
	boss.global_position = Vector2(200, 200)
	carrier.input_dir = Vector2.ZERO
	var seat: String = passenger.occupy_id
	await physics_frame
	check(match_node.nearest_carry_target(carrier) == passenger, "nearby seated employee selected")
	carrier._try_employee_interact()
	check(carrier.carrying_slot == passenger.slot and passenger.carried_by == carrier.slot, "E picks up employee")
	check(game.office.occupiers[seat] == -1, "pickup frees occupied seat")
	check(passenger.emp_state == rules.EmpState.CARRIED, "passenger enters carried state")
	check(match_node.is_catchable(carrier), "boss can catch loaded pelican")
	check(not match_node.try_carry(carrier), "cannot carry a second passenger")
	await create_timer(0.13).timeout
	await capture("pickup")
	await create_timer(0.35).timeout
	await capture("carrying")
	var saved_hours: float = passenger.hours
	var saved_energy: float = passenger.energy
	carrier.input_dir = Vector2.RIGHT
	await create_timer(0.3).timeout
	carrier.input_dir = Vector2.ZERO
	check(passenger.global_position.distance_to(carrier.global_position) < 5.0, "passenger follows moving carrier")
	check(passenger.hours == saved_hours and passenger.energy == saved_energy, "carried employee does not work or recover energy")
	carrier.want_interact = true
	await create_timer(0.06).timeout
	check(passenger.carried_by == -1 and passenger.emp_state == rules.EmpState.WALK, "E drops employee")
	await capture("landing")
	check(not match_node.try_carry(carrier), "recovery prevents immediate regrab")
	await create_timer(0.7).timeout
	passenger.global_position = carrier.global_position + Vector2(35, 0)
	passenger.begin_talk()
	passenger.talk_progress = 0.4
	check(match_node.try_carry(carrier), "can pick up employee in a talk")
	carrier.begin_talk()
	check(carrier.carrying_slot == -1 and passenger.carried_by == -1, "catching carrier releases passenger")
	check(passenger.emp_state == rules.EmpState.TALK and passenger.talk_progress >= 0.4, "interruption restores talk progress")
	carrier.end_talk_rescued()
	carrier.carry_recovery = 0.0
	passenger.end_talk_rescued()
	passenger.global_position = carrier.global_position + Vector2(35, 0)
	check(match_node.try_carry(carrier), "can carry again after interruption")
	carrier.carry_left = 0.01
	await create_timer(0.05).timeout
	check(carrier.carrying_slot == -1, "timeout safely releases passenger")
	carrier.carry_recovery = 0.0
	passenger.emp_state = rules.EmpState.MEETING
	check(match_node.nearest_carry_target(carrier) != passenger, "meeting cannot be interrupted by pickup")
	passenger.emp_state = rules.EmpState.LEFT
	check(match_node.nearest_carry_target(carrier) != passenger, "departed employee cannot be picked up")
	print("CARRY CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP") + "/clock-out-" + label + ".png")
