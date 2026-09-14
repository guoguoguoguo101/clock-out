extends Node2D
class_name OfficeMap

const WALL := 1
const TOP_Y := 560.0
const BOT_Y := 780.0
const X_TOILET := 500.0
const X_NORTH := 980.0
const X_TEA := 1700.0
const X_DESK := 1720.0
const DESK_RECT := Rect2(520, 780, 1200, 700)

const PROP_REGION := {
	"res://assets/game/props/desk.png": Rect2(137, 617, 750, 286),
	"res://assets/game/props/chair.png": Rect2(377, 637, 270, 266),
	"res://assets/game/props/screen.png": Rect2(357, 427, 310, 300),
	"res://assets/game/props/paper.png": Rect2(657, 517, 206, 246),
	"res://assets/game/props/coffee.png": Rect2(697, 541, 166, 162),
	"res://assets/game/props/browser_ui.png": Rect2(157, 177, 710, 586),
	"res://assets/game/props/plant.png": Rect2(33, 17, 62, 90),
	"res://assets/game/props/cabinet.png": Rect2(37, 21, 54, 82),
	"res://assets/game/props/sofa.png": Rect2(9, 45, 110, 46),
	"res://assets/game/props/toilet.png": Rect2(37, 21, 54, 82),
	"res://assets/game/props/sink.png": Rect2(21, 25, 86, 70),
	"res://assets/game/props/door.png": Rect2(39, 21, 50, 82),
	"res://assets/game/props/clock.png": Rect2(45, 25, 38, 78),
	"res://assets/game/props/coffee_machine.png": Rect2(37, 37, 54, 64),
	"res://assets/game/props/water.png": Rect2(43, 21, 42, 86),
	"res://assets/game/props/meeting.png": Rect2(9, 33, 110, 58),
	"res://assets/game/props/laptop.png": Rect2(33, 45, 62, 38),
	"res://assets/game/props/books.png": Rect2(33, 33, 62, 62),
	"res://assets/game/props/file.png": Rect2(39, 29, 50, 70),
	"res://assets/game/props/drink.png": Rect2(45, 33, 38, 66),
	"res://assets/game/props/phone.png": Rect2(45, 29, 38, 70),
}

var points: Dictionary = {}
var zone_areas: Dictionary = {}
var occupiers: Dictionary = {}
var window_panes: Array[ColorRect] = []
var wall_clocks: Array[Node2D] = []
var clock_labels: Array[Label] = []
var desk_screens: Array[Sprite2D] = []
var desk_left: Array[bool] = [false, false, false, false]
var day_mod: CanvasModulate
var dusk_veil: ColorRect
var wall_cams: Array[Sprite2D] = []
var cam_leds: Array[ColorRect] = []
var flicker_lights: Array[ColorRect] = []
var gloom_veils: Array[ColorRect] = []
var gloom_base: Array[float] = []
var flicker_t := 0.0


func _ready() -> void:
	y_sort_enabled = true
	var floors := FloorPainter.new()
	floors.name = "Floors"
	add_child(floors)
	_build_walls()
	_build_windows()
	_build_furniture()
	_build_labels()
	_build_clocks()
	_build_zones()
	day_mod = CanvasModulate.new()
	day_mod.color = Color(0.97, 0.98, 1.0)
	add_child(day_mod)
	dusk_veil = ColorRect.new()
	dusk_veil.color = Color(0.16, 0.08, 0.04, 0.0)
	dusk_veil.position = Vector2(0, 0)
	dusk_veil.size = Vector2(2560, 1520)
	dusk_veil.z_index = -1
	dusk_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dusk_veil)


func _process(delta: float) -> void:
	apply_daylight(Match.day_progress())
	_sync_left_desks()
	_tick_horror(delta)


func _build_walls() -> void:
	_wall(Rect2(16, 16, 2528, 24), true)
	_wall(Rect2(16, 1480, 2528, 24), true)
	_wall(Rect2(16, 16, 24, 1488), true)
	_wall(Rect2(2520, 16, 24, 1488), true)
	# 北区南墙，门口对准厕所/储物/茶水/休息
	_wall(Rect2(40, 544, 88, 20))
	_wall(Rect2(232, 544, 260, 20))
	_wall(Rect2(492, 544, 196, 20))
	_wall(Rect2(792, 544, 180, 20))
	_wall(Rect2(972, 544, 316, 20))
	_wall(Rect2(1392, 544, 300, 20))
	_wall(Rect2(1692, 544, 96, 20))
	_wall(Rect2(1892, 544, 628, 20))
	_wall(Rect2(488, 40, 20, 524))
	_wall(Rect2(968, 40, 20, 524))
	_wall(Rect2(1688, 40, 20, 524))
	# 门厅北墙留口；工位朝走廊敞开
	_wall(Rect2(40, 764, 88, 20))
	_wall(Rect2(232, 764, 276, 20))
	_wall(Rect2(1712, 764, 112, 20))
	_wall(Rect2(1952, 764, 568, 20))
	_wall(Rect2(504, 780, 20, 140))
	_wall(Rect2(504, 1060, 20, 420))
	_wall(Rect2(1704, 780, 20, 140))
	_wall(Rect2(1704, 1060, 20, 420))
	_door_posts(Vector2(180, 554))
	_door_posts(Vector2(740, 554))
	_door_posts(Vector2(1340, 554))
	_door_posts(Vector2(1840, 554))
	_door_posts(Vector2(180, 774))
	_door_posts(Vector2(1860, 774))


func _wall(rect: Rect2, outer := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = WALL
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = Color(0.90, 0.93, 0.95) if outer else Color(0.96, 0.97, 0.98)
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	var cap := ColorRect.new()
	cap.color = Color(0.78, 0.82, 0.86)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.size.x >= rect.size.y:
		cap.size = Vector2(rect.size.x, 4)
		cap.position = Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5)
	else:
		cap.size = Vector2(4, rect.size.y)
		cap.position = Vector2(rect.size.x * 0.5 - 4, -rect.size.y * 0.5)
	body.add_child(cap)
	add_child(body)


func _door_posts(center: Vector2) -> void:
	_rect(Rect2(center.x - 58, center.y - 14, 12, 28), Color(0.88, 0.91, 0.94), -2)
	_rect(Rect2(center.x + 46, center.y - 14, 12, 28), Color(0.88, 0.91, 0.94), -2)
	_rect(Rect2(center.x - 46, center.y - 4, 92, 8), Color(0.72, 0.76, 0.80, 0.55), -6)


func _build_windows() -> void:
	for x in [90.0, 230.0, 580.0, 760.0, 1100.0, 1380.0, 1860.0, 2140.0]:
		_window(Rect2(x, 22, 96, 28), false)
	for y in [860.0, 1060.0, 1260.0]:
		_window(Rect2(22, y, 28, 100), true)
		_window(Rect2(2510, y, 28, 100), true)


func _window(rect: Rect2, tall: bool) -> void:
	_rect(rect, Color(0.22, 0.24, 0.28), -4)
	var inner := rect.grow(-5)
	window_panes.append(_rect(inner, Color(0.72, 0.86, 0.94), -3))
	if tall:
		_rect(Rect2(inner.position.x, inner.get_center().y - 1, inner.size.x, 2), Color(0.22, 0.24, 0.28, 0.7), -2)
		_rect(Rect2(inner.get_center().x - 1, inner.position.y, 2, inner.size.y), Color(0.22, 0.24, 0.28, 0.7), -2)
	else:
		_rect(Rect2(inner.get_center().x - 1, inner.position.y, 2, inner.size.y), Color(0.22, 0.24, 0.28, 0.7), -2)
		_rect(Rect2(inner.position.x, inner.get_center().y - 1, inner.size.x, 2), Color(0.22, 0.24, 0.28, 0.7), -2)


func _build_furniture() -> void:
	points["coffee_0"] = Vector2(1180, 180)
	points["coffee_1"] = Vector2(1460, 180)
	points["toilet_0"] = Vector2(160, 200)
	points["toilet_1"] = Vector2(360, 200)
	points["punch_0"] = Vector2(160, 1000)
	points["punch_1"] = Vector2(380, 1000)
	points["meeting"] = Vector2(2120, 1100)
	points["lounge"] = Vector2(2000, 220)
	points["corridor"] = Vector2(1280, Rules.CORRIDOR_Y)
	points["boss_spawn"] = Vector2(1280, Rules.CORRIDOR_Y)
	var seats := [
		Vector2(820, 1000),
		Vector2(1280, 1000),
		Vector2(820, 1280),
		Vector2(1280, 1280),
	]
	for i in 4:
		var desk: Vector2 = seats[i] + Vector2(0, -78)
		points["desk_%d" % (i + 1)] = desk
		points["seat_%d" % (i + 1)] = seats[i]
		points["sup_%d" % (i + 1)] = seats[i] + Vector2(0, 58)
		_cubicle(i, seats[i], desk)
	_dress_toilet()
	_dress_storage()
	_dress_tea()
	_dress_lounge()
	_dress_lobby()
	_dress_meeting()
	_dress_corridor()
	_dress_desk_shared()
	_dress_horror()


func _cubicle(idx: int, seat: Vector2, desk: Vector2) -> void:
	var right := idx == 1 or idx == 3
	var drawer_x := 70.0 if right else -118.0
	_desk_block(desk, drawer_x)
	_prop("res://assets/game/props/desk.png", desk + Vector2(0, 10), 250, -4)
	desk_screens.append(_prop("res://assets/game/props/screen.png", desk + Vector2(-8, -36), 92, -3))
	_prop("res://assets/game/props/chair.png", seat + Vector2(0, 10), 72, -3)
	_prop("res://assets/game/props/laptop.png", desk + Vector2(54 if right else -54, 8), 44, -3)
	_prop("res://assets/game/props/paper.png", desk + Vector2(78 if right else -78, 18), 32, -3)
	_prop("res://assets/game/props/coffee.png", desk + Vector2(-70 if right else 70, 14), 22, -3)
	_prop("res://assets/game/props/plant.png", desk + Vector2(108 if right else -108, -22), 48, -3)
	_prop("res://assets/game/props/phone.png", desk + Vector2(36 if right else -36, 20), 18, -3)
	_frame(Rect2(desk.x + (-150 if right else 86), desk.y - 118, 58, 42), Color(0.10, 0.11, 0.13) if idx == 2 else Color(0.28, 0.30, 0.34))
	_shelf(desk + Vector2(-130 if right else 90, -88), right)


func _desk_block(desk: Vector2, drawer_x: float) -> void:
	_rect(Rect2(desk.x - 118, desk.y + 8, 236, 18), Color(0.12, 0.14, 0.16, 0.16), -6)
	_rect(Rect2(desk.x - 120, desk.y - 28, 240, 52), Color(0.97, 0.97, 0.98), -5)
	_rect(Rect2(desk.x - 120, desk.y - 28, 240, 6), Color(0.90, 0.91, 0.93), -4)
	_rect(Rect2(desk.x + drawer_x, desk.y - 8, 48, 44), Color(0.93, 0.94, 0.96), -4)
	_rect(Rect2(desk.x + drawer_x + 6, desk.y + 2, 36, 3), Color(0.78, 0.80, 0.84), -3)
	_rect(Rect2(desk.x + drawer_x + 6, desk.y + 14, 36, 3), Color(0.78, 0.80, 0.84), -3)


func _shelf(pos: Vector2, right: bool) -> void:
	var x := pos.x
	_rect(Rect2(x, pos.y, 70, 10), Color(0.88, 0.90, 0.93), -4)
	_rect(Rect2(x, pos.y + 28, 70, 10), Color(0.88, 0.90, 0.93), -4)
	_prop("res://assets/game/props/books.png", Vector2(x + (48 if right else 22), pos.y + 6), 28, -3)
	_prop("res://assets/game/props/file.png", Vector2(x + (22 if right else 50), pos.y + 34), 20, -3)


func _dress_desk_shared() -> void:
	# 工位矮隔断，中间十字走道留空
	_partition(Rect2(548, 1070, 372, 18))
	_partition(Rect2(1120, 1070, 372, 18))
	_partition(Rect2(1036, 800, 18, 250))
	_partition(Rect2(1036, 1168, 18, 268))
	_partition(Rect2(548, 800, 18, 270))
	_partition(Rect2(1634, 800, 18, 270))
	_partition(Rect2(548, 1168, 18, 268))
	_partition(Rect2(1634, 1168, 18, 268))
	_prop("res://assets/game/props/plant.png", Vector2(980, 1120), 64, -3)
	_prop("res://assets/game/props/plant.png", Vector2(1488, 1120), 58, -3)
	_prop("res://assets/game/props/plant.png", Vector2(640, 1410), 58, -3)
	_prop("res://assets/game/props/cabinet.png", Vector2(600, 1430), 70, -4)
	_prop("res://assets/game/props/cabinet.png", Vector2(1540, 1430), 70, -4)
	_prop("res://assets/game/props/file.png", Vector2(600, 1396), 24, -3)
	_frame(Rect2(560, 786, 70, 48), Color(0.10, 0.11, 0.13))
	_frame(Rect2(1590, 786, 70, 48), Color(0.18, 0.16, 0.16))
	_notice(Vector2(640, 788), "18:00 离开", 92)


func _partition(rect: Rect2) -> void:
	_rect(rect, Color(0.97, 0.98, 0.99), -5)
	_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 5), Color(0.86, 0.89, 0.92), -4)
	_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), Color(0.82, 0.85, 0.88), -4)


func _dress_toilet() -> void:
	_stall(Rect2(72, 72, 176, 220), points["toilet_0"])
	_stall(Rect2(272, 72, 176, 220), points["toilet_1"])
	_rect(Rect2(80, 330, 340, 86), Color(0.91, 0.94, 0.96), -5)
	_rect(Rect2(80, 330, 340, 12), Color(0.82, 0.86, 0.90), -4)
	_prop("res://assets/game/props/sink.png", Vector2(160, 368), 92, -4)
	_prop("res://assets/game/props/sink.png", Vector2(340, 368), 92, -4)
	_prop("res://assets/game/props/plant.png", Vector2(430, 470), 54, -3)
	_prop("res://assets/game/props/door.png", Vector2(180, 528), 46, -3)
	_frame(Rect2(70, 300, 48, 36), Color(0.22, 0.28, 0.32))
	_stain(Rect2(188, 78, 22, 96), 0.22)
	_notice(Vector2(310, 300), "随手关门", 80)
	_rect(Rect2(72, 72, 176, 220), Color(0.08, 0.10, 0.12, 0.10), -5)


func _stall(rect: Rect2, toilet_at: Vector2) -> void:
	_rect(rect, Color(0.94, 0.96, 0.98), -6)
	_partition(Rect2(rect.position.x, rect.position.y, 10, rect.size.y))
	_partition(Rect2(rect.end.x - 10, rect.position.y, 10, rect.size.y))
	_partition(Rect2(rect.position.x, rect.position.y, rect.size.x, 10))
	_rect(Rect2(rect.position.x + 48, rect.end.y - 14, rect.size.x - 96, 12), Color(0.78, 0.84, 0.88), -4)
	_prop("res://assets/game/props/toilet.png", toilet_at, 70, -4)


func _dress_storage() -> void:
	for x in [600.0, 720.0, 840.0]:
		for y in [140.0, 270.0, 400.0]:
			_prop("res://assets/game/props/cabinet.png", Vector2(x, y), 78, -4)
	_prop("res://assets/game/props/books.png", Vector2(900, 250), 34, -3)
	_prop("res://assets/game/props/file.png", Vector2(640, 108), 28, -3)
	_prop("res://assets/game/props/file.png", Vector2(760, 238), 28, -3)
	_prop("res://assets/game/props/plant.png", Vector2(920, 470), 56, -3)
	_prop("res://assets/game/props/door.png", Vector2(740, 528), 46, -3)
	_frame(Rect2(520, 70, 52, 40), Color(0.08, 0.08, 0.10))
	_gloom(Rect2(508, 48, 456, 500), 0.16)
	_stain(Rect2(790, 64, 48, 28), 0.28)
	_notice(Vector2(540, 300), "非公勿入", 80)
	_rect(Rect2(686, 250, 10, 54), Color(0.04, 0.04, 0.05, 0.72), -3)


func _dress_tea() -> void:
	_rect(Rect2(1028, 64, 620, 108), Color(0.90, 0.82, 0.70), -5)
	_rect(Rect2(1028, 64, 620, 16), Color(0.78, 0.68, 0.54), -4)
	_rect(Rect2(1040, 156, 596, 10), Color(0.22, 0.18, 0.14, 0.18), -6)
	_prop("res://assets/game/props/coffee_machine.png", points["coffee_0"], 72, -4)
	_prop("res://assets/game/props/coffee_machine.png", points["coffee_1"], 72, -4)
	_prop("res://assets/game/props/coffee.png", points["coffee_0"] + Vector2(46, 22), 26, -3)
	_prop("res://assets/game/props/drink.png", points["coffee_1"] + Vector2(44, 18), 24, -3)
	_prop("res://assets/game/props/water.png", Vector2(1588, 210), 48, -4)
	_prop("res://assets/game/props/sofa.png", Vector2(1180, 390), 210, -4)
	_prop("res://assets/game/props/plant.png", Vector2(1048, 430), 58, -3)
	_prop("res://assets/game/props/plant.png", Vector2(1620, 430), 58, -3)
	_prop("res://assets/game/props/door.png", Vector2(1340, 528), 46, -3)
	_frame(Rect2(1500, 300, 64, 44), Color(0.62, 0.48, 0.36))


func _dress_lounge() -> void:
	_prop("res://assets/game/props/sofa.png", Vector2(1860, 200), 220, -4)
	_prop("res://assets/game/props/sofa.png", Vector2(2160, 200), 220, -4)
	_prop("res://assets/game/props/sofa.png", Vector2(2010, 390), 200, -4)
	_prop("res://assets/game/props/plant.png", Vector2(2420, 160), 72, -3)
	_prop("res://assets/game/props/plant.png", Vector2(1788, 430), 58, -3)
	_prop("res://assets/game/props/books.png", Vector2(2300, 360), 36, -3)
	_prop("res://assets/game/props/door.png", Vector2(1840, 528), 46, -3)
	_frame(Rect2(2280, 80, 72, 52), Color(0.10, 0.12, 0.12))
	_frame(Rect2(1760, 80, 56, 40), Color(0.28, 0.32, 0.28))


func _dress_lobby() -> void:
	_rect(Rect2(64, 848, 400, 86), Color(0.94, 0.95, 0.97), -5)
	_rect(Rect2(64, 848, 400, 14), Color(0.78, 0.82, 0.88), -4)
	_rect(Rect2(80, 920, 368, 12), Color(0.16, 0.18, 0.22, 0.12), -6)
	_prop("res://assets/game/ui/lobby/punch.png", points["punch_0"], 58, -4)
	_prop("res://assets/game/ui/lobby/punch.png", points["punch_1"], 58, -4)
	_prop("res://assets/game/props/cabinet.png", Vector2(90, 1180), 74, -4)
	_prop("res://assets/game/props/sofa.png", Vector2(280, 1280), 180, -4)
	_prop("res://assets/game/props/plant.png", Vector2(90, 1320), 62, -3)
	_prop("res://assets/game/props/plant.png", Vector2(440, 1420), 58, -3)
	_prop("res://assets/game/props/door.png", Vector2(180, 748), 46, -3)
	_frame(Rect2(72, 800, 74, 52), Color(0.12, 0.13, 0.16))
	_prop("res://assets/game/props/file.png", Vector2(120, 1140), 26, -3)
	_gloom(Rect2(48, 788, 160, 280), 0.14)
	_notice(Vector2(160, 802), "全楼监控", 88)
	_tag(Vector2(72, 1360), "谁准你下班")


func _dress_meeting() -> void:
	_rect(Rect2(1860, 820, 520, 140), Color(0.10, 0.11, 0.14), -5)
	_rect(Rect2(1880, 836, 480, 108), Color(0.22, 0.38, 0.48), -4)
	var board := _prop("res://assets/game/props/browser_ui.png", Vector2(2120, 890), 300, -3)
	board.modulate = Color(0.55, 0.66, 0.72)
	_prop("res://assets/game/props/meeting.png", points["meeting"], 280, -4)
	_prop("res://assets/game/props/chair.png", points["meeting"] + Vector2(-100, 64), 56, -3)
	_prop("res://assets/game/props/chair.png", points["meeting"] + Vector2(0, 70), 56, -3)
	_prop("res://assets/game/props/chair.png", points["meeting"] + Vector2(100, 64), 56, -3)
	_prop("res://assets/game/props/chair.png", points["meeting"] + Vector2(-100, -72), 56, -3)
	_prop("res://assets/game/props/chair.png", points["meeting"] + Vector2(100, -72), 56, -3)
	_prop("res://assets/game/props/laptop.png", points["meeting"] + Vector2(0, -10), 50, -3)
	_prop("res://assets/game/props/paper.png", points["meeting"] + Vector2(70, 8), 28, -3)
	_prop("res://assets/game/props/plant.png", Vector2(2410, 900), 64, -3)
	_prop("res://assets/game/props/door.png", Vector2(1860, 748), 46, -3)
	_frame(Rect2(1760, 860, 58, 70), Color(0.08, 0.08, 0.10))
	_rect(Rect2(1768, 872, 42, 4), Color(0.42, 0.16, 0.16), -2)
	_rect(Rect2(1768, 882, 36, 4), Color(0.28, 0.30, 0.32), -2)
	_rect(Rect2(1768, 892, 40, 4), Color(0.28, 0.30, 0.32), -2)
	_notice(Vector2(1890, 822), "REC  ●", 72)
	_gloom(Rect2(1728, 788, 780, 120), 0.12)


func _dress_corridor() -> void:
	for x in [140.0, 560.0, 980.0, 1400.0, 1820.0, 2240.0]:
		_prop("res://assets/game/props/plant.png", Vector2(x, 590), 50, -3)
	_prop("res://assets/game/props/cabinet.png", Vector2(980, 720), 58, -4)
	_prop("res://assets/game/props/cabinet.png", Vector2(1580, 720), 58, -4)
	_frame(Rect2(640, 580, 80, 54), Color(0.08, 0.09, 0.11))
	_frame(Rect2(1500, 580, 80, 54), Color(0.12, 0.10, 0.10))
	_notice(Vector2(1188, 582), "禁止停留", 80)
	_prop("res://assets/game/props/chair.png", Vector2(2320, 742), 64, -3)


func _dress_horror() -> void:
	_cam(Vector2(180, 518), 46, false)
	_cam(Vector2(740, 518), 42, true)
	_cam(Vector2(1340, 518), 46, false)
	_cam(Vector2(1840, 518), 42, true)
	_cam(Vector2(90, 736), 46, false)
	_cam(Vector2(1988, 736), 44, true)
	_cam(Vector2(1100, 778), 40, false)
	_cam(Vector2(400, 778), 40, true)
	_exit_sign(Vector2(214, 778))
	_exit_sign(Vector2(1898, 778))
	_exit_sign(Vector2(2468, 568))
	_gloom(Rect2(40, 560, 260, 220), 0.22)
	_gloom(Rect2(2260, 560, 260, 220), 0.32)
	_gloom(Rect2(40, 560, 2480, 40), 0.16)
	for door_x in [180.0, 740.0, 1340.0, 1840.0]:
		_gloom(Rect2(door_x - 48, 554, 96, 86), 0.18)
	_stain(Rect2(420, 568, 70, 18), 0.2)
	_stain(Rect2(1688, 572, 54, 16), 0.18)
	_shadow_figure(Vector2(2468, 646))
	_fluorescent(Vector2(180, 610))
	_fluorescent(Vector2(1340, 610))
	_dead_light(Vector2(740, 610))
	_dead_light(Vector2(1980, 610))
	_dead_light(Vector2(220, 96))
	_prop("res://assets/game/ui/lobby/clock.png", Vector2(2408, 586), 40, 2)


func _cam(pos: Vector2, width: float, flip: bool) -> void:
	var s := _prop("res://assets/game/ui/lobby/cam.png", pos, width, 2)
	s.flip_h = flip
	s.modulate = Color(0.90, 0.91, 0.93)
	wall_cams.append(s)
	var led := ColorRect.new()
	led.color = Color(0.92, 0.14, 0.12, 0.95)
	led.size = Vector2(6, 6)
	led.position = pos + Vector2((-width * 0.08) if flip else (width * 0.08), -6)
	led.z_index = 3
	led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(led)
	cam_leds.append(led)


func _exit_sign(pos: Vector2) -> void:
	_rect(Rect2(pos.x - 2, pos.y - 2, 56, 22), Color(0.22, 0.06, 0.06), 1)
	_rect(Rect2(pos.x, pos.y, 52, 18), Color(0.78, 0.12, 0.14), 2)
	var lab := Label.new()
	lab.text = "EXIT"
	lab.position = pos + Vector2(7, 0)
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.98, 0.96, 0.96))
	lab.z_index = 3
	add_child(lab)


func _notice(pos: Vector2, text: String, width: float = 88.0) -> void:
	_rect(Rect2(pos.x, pos.y, width, 20), Color(0.14, 0.15, 0.18, 0.92), 1)
	var lab := Label.new()
	lab.text = text
	lab.position = pos + Vector2(6, 1)
	lab.size = Vector2(width - 8, 18)
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.82, 0.86, 0.88))
	lab.z_index = 2
	add_child(lab)


func _tag(pos: Vector2, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color("00B8D4"))
	lab.z_index = 2
	add_child(lab)


func _stain(rect: Rect2, alpha: float) -> void:
	_rect(rect, Color(0.28, 0.32, 0.34, alpha), -8)
	_rect(Rect2(rect.position.x + 8, rect.position.y + 6, rect.size.x * 0.45, rect.size.y * 0.7), Color(0.18, 0.22, 0.24, alpha * 0.8), -8)


func _gloom(rect: Rect2, alpha: float) -> ColorRect:
	var vis := _rect(rect, Color(0.05, 0.06, 0.08, alpha), -7)
	gloom_veils.append(vis)
	gloom_base.append(alpha)
	return vis


func _fluorescent(pos: Vector2) -> void:
	var glow := _rect(Rect2(pos.x - 52, pos.y - 8, 104, 28), Color(1, 1, 0.88, 0.10), -8)
	flicker_lights.append(glow)


func _dead_light(pos: Vector2) -> void:
	_rect(Rect2(pos.x - 22, pos.y - 8, 44, 8), Color(0.22, 0.24, 0.26, 0.85), -8)


func _shadow_figure(pos: Vector2) -> void:
	var fig := ShadowFigure.new()
	fig.position = pos
	fig.z_index = -6
	add_child(fig)


func _tick_horror(_delta: float) -> void:
	flicker_t += _delta
	var pulse := 0.62 + 0.38 * sin(flicker_t * 5.4)
	var hitch := fmod(flicker_t * 0.31, 1.0)
	if hitch < 0.035 or hitch > 0.975:
		pulse = 0.08
	for n in flicker_lights:
		n.color = Color(1.0, 1.0, 0.88, 0.06 + 0.10 * pulse)
	var led_on := int(Time.get_ticks_msec() / 460) % 2 == 0
	for led in cam_leds:
		led.color.a = 0.95 if led_on else 0.12
	for cam in wall_cams:
		cam.modulate = Color(0.94, 0.95, 0.96) if led_on else Color(0.80, 0.82, 0.84)


func _build_labels() -> void:
	_plaque(Vector2(80, 52), "厕所")
	_plaque(Vector2(540, 52), "储物")
	_plaque(Vector2(1020, 52), "茶水间")
	_plaque(Vector2(1740, 52), "休息角")
	_plaque(Vector2(80, 800), "门厅 · 打卡")
	_plaque(Vector2(560, 800), "工位区")
	_plaque(Vector2(1760, 800), "会议室")


func _plaque(pos: Vector2, text: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.86)
	bg.position = pos
	bg.size = Vector2(112, 22)
	bg.z_index = -2
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var lab := Label.new()
	lab.text = text
	lab.position = pos + Vector2(8, 1)
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.36, 0.42, 0.48))
	lab.z_index = -1
	add_child(lab)


func _frame(rect: Rect2, inner: Color) -> void:
	_rect(rect, Color(0.82, 0.86, 0.90), -4)
	_rect(rect.grow(-5), inner, -3)


func _rect(rect: Rect2, color: Color, z: int) -> ColorRect:
	var vis := ColorRect.new()
	vis.color = color
	vis.position = rect.position
	vis.size = rect.size
	vis.z_index = z
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vis)
	return vis


func _prop(path: String, pos: Vector2, width: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.centered = true
	s.z_index = z
	if s.texture != null:
		if PROP_REGION.has(path):
			s.region_enabled = true
			s.region_rect = PROP_REGION[path]
			var w: float = s.region_rect.size.x
			if w > 0.0:
				s.scale = Vector2.ONE * (width / w)
		else:
			var sz := s.texture.get_size()
			if sz.x > 0.0:
				s.scale = Vector2.ONE * (width / sz.x)
	add_child(s)
	return s


func _build_clocks() -> void:
	_wall_clock(Vector2(270, 818), 34.0, true)
	_wall_clock(Vector2(1280, 588), 30.0, false)
	_wall_clock(Vector2(2100, 818), 28.0, false)


func _wall_clock(pos: Vector2, radius: float, frozen := false) -> void:
	var clock := WallClock.new()
	clock.position = pos
	clock.radius = radius
	clock.frozen = frozen
	clock.z_index = 2
	add_child(clock)
	wall_clocks.append(clock)
	var lab := Label.new()
	lab.position = pos + Vector2(-28, radius + 6)
	lab.size = Vector2(56, 16)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.72, 0.18, 0.16) if frozen else Color(0.28, 0.32, 0.36))
	lab.z_index = 2
	lab.text = "18:00" if frozen else "17:50"
	add_child(lab)
	clock_labels.append(lab)


func apply_daylight(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var cool := Color(0.97, 0.99, 1.0)
	var warm := Color(1.0, 0.90, 0.78)
	var dusk := Color(0.90, 0.76, 0.64)
	var tone := cool.lerp(warm, smoothstep(0.45, 0.82, p))
	if p > 0.82:
		tone = warm.lerp(dusk, clampf((p - 0.82) / 0.18, 0.0, 1.0))
	if day_mod:
		day_mod.color = tone
	if dusk_veil:
		dusk_veil.color = Color(0.08, 0.06, 0.14, 0.34 * smoothstep(0.72, 1.0, p))
	var extra := 0.12 * smoothstep(0.55, 1.0, p)
	for i in gloom_veils.size():
		if gloom_veils[i]:
			gloom_veils[i].color.a = minf(0.52, gloom_base[i] + extra)
	var pane := Color(0.72, 0.86, 0.94).lerp(Color(0.96, 0.58, 0.28), smoothstep(0.5, 1.0, p))
	for w in window_panes:
		if w:
			w.color = pane
	for c in wall_clocks:
		(c as WallClock).progress = p
		c.queue_redraw()
	var text := Rules.office_clock_text(p)
	for i in clock_labels.size():
		if i < wall_clocks.size() and (wall_clocks[i] as WallClock).frozen:
			clock_labels[i].text = "18:00"
		else:
			clock_labels[i].text = text


func _sync_left_desks() -> void:
	for s in [Rules.Slot.EMP_A, Rules.Slot.EMP_B, Rules.Slot.EMP_C, Rules.Slot.EMP_D]:
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
	var screen: Sprite2D = desk_screens[i]
	if screen:
		screen.modulate = Color(0.32, 0.34, 0.38)
	var desk: Vector2 = points["desk_%d" % (i + 1)]
	var lab := Label.new()
	lab.text = "已下班"
	lab.position = desk + Vector2(-30, -78)
	lab.size = Vector2(60, 16)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.42, 0.62, 0.38))
	lab.z_index = 2
	lab.add_to_group("desk_left_mark")
	add_child(lab)


func is_desk_area(p: Vector2) -> bool:
	return _room_id(p) == 7


func reset_shift() -> void:
	desk_left = [false, false, false, false]
	for s in desk_screens:
		if s:
			s.modulate = Color.WHITE
	for n in get_tree().get_nodes_in_group("desk_left_mark"):
		n.queue_free()
	apply_daylight(0.0)


func room_title(p: Vector2) -> String:
	match _room_id(p):
		1:
			return "厕所"
		2:
			return "储物"
		3:
			return "茶水间"
		4:
			return "休息角"
		5:
			return "走廊"
		6:
			return "门厅"
		7:
			return "工位区"
		_:
			return "会议室"


func _build_zones() -> void:
	_zone("coffee_0", points["coffee_0"], 56)
	_zone("coffee_1", points["coffee_1"], 56)
	_zone("toilet_0", points["toilet_0"], 56)
	_zone("toilet_1", points["toilet_1"], 56)
	_zone("punch_0", points["punch_0"], 56)
	_zone("punch_1", points["punch_1"], 56)
	_zone("meeting", points["meeting"], 110)
	for i in 4:
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


func seat_for_slot(slot: int) -> Vector2:
	return points["seat_%d" % (Rules.employee_index(slot) + 1)]


func nearest_punch(from: Vector2) -> Vector2:
	var a: Vector2 = points["punch_0"]
	var b: Vector2 = points["punch_1"]
	return a if from.distance_to(a) <= from.distance_to(b) else b


func nearest_free(prefix: String, from: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for i in 2:
		var id := "%s_%d" % [prefix, i]
		if occupiers.get(id, -1) != -1:
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
	return true


func free_spot(id: String, actor_id: int) -> void:
	if id != "" and occupiers.get(id, -1) == actor_id:
		occupiers[id] = -1


func path_to(from: Vector2, to: Vector2) -> Vector2:
	var corridor := Vector2(from.x, Rules.CORRIDOR_Y)
	if abs(from.y - to.y) < 90 and abs(from.x - to.x) < 800:
		return to
	if abs(from.y - Rules.CORRIDOR_Y) > 28 and not _same_room(from, to):
		if abs(from.x - corridor.x) > 8:
			return Vector2(from.x, Rules.CORRIDOR_Y)
		return Vector2(to.x, Rules.CORRIDOR_Y)
	if abs(from.y - Rules.CORRIDOR_Y) <= 28 and abs(to.y - Rules.CORRIDOR_Y) > 28:
		if abs(from.x - to.x) > 28:
			return Vector2(to.x, Rules.CORRIDOR_Y)
	return to


func _same_room(a: Vector2, b: Vector2) -> bool:
	return _room_id(a) == _room_id(b)


func view_rect_at(p: Vector2) -> Rect2:
	match _room_id(p):
		1:
			return Rect2(32, 32, 480, 540)
		2:
			return Rect2(490, 32, 500, 540)
		3:
			return Rect2(970, 32, 740, 540)
		4:
			return Rect2(1690, 32, 840, 540)
		5:
			if p.x < 1280.0:
				return Rect2(32, 548, 1280, 240)
			return Rect2(1248, 548, 1272, 240)
		6:
			return Rect2(32, 770, 500, 720)
		7:
			return DESK_RECT.grow_individual(8, 8, 8, 8)
		_:
			return Rect2(1710, 770, 820, 720)


func same_view(a: Vector2, b: Vector2) -> bool:
	if _room_id(a) != _room_id(b):
		return false
	if _room_id(a) == 5:
		return (a.x < 1280.0) == (b.x < 1280.0)
	return true


func _room_id(p: Vector2) -> int:
	if p.y < TOP_Y:
		if p.x < X_TOILET:
			return 1
		if p.x < X_NORTH:
			return 2
		if p.x < X_TEA:
			return 3
		return 4
	if p.y < BOT_Y:
		return 5
	if p.x < X_TOILET:
		return 6
	if p.x < X_DESK:
		return 7
	return 8


class WallClock extends Node2D:
	var radius := 34.0
	var progress := 0.0
	var frozen := false

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius + 3.0, Color(0.58, 0.22, 0.22) if frozen else Color(0.78, 0.82, 0.86))
		draw_circle(Vector2.ZERO, radius, Color(0.94, 0.94, 0.95) if frozen else Color(0.97, 0.98, 0.99))
		for i in 12:
			var a := deg_to_rad(-90.0 + float(i) * 30.0)
			var outer := Vector2.from_angle(a) * (radius - 2.0)
			var inner := Vector2.from_angle(a) * (radius - (8.0 if i % 3 == 0 else 5.0))
			draw_line(inner, outer, Color(0.28, 0.32, 0.36), 1.6 if i % 3 == 0 else 1.0)
		var min_a: float
		var hr_a: float
		if frozen:
			min_a = deg_to_rad(90.0)
			hr_a = deg_to_rad(90.0)
		else:
			var span := 50.0 + progress * 10.0
			var minutes := fmod(span, 60.0)
			var hours := 5.0 + span / 60.0
			min_a = deg_to_rad(-90.0 + minutes * 6.0)
			hr_a = deg_to_rad(-90.0 + hours * 30.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(hr_a) * radius * 0.48, Color(0.18, 0.20, 0.22), 3.2)
		draw_line(Vector2.ZERO, Vector2.from_angle(min_a) * radius * 0.72, Color(0.78, 0.18, 0.16), 2.0)
		draw_circle(Vector2.ZERO, 3.2, Color(0.18, 0.20, 0.22))


class ShadowFigure extends Node2D:
	func _draw() -> void:
		var c := Color(0.04, 0.05, 0.07, 0.62)
		draw_circle(Vector2(0, -30), 13, c)
		draw_circle(Vector2(-9, -41), 5.5, c)
		draw_circle(Vector2(9, -41), 5.5, c)
		draw_rect(Rect2(-11, -18, 22, 38), c, true)
		draw_rect(Rect2(-10, 18, 8, 18), c, true)
		draw_rect(Rect2(2, 18, 8, 18), c, true)
		draw_circle(Vector2(-4, -32), 1.6, Color(0.16, 0.18, 0.20, 0.45))
		draw_circle(Vector2(4, -32), 1.6, Color(0.16, 0.18, 0.20, 0.45))


class FloorPainter extends Node2D:
	func _ready() -> void:
		z_index = -10
		z_as_relative = false
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 2560, 1520), Color(0.76, 0.82, 0.87), true)
		_room(Rect2(40, 40, 460, 520), Color(0.84, 0.88, 0.90))
		_room(Rect2(500, 40, 480, 520), Color(0.80, 0.81, 0.83))
		_room(Rect2(980, 40, 720, 520), Color(0.97, 0.94, 0.90))
		_room(Rect2(1700, 40, 820, 520), Color(0.93, 0.96, 0.92))
		_room(Rect2(40, 560, 2480, 220), Color(0.62, 0.64, 0.68))
		_room(Rect2(40, 780, 480, 700), Color(0.86, 0.87, 0.90))
		_room(Rect2(520, 780, 1200, 700), Color(0.96, 0.97, 0.98))
		_room(Rect2(1720, 780, 800, 700), Color(0.78, 0.80, 0.86))
		_back(Rect2(40, 40, 460, 42), Color(0.70, 0.76, 0.80))
		_back(Rect2(500, 40, 480, 42), Color(0.66, 0.67, 0.70))
		_back(Rect2(980, 40, 720, 42), Color(0.90, 0.84, 0.76))
		_back(Rect2(1700, 40, 820, 42), Color(0.84, 0.90, 0.82))
		_tiles(Rect2(48, 82, 444, 468), 28, Color(0.78, 0.84, 0.88), Color(0.86, 0.90, 0.93))
		_tiles(Rect2(508, 82, 464, 468), 36, Color(0.70, 0.71, 0.73, 0.8), Color(0.78, 0.79, 0.81, 0.4))
		_wood(Rect2(988, 82, 704, 468))
		_tiles(Rect2(1708, 82, 804, 468), 48, Color(0.84, 0.91, 0.82, 0.4), Color(0.94, 0.97, 0.92, 0.2))
		_corridor()
		_tiles(Rect2(48, 788, 464, 684), 40, Color(0.78, 0.80, 0.84, 0.5), Color(0.88, 0.89, 0.91, 0.22))
		_desk_carpets()
		_rug(Rect2(1860, 980, 520, 360), Color(0.42, 0.44, 0.56, 0.55))
		_rug(Rect2(1808, 250, 540, 220), Color(0.80, 0.90, 0.78, 0.4))
		_lights()

	func _room(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color, true)

	func _back(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color, true)
		draw_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), Color(0.70, 0.74, 0.78, 0.45), true)

	func _tiles(rect: Rect2, cell: float, a: Color, b: Color) -> void:
		var y := rect.position.y
		var row := 0
		while y < rect.end.y:
			var x := rect.position.x
			var col := 0
			while x < rect.end.x:
				var w := minf(cell, rect.end.x - x)
				var h := minf(cell, rect.end.y - y)
				draw_rect(Rect2(x, y, w, h), a if (row + col) % 2 == 0 else b, true)
				x += cell
				col += 1
			y += cell
			row += 1

	func _wood(rect: Rect2) -> void:
		var y := rect.position.y
		var i := 0
		while y < rect.end.y:
			var c := Color(0.93, 0.88, 0.80, 0.55) if i % 2 == 0 else Color(0.89, 0.82, 0.72, 0.45)
			draw_rect(Rect2(rect.position.x, y, rect.size.x, 18), c, true)
			y += 18.0
			i += 1

	func _corridor() -> void:
		draw_rect(Rect2(40, 640, 2480, 52), Color(0.48, 0.50, 0.54, 0.55), true)
		var x := 80.0
		while x < 2500.0:
			draw_rect(Rect2(x, 656, 46, 10), Color(0.32, 0.34, 0.38, 0.45), true)
			x += 120.0
		draw_rect(Rect2(40, 560, 2480, 34), Color(0.08, 0.09, 0.11, 0.28), true)
		draw_rect(Rect2(40, 560, 240, 220), Color(0.04, 0.05, 0.07, 0.34), true)
		draw_rect(Rect2(2260, 560, 260, 220), Color(0.03, 0.03, 0.05, 0.46), true)
		draw_rect(Rect2(188, 86, 18, 90), Color(0.42, 0.50, 0.54, 0.28), true)
		draw_rect(Rect2(786, 70, 40, 22), Color(0.28, 0.30, 0.32, 0.32), true)

	func _desk_carpets() -> void:
		var dark_a := Color(0.16, 0.18, 0.21)
		var dark_b := Color(0.22, 0.24, 0.27)
		_tiles(Rect2(548, 800, 396, 268), 36, dark_a, dark_b)
		_tiles(Rect2(1096, 800, 396, 268), 36, dark_a, dark_b)
		_tiles(Rect2(548, 1148, 396, 300), 36, dark_a, dark_b)
		_tiles(Rect2(1096, 1148, 396, 300), 36, dark_a, dark_b)
		var pale_a := Color(0.95, 0.96, 0.97)
		var pale_b := Color(0.90, 0.91, 0.93)
		_tiles(Rect2(944, 800, 152, 648), 38, pale_a, pale_b)
		_tiles(Rect2(548, 1068, 944, 80), 40, pale_a, pale_b)

	func _rug(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color, true)
		draw_rect(rect.grow(-12), Color(color.r, color.g, color.b, color.a * 0.4), true)

	func _lights() -> void:
		var live := [
			Vector2(740, 96), Vector2(1340, 96), Vector2(2100, 96),
			Vector2(180, 610), Vector2(1340, 610),
			Vector2(280, 900), Vector2(1120, 860), Vector2(820, 1180), Vector2(1280, 1180)
		]
		var dead := [
			Vector2(220, 96), Vector2(740, 610), Vector2(1980, 610), Vector2(2120, 860)
		]
		for p in live:
			draw_rect(Rect2(p.x - 22, p.y - 8, 44, 8), Color(0.98, 0.98, 0.94, 0.55), true)
			draw_rect(Rect2(p.x - 50, p.y - 6, 100, 36), Color(1, 1, 0.93, 0.07), true)
		for p in dead:
			draw_rect(Rect2(p.x - 22, p.y - 8, 44, 8), Color(0.18, 0.19, 0.21, 0.8), true)
