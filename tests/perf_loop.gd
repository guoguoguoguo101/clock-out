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
	match_node.elapsed = rules.CATCH_GRACE + 1.0
	var emp = match_node.actors[rules.Slot.EMP_A]
	var boss = match_node.actors[rules.Slot.BOSS]
	emp._stand_up()
	emp.energy_cells = rules.ENERGY_CELLS
	emp.energy_charge = 0.0
	emp.task_progress = 0.9
	emp.tasks_done = 0
	emp.dizzy = false
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp._start_task()
	check(emp.tasking, "starting a task no longer spends energy upfront")
	check(emp.energy_cells == rules.ENERGY_CELLS, "energy remains until the task ticks")
	emp.task_progress = 0.4
	emp._leave_work(true, "")
	var saves = rules.task_saves_for(emp.slot, 0)
	var kept = rules.task_checkpoint_of(0.4, saves)
	check(is_equal_approx(emp.task_progress, kept), "leaving mid-task rolls back to the last checkpoint")
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp.energy_cells = rules.ENERGY_CELLS
	emp._start_task()
	emp.task_progress = 0.12
	emp._leave_work(true, "")
	check(emp.task_progress <= 0.001, "leaving before any checkpoint discards the unsaved chunk")
	check(not emp.dizzy, "aborting does not force dizzy")
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp._start_task()
	if saves.size() > 0:
		emp.task_progress = minf(0.99, saves[0] + 0.05)
		emp._leave_work(true, "")
		check(is_equal_approx(emp.task_progress, saves[0]), "progress past a checkpoint keeps the save")
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp.task_progress = 0.0
	emp._start_task()
	emp.task_progress = 1.0
	emp._sit_work(0.0, false)
	check(emp.dizzy, "finishing a task forces a short dizzy")
	check(emp.dizzy_left >= 1.0, "dizzy lasts about 1-2 seconds")
	check(not emp.tasking, "finished task is no longer tasking")
	emp.energy_cells = 4
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp._start_task()
	check(not emp.tasking, "dizzy blocks starting another task")
	emp._tick_dizzy(2.1)
	check(not emp.dizzy, "dizzy wears off on its own")
	emp.emp_state = rules.EmpState.WORK
	emp.occupy_id = "seat_1"
	emp.energy_cells = 4
	emp._start_task()
	check(emp.tasking, "after dizzy you can sit and work again")
	emp.perf_hp = rules.PERF_FIRE
	emp.emp_state = rules.EmpState.WALK
	emp.tasking = false
	boss.global_position = emp.global_position + Vector2(-30, 0)
	boss._facing = Vector2.RIGHT
	match_node.grab_lunge(boss, emp)
	check(emp.emp_state == rules.EmpState.FIRED, "low performance catch fires immediately")
	print("PERF LOOP CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
