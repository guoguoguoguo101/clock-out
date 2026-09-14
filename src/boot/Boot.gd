extends Node
class_name Boot

func _ready() -> void:
	var dedicated := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--server" or arg == "--dedicated":
			dedicated = true
	if dedicated:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		var err := Net.host_dedicated()
		if err != OK:
			push_error(Net.last_error)
			get_tree().quit(1)
			return
	get_tree().change_scene_to_file.call_deferred("res://src/game/Game.tscn")
