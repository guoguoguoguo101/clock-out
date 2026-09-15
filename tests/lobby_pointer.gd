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
	var Pointer = load("res://src/ui/LobbyPointer.gd")
	var Haunt = load("res://src/ui/LobbyHaunt.gd")
	var view := Vector2(1280, 720)
	var tex := Vector2(1280, 720)
	var cover: Rect2 = Pointer.aspect_cover_rect(view, tex)
	check(cover.position == Vector2.ZERO, "same-aspect cover starts at origin")
	check(cover.size == view, "same-aspect cover fills the view")
	var tiger: Rect2 = Pointer.uv_to_screen(view, tex, Pointer.TIGER_UV)
	check(tiger.position.x > 600.0 and tiger.position.x < 720.0, "tiger hotspot sits in the glass")
	check(tiger.has_point(Vector2(780, 280)), "tiger chest is inside the inspect rect")
	check(not tiger.has_point(Vector2(80, 80)), "left corridor is not the tiger")
	var wide := Vector2(1600, 720)
	var wide_cover: Rect2 = Pointer.aspect_cover_rect(wide, tex)
	check(wide_cover.size.y > wide.y - 1.0, "cover grows past a wider view")
	check(wide_cover.position.y < 0.0, "cover crops the top and bottom")
	check(Pointer.cursor_mode("start") == "operate", "buttons use the operate cursor")
	check(Pointer.cursor_mode("punch") == "inspect", "hotspots use the inspect cursor")
	check(Pointer.cursor_mode("text") == "text", "fields keep an I-beam")
	check(Pointer.cursor_mode("idle") == "idle", "empty lobby keeps the default arrow")
	var idle_img: Image = Pointer.make_cursor_image("idle")
	check(idle_img.get_pixel(2, 2).a > 0.5, "idle cursor has a hotspot pixel")
	check(Pointer.make_cursor_image("inspect").get_pixel(16, 16).a > 0.5, "inspect cursor is centered")
	var host := Control.new()
	var btn := Button.new()
	var cap := Label.new()
	btn.add_child(cap)
	host.add_child(btn)
	check(Pointer.owning_widget(cap, host) == btn, "caption hits resolve to the button")
	check(Pointer.owning_widget(host, host) == null, "the lobby root is not a widget")
	var haunt = Haunt.new()
	check(haunt.trigger_pointer("tiger"), "first tiger click opens the fifth-person event")
	check(haunt._event_kind == 3, "tiger click uses the unnamed attendee card")
	check(not haunt.trigger_pointer("tiger"), "tiger click waits out its cooldown")
	check(haunt.trigger_pointer("punch"), "punch click is flavor only")
	check(haunt.start_pulse > 0.8, "punch click lights the clock-in button")
	check(haunt.trigger_pointer("exit"), "exit click posts the B1 gate event")
	check(haunt._event_kind == 2, "exit click does not start the match")
	check(haunt.trigger_pointer("cam"), "camera click boosts the scan")
	check(haunt.scan_boost > 0.5, "camera click is a focus pulse")
	var game = load("res://src/game/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.pointer != null, "lobby pointer is wired")
	check(game.lobby != null and game.lobby.visible, "the game opens in the lobby")
	var start: Node = game.home_page.get_node_or_null("StartBtn")
	check(start != null and str(start.get_meta("pointer_id")) == "start", "clock-in button is tagged")
	check(game.home_page.get_node_or_null("HauntStamp") != null, "stamp flash has a target")
	game.queue_free()
	host.queue_free()
	print("POINTER CHECKS FINISHED failures=", failures)
	quit(1 if failures else 0)
