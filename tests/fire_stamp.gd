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
	var Overlay := load("res://src/ui/FireStampOverlay.gd")
	var node = Overlay.new()
	node.size = Vector2(1280, 720)
	root.add_child(node)
	await process_frame
	check(node.stamp != null and node.stamp.texture != null, "stamp texture is wired")
	check(node.paper != null and node.paper.texture != null, "notice texture is wired")
	check(node.imprint != null and node.imprint.texture != null, "imprint texture is wired")
	node.play(0, "小马")
	check(node.visible, "victim overlay is visible after play")
	await create_timer(0.85).timeout
	check(node._hit, "stamp slams before a second")
	check(node.imprint.modulate.a > 0.5, "imprint appears on slam")
	check(str(node.title.text).find("开除") >= 0, "title says fired")
	node.stop()
	check(not node.visible, "stop hides overlay")
	node.play(1, "鹈鹕")
	check(str(node.title.text).find("鹈鹕") >= 0, "boss overlay names the victim")
	quit(1 if failures > 0 else 0)
