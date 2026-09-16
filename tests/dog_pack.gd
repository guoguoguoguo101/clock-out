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
	match_node.elapsed = rules.CATCH_GRACE + 1.0
	var dog = match_node.actors[rules.Slot.EMP_D]
	var horse = match_node.actors[rules.Slot.EMP_A]
	var boss = match_node.actors[rules.Slot.BOSS]
	check(dog.skin == rules.CharSkin.DOG, "EMP_D is dog")
	dog._stand_up()
	horse._stand_up()
	dog.global_position = game.office.points["corridor"]
	horse.global_position = dog.global_position + Vector2(120, 0)
	dog.input_dir = Vector2.ZERO
	dog.pack_cd = 0.0
	await physics_frame
	check(match_node.try_bros(horse) == false, "other employees cannot summon brothers")
	check("兄弟" in dog.nearby_action(), "empty corridor shows brother prompt")
	check(match_node.try_bros(dog), "E / try_bros summons the pack")
	check(dog.pack_hp == 3, "three brothers spawn")
	check(dog.pack_left >= rules.DOG_PACK_TIME - 0.05, "pack lasts about 8s")
	check(dog.pack_cd >= rules.DOG_PACK_CD - 0.05, "summon starts cooldown")
	check(dog.pack_visual != null and dog.pack_visual.active(), "pack visual is on")
	dog.input_dir = Vector2.RIGHT
	await physics_frame
	var expected: float = rules.EMPLOYEE_SPEED * rules.DOG_PACK_SPEED_MUL
	check(absf(dog.velocity.length() - expected) < 8.0, "pack slightly raises walk speed")
	dog.input_dir = Vector2.ZERO
	check(match_node.try_bros(dog) == false, "cannot recast while brothers are out")
	boss._stand_up()
	boss.global_position = dog.global_position + Vector2(-40, 0)
	boss._facing = Vector2.RIGHT
	boss.power_pips = 0
	check(match_node.hit_lunge_bro(boss, boss.global_position, dog.global_position), "lunge hits a brother first")
	check(dog.pack_hp == 2, "one brother soaks the lunge")
	check(dog.emp_state == rules.EmpState.WALK, "dog is not grabbed")
	check(boss.power_pips == 0, "soaked lunge grants no power")
	check(boss.lunge_stun >= rules.DOG_PACK_STUN - 0.05, "boss is stunned by the soak")
	boss.lunge_stun = 0.0
	var slot_pos: Vector2 = match_node.pack_world_slots(dog)[0]
	check(match_node.hit_report_bro(slot_pos), "weekly report can hit a brother")
	check(dog.pack_hp == 1, "report consumes one brother")
	check(dog.slow_left <= 0.0, "soaked report does not slow the dog")
	dog.tasks_done = 2
	match_node.cast_kpi()
	check(dog.tasks_done == 1, "KPI still hits the dog")
	check(dog.pack_hp == 1, "KPI does not consume brothers")
	boss.power_pips = 3
	boss.global_position = dog.global_position + Vector2(-60, 0)
	boss._facing = Vector2.RIGHT
	dog.send_to_meeting(rules.TIGER_MEETING_TIME, game.office.points["meeting"])
	check(dog.emp_state == rules.EmpState.MEETING, "meeting still pulls the dog")
	check(dog.global_position.distance_to(game.office.points["meeting"]) < 8.0, "meeting ignores the pack")
	check(dog.pack_hp == 0, "pack leaves when the dog is pulled")
	dog.emp_state = rules.EmpState.WALK
	dog.meeting_left = 0.0
	dog.global_position = game.office.points["corridor"]
	dog.pack_cd = 0.0
	check(match_node.try_bros(dog), "can summon again after pack ended")
	match_node.hit_lunge_bro(boss, boss.global_position, dog.global_position)
	match_node.hit_lunge_bro(boss, boss.global_position, dog.global_position)
	match_node.hit_lunge_bro(boss, boss.global_position, dog.global_position)
	check(dog.pack_hp == 0, "three soaks empty the pack")
	check(not match_node.hit_lunge_bro(boss, boss.global_position, dog.global_position), "empty pack no longer intercepts")
	boss.global_position = dog.global_position + Vector2(72, 0)
	var hit = match_node.lunge_victim(boss, boss.global_position, dog.global_position)
	check(hit == dog, "fourth lunge reaches the dog")
	dog.pack_cd = 0.0
	dog.global_position = game.office.points["seat_6"]
	await physics_frame
	check("坐下" in dog.nearby_action(), "seat prompt still wins over summon")
	dog._try_employee_interact()
	check(dog.emp_state == rules.EmpState.WORK, "E sits instead of summoning at a desk")
	print("DOG PACK CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
