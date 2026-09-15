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
	var bird = match_node.actors[rules.Slot.EMP_D]
	var horse = match_node.actors[rules.Slot.EMP_A]
	check(bird.skin == rules.CharSkin.PELICAN, "EMP_D is pelican")
	bird._stand_up()
	horse._stand_up()
	var door = game.office.nearest_door(Vector2(1340, 554), 24.0)
	check(door != null, "tea door exists")
	door.slam()
	bird.global_position = Vector2(1340, 640)
	horse.global_position = bird.global_position + Vector2(36, 0)
	bird.input_dir = Vector2(0, -1)
	bird._facing = Vector2(0, -1)
	await physics_frame
	horse.want_fly = true
	check(not horse._try_start_fly(), "horse cannot fly")
	bird.emp_state = rules.EmpState.WORK
	bird.want_fly = true
	check(not bird._try_start_fly(), "sitting pelican cannot fly")
	bird.emp_state = rules.EmpState.WALK
	bird.want_fly = true
	check(bird._try_start_fly(), "space starts fly")
	check(bird.fly_left > 0.2, "fly timer is armed")
	check(bird.collision_mask == 0, "fly ignores walls")
	check(is_equal_approx(bird.fly_cd, rules.PELICAN_FLY_CD) or bird.fly_cd > rules.PELICAN_FLY_CD - 0.05, "fly starts 10s cooldown")
	var start_y: float = bird.global_position.y
	await create_timer(0.5).timeout
	check(bird.fly_left <= 0.0, "fly ends after burst")
	check(bird.global_position.y < 530.0, "fly crossed the closed tea door")
	check(bird.global_position.y < start_y - 80.0, "fly travels forward")
	check(bird.collision_mask == 1, "landing restores collision")
	check(not bird._blocked_at(bird.global_position), "landing is walkable")
	var saved_cd: float = bird.fly_cd
	bird.want_fly = true
	check(not bird._try_start_fly(), "cooldown blocks a second fly")
	check(bird.fly_cd <= saved_cd + 0.05, "cooldown still ticking")
	bird.fly_cd = 0.0
	bird.global_position = Vector2(1340, 640)
	horse.global_position = bird.global_position + Vector2(36, 0)
	await physics_frame
	check(match_node.try_carry(bird), "can pick up colleague before fly")
	bird._facing = Vector2(0, -1)
	bird.input_dir = Vector2(0, -1)
	bird.want_fly = true
	check(bird._try_start_fly(), "loaded pelican can fly")
	await create_timer(0.5).timeout
	check(horse.carried_by == bird.slot, "passenger stays in beak during fly")
	check(horse.global_position.distance_to(bird.global_position) < 8.0, "passenger is carried over the wall")
	check(bird.global_position.y < 530.0, "loaded fly still crosses the door")
	print("FLY CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
