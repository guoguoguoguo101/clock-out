extends Node2D
class_name OfficeMap

const WALL := 1
const TOP_Y := 268.0
const BOT_Y := 392.0
const X_TOILET := 300.0
const X_NORTH := 580.0
const X_TEA := 1020.0
const X_DESK := 1080.0

var points: Dictionary = {}
var zone_areas: Dictionary = {}
var occupiers: Dictionary = {}


func _ready() -> void:
	y_sort_enabled = true
	_build_floors()
	_build_walls()
	_build_furniture()
	_build_zones()


func _build_floors() -> void:
	_floor("toilet", Rect2(32, 32, 268, 236), Color(0.93, 0.95, 0.96))
	_floor("north", Rect2(300, 32, 280, 236), Color(0.93, 0.93, 0.93))
	_floor("tea", Rect2(580, 32, 440, 236), Color(0.97, 0.95, 0.92))
	_floor("lounge", Rect2(1020, 32, 628, 236), Color(0.95, 0.96, 0.94))
	_floor("corridor", Rect2(32, 268, 1616, 124), Color(0.91, 0.91, 0.91))
	_floor("lobby", Rect2(32, 392, 268, 556), Color(0.96, 0.96, 0.96))
	_floor("desks", Rect2(300, 392, 780, 556), Color(0.957, 0.957, 0.957))
	_floor("meeting", Rect2(1080, 392, 568, 556), Color(0.94, 0.94, 0.957))
	_label_at(Vector2(110, 48), "厕所")
	_label_at(Vector2(740, 48), "茶水间")
	_label_at(Vector2(1260, 48), "休息角")
	_label_at(Vector2(90, 412), "门厅 · 打卡")
	_label_at(Vector2(620, 412), "工位区")
	_label_at(Vector2(1280, 412), "会议室")
	# 门洞 / 工位区朝走廊敞开
	_door_floor(Rect2(90, 252, 180, 28), "门")
	_door_floor(Rect2(680, 252, 180, 28), "门")
	_door_floor(Rect2(1180, 252, 200, 28), "门")
	_door_floor(Rect2(70, 376, 180, 28), "门")
	_door_floor(Rect2(360, 376, 660, 28), "工位入口")
	_door_floor(Rect2(1180, 376, 200, 28), "门")
	_door_floor(Rect2(284, 520, 32, 220), "门")
	_door_floor(Rect2(1064, 520, 32, 220), "门")


func _floor(id: String, rect: Rect2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	poly.z_index = -8
	poly.name = "floor_" + id
	add_child(poly)


func _door_floor(rect: Rect2, text: String = "门") -> void:
	var r := ColorRect.new()
	r.color = Color(0.76, 0.7, 0.62)
	r.position = rect.position
	r.size = rect.size
	r.z_index = -7
	add_child(r)
	var lab := Label.new()
	lab.text = text
	lab.position = rect.position + Vector2(8, 2)
	lab.add_theme_color_override("font_color", Color(0.42, 0.34, 0.26))
	lab.add_theme_font_size_override("font_size", 14)
	lab.z_index = -6
	add_child(lab)


func _label_at(pos: Vector2, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	lab.z_index = -6
	add_child(lab)


func _build_walls() -> void:
	_wall(Rect2(16, 16, 1648, 16))
	_wall(Rect2(16, 948, 1648, 16))
	_wall(Rect2(16, 16, 16, 948))
	_wall(Rect2(1648, 16, 16, 948))
	# 上层南墙，门宽 180+
	_wall(Rect2(32, 260, 58, 16))
	_wall(Rect2(270, 260, 410, 16))
	_wall(Rect2(860, 260, 320, 16))
	_wall(Rect2(1380, 260, 268, 16))
	# 上层竖墙
	_wall(Rect2(300, 32, 16, 228))
	_wall(Rect2(580, 32, 16, 228))
	_wall(Rect2(1020, 32, 16, 228))
	# 下层北墙：工位区整段敞开，门厅/会议室留大门
	_wall(Rect2(32, 384, 38, 16))
	_wall(Rect2(250, 384, 50, 16))
	_wall(Rect2(1080, 384, 100, 16))
	_wall(Rect2(1380, 384, 268, 16))
	# 下层竖墙，中间开 220 的口
	_wall(Rect2(300, 392, 16, 128))
	_wall(Rect2(300, 740, 16, 208))
	_wall(Rect2(1080, 392, 16, 128))
	_wall(Rect2(1080, 740, 16, 208))


func _wall(rect: Rect2) -> void:
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
	vis.color = Color(0.82, 0.82, 0.82)
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	body.add_child(vis)
	add_child(body)


func _build_furniture() -> void:
	points["coffee_0"] = Vector2(720, 140)
	points["coffee_1"] = Vector2(900, 140)
	points["toilet_0"] = Vector2(110, 140)
	points["toilet_1"] = Vector2(220, 140)
	points["punch_0"] = Vector2(110, 560)
	points["punch_1"] = Vector2(220, 560)
	points["meeting"] = Vector2(1340, 680)
	points["lounge"] = Vector2(1280, 150)
	points["corridor"] = Vector2(840, Rules.CORRIDOR_Y)
	points["boss_spawn"] = Vector2(840, Rules.CORRIDOR_Y)
	var seats := [
		Vector2(500, 620),
		Vector2(860, 620),
		Vector2(500, 820),
		Vector2(860, 820),
	]
	for i in 4:
		var desk: Vector2 = seats[i] + Vector2(0, -56)
		var key := "desk_%d" % (i + 1)
		points[key] = desk
		points["seat_%d" % (i + 1)] = seats[i]
		points["sup_%d" % (i + 1)] = seats[i] + Vector2(0, 52)
		_desk_sprite(desk)
	_box(points["coffee_0"], Vector2(56, 64), Color(0.98, 0.98, 0.98), "咖啡")
	_box(points["coffee_1"], Vector2(56, 64), Color(0.98, 0.98, 0.98), "咖啡")
	_box(points["toilet_0"], Vector2(58, 76), Color(0.97, 0.97, 0.97), "隔间")
	_box(points["toilet_1"], Vector2(58, 76), Color(0.97, 0.97, 0.97), "隔间")
	_box(points["punch_0"], Vector2(48, 70), Color(0.98, 0.98, 0.98), "打卡")
	_box(points["punch_1"], Vector2(48, 70), Color(0.98, 0.98, 0.98), "打卡")
	_box(points["meeting"], Vector2(240, 78), Color(1, 1, 1), "会议桌")


func _desk_sprite(center: Vector2) -> void:
	_box(center + Vector2(0, -16), Vector2(120, 48), Color(1, 1, 1), "")
	var screen := ColorRect.new()
	screen.color = Color(0.49, 0.72, 0.97)
	screen.size = Vector2(42, 28)
	screen.position = center + Vector2(-21, -52)
	screen.z_index = -4
	add_child(screen)
	var tag := Label.new()
	tag.text = "工位"
	tag.position = center + Vector2(-18, -8)
	tag.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	tag.z_index = -3
	add_child(tag)


func _box(center: Vector2, size: Vector2, color: Color, text: String) -> void:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = center - size * 0.5
	r.z_index = -4
	add_child(r)
	if text != "":
		var lab := Label.new()
		lab.text = text
		lab.position = center + Vector2(-20, -8)
		lab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lab.z_index = -3
		add_child(lab)


func _build_zones() -> void:
	_zone("coffee_0", points["coffee_0"], 48)
	_zone("coffee_1", points["coffee_1"], 48)
	_zone("toilet_0", points["toilet_0"], 48)
	_zone("toilet_1", points["toilet_1"], 48)
	_zone("punch_0", points["punch_0"], 50)
	_zone("punch_1", points["punch_1"], 50)
	_zone("meeting", points["meeting"], 100)
	for i in 4:
		_zone("seat_%d" % (i + 1), points["seat_%d" % (i + 1)], 46)
		_zone("sup_%d" % (i + 1), points["sup_%d" % (i + 1)], 56)


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
	var same_band := (from.y < TOP_Y) == (to.y < TOP_Y) or (from.y > BOT_Y) == (to.y > BOT_Y)
	if from.y > TOP_Y and from.y < BOT_Y:
		same_band = to.y > TOP_Y and to.y < BOT_Y
	if abs(from.y - to.y) < 80 and abs(from.x - to.x) < 700:
		return to
	if abs(from.y - Rules.CORRIDOR_Y) > 24 and not _same_room(from, to):
		if abs(from.x - corridor.x) > 8:
			return Vector2(from.x, Rules.CORRIDOR_Y)
		return Vector2(to.x, Rules.CORRIDOR_Y)
	if abs(from.y - Rules.CORRIDOR_Y) <= 24 and abs(to.y - Rules.CORRIDOR_Y) > 24:
		if abs(from.x - to.x) > 24:
			return Vector2(to.x, Rules.CORRIDOR_Y)
	return to


func _same_room(a: Vector2, b: Vector2) -> bool:
	return _room_id(a) == _room_id(b)


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
