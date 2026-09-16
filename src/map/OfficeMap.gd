extends Node2D
class_name OfficeMap

const OfficeDoorScript := preload("res://src/map/OfficeDoor.gd")
const RoomFogScript := preload("res://src/map/RoomFog.gd")
const Art := preload("res://src/map/OfficeArt.gd")

const WALL := 1
const PAPER_BLOCK := 16
const CELL := 32
const DESK_RECT := Rect2(896, 1152, 1760, 928)
const DESK_DOOR := Vector2(1776, 1152)

const ROOMS := [
	{"id": 1, "key": "toilet", "title": "洗手间", "rect": Rect2(64, 160, 640, 704)},
	{"id": 2, "key": "archive", "title": "档案室", "rect": Rect2(896, 160, 736, 704)},
	{"id": 3, "key": "tea", "title": "茶水间", "rect": Rect2(1824, 160, 832, 704)},
	{"id": 4, "key": "lounge", "title": "休息区", "rect": Rect2(2848, 160, 1184, 704)},
	{"id": 6, "key": "lobby", "title": "门厅 / 打卡", "rect": Rect2(64, 1152, 640, 928)},
	{"id": 7, "key": "office", "title": "产品研发中心", "rect": DESK_RECT},
	{"id": 8, "key": "meeting", "title": "会议中心", "rect": Rect2(2848, 1152, 1184, 928)},
	{"id": 9, "key": "print", "title": "打印 / 后勤", "rect": Rect2(64, 2368, 1568, 384)},
	{"id": 10, "key": "focus", "title": "安静工作间", "rect": Rect2(1824, 2368, 832, 384)},
	{"id": 11, "key": "garden", "title": "窗边休憩", "rect": Rect2(2848, 2368, 1184, 384)},
]

var points: Dictionary = {}
var zone_areas: Dictionary = {}
var occupiers: Dictionary = {}
var energy_loot: Dictionary = {}
var solids: Array[Rect2] = []
var sight_walls: Array[Rect2] = []
var desk_screens: Array[Sprite2D] = []
var desk_left: Array[bool] = [false, false, false, false, false, false]
var day_mod: CanvasModulate
var doors: Array = []
var stall_toilets: Dictionary = {}
var nav := AStarGrid2D.new()
var _path_cache: Dictionary = {}
var _floor_texture: Texture2D
var _clock: Label
var flicker_t := 0.0
var discovered: Dictionary = {}


func _ready() -> void:
	y_sort_enabled = true
	Art.prepare()
	_floor_texture = _load_tex(Art.FLOOR_PATH)
	var floors := Node2D.new()
	floors.z_index = -20
	floors.z_as_relative = false
	floors.draw.connect(_draw_floors.bind(floors))
	add_child(floors)
	floors.queue_redraw()
	_build_structure()
	_build_props()
	_build_doors()
	_build_energy()
	_build_zones()
	_build_navigation()
	day_mod = CanvasModulate.new()
	day_mod.color = Color(1, 1, 1)
	add_child(day_mod)
	var fog := RoomFogScript.new()
	fog.name = "RoomFog"
	add_child(fog)


func _process(delta: float) -> void:
	if Match == null:
		return
	flicker_t += delta
	apply_daylight(Match.day_progress())
	_sync_left_desks()
	if Net.is_enet_server():
		for d in doors:
			var door = d
			var was: bool = door.opening
			door.tick(delta)
			if was and not door.opening:
				_sync_door.rpc(door.door_id, door.closed, door.opening, door.open_left)
	queue_redraw()


func _draw_floors(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Rules.MAP_SIZE), Color("#e6ecee"))
	for room in ROOMS:
		var rect: Rect2 = room.rect
		canvas.draw_rect(rect, Color("#dce4e7"))
		if _floor_texture:
			canvas.draw_texture_rect(_floor_texture, rect, true, Color(1, 1, 1, 0.42))
		canvas.draw_rect(rect, Color("#becbd0"), false, 2)
	for y in [896.0, 2112.0]:
		var band := Rect2(32, y, 4032, 224)
		canvas.draw_rect(band, Color("#edf0ed"))
		if _floor_texture:
			canvas.draw_texture_rect(_floor_texture, band, true, Color(1, 1, 1, 0.22))
		canvas.draw_line(Vector2(32, y + 192), Vector2(4064, y + 192), Color("#bccdd0"), 3)
	for x in [736.0, 1664.0, 2688.0]:
		canvas.draw_rect(Rect2(x, 32, 128, 2752), Color(0.94, 0.95, 0.93, 0.35))


func _build_structure() -> void:
	_wall(Rect2(0, 0, 4096, 32), true)
	_wall(Rect2(0, 2784, 4096, 32), true)
	_wall(Rect2(0, 0, 32, 2816), true)
	_wall(Rect2(4064, 0, 32, 2816), true)
	for room in ROOMS:
		var r: Rect2 = room.rect
		var bottom_gaps: Array = [r.get_center().x]
		var top_gaps: Array = []
		var left_gaps: Array = []
		var right_gaps: Array = []
		match str(room.key):
			"office":
				bottom_gaps = [1120.0, 2432.0]
				top_gaps = [1120.0, 2432.0]
				left_gaps = [1632.0]
				right_gaps = [1632.0]
			"archive", "tea":
				right_gaps = [512.0]
				left_gaps = [512.0] if str(room.key) == "tea" else []
			"lounge":
				left_gaps = [512.0]
			"lobby":
				top_gaps = [384.0]
				right_gaps = [1632.0]
			"meeting":
				top_gaps = [3424.0]
				left_gaps = [1632.0]
			"print", "focus", "garden":
				top_gaps = [r.position.x + 192, r.end.x - 192]
				bottom_gaps = []
			"toilet":
				bottom_gaps = [r.get_center().x]
		_wall_run(r.position.x, r.end.x, r.position.y, true, top_gaps)
		_wall_run(r.position.x, r.end.x, r.end.y, true, bottom_gaps)
		_wall_run(r.position.y, r.end.y, r.position.x, false, left_gaps)
		_wall_run(r.position.y, r.end.y, r.end.x, false, right_gaps)
		_sign(r.position + Vector2(28, 22), str(room.title), 18)
	_sign(Vector2(944, 973), "← 洗手间 / 档案     NORTH WALK     茶水间 / 休息区 →", 18)
	_sign(Vector2(1408, 2193), "← 门厅 / 打卡     SOUTH WALK     打印 / 窗边休憩 →", 18)
	for x in [64.0, 1824.0, 3232.0]:
		_sign(Vector2(x, 74), "更好的工作 · 更好的生活", 20)
	for x in [480.0, 1472.0, 2400.0, 3776.0]:
		_prop("window", Vector2(x, 145), 240, false)
	_clock = _sign(Vector2(1920, 1105), "17:50", 22)
	_prop("poster", Vector2(1344, 1288), 180, false)
	_prop("wayfinding", Vector2(2680, 1040), 70)
	_prop("wayfinding", Vector2(800, 2240), 70)


func _wall_run(start: float, end: float, fixed: float, horizontal: bool, gaps: Array) -> void:
	gaps.sort()
	var cursor := start
	for center in gaps:
		var stop: float = float(center) - 80.0
		if stop > cursor:
			if horizontal:
				_wall(Rect2(cursor, fixed - 10, stop - cursor, 20))
			else:
				_wall(Rect2(fixed - 10, cursor, 20, stop - cursor))
		cursor = float(center) + 80.0
	if cursor < end:
		if horizontal:
			_wall(Rect2(cursor, fixed - 10, end - cursor, 20))
		else:
			_wall(Rect2(fixed - 10, cursor, 20, end - cursor))


func _wall(rect: Rect2, _outer := false) -> void:
	_obstacle(rect, true)
	_rect(rect.grow(3), Color("#9eafb9"), -3)
	_rect(rect, Color("#edf0ec"), -2)
	if rect.size.x > rect.size.y:
		_rect(Rect2(rect.position + Vector2(0, 9), Vector2(rect.size.x, 4)), Color("#c2cdd2"), -1)


func _obstacle(rect: Rect2, blocks_sight := false) -> void:
	solids.append(rect)
	if blocks_sight:
		sight_walls.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = WALL | PAPER_BLOCK
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _prop(kind: String, foot: Vector2, width: float, solid := true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Art.prop(kind)
	sprite.position = foot
	if sprite.texture:
		var texture_size := sprite.texture.get_size()
		sprite.scale = Vector2.ONE * width / maxf(texture_size.x, 1.0)
		sprite.offset.y = -texture_size.y * 0.5
	sprite.z_index = 0
	add_child(sprite)
	if solid:
		var depth := minf(width * 0.22, 56.0)
		_obstacle(Rect2(foot.x - width * 0.43, foot.y - depth, width * 0.86, depth))
	return sprite


func _file_prop(path: String, foot: Vector2, width: float, solid := true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _load_tex(path)
	sprite.position = foot
	if sprite.texture:
		var sz := sprite.texture.get_size()
		sprite.scale = Vector2.ONE * width / maxf(sz.x, 1.0)
		sprite.offset.y = -sz.y * 0.5
	sprite.z_index = 0
	add_child(sprite)
	if solid:
		_obstacle(Rect2(foot.x - width * 0.4, foot.y - 28, width * 0.8, 36))
	return sprite


func _build_props() -> void:
	var index := 0
	for y in [1472.0, 1840.0]:
		for x in [1120.0, 1536.0, 1952.0, 2368.0]:
			var desk := _prop("desk", Vector2(x, y), 290)
			var seat := Vector2(x, y + 76)
			_prop("chair", seat + Vector2(0, 18), 62, false)
			if index < 6:
				points["desk_%d" % (index + 1)] = Vector2(x, y)
				points["seat_%d" % (index + 1)] = seat
				points["sup_%d" % (index + 1)] = seat + Vector2(0, 58)
				desk_screens.append(desk)
				_sign(Vector2(x - 120, y + 5), "EMP.%02d" % (index + 1), 11)
			if index == 1 or index == 4:
				_prop("divider", Vector2(x + 210, y + 10), 90)
				sight_walls.append(Rect2(x + 170, y - 40, 24, 80))
			index += 1
	for p in [Vector2(968, 1392), Vector2(2584, 1392), Vector2(968, 1992), Vector2(2584, 1992)]:
		_prop("plant", p, 72)
	for x in [1088.0, 1440.0]:
		for y in [400.0, 608.0]:
			_prop("cabinet", Vector2(x, y), 174)
			sight_walls.append(Rect2(x - 72, y - 42, 144, 42))
	_prop("copier", Vector2(1168, 792), 100)
	_sign(Vector2(928, 230), "归档完成，也要再检查一遍。", 14)
	for i in 2:
		var tx := 240.0 + i * 256.0
		var bowl := _prop("toilet", Vector2(tx, 432), 80)
		points["toilet_%d" % i] = Vector2(tx, 480)
		stall_toilets["toilet_%d" % i] = bowl
		_wall(Rect2(tx - 86, 304, 12, 264))
		_wall(Rect2(tx + 86, 304, 12, 264))
		_wall(Rect2(tx - 86, 304, 184, 12))
	_prop("sink", Vector2(432, 752), 192)
	_prop("plant", Vector2(624, 752), 58)
	for i in 2:
		var cx := 2048.0 + i * 352.0
		_prop("coffee", Vector2(cx, 448), 180)
		points["coffee_%d" % i] = Vector2(cx, 512)
	_prop("water", Vector2(2560, 704), 80)
	_prop("cabinet", Vector2(1984, 736), 170)
	_sign(Vector2(1888, 260), "咖啡不是生产力，但你需要。", 14)
	_prop("sofa", Vector2(3120, 464), 300)
	_prop("sofa", Vector2(3712, 464), 300)
	_prop("meeting", Vector2(3424, 736), 240)
	_prop("plant", Vector2(3904, 736), 96)
	_prop("cabinet", Vector2(2944, 768), 120)
	points["lounge"] = Vector2(3424, 576)
	points["stock_0"] = Vector2(3424, 700)
	_file_prop("res://assets/game/props/stock_machine.png", points["stock_0"] + Vector2(90, -20), 92)
	_sign(Vector2(2912, 260), "累了？坐一会儿。", 16)
	for i in 2:
		var foot := Vector2(192 + i * 416, 1472 + i * 448)
		_prop("punch", foot, 64)
		points["punch_%d" % i] = foot + Vector2(0, 64)
		_sign(foot + Vector2(-52, -150), "打卡 %s" % ("A" if i == 0 else "B"), 15)
	_prop("sofa", Vector2(368, 1984), 184)
	_prop("plant", Vector2(144, 1984), 78)
	_sign(Vector2(160, 1260), "今日辛苦了\n完成交付后打卡离场", 16)
	_prop("glass_wall", Vector2(3424, 1288), 520, false)
	_prop("meeting", Vector2(3424, 1576), 420)
	for x in [3200.0, 3424.0, 3648.0]:
		_prop("chair", Vector2(x, 1620), 62, false)
		_prop("chair", Vector2(x, 1392), 58, false)
	_prop("whiteboard", Vector2(3872, 1472), 150)
	_prop("plant", Vector2(3008, 1952), 86)
	points["meeting"] = Vector2(3424, 1792)
	_prop("sofa", Vector2(3776, 1984), 260)
	for x in [288.0, 608.0]:
		_prop("copier", Vector2(x, 2704), 152)
	for x in [960.0, 1280.0]:
		_prop("cabinet", Vector2(x, 2704), 210)
	points["print"] = Vector2(800, 2528)
	_sign(Vector2(832, 2472), "打印失败，请再试一次。", 14)
	_prop("desk", Vector2(2080, 2688), 226)
	_prop("whiteboard", Vector2(2496, 2672), 125)
	points["focus"] = Vector2(2304, 2528)
	_prop("sofa", Vector2(3264, 2720), 280)
	_prop("plant", Vector2(2944, 2704), 105)
	_prop("plant", Vector2(3904, 2704), 105)
	points["garden"] = Vector2(3552, 2528)
	points["corridor"] = Vector2(1776, 1008)
	points["boss_spawn"] = Vector2(2496, 1008)
	points["shop_0"] = Vector2(1984, 736)
	points["shop_1"] = Vector2(800, 2528)
	for p in [Vector2(128, 1024), Vector2(3968, 1024), Vector2(128, 2240), Vector2(3968, 2240)]:
		_prop("plant", p, 82)
	for p in [Vector2(1696, 896), Vector2(3968, 1184), Vector2(768, 2272), Vector2(2400, 2112)]:
		_prop("camera", p, 50, false)
	for key in points:
		occupiers[key] = -1


func _build_doors() -> void:
	_add_door("toilet", Vector2(384, 864), "洗手间")
	_add_door("storage", Vector2(1264, 864), "档案")
	_add_door("tea", Vector2(2240, 864), "茶水")
	_add_door("lounge", Vector2(3440, 864), "休息")
	_add_door("lobby", Vector2(384, 1152), "门厅")
	_add_door("desk", DESK_DOOR, "工位")
	_add_door("meeting", Vector2(2848, 1632), "会议")
	_add_door("print", Vector2(256, 2368), "后勤")


func _add_door(id: String, pos: Vector2, title: String) -> void:
	var d = OfficeDoorScript.new()
	d.setup(id, pos, title)
	add_child(d)
	doors.append(d)


func nearest_door(from: Vector2, max_d := 72.0):
	var best = null
	var best_d := max_d
	for item in doors:
		var d = item
		var dist: float = from.distance_to(d.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func door_by_id(id: String):
	for item in doors:
		if item.door_id == id:
			return item
	return null


func try_door(actor: Actor) -> bool:
	var d = nearest_door(actor.global_position, Rules.DOOR_RANGE)
	if d == null:
		return false
	if d.opening:
		return true
	if d.closed:
		if d.begin_open():
			_sync_door.rpc(d.door_id, d.closed, d.opening, d.open_left)
		return true
	if actor.kind == Rules.Kind.EMPLOYEE:
		d.slam()
		_sync_door.rpc(d.door_id, d.closed, d.opening, d.open_left)
		return true
	return false


@rpc("authority", "reliable")
func _sync_door(id: String, closed: bool, opening: bool, open_left: float) -> void:
	for item in doors:
		var d = item
		if d.door_id == id:
			d.apply_state(closed, opening, open_left)
			return


func door_pos_for_room(room: int, from: Vector2) -> Vector2:
	for item in doors:
		if _door_room(item.door_id) == room:
			return item.global_position
	return from


func _door_room(id: String) -> int:
	match id:
		"toilet":
			return 1
		"storage":
			return 2
		"tea":
			return 3
		"lounge":
			return 4
		"lobby":
			return 6
		"desk":
			return 7
		"meeting":
			return 8
		"print":
			return 9
		_:
			return 5


func _build_energy() -> void:
	_energy_spot("vend_0", "vend", Vector2(2160, 760), "res://assets/game/props/energy/vending.png", 78, false)
	_energy_spot("water_0", "water", Vector2(2560, 760), "res://assets/game/props/energy/water_cup.png", 28, false)
	_energy_spot("fridge_0", "rummage", Vector2(1900, 700), "res://assets/game/props/energy/fridge.png", 70, false)
	_energy_spot("rummage_0", "rummage", Vector2(1088, 760), "res://assets/game/props/energy/drawer.png", 64, true)
	_energy_spot("rummage_1", "rummage", Vector2(1440, 760), "res://assets/game/props/energy/drawer.png", 64, true)
	_energy_spot("snack_0", "snack", Vector2(1120, 1548), "res://assets/game/props/energy/snack_choco.png", 28, true)
	_energy_spot("snack_1", "snack", Vector2(1952, 1548), "res://assets/game/props/energy/snack_cookie.png", 30, true)
	_energy_spot("snack_2", "snack", Vector2(800, 2600), "res://assets/game/props/energy/snack_noodle.png", 34, true)
	_energy_spot("snack_3", "snack", Vector2(3552, 2600), "res://assets/game/props/energy/can_drink.png", 22, true)
	_energy_spot("snack_4", "snack", Vector2(368, 1984), "res://assets/game/props/energy/snack_choco.png", 26, true)


func _energy_spot(id: String, kind: String, pos: Vector2, path: String, width: float, once: bool) -> void:
	var spr := _file_prop(path, pos, width, false)
	points[id] = pos
	occupiers[id] = -1
	energy_loot[id] = {"kind": kind, "once": once, "used": false, "sprite": spr}


func _build_zones() -> void:
	for id in ["coffee_0", "coffee_1", "toilet_0", "toilet_1", "punch_0", "punch_1", "meeting", "stock_0"]:
		if points.has(id):
			_zone(id, points[id], 56.0 if id != "meeting" else 110.0)
	for i in 6:
		_zone("seat_%d" % (i + 1), points["seat_%d" % (i + 1)], 52)
		_zone("sup_%d" % (i + 1), points["sup_%d" % (i + 1)], 60)


func _zone(id: String, pos: Vector2, radius: float) -> void:
	var area := Area2D.new()
	area.name = id
	area.position = pos
	area.collision_layer = 4
	area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	area.add_child(cs)
	add_child(area)
	zone_areas[id] = area
	occupiers[id] = -1


func _build_navigation() -> void:
	nav.region = Rect2i(0, 0, int(Rules.MAP_SIZE.x / CELL), int(Rules.MAP_SIZE.y / CELL))
	nav.cell_size = Vector2(CELL, CELL)
	nav.offset = Vector2(CELL / 2.0, CELL / 2.0)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for rect in solids:
		var padded := rect.grow(17)
		var start := Vector2i(floor(padded.position.x / CELL), floor(padded.position.y / CELL))
		var finish := Vector2i(ceil(padded.end.x / CELL), ceil(padded.end.y / CELL))
		for y in range(maxi(start.y, 0), mini(finish.y, nav.region.end.y)):
			for x in range(maxi(start.x, 0), mini(finish.x, nav.region.end.x)):
				if padded.has_point(nav.get_point_position(Vector2i(x, y))):
					nav.set_point_solid(Vector2i(x, y))


func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x / CELL), 0, nav.region.end.x - 1), clampi(int(pos.y / CELL), 0, nav.region.end.y - 1))


func _free_cell(pos: Vector2) -> Vector2i:
	var center := _cell_at(pos)
	if not nav.is_point_solid(center):
		return center
	for radius in range(1, 9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := center + Vector2i(x, y)
				if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
					return cell
	return center


func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _free_cell(from)
	var finish := _free_cell(to)
	var key := Vector4i(start.x, start.y, finish.x, finish.y)
	if not _path_cache.has(key):
		if _path_cache.size() > 512:
			_path_cache.clear()
		_path_cache[key] = nav.get_point_path(start, finish)
	return _path_cache[key]


func path_to(from: Vector2, to: Vector2) -> Vector2:
	if segment_clear(from, to, solids, 15):
		return to
	var path := route(from, to)
	if path.is_empty():
		return from
	for i in range(mini(path.size() - 1, 8), -1, -1):
		if from.distance_to(path[i]) > 10 and segment_clear(from, path[i], solids, 14):
			return path[i]
	return path[mini(1, path.size() - 1)]


func segment_clear(a: Vector2, b: Vector2, rectangles: Array[Rect2], margin := 0.0) -> bool:
	for original in rectangles:
		var rect := original.grow(margin)
		if rect.has_point(a) or rect.has_point(b):
			return false
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true


func same_view(a: Vector2, b: Vector2) -> bool:
	if _room_id(a) == _room_id(b) and _room_id(a) not in [5, 12]:
		return true
	return a.distance_to(b) <= 680.0 and segment_clear(a, b, sight_walls)


func room_id(p: Vector2) -> int:
	return _room_id(p)


func _room_id(p: Vector2) -> int:
	for room in ROOMS:
		if room.rect.has_point(p):
			return int(room.id)
	return 5 if p.y < 1500.0 else 12


func room_title(p: Vector2) -> String:
	for room in ROOMS:
		if room.rect.has_point(p):
			return str(room.title)
	return "北侧主廊" if p.y < 1500.0 else "南侧回廊"


func view_rect_at(p: Vector2) -> Rect2:
	var size := Vector2(1080, 680)
	var pos := p - size * 0.5
	pos.x = clampf(pos.x, 0.0, Rules.MAP_SIZE.x - size.x)
	pos.y = clampf(pos.y, 0.0, Rules.MAP_SIZE.y - size.y)
	return Rect2(pos, size)


func visible_rect_for(actor: Actor) -> Rect2:
	return view_rect_at(actor.global_position).grow(12)


func is_desk_area(p: Vector2) -> bool:
	return DESK_RECT.has_point(p)


func seat_for_slot(slot: int) -> Vector2:
	return points["seat_%d" % (Rules.employee_index(slot) + 1)]


func roll_employee_spawn(taken: Array[Vector2] = []) -> Vector2:
	var pool: Array[Vector2] = [
		Vector2(1776, 1008),
		Vector2(800, 1008),
		Vector2(2600, 1008),
		Vector2(384, 1632),
		Vector2(2304, 2528),
		Vector2(3424, 576),
		Vector2(2240, 760),
		Vector2(3552, 2528),
		Vector2(1264, 760),
		Vector2(384, 1984),
	]
	pool.shuffle()
	for p in pool:
		var ok := true
		for t in taken:
			if p.distance_to(t) < 96.0:
				ok = false
				break
		if ok:
			return p + Vector2(randf_range(-20.0, 20.0), randf_range(-14.0, 14.0))
	return points.get("corridor", Vector2(1776, Rules.CORRIDOR_Y)) + Vector2(randf_range(-120.0, 120.0), randf_range(-18.0, 18.0))


func nearest_punch(from: Vector2) -> Vector2:
	var a: Vector2 = points["punch_0"]
	var b: Vector2 = points["punch_1"]
	return a if from.distance_to(a) <= from.distance_to(b) else b


func nearest_spot(prefix: String, from: Vector2, max_d := 1e9) -> String:
	var best := ""
	var best_d := max_d
	var key := prefix + "_"
	for id in occupiers.keys():
		if not str(id).begins_with(key) or not points.has(id):
			continue
		var d: float = from.distance_to(points[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func nearest_free(prefix: String, from: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	var key := prefix + "_"
	for id in occupiers.keys():
		if not str(id).begins_with(key) or not points.has(id):
			continue
		if occupiers[id] != -1:
			continue
		var d: float = from.distance_to(points[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func take_spot(id: String, actor_id: int) -> bool:
	if id == "":
		return false
	if occupiers.get(id, -1) != -1 and occupiers[id] != actor_id:
		return false
	occupiers[id] = actor_id
	_set_stall_bowl_visible(id)
	return true


func free_spot(id: String, actor_id: int) -> void:
	if id != "" and occupiers.get(id, -1) == actor_id:
		occupiers[id] = -1
		_set_stall_bowl_visible(id)


func _set_stall_bowl_visible(id: String) -> void:
	if not stall_toilets.has(id):
		return
	(stall_toilets[id] as CanvasItem).visible = occupiers.get(id, -1) == -1


func nearest_energy(from: Vector2, max_d: float) -> String:
	var best := ""
	var best_d := max_d
	for id in energy_loot.keys():
		var loot: Dictionary = energy_loot[id]
		if loot.get("used", false):
			continue
		if occupiers.get(id, -1) != -1:
			continue
		if not points.has(id):
			continue
		var d: float = from.distance_to(points[id])
		if d < best_d:
			best_d = d
			best = id
	return best


func energy_prompt(id: String) -> String:
	if str(id).begins_with("fridge"):
		return "E 翻冰箱 · 不是你的也先垫一口"
	match energy_kind(id):
		"vend":
			return "E 投币柜 · 停格出货"
		"rummage":
			return "E 翻抽屉 · 卡点摸零食"
		"water":
			return "E 接一杯水"
		"snack":
			return "E 搜刮桌面零食"
		_:
			return "E 找精力"


func energy_kind(id: String) -> String:
	if not energy_loot.has(id):
		return ""
	return str(energy_loot[id].get("kind", ""))


func energy_pos(id: String) -> Vector2:
	return points.get(id, Vector2.ZERO)


func take_energy(id: String, actor_id: int) -> bool:
	if id == "" or not energy_loot.has(id):
		return false
	if energy_loot[id].get("used", false):
		return false
	return take_spot(id, actor_id)


func free_energy(id: String, actor_id: int) -> void:
	free_spot(id, actor_id)


func consume_energy(id: String) -> void:
	if not energy_loot.has(id):
		return
	if not energy_loot[id].get("once", false):
		return
	energy_loot[id]["used"] = true
	var spr = energy_loot[id].get("sprite")
	if spr:
		spr.visible = false


func _reset_energy() -> void:
	for id in energy_loot.keys():
		energy_loot[id]["used"] = false
		var spr = energy_loot[id].get("sprite")
		if spr:
			spr.visible = true
		occupiers[id] = -1


func apply_daylight(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if day_mod:
		day_mod.color = Color(1, 1, 1).lerp(Color(1.0, 0.97, 0.94), smoothstep(0.72, 1.0, p))
	if _clock:
		_clock.text = Rules.office_clock_text(p)


func _sync_left_desks() -> void:
	for s in Rules.EMPLOYEE_SLOTS:
		if not Match.actors.has(s):
			continue
		var e: Actor = Match.actors[s]
		if e.emp_state == Rules.EmpState.LEFT:
			mark_desk_left(int(s))


func mark_desk_left(slot: int) -> void:
	var i := Rules.employee_index(slot)
	if i < 0 or i >= desk_screens.size() or desk_left[i]:
		return
	desk_left[i] = true
	desk_screens[i].modulate = Color("#bbcad0")


func reset_shift() -> void:
	discovered.clear()
	desk_left = [false, false, false, false, false, false]
	for s in desk_screens:
		if s:
			s.modulate = Color.WHITE
	for n in get_tree().get_nodes_in_group("desk_left_mark"):
		n.queue_free()
	for item in doors:
		item.force_open()
	apply_daylight(0.0)
	_reset_energy()


func employee_threat() -> float:
	var me: Actor = Match.actors.get(Match.my_slot()) as Actor
	if me == null or me.kind != Rules.Kind.EMPLOYEE:
		return 0.0
	return threat_for(me)


func threat_for(me: Actor) -> float:
	if me == null or me.kind != Rules.Kind.EMPLOYEE:
		return 0.0
	if me.emp_state == Rules.EmpState.TALK:
		return 1.0
	var boss: Actor = Match.actors.get(Rules.Slot.BOSS) as Actor
	if boss == null:
		return 0.1 if me.emp_state == Rules.EmpState.SLACK else 0.0
	if same_view(me.global_position, boss.global_position):
		return 1.0
	var dist := me.global_position.distance_to(boss.global_position)
	var prox := 1.0 - clampf((dist - 160.0) / 640.0, 0.0, 1.0)
	prox *= prox
	if _room_id(me.global_position) != _room_id(boss.global_position):
		prox *= 0.58
	if me.emp_state == Rules.EmpState.SLACK:
		prox = maxf(prox, 0.12)
	return clampf(prox, 0.0, 0.92)


func _draw() -> void:
	if Match == null:
		return
	if Match.incident_active:
		var tp: Vector2 = Match.incident_terminal_pos
		var pulse := 0.6 + 0.4 * absf(sin(flicker_t * 5.0))
		draw_rect(Rect2(tp.x - 20, tp.y - 20, 40, 40), Color(0.18, 0.62, 0.48, 0.85 * pulse))
		draw_rect(Rect2(tp.x - 20, tp.y - 20, 40, 40), Color(0.10, 0.28, 0.24), false, 2.0)
	for k in Match.delivery_spots:
		var dp: Vector2 = Match.delivery_spots[k]
		draw_circle(dp, 18.0, Color(0.95, 0.72, 0.28, 0.55))


func _rect(rect: Rect2, color: Color, z: int) -> ColorRect:
	var vis := ColorRect.new()
	vis.color = color
	vis.position = rect.position
	vis.size = rect.size
	vis.z_index = z
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	return vis


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


func _sign(pos: Vector2, text: String, font_size := 16) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#526575"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = -1
	add_child(label)
	return label
