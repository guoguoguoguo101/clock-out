extends Node
class_name Boot

func _ready() -> void:
	var dedicated := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--server" or arg == "--dedicated":
			dedicated = true
	if dedicated:
		push_error("联机权威已改到 Go。请运行 server.bat 或 go run ./cmd/clockout-server")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file.call_deferred("res://src/game/Game.tscn")
