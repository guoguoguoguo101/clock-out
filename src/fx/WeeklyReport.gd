extends Node2D
class_name WeeklyReport

const TEX := preload("res://assets/game/props/reports/weekly.png")

var report_id := 0
var dir := Vector2.DOWN
var speed := 280.0
var age := 0.0
var flutter := 0.0
var tumble := 0.0
var flying := true
var burst_t := 0.0
var hit_person := false
var shards: Array[Dictionary] = []
var trail: Array[Vector2] = []
var _authoritative := false
var _sound: AudioStreamPlayer2D


func setup(p_id: int, pos: Vector2, direction: Vector2, server: bool, speed_mul := 1.0) -> void:
	report_id = p_id
	global_position = pos
	dir = direction.normalized() if direction.length() > 0.01 else Vector2.DOWN
	speed = Rules.REPORT_SPEED * speed_mul
	_authoritative = server
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flutter = randf() * TAU
	tumble = randf_range(-2.4, 2.4)
	trail.append(pos)


func _ready() -> void:
	_sound = AudioStreamPlayer2D.new()
	_sound.max_distance = 420.0
	_sound.volume_db = -18.0
	add_child(_sound)


func begin_burst(person: bool) -> void:
	if not flying:
		return
	flying = false
	hit_person = person
	burst_t = 0.55 if person else 0.38
	var n := 7 if person else 5
	for i in n:
		var ang := TAU * float(i) / float(n) + randf_range(-0.2, 0.2)
		var spd := randf_range(70.0, 150.0) if person else randf_range(40.0, 90.0)
		shards.append({
			"p": global_position + Vector2(0, -18),
			"v": Vector2.from_angle(ang) * spd + Vector2(0, -40.0),
			"spin": randf_range(-8.0, 8.0),
			"rot": randf() * TAU,
			"life": burst_t,
			"s": randf_range(0.55, 1.0),
		})
	_play_rustle(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if flying:
		_fly(delta)
	else:
		burst_t = maxf(0.0, burst_t - delta)
		for shard in shards:
			shard["life"] -= delta
			shard["v"] = shard["v"] * (1.0 - 1.8 * delta) + Vector2(0, 220.0 * delta)
			shard["p"] += shard["v"] * delta
			shard["rot"] += shard["spin"] * delta
		if burst_t <= 0.0:
			queue_free()
	queue_redraw()


func _fly(delta: float) -> void:
	age += delta
	var prev := global_position
	var nxt := prev + dir * speed * delta
	if _authoritative:
		if Match.paper_blocked(prev, nxt) or age >= Rules.REPORT_LIFE:
			Match.end_report(report_id, -1)
			return
		var victim: Actor = Match.report_victim(nxt)
		if victim != null:
			Match.end_report(report_id, victim.slot)
			return
	elif age >= Rules.REPORT_LIFE + 0.35:
		begin_burst(false)
		return
	global_position = nxt
	trail.append(nxt)
	if trail.size() > 8:
		trail.remove_at(0)


func _play_rustle(hit: bool) -> void:
	var data := PackedByteArray()
	var n := 2800 if hit else 2200
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(1400.0 if hit else 900.0, 420.0 if hit else 1600.0, t)
		phase += TAU * f / 24000.0
		var env := sin(PI * t) * (0.7 if hit else 0.45)
		var noise := (randf() - 0.5) * 0.55
		var value := int(clampf(sin(phase) * 0.35 + noise, -1.0, 1.0) * env * 7000.0)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	stream.data = data
	_sound.stream = stream
	var me := Match.actors.get(Match.my_slot()) as Actor
	if me != null and Match.office != null and Match.office.same_view(me.global_position, global_position):
		_sound.play()


func _draw() -> void:
	if flying:
		_draw_flight()
	else:
		_draw_burst()


func _draw_flight() -> void:
	var ang := dir.angle() + PI * 0.5 + tumble * age * 0.35 + sin(age * 16.0 + flutter) * 0.16
	var launch := clampf(1.0 - age / 0.14, 0.0, 1.0)
	var lift := -50.0 - 6.0 * launch
	var bob := Vector2(0, lift) - dir * (18.0 * launch) + Vector2(0, sin(age * 13.0 + flutter) * 1.6)
	for i in trail.size():
		var a := float(i) / float(maxi(trail.size(), 1))
		var p := to_local(trail[i]) + Vector2(0, lift)
		draw_circle(p, 2.2, Color(0.92, 0.88, 0.80, 0.08 + a * 0.10))
	draw_set_transform(Vector2(3, 8), ang * 0.08, Vector2(1.05, 0.38))
	draw_circle(Vector2.ZERO, 13.0, Color(0.05, 0.05, 0.06, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if TEX == null:
		return
	var sz := TEX.get_size()
	var sc := 30.0 / sz.x
	draw_set_transform(bob, ang, Vector2(sc, sc))
	draw_texture(TEX, -sz * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	if font:
		var header := bob + Vector2(0, -sz.y * sc * 0.36).rotated(ang)
		draw_set_transform(header, ang, Vector2.ONE)
		draw_string(font, Vector2(-14, 5), "周报", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.16, 0.18, 0.22, 0.92))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_burst() -> void:
	if TEX == null:
		return
	var sz := TEX.get_size()
	var font := ThemeDB.fallback_font
	for shard in shards:
		if float(shard["life"]) <= 0.0:
			continue
		var a := clampf(float(shard["life"]) / 0.55, 0.0, 1.0)
		var p: Vector2 = to_local(shard["p"])
		var sc: float = 12.0 / sz.x * float(shard["s"])
		draw_set_transform(p, float(shard["rot"]), Vector2(sc, sc))
		draw_texture(TEX, -sz * 0.5, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hit_person and burst_t > 0.28 and font:
		var pop := (0.55 - burst_t) / 0.27
		draw_string(font, Vector2(-24, -46.0 - pop * 10.0), "请查收", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.16, 0.14, clampf(1.2 - pop, 0.0, 1.0)))
