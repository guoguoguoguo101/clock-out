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
	check(rules.EMPLOYEE_SLOTS.size() == 4, "roster has exactly four employee slots")
	check(match_node.slots.size() == 5, "lobby has boss plus four employee slots")
	check(game.mate_box.size() == 4, "HUD monitor strip has four employee monitors")
	game._pick_slot(rules.Slot.EMP_A)
	game._enter_test_room()
	await physics_frame
	check(match_node.actors.size() == 5, "test room spawns one boss and four employees")
	check(match_node.actors[rules.Slot.EMP_A].skin == rules.CharSkin.HORSE, "EMP_A is horse")
	check(match_node.actors[rules.Slot.EMP_B].skin == rules.CharSkin.PELICAN, "EMP_B is pelican")
	check(match_node.actors[rules.Slot.EMP_C].skin == rules.CharSkin.KANGAROO, "EMP_C is kangaroo")
	check(match_node.actors[rules.Slot.EMP_D].skin == rules.CharSkin.DOG, "EMP_D is dog")
	print("1V4 ROSTER CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
