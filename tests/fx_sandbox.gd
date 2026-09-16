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
	var Catalog := load("res://src/fx/EventFx.gd")
	var clips: Array = Catalog.clips()
	check(clips.size() >= 4, "clip catalog has entries")
	var ids := PackedStringArray()
	for clip in clips:
		ids.append(str(clip["id"]))
	check(ids.has("fired_victim"), "catalog includes fired_victim")
	check(ids.has("kickoff_10"), "catalog includes kickoff")
	var Sandbox := load("res://src/ui/FxSandbox.gd")
	var box = Sandbox.new()
	root.add_child(box)
	await process_frame
	check(not box.visible, "sandbox starts closed")
	box.open()
	check(box.visible and box.is_open(), "open shows the panel")
	var played := []
	box.play_requested.connect(func(id): played.append(id))
	box._ask_play("fired_victim")
	check(played.has("fired_victim"), "clicking a clip requests play")
	box.close()
	check(not box.is_open(), "close hides the panel")
	quit(1 if failures > 0 else 0)
