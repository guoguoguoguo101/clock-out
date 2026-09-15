extends Node2D
class_name OfficeMap

const OfficeDoorScript := preload("res://src/map/OfficeDoor.gd")
const RoomFogScript := preload("res://src/map/RoomFog.gd")

const WALL := 1
const PAPER_BLOCK := 16
const TOP_Y := 560.0
const BOT_Y := 780.0
const X_TOILET := 500.0
const X_NORTH := 980.0
const X_TEA := 1700.0
const X_DESK := 1340.0
const DESK_RECT := Rect2(520, 780, 800, 456)
const DESK_DOOR := Vector2(900, 774)

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
var energy_loot: Dictionary = {}
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
var doors: Array = []
var desk_fx: Array[ColorRect] = []
var desk_fx_lab: Array[Label] = []
var steam_at: Array[Vector2] = []
var sway: Array[Sprite2D] = []
var exit_fx: Array[ColorRect] = []
var notice_labs: Array[Label] = []
var shadow_figs: Array[Node2D] = []
var stall_toilets: Dictionary = {}


func _ready() -> void:
	y_sort_enabled = true
	var floors := FloorPainter.new()
	floors.name = "Floors"
	add_child(floors)
	_build_walls()
	_build_windows()
	_build_furniture()
	_build_doors()
	_build_labels()
	_build_clocks()
	_build_zones()
	day_mod = CanvasModulate.new()
	day_mod.color = Color(0.90, 0.88, 0.86)
	add_child(day_mod)
	dusk_veil = ColorRect.new()
	dusk_veil.color = Color(0.16, 0.08, 0.04, 0.0)
	dusk_veil.position = Vector2(0, 0)
	dusk_veil.size = Vector2(2560, 1520)
	dusk_veil.z_index = -1
	dusk_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dusk_veil)
	var fog := RoomFogScript.new()
	fog.name = "RoomFog"
	add_child(fog)


func _process(delta: float) -> void:
	if Match == null:
		return
	apply_daylight(Match.day_progress())
	_sync_left_desks()
	_tick_horror(delta)
	if Net.is_enet_server():
		for d in doors:
			var door = d
			var was: bool = door.opening
			door.tick(delta)
			if was and not door.opening:
				_sync_door.rpc(door.door_id, door.closed, door.opening, door.open_left)


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
	# 主办公区的南墙留出三个入口：门厅、开放工位、审批中心。
	# 第二个工位入口和中庭连通，避免所有人只挤同一扇门。
	_wall(Rect2(40, 764, 88, 20))
	_wall(Rect2(232, 764, 276, 20))
	_wall(Rect2(508, 764, 332, 20))
	_wall(Rect2(960, 764, 180, 20))
	_wall(Rect2(1260, 764, 60, 20))
	_wall(Rect2(1320, 764, 392, 20))
	_wall(Rect2(1712, 764, 112, 20))
	_wall(Rect2(1952, 764, 568, 20))
	_wall(Rect2(504, 780, 20, 140))
	_wall(Rect2(504, 1060, 20, 420))
	# 开放工位和审批中心之间留一条横向通道。
	_wall(Rect2(1320, 780, 20, 260))
	_wall(Rect2(1320, 1160, 20, 320))
	# 后勤翼是两个紧凑的功能间，不再是办公室下方的一片空地。
	_wall(Rect2(520, 1220, 190, 20))
	_wall(Rect2(830, 1220, 100, 20))
	_wall(Rect2(1050, 1220, 270, 20))
	_wall(Rect2(850, 1240, 20, 240))
	# 右侧按真实办公尺度拆为审批中心、会议室和老板办公室。
	# 会议室可从审批中心进入；老板办公室通过会议室内门抵达。
	_wall(Rect2(1840, 780, 20, 240))
	_wall(Rect2(1840, 1140, 20, 340))
	_wall(Rect2(1860, 1140, 190, 20))
	_wall(Rect2(2170, 1140, 350, 20))
	_door_posts(Vector2(180, 554))
	_door_posts(Vector2(740, 554))
	_door_posts(Vector2(1340, 554))
	_door_posts(Vector2(1840, 554))
	_door_posts(Vector2(180, 774))
	_door_posts(DESK_DOOR)
	_door_posts(Vector2(1200, 774))
	_door_posts(Vector2(1860, 774))
	_door_posts(Vector2(770, 1220))
	_door_posts(Vector2(990, 1220))
	_door_posts(Vector2(1840, 1080))
	_door_posts(Vector2(2110, 1140))


func _wall(rect: Rect2, outer := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = WALL | PAPER_BLOCK
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = Color(0.38, 0.36, 0.38) if outer else Color(0.48, 0.46, 0.47)
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	var cap := ColorRect.new()
	cap.color = Color(0.22, 0.20, 0.22)
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
	points["coffee_0"] = Vector2(1180, 198)
	points["coffee_1"] = Vector2(1460, 198)
	points["toilet_0"] = Vector2(160, 200)
	points["toilet_1"] = Vector2(360, 200)
	points["punch_0"] = Vector2(160, 1000)
	points["punch_1"] = Vector2(380, 1000)
	points["meeting"] = Vector2(2120, 1030)
	points["lounge"] = Vector2(2000, 220)
	points["stock_0"] = Vector2(2110, 328)
	points["corridor"] = Vector2(1280, Rules.CORRIDOR_Y)
	points["boss_spawn"] = Vector2(1280, Rules.CORRIDOR_Y)
	var seats := [
		Vector2(670, 1048),
		Vector2(790, 1048),
		Vector2(1010, 1048),
		Vector2(1130, 1048),
		Vector2(1240, 1048),
		Vector2(1360, 1048),
	]
	var desk_y := 970.0
	_shared_table(Vector2(730, desk_y))
	_shared_table(Vector2(1070, desk_y))
	_compact_table(Vector2(1240, desk_y))
	_compact_table(Vector2(1360, desk_y))
	for i in seats.size():
		var seat: Vector2 = seats[i]
		var desk := Vector2(seat.x, desk_y)
		points["desk_%d" % (i + 1)] = desk
		points["seat_%d" % (i + 1)] = seat
		points["sup_%d" % (i + 1)] = seat + Vector2(0, 58)
		_shared_place(i, seat, desk)
	_dress_toilet()
	_dress_storage()
	_dress_tea()
	_dress_lounge()
	_dress_lobby()
	_dress_meeting()
	_dress_archive_and_server()
	_dress_boss_office()
	_dress_corridor()
	_dress_desk_shared()
	_dress_office_flow_props()
	_dress_horror()
	_build_energy()


func _shared_table(center: Vector2) -> void:
	_rect(Rect2(center.x - 124, center.y - 22, 248, 48), Color(0.42, 0.42, 0.44), -5)
	_rect(Rect2(center.x - 124, center.y - 22, 248, 6), Color(0.28, 0.28, 0.30), -4)
	_rect(Rect2(center.x - 118, center.y + 10, 236, 14), Color(0.04, 0.04, 0.05, 0.35), -6)
	_prop("res://assets/game/props/horror/desk.png", center + Vector2(0, 8), 250, -4)
	_blocker(center + Vector2(0, 4), Vector2(236, 36))


func _compact_table(center: Vector2) -> void:
	_rect(Rect2(center.x - 58, center.y - 22, 116, 48), Color(0.42, 0.42, 0.44), -5)
	_rect(Rect2(center.x - 58, center.y - 22, 116, 6), Color(0.28, 0.28, 0.30), -4)
	_rect(Rect2(center.x - 54, center.y + 10, 108, 14), Color(0.04, 0.04, 0.05, 0.35), -6)
	_prop("res://assets/game/props/horror/desk.png", center + Vector2(0, 8), 118, -4)
	_blocker(center + Vector2(0, 4), Vector2(108, 36))


func _shared_place(idx: int, seat: Vector2, desk: Vector2) -> void:
	var flip := idx % 2 == 1
	desk_screens.append(_prop("res://assets/game/props/screen.png", desk + Vector2(0, -36), 80, -3))
	_desk_terminal(desk + Vector2(-22 if flip else -10, -58))
	_prop("res://assets/game/props/horror/chair.png", seat + Vector2(0, 8), 68, -3)
	_prop("res://assets/game/props/laptop.png", desk + Vector2(28 if flip else -28, 6), 40, -3)
	_prop("res://assets/game/props/paper.png", desk + Vector2(48 if flip else -48, 14), 28, -3)
	_prop("res://assets/game/props/coffee.png", desk + Vector2(-40 if flip else 40, 12), 20, -3)
	_prop("res://assets/game/props/phone.png", desk + Vector2(18 if flip else -18, 16), 16, -3)


func _dress_desk_shared() -> void:
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(560, 820), 56, -3, Vector2(34, 24))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1248, 820), 54, -3, Vector2(34, 24))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(560, 1200), 52, -3, Vector2(32, 22))
	_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(1288, 1188), 64, -4, Vector2(46, 40))
	_prop("res://assets/game/props/file.png", Vector2(1288, 1154), 22, -3)
	_frame(Rect2(560, 786, 70, 48), Color(0.10, 0.11, 0.13))
	_notice(Vector2(640, 788), "共享工位", 92)


func _dress_office_flow_props() -> void:
	# New workflow props are visual anchors for the future inspection / work-order loop.
	# They deliberately have no blockers yet, so they do not narrow the current routes.
	_flow_prop("res://assets/game/props/office_flow/printer_states.png", Vector2(930, 350), 112, -3, 1)
	_flow_prop("res://assets/game/props/office_flow/approval_board_states.png", Vector2(1590, 1018), 152, -3, 0)
	_flow_prop("res://assets/game/props/office_flow/cctv_states.png", Vector2(1110, 566), 54, 3, 1)
	_flow_prop("res://assets/game/props/office_flow/cctv_states.png", Vector2(1740, 566), 54, 3, 2)
	_flow_prop("res://assets/game/props/office_flow/turnstile_states.png", Vector2(380, 1090), 118, -3, 0)
	_flow_prop("res://assets/game/props/office_flow/office_flow_icons.png", Vector2(1514, 922), 34, 2, 0, Vector2i(3, 2))
	_notice(Vector2(850, 470), "流程打印", 92)
	_notice(Vector2(1512, 1120), "审批墙", 92)


func _flow_prop(path: String, pos: Vector2, width: float, z: int, cell: int, grid := Vector2i(2, 2)) -> Sprite2D:
	var s := _prop(path, pos, width, z)
	if s.texture == null:
		return s
	var tex_size := s.texture.get_size()
	var cell_size := Vector2(tex_size.x / float(grid.x), tex_size.y / float(grid.y))
	s.region_enabled = true
	s.region_rect = Rect2(
		float(cell % grid.x) * cell_size.x,
		float(cell / grid.x) * cell_size.y,
		cell_size.x,
		cell_size.y
	)
	s.scale = Vector2.ONE * (width / cell_size.x)
	return s


func _partition(rect: Rect2) -> void:
	_rect(rect, Color(0.32, 0.32, 0.34), -5)
	_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 5), Color(0.18, 0.18, 0.20), -4)
	_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), Color(0.14, 0.14, 0.16), -4)
	_blocker_rect(rect)


func _dress_toilet() -> void:
	_stall(Rect2(72, 72, 176, 220), points["toilet_0"], "toilet_0")
	_stall(Rect2(272, 72, 176, 220), points["toilet_1"], "toilet_1")
	_rect(Rect2(80, 330, 340, 86), Color(0.91, 0.94, 0.96), -5)
	_rect(Rect2(80, 330, 340, 12), Color(0.82, 0.86, 0.90), -4)
	_blocker_rect(Rect2(80, 330, 340, 72))
	_prop("res://assets/game/props/sink.png", Vector2(160, 368), 92, -4)
	_prop("res://assets/game/props/sink.png", Vector2(340, 368), 92, -4)
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(430, 470), 54, -3, Vector2(32, 22))
	_frame(Rect2(70, 300, 48, 36), Color(0.22, 0.28, 0.32))
	_stain(Rect2(188, 78, 22, 96), 0.22)
	_notice(Vector2(310, 300), "随手关门", 80)
	_rect(Rect2(72, 72, 176, 220), Color(0.08, 0.10, 0.12, 0.10), -5)


func _stall(rect: Rect2, toilet_at: Vector2, toilet_id: String) -> void:
	_rect(rect, Color(0.94, 0.96, 0.98), -6)
	_partition(Rect2(rect.position.x, rect.position.y, 10, rect.size.y))
	_partition(Rect2(rect.end.x - 10, rect.position.y, 10, rect.size.y))
	_partition(Rect2(rect.position.x, rect.position.y, rect.size.x, 10))
	_rect(Rect2(rect.position.x + 48, rect.end.y - 14, rect.size.x - 96, 12), Color(0.78, 0.84, 0.88), -4)
	var bowl := _prop("res://assets/game/props/toilet_sit.png", toilet_at + Vector2(-6, 6), 52, -4)
	stall_toilets[toilet_id] = bowl


func _dress_storage() -> void:
	for x in [600.0, 720.0, 840.0]:
		for y in [140.0, 270.0, 400.0]:
			_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(x, y), 78, -4, Vector2(52, 44))
	_prop("res://assets/game/props/books.png", Vector2(900, 250), 34, -3)
	_prop("res://assets/game/props/file.png", Vector2(640, 108), 28, -3)
	_prop("res://assets/game/props/file.png", Vector2(760, 238), 28, -3)
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(920, 470), 56, -3, Vector2(32, 22))
	_frame(Rect2(520, 70, 52, 40), Color(0.08, 0.08, 0.10))
	_gloom(Rect2(508, 48, 456, 500), 0.16)
	_stain(Rect2(790, 64, 48, 28), 0.28)
	_notice(Vector2(540, 300), "非公勿入", 80)
	_rect(Rect2(686, 250, 10, 54), Color(0.04, 0.04, 0.05, 0.72), -3)


func _dress_tea() -> void:
	_rect(Rect2(1028, 64, 620, 108), Color(0.90, 0.82, 0.70), -5)
	_rect(Rect2(1028, 64, 620, 16), Color(0.78, 0.68, 0.54), -4)
	_rect(Rect2(1040, 156, 596, 10), Color(0.22, 0.18, 0.14, 0.18), -6)
	_blocker_rect(Rect2(1028, 64, 620, 96))
	_prop("res://assets/game/props/coffee_machine.png", points["coffee_0"] + Vector2(0, -22), 72, -4)
	_prop("res://assets/game/props/coffee_machine.png", points["coffee_1"] + Vector2(0, -22), 72, -4)
	_prop("res://assets/game/props/coffee.png", points["coffee_0"] + Vector2(46, 8), 26, -3)
	_prop("res://assets/game/props/drink.png", points["coffee_1"] + Vector2(44, 4), 24, -3)
	steam_at.append(points["coffee_0"] + Vector2(0, -36))
	steam_at.append(points["coffee_1"] + Vector2(0, -36))
	_solid_prop("res://assets/game/props/water.png", Vector2(1588, 210), 48, -4, Vector2(28, 40))
	_solid_prop("res://assets/game/props/sofa.png", Vector2(1180, 390), 210, -4, Vector2(168, 34))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1048, 430), 58, -3, Vector2(32, 22))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1620, 430), 58, -3, Vector2(32, 22))
	_frame(Rect2(1500, 300, 64, 44), Color(0.62, 0.48, 0.36))


func _dress_lounge() -> void:
	_solid_prop("res://assets/game/props/sofa.png", Vector2(1860, 200), 220, -4, Vector2(176, 34))
	_solid_prop("res://assets/game/props/sofa.png", Vector2(2160, 200), 220, -4, Vector2(176, 34))
	_solid_prop("res://assets/game/props/sofa.png", Vector2(2010, 390), 200, -4, Vector2(160, 34))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(2420, 160), 72, -3, Vector2(36, 26))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1788, 430), 58, -3, Vector2(32, 22))
	_prop("res://assets/game/props/books.png", Vector2(2300, 360), 36, -3)
	_frame(Rect2(2280, 80, 72, 52), Color(0.10, 0.12, 0.12))
	_frame(Rect2(1760, 80, 56, 40), Color(0.28, 0.32, 0.28))
	_solid_prop("res://assets/game/props/stock_machine.png", Vector2(2110, 268), 150, -2, Vector2(70, 42))
	_prop("res://assets/game/props/horror/chair.png", points["stock_0"] + Vector2(-8, 10), 48, -3)
	_notice(Vector2(1990, 118), "严禁炒股", 88)
	_red_notice(Vector2(2110, 148), "E 内网交易  赚了加精力", 150, 0.06)


func _dress_lobby() -> void:
	_rect(Rect2(64, 848, 400, 86), Color(0.94, 0.95, 0.97), -5)
	_rect(Rect2(64, 848, 400, 14), Color(0.78, 0.82, 0.88), -4)
	_rect(Rect2(80, 920, 368, 12), Color(0.16, 0.18, 0.22, 0.12), -6)
	_blocker_rect(Rect2(64, 848, 400, 72))
	_horror_punch(points["punch_0"], true)
	_horror_punch(points["punch_1"], false)
	_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(90, 1180), 74, -4, Vector2(48, 42))
	_solid_prop("res://assets/game/props/sofa.png", Vector2(280, 1280), 180, -4, Vector2(148, 32))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(90, 1320), 62, -3, Vector2(34, 24))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(440, 1420), 58, -3, Vector2(32, 22))
	_frame(Rect2(72, 800, 74, 52), Color(0.12, 0.13, 0.16))
	_prop("res://assets/game/props/file.png", Vector2(120, 1140), 26, -3)
	_gloom(Rect2(48, 788, 160, 280), 0.14)
	_notice(Vector2(160, 802), "全楼监控", 88)
	_tag(Vector2(72, 1360), "谁准你下班")
	_red_notice(Vector2(160, 1320), "内部资料 严禁外传", 132, -0.05)


func _horror_punch(at: Vector2, left: bool) -> void:
	var punch := _prop("res://assets/game/ui/lobby/punch.png", at + Vector2(0, -84), 92, -4)
	punch.modulate = Color(0.88, 0.72, 0.68)
	var key := ShaderMaterial.new()
	key.shader = preload("res://src/ui/lobby_chroma.gdshader")
	punch.material = key
	_rect(Rect2(at.x + 28, at.y - 118, 8, 8), Color(0.86, 0.08, 0.08, 0.95), 2)
	_red_notice(at + Vector2(-58, -152), "加班须知", 108, -0.06)
	_red_notice(at + Vector2(-62, 16), "未打卡=自愿留下", 138, 0.05)
	var lab := Label.new()
	lab.text = "插入工卡"
	lab.position = at + Vector2(-36, -28)
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.82, 0.16, 0.12))
	lab.rotation = -0.08 if left else 0.07
	lab.z_index = 2
	add_child(lab)
	_stain(Rect2(at.x + (-40 if left else 10), at.y + 24, 48, 14), 0.28)
	_rect(Rect2(at.x + (-36 if left else 8), at.y + 20, 36, 18), Color(0.42, 0.04, 0.05, 0.45), -8)
	_gloom(Rect2(at.x - 60, at.y - 160, 120, 200), 0.16)
	var cctv := _prop("res://assets/game/ui/lobby/cam.png", at + Vector2(-70 if left else 70, -170), 48, 3)
	cctv.material = key


func _red_notice(pos: Vector2, text: String, width: float, tilt: float) -> void:
	var paper := _rect(Rect2(pos.x, pos.y, width, 22), Color(0.62, 0.08, 0.08, 0.94), 1)
	paper.rotation = tilt
	paper.pivot_offset = Vector2(width * 0.5, 11)
	var lab := Label.new()
	lab.text = text
	lab.position = pos + Vector2(6, 1)
	lab.size = Vector2(width - 8, 18)
	lab.rotation = tilt
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.96, 0.84, 0.72))
	lab.z_index = 2
	add_child(lab)
	lab.set_meta("base", text)
	lab.set_meta("ink", Color(0.96, 0.84, 0.72))
	notice_labs.append(lab)


func _dress_meeting() -> void:
	# 会议室收进右上；右下完整留给老板办公室，地图的功能分区更清楚。
	_rect(Rect2(1900, 820, 520, 140), Color(0.10, 0.11, 0.14), -5)
	_rect(Rect2(1920, 836, 480, 108), Color(0.22, 0.38, 0.48), -4)
	var board := _prop("res://assets/game/props/browser_ui.png", Vector2(2160, 890), 300, -3)
	board.modulate = Color(0.55, 0.66, 0.72)
	_prop("res://assets/game/props/meeting.png", points["meeting"], 280, -4)
	_blocker(points["meeting"] + Vector2(0, -4), Vector2(210, 42))
	_prop("res://assets/game/props/horror/chair.png", points["meeting"] + Vector2(-100, 8), 56, -3)
	_prop("res://assets/game/props/horror/chair.png", points["meeting"] + Vector2(0, 12), 56, -3)
	_prop("res://assets/game/props/horror/chair.png", points["meeting"] + Vector2(100, 8), 56, -3)
	_prop("res://assets/game/props/horror/chair.png", Vector2(2020, 960), 56, -3)
	_prop("res://assets/game/props/horror/chair.png", Vector2(2220, 960), 56, -3)
	_prop("res://assets/game/props/laptop.png", points["meeting"] + Vector2(0, -10), 50, -3)
	_prop("res://assets/game/props/paper.png", points["meeting"] + Vector2(70, 8), 28, -3)
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(2410, 900), 64, -3, Vector2(34, 24))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1460, 900), 58, -3, Vector2(32, 22))
	_frame(Rect2(1760, 860, 58, 70), Color(0.08, 0.08, 0.10))
	_rect(Rect2(1768, 872, 42, 4), Color(0.42, 0.16, 0.16), -2)
	_rect(Rect2(1768, 882, 36, 4), Color(0.28, 0.30, 0.32), -2)
	_rect(Rect2(1768, 892, 40, 4), Color(0.28, 0.30, 0.32), -2)
	_notice(Vector2(1930, 822), "REC  ●", 72)
	_gloom(Rect2(1344, 788, 1164, 120), 0.12)


func _dress_archive_and_server() -> void:
	# 下方后勤翼：视觉上分成档案区和测试/服务器区，走路仍保持连续，便于当前 AI 导航。
	for x in [590.0, 700.0, 810.0]:
		_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(x, 1320), 76, -4, Vector2(50, 42))
	_prop("res://assets/game/props/file.png", Vector2(620, 1404), 32, -3)
	_prop("res://assets/game/props/file.png", Vector2(760, 1402), 28, -3)
	_frame(Rect2(550, 1264, 260, 12), Color(0.20, 0.22, 0.24))
	_notice(Vector2(562, 1280), "归档超过 30 天禁止翻阅", 210)
	for x in [930.0, 1060.0, 1190.0]:
		_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(x, 1322), 74, -4, Vector2(48, 42))
		_prop("res://assets/game/props/screen.png", Vector2(x, 1268), 66, -3)
	_frame(Rect2(890, 1262, 350, 18), Color(0.10, 0.14, 0.16))
	_flow_prop("res://assets/game/props/office_flow/cctv_states.png", Vector2(1180, 1410), 56, 2, 3)
	_notice(Vector2(900, 1282), "测试 / 服务器 · 运行中", 220)
	_red_notice(Vector2(1010, 1430), "异常工时正在同步", 150, -0.03)


func _dress_boss_office() -> void:
	# 老板办公室约 6.6m × 3.2m：够一张主管桌、柜体和等候椅，不会像空旷展厅。
	_rect(Rect2(1880, 1180, 620, 8), Color(0.38, 0.46, 0.50, 0.65), -4)
	_rect(Rect2(1880, 1188, 620, 3), Color(0.76, 0.86, 0.90, 0.35), -3)
	_prop("res://assets/game/props/horror/desk.png", Vector2(2120, 1340), 360, -4)
	_prop("res://assets/game/props/screen.png", Vector2(2120, 1284), 132, -3)
	_prop("res://assets/game/props/laptop.png", Vector2(2058, 1346), 54, -3)
	_prop("res://assets/game/props/phone.png", Vector2(2190, 1350), 28, -3)
	_prop("res://assets/game/props/paper.png", Vector2(2250, 1350), 38, -3)
	_prop("res://assets/game/props/horror/chair.png", Vector2(2120, 1412), 76, -3)
	_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(2380, 1330), 86, -4, Vector2(54, 46))
	_solid_prop("res://assets/game/props/horror/plant.png", Vector2(1900, 1400), 70, -3, Vector2(38, 26))
	_notice(Vector2(1900, 1200), "老板办公室 · 请勿越级汇报", 240)
	_red_notice(Vector2(2170, 1440), "战略调整，今晚上线", 158, 0.04)


func _dress_corridor() -> void:
	for x in [140.0, 560.0, 980.0, 1400.0, 1820.0, 2240.0]:
		_solid_prop("res://assets/game/props/horror/plant.png", Vector2(x, 590), 50, -3, Vector2(28, 18))
	_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(980, 720), 58, -4, Vector2(40, 28))
	_solid_prop("res://assets/game/props/horror/cabinet.png", Vector2(1580, 720), 58, -4, Vector2(40, 28))
	_frame(Rect2(640, 580, 80, 54), Color(0.08, 0.09, 0.11))
	_frame(Rect2(1500, 580, 80, 54), Color(0.12, 0.10, 0.10))
	_notice(Vector2(1188, 582), "禁止停留", 80)
	_prop("res://assets/game/props/horror/chair.png", Vector2(2320, 742), 64, -3)


func _dress_horror() -> void:
	_cam(Vector2(180, 518), 46, false)
	_cam(Vector2(740, 518), 42, true)
	_cam(Vector2(1340, 518), 46, false)
	_cam(Vector2(1840, 518), 42, true)
	_cam(Vector2(90, 736), 46, false)
	_cam(Vector2(1988, 736), 44, true)
	_cam(Vector2(900, 778), 40, false)
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


func _build_doors() -> void:
	_add_door("toilet", Vector2(180, 554), "厕所")
	_add_door("storage", Vector2(740, 554), "储物")
	_add_door("tea", Vector2(1340, 554), "茶水")
	_add_door("lounge", Vector2(1840, 554), "休息")
	_add_door("lobby", Vector2(180, 774), "门厅")
	_add_door("desk", DESK_DOOR, "工位")
	_add_door("meeting", Vector2(1860, 774), "会议")


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
	match room:
		1:
			return Vector2(180, 554)
		2:
			return Vector2(740, 554)
		3:
			return Vector2(1340, 554)
		4:
			return Vector2(1840, 554)
		6:
			return Vector2(180, 774)
		7:
			return DESK_DOOR
		8:
			return Vector2(1860, 774)
		_:
			return from


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
	var glow := _rect(Rect2(pos.x, pos.y, 52, 18), Color(0.78, 0.12, 0.14), 2)
	exit_fx.append(glow)
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
	lab.set_meta("base", text)
	lab.set_meta("ink", Color(0.82, 0.86, 0.88))
	notice_labs.append(lab)


func _tag(pos: Vector2, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.82, 0.16, 0.14))
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
	shadow_figs.append(fig)


func _tick_horror(delta: float) -> void:
	flicker_t += delta
	var pulse := 0.55 + 0.45 * sin(flicker_t * 6.2)
	var hitch := fmod(flicker_t * 0.27, 1.0)
	if hitch < 0.05 or hitch > 0.97:
		pulse = 0.04
	var threat := _local_threat()
	if threat > 0.6 and fmod(flicker_t * 0.51, 1.0) < 0.08:
		pulse = 0.02
	for n in flicker_lights:
		n.color = Color(1.0, 1.0, 0.86, 0.05 + 0.14 * pulse)
	_tick_cams()
	_tick_desks()
	_tick_notices()
	for i in exit_fx.size():
		var on := int((flicker_t + float(i) * 0.37) * 2.4) % 2 == 0
		exit_fx[i].color.a = 1.0 if on else 0.28
	for i in sway.size():
		if sway[i]:
			sway[i].rotation = sin(flicker_t * 0.7 + float(i)) * 0.04
	for fig in shadow_figs:
		fig.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(flicker_t * 0.8))
		fig.visible = threat < 0.85
	for c in wall_clocks:
		c.queue_redraw()
	queue_redraw()


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
	if not _rooms_touch(me.global_position, boss.global_position):
		prox *= 0.58
	if me.emp_state == Rules.EmpState.SLACK:
		prox = maxf(prox, 0.12)
	return clampf(prox, 0.0, 0.92)


func _local_threat() -> float:
	return employee_threat()


func room_id(p: Vector2) -> int:
	return _room_id(p)


func _rooms_touch(a: Vector2, b: Vector2) -> bool:
	var ra := _room_id(a)
	var rb := _room_id(b)
	if ra == rb or ra == 5 or rb == 5:
		return true
	return mini(ra, rb) == 6 and maxi(ra, rb) == 7


func _desk_terminal(pos: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.16, 0.14, 0.92)
	bg.position = pos
	bg.size = Vector2(52, 28)
	bg.z_index = 1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	desk_fx.append(bg)
	var lab := Label.new()
	lab.text = "待机"
	lab.position = pos + Vector2(3, 6)
	lab.size = Vector2(48, 18)
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", Color(0.55, 0.95, 0.62))
	lab.z_index = 2
	add_child(lab)
	desk_fx_lab.append(lab)


func _tick_desks() -> void:
	var msgs_work := ["周报未交", "未读 99+", "OKR 12%", "开摄像头"]
	var msgs_slack := ["SIGNAL", "■■■■", "404"]
	var idx := int(flicker_t / 2.1)
	for i in desk_fx.size():
		if i >= Rules.EMPLOYEE_SLOTS.size():
			break
		var slot: int = Rules.EMPLOYEE_SLOTS[i]
		var e: Actor = Match.actors.get(slot) as Actor
		var bg := desk_fx[i]
		var lab := desk_fx_lab[i]
		if i < desk_left.size() and desk_left[i]:
			bg.color = Color(0.08, 0.09, 0.10, 0.9)
			lab.text = "OFF"
			lab.add_theme_color_override("font_color", Color(0.35, 0.38, 0.40))
			if i < desk_screens.size() and desk_screens[i]:
				desk_screens[i].modulate = Color(0.28, 0.30, 0.32)
			continue
		if e == null:
			bg.color = Color(0.05, 0.08, 0.08, 0.85)
			lab.text = "待机"
			continue
		if e.emp_state == Rules.EmpState.SLACK:
			bg.color = Color(0.10, 0.08, 0.06, 0.92)
			lab.text = msgs_slack[idx % msgs_slack.size()]
			lab.add_theme_color_override("font_color", Color(0.72, 0.55, 0.32))
			if i < desk_screens.size() and desk_screens[i]:
				desk_screens[i].modulate = Color(0.55, 0.52, 0.48)
		elif e.emp_state == Rules.EmpState.WORK:
			bg.color = Color(0.04, 0.16, 0.14, 0.94)
			lab.text = msgs_work[(idx + i) % msgs_work.size()]
			lab.add_theme_color_override("font_color", Color(0.55, 0.95, 0.62))
			if i < desk_screens.size() and desk_screens[i]:
				var blink := 0.82 + 0.18 * sin(flicker_t * 8.0 + float(i))
				desk_screens[i].modulate = Color(blink, blink, 1.0)
		elif e.emp_state == Rules.EmpState.TALK:
			bg.color = Color(0.28, 0.06, 0.06, 0.94)
			lab.text = "约谈中"
			lab.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
		else:
			bg.color = Color(0.06, 0.07, 0.08, 0.88)
			lab.text = "离开"
			lab.add_theme_color_override("font_color", Color(0.55, 0.58, 0.60))
			if i < desk_screens.size() and desk_screens[i]:
				desk_screens[i].modulate = Color(0.70, 0.72, 0.74)


func _tick_cams() -> void:
	var threat := _local_threat()
	for i in mini(cam_leds.size(), wall_cams.size()):
		var cam: Sprite2D = wall_cams[i]
		var saw := _cam_sees_someone(cam.position)
		var saw_boss := _cam_sees_boss(cam.position)
		var blink := int(flicker_t * (8.0 if saw_boss else 3.2)) % 2 == 0
		if saw_boss or threat > 0.8:
			cam_leds[i].color = Color(1.0, 0.08, 0.06, 1.0 if blink else 0.2)
			cam.modulate = Color(1.0, 0.55, 0.52)
		elif saw:
			cam_leds[i].color = Color(0.95, 0.16, 0.12, 0.95)
			cam.modulate = Color(0.96, 0.96, 0.98)
		else:
			cam_leds[i].color = Color(0.92, 0.14, 0.12, 0.95 if blink else 0.12)
			cam.modulate = Color(0.82, 0.83, 0.85)


func _cam_sees_someone(pos: Vector2) -> bool:
	for a in Match.actors.values():
		var e := a as Actor
		if e == null or e.emp_state == Rules.EmpState.LEFT:
			continue
		if same_view(pos, e.global_position):
			return true
	return false


func _cam_sees_boss(pos: Vector2) -> bool:
	var boss: Actor = Match.actors.get(Rules.Slot.BOSS) as Actor
	return boss != null and same_view(pos, boss.global_position)


func _tick_notices() -> void:
	if notice_labs.is_empty():
		return
	var spook := _local_threat() > 0.5 and fmod(flicker_t, 3.4) < 0.22
	var glitch := ["不准下班", "谁准你走", "REC ON", "看着我"]
	for i in notice_labs.size():
		var lab := notice_labs[i]
		var base := str(lab.get_meta("base", lab.text))
		if spook and i == int(flicker_t * 3.0) % notice_labs.size():
			lab.add_theme_color_override("font_color", Color(0.95, 0.22, 0.18))
			lab.text = glitch[int(flicker_t * 7.0) % glitch.size()]
		else:
			lab.add_theme_color_override("font_color", lab.get_meta("ink", Color(0.82, 0.86, 0.88)))
			lab.text = base


func _draw() -> void:
	# 事故终端标记
	if Match.incident_active:
		var tp: Vector2 = Match.incident_terminal_pos
		var pulse := 0.6 + 0.4 * absf(sin(flicker_t * 5.0))
		draw_rect(Rect2(tp.x - 24, tp.y - 24, 48, 48), Color(0.92, 0.12, 0.08, 0.18 * pulse))
		draw_rect(Rect2(tp.x - 20, tp.y - 20, 40, 40), Color(0.08, 0.16, 0.14, 0.92))
		draw_rect(Rect2(tp.x - 18, tp.y - 18, 36, 36), Color(0.14, 0.82, 0.42, 0.85 * pulse))
		draw_rect(Rect2(tp.x - 16, tp.y - 16, 32, 32), Color(0.04, 0.12, 0.08, 0.95))
		# 十字线
		draw_line(Vector2(tp.x, tp.y - 32), Vector2(tp.x, tp.y - 22), Color(1.0, 0.25, 0.18, 0.6 * pulse), 1.5)
		draw_line(Vector2(tp.x, tp.y + 22), Vector2(tp.x, tp.y + 32), Color(1.0, 0.25, 0.18, 0.6 * pulse), 1.5)
		draw_line(Vector2(tp.x - 32, tp.y), Vector2(tp.x - 22, tp.y), Color(1.0, 0.25, 0.18, 0.6 * pulse), 1.5)
		draw_line(Vector2(tp.x + 22, tp.y), Vector2(tp.x + 32, tp.y), Color(1.0, 0.25, 0.18, 0.6 * pulse), 1.5)

	# 匿名举报 — Boss 视角箭头指向被举报者
	if Match.anon_reveal_slot >= 0 and Match.actors.has(Match.anon_reveal_slot):
		var my := Match.my_slot()
		if my == Rules.Slot.BOSS:
			var target: Actor = Match.actors[Match.anon_reveal_slot]
			var tp2: Vector2 = target.global_position
			var pulse2 := 0.6 + 0.4 * absf(sin(flicker_t * 3.5))
			draw_circle(tp2, 28.0, Color(0.95, 0.55, 0.08, 0.25 * pulse2))
			draw_circle(tp2, 18.0, Color(0.95, 0.65, 0.12, 0.45 * pulse2))
			draw_circle(tp2, 6.0, Color(1.0, 0.85, 0.2, 0.8 * pulse2))

	# 外卖标记
	for k in Match.delivery_spots:
		var dp: Vector2 = Match.delivery_spots[k]
		var pulse3 := 0.5 + 0.5 * absf(sin(flicker_t * 4.0 + float(k) * 1.2))
		draw_rect(Rect2(dp.x - 14, dp.y - 14, 28, 28), Color(0.92, 0.62, 0.12, 0.3 * pulse3))
		draw_rect(Rect2(dp.x - 10, dp.y - 10, 20, 20), Color(0.95, 0.75, 0.2, 0.7 * pulse3))
		draw_circle(dp, 4.0, Color(1.0, 0.9, 0.3, 0.9))

	for i in steam_at.size():
		var origin: Vector2 = steam_at[i]
		for k in 3:
			var t := fmod(flicker_t * 0.55 + float(i) * 0.3 + float(k) * 0.22, 1.0)
			var p := origin + Vector2(sin((t + float(k)) * 6.2) * 6.0, -t * 28.0)
			var a := (1.0 - t) * 0.22
			draw_circle(p, 4.0 + t * 5.0, Color(0.92, 0.94, 0.96, a))


func _build_labels() -> void:
	_plaque(Vector2(80, 52), "厕所")
	_plaque(Vector2(540, 52), "储物 / 打印")
	_plaque(Vector2(1020, 52), "茶水间")
	_plaque(Vector2(1740, 52), "休息角")
	_plaque(Vector2(80, 800), "门厅 · 打卡")
	_plaque(Vector2(560, 800), "开放工位")
	_plaque(Vector2(1400, 800), "审批墙")
	_plaque(Vector2(1940, 800), "会议室")
	_plaque(Vector2(560, 1240), "档案区")
	_plaque(Vector2(910, 1240), "测试 / 服务器")
	_plaque(Vector2(1900, 1180), "老板办公室")


func _plaque(pos: Vector2, text: String) -> void:
	var plaque_width := maxf(112.0, float(text.length()) * 13.0 + 20.0)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.86)
	bg.position = pos
	bg.size = Vector2(plaque_width, 22)
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


func _tex(path: String) -> Texture2D:
	if path.contains("/horror/"):
		var horror := Image.load_from_file(ProjectSettings.globalize_path(path))
		if horror != null and not horror.is_empty():
			return ImageTexture.create_from_image(horror)
		return null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


func _blocker(center: Vector2, size: Vector2) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = WALL
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	add_child(body)


func _blocker_rect(rect: Rect2) -> void:
	_blocker(rect.get_center(), rect.size)


func _solid_prop(path: String, pos: Vector2, width: float, z: int, hit: Vector2) -> Sprite2D:
	var s := _prop(path, pos, width, z)
	_blocker(pos, hit)
	if path.contains("plant"):
		sway.append(s)
	return s


func _prop(path: String, pos: Vector2, width: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(path)
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
	var extra := 0.12 * smoothstep(0.55, 1.0, p)
	var threat := employee_threat()
	if day_mod:
		day_mod.color = tone * Color(1.0 - threat * 0.12, 1.0 - threat * 0.20, 1.0 - threat * 0.16)
	if dusk_veil:
		dusk_veil.color = Color(0.08, 0.06, 0.14, maxf(0.34 * smoothstep(0.72, 1.0, p), 0.08 + threat * 0.16))
	for i in gloom_veils.size():
		if gloom_veils[i]:
			gloom_veils[i].color.a = minf(0.66, gloom_base[i] + extra + threat * 0.22)
	var pane := Color(0.72, 0.86, 0.94).lerp(Color(0.96, 0.58, 0.28), smoothstep(0.5, 1.0, p))
	pane = pane.lerp(Color(0.42, 0.18, 0.16), threat * 0.55)
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
	for s in Rules.EMPLOYEE_SLOTS:
		if not Match.actors.has(s):
			continue
		var e: Actor = Match.actors[s]
		if e.emp_state == Rules.EmpState.LEFT:
			mark_desk_left(int(s))


func mark_desk_left(slot: int) -> void:
	var emp: Actor = Match.actors.get(slot) as Actor
	var i := (emp.last_seat - 1) if emp != null and emp.last_seat > 0 else Rules.employee_index(slot)
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
	for item in doors:
		item.force_open()
	apply_daylight(0.0)
	_reset_energy()


func room_title(p: Vector2) -> String:
	# 细分名称只影响信息呈现；导航继续沿用大房间模型，避免旧机器人路线失效。
	if p.y >= 1240.0 and p.x < X_DESK:
		return "档案区" if p.x < 860.0 else "测试 / 服务器"
	if p.y >= 1160.0 and p.x >= 1860.0:
		return "老板办公室"
	if p.y >= BOT_Y and p.x >= X_DESK:
		return "审批中心" if p.x < 1860.0 else "会议室"
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
	_zone("stock_0", points["stock_0"], 56)
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
	var kind := energy_kind(id)
	match kind:
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


func _build_energy() -> void:
	_energy_spot("vend_0", "vend", Vector2(1348, 352), "res://assets/game/props/energy/vending.png", 78, false)
	_energy_spot("water_0", "water", Vector2(1588, 248), "res://assets/game/props/energy/water_cup.png", 28, false)
	_energy_spot("fridge_0", "rummage", Vector2(1788, 268), "res://assets/game/props/energy/fridge.png", 70, false)
	_energy_spot("rummage_0", "rummage", Vector2(640, 250), "res://assets/game/props/energy/drawer.png", 64, true)
	_energy_spot("rummage_1", "rummage", Vector2(840, 380), "res://assets/game/props/energy/drawer.png", 64, true)
	_energy_spot("snack_0", "snack", Vector2(600, 1008), "res://assets/game/props/energy/snack_choco.png", 28, true)
	_energy_spot("snack_1", "snack", Vector2(1188, 1008), "res://assets/game/props/energy/snack_cookie.png", 30, true)
	_energy_spot("snack_2", "snack", Vector2(2010, 330), "res://assets/game/props/energy/snack_noodle.png", 34, true)
	_energy_spot("snack_3", "snack", Vector2(2300, 390), "res://assets/game/props/energy/can_drink.png", 22, true)
	_energy_spot("snack_4", "snack", Vector2(380, 1188), "res://assets/game/props/energy/snack_choco.png", 26, true)
	_notice(Vector2(1288, 318), "投币续命", 92)
	_notice(Vector2(1760, 210), "不是你的冰箱", 108)


func _energy_spot(id: String, kind: String, pos: Vector2, path: String, width: float, once: bool) -> void:
	points[id] = pos
	occupiers[id] = -1
	var spr := _prop(path, pos, width, -2)
	energy_loot[id] = {"kind": kind, "once": once, "used": false, "sprite": spr}


func seat_for_slot(slot: int) -> Vector2:
	return points["seat_%d" % (Rules.employee_index(slot) + 1)]


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


func path_to(from: Vector2, to: Vector2) -> Vector2:
	var ra := _room_id(from)
	var rb := _room_id(to)
	if ra == rb:
		return _avoid_furniture(from, to)
	if ra != 5:
		var dpos := door_pos_for_room(ra, from)
		if from.distance_to(dpos) > 22.0:
			return _avoid_furniture(from, dpos)
		return Vector2(dpos.x, Rules.CORRIDOR_Y)
	if rb != 5:
		var dpos := door_pos_for_room(rb, to)
		if absf(from.x - dpos.x) > 18.0:
			return Vector2(dpos.x, Rules.CORRIDOR_Y)
		if from.distance_to(dpos) > 18.0:
			return dpos
		return to
	return to


func _avoid_furniture(from: Vector2, to: Vector2) -> Vector2:
	if _room_id(from) != 7:
		return to
	var aisle := DESK_DOOR.x
	var north := from.y < 1000.0
	var want_n := to.y < 1000.0
	if north == want_n:
		return to
	if absf(from.x - aisle) > 22.0:
		return Vector2(aisle, from.y)
	if north:
		return Vector2(aisle, 1056.0)
	return Vector2(aisle, 880.0)


func _same_room(a: Vector2, b: Vector2) -> bool:
	return _room_id(a) == _room_id(b)


func view_rect_at(p: Vector2) -> Rect2:
	var rid := _room_id(p)
	var r := Rect2()
	match rid:
		1:
			r = Rect2(40, 40, 448, 504)
		2:
			r = Rect2(508, 40, 460, 504)
		3:
			r = Rect2(988, 40, 700, 504)
		4:
			r = Rect2(1708, 40, 800, 504)
		5:
			if p.x < 1280.0:
				r = Rect2(40, 560, 1240, 220)
			else:
				r = Rect2(1280, 560, 1240, 220)
		6:
			r = Rect2(40, 780, 464, 700)
		7:
			r = DESK_RECT
		_:
			r = Rect2(X_DESK + 4, 780, 2520.0 - X_DESK - 4, 700)
	match rid:
		1, 2, 3, 4:
			r.size.y += 46.0
		5:
			r = r.grow_individual(0, 10, 0, 10)
		6, 7, 8:
			r.position.y -= 46.0
			r.size.y += 46.0
	return r


func visible_rect_for(actor: Actor) -> Rect2:
	var r := view_rect_at(actor.global_position)
	var body := Rect2(actor.global_position + Vector2(-46, -112), Vector2(92, 128))
	return r.merge(body).grow(12)


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
		if not frozen:
			var sec_a := deg_to_rad(-90.0 + float(Time.get_ticks_msec() % 60000) / 60000.0 * 360.0)
			draw_line(Vector2.ZERO, Vector2.from_angle(sec_a) * radius * 0.78, Color(0.55, 0.12, 0.12, 0.85), 1.0)
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
	var tex_carpet: Texture2D
	var tex_hall: Texture2D
	var tex_bath: Texture2D
	var tex_tea: Texture2D

	func _ready() -> void:
		z_index = -10
		z_as_relative = false
		tex_carpet = _file_tex("res://assets/game/props/horror/floor_carpet_afterhours.png")
		tex_hall = _file_tex("res://assets/game/props/horror/floor_hall_afterhours.png")
		tex_bath = _file_tex("res://assets/game/props/horror/floor_bath_afterhours.png")
		tex_tea = _file_tex("res://assets/game/props/horror/floor_tea_afterhours.png")
		queue_redraw()

	func _file_tex(path: String) -> Texture2D:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		return null

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 2560, 1520), Color(0.08, 0.08, 0.10), true)
		_fill(Rect2(40, 40, 460, 520), tex_bath, Color(0.28, 0.32, 0.32))
		_fill(Rect2(500, 40, 480, 520), tex_hall, Color(0.22, 0.22, 0.24))
		_fill(Rect2(980, 40, 720, 520), tex_tea, Color(0.32, 0.28, 0.24))
		_fill(Rect2(1700, 40, 820, 520), tex_carpet, Color(0.24, 0.26, 0.24))
		_fill(Rect2(40, 560, 2480, 220), tex_hall, Color(0.16, 0.16, 0.18))
		_fill(Rect2(40, 780, 480, 700), tex_hall, Color(0.22, 0.22, 0.24))
		_fill(Rect2(520, 780, 800, 456), tex_carpet, Color(0.14, 0.14, 0.16))
		# 按真实用途拆开：档案和机房是窄而密的后勤间；右侧是审批、会议、主管三间房。
		_fill(Rect2(520, 1240, 330, 240), tex_hall, Color(0.12, 0.12, 0.14))
		_fill(Rect2(870, 1240, 450, 240), tex_hall, Color(0.09, 0.12, 0.14))
		_fill(Rect2(1324, 780, 516, 700), tex_hall, Color(0.18, 0.18, 0.22))
		_fill(Rect2(1860, 780, 660, 360), tex_hall, Color(0.16, 0.18, 0.22))
		_fill(Rect2(1860, 1160, 660, 320), tex_carpet, Color(0.16, 0.14, 0.16))
		_back(Rect2(40, 40, 460, 42), Color(0.22, 0.26, 0.28))
		_back(Rect2(500, 40, 480, 42), Color(0.16, 0.16, 0.18))
		_back(Rect2(980, 40, 720, 42), Color(0.28, 0.22, 0.18))
		_back(Rect2(1700, 40, 820, 42), Color(0.18, 0.22, 0.18))
		_corridor()
		_lights()

	func _fill(rect: Rect2, tex: Texture2D, fallback: Color) -> void:
		if tex:
			draw_texture_rect(tex, rect, true, Color(0.82, 0.80, 0.78, 1))
		else:
			draw_rect(rect, fallback, true)

	func _room(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color, true)

	func _back(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color, true)
		draw_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), Color(0.08, 0.08, 0.10, 0.55), true)

	func _corridor() -> void:
		draw_rect(Rect2(40, 640, 2480, 52), Color(0.10, 0.10, 0.12, 0.35), true)
		var x := 80.0
		while x < 2500.0:
			draw_rect(Rect2(x, 656, 46, 10), Color(0.08, 0.08, 0.10, 0.4), true)
			x += 120.0
		draw_rect(Rect2(40, 560, 2480, 34), Color(0.04, 0.04, 0.05, 0.42), true)
		draw_rect(Rect2(40, 560, 240, 220), Color(0.02, 0.02, 0.03, 0.46), true)
		draw_rect(Rect2(2260, 560, 260, 220), Color(0.02, 0.02, 0.03, 0.52), true)
		draw_rect(Rect2(188, 86, 18, 90), Color(0.18, 0.24, 0.24, 0.35), true)
		draw_rect(Rect2(786, 70, 40, 22), Color(0.10, 0.10, 0.12, 0.4), true)

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
			draw_rect(Rect2(p.x - 22, p.y - 8, 44, 8), Color(0.92, 0.90, 0.78, 0.45), true)
			draw_rect(Rect2(p.x - 50, p.y - 6, 100, 36), Color(1, 0.96, 0.82, 0.05), true)
		for p in dead:
			draw_rect(Rect2(p.x - 22, p.y - 8, 44, 8), Color(0.12, 0.12, 0.14, 0.85), true)
