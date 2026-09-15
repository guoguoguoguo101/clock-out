extends Node2D
## Procedural cutout animation, kept below the office fog and attached to its actor.
var age := 10.0
var burst := 0.0
var passenger_texture: Texture2D
var start_offset := Vector2.ZERO
var pickup_side := 1.0
var particles: Array[Dictionary] = []
var trail_clock := 0.0
var sound: AudioStreamPlayer2D

func _ready() -> void:
	sound = AudioStreamPlayer2D.new()
	sound.max_distance = 380.0
	sound.volume_db = -17.0
	add_child(sound)

func pickup(passenger: Actor, from: Vector2) -> void:
	passenger_texture = passenger.Kit.tex(passenger.skin, "idle_0")
	start_offset = from - global_position
	pickup_side = 1.0 if get_parent()._facing.x >= 0.0 else -1.0
	age = 0.0
	burst = 0.65
	_emit_feathers(14)
	_play_swoop(true)

func release() -> void:
	burst = 0.5
	_emit_feathers(10)
	_play_swoop(false)

func _play_swoop(up: bool) -> void:
	# A soft, short air whistle, generated locally; no external audio dependency.
	var data := PackedByteArray()
	var phase := 0.0
	for i in 6000:
		var t := float(i) / 6000.0
		phase += TAU * lerpf(260.0 if up else 580.0, 700.0 if up else 200.0, t) / 24000.0
		var value := int(sin(phase) * sin(PI * t) * 5500.0)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	stream.data = data
	sound.stream = stream
	var me := Match.actors.get(Match.my_slot()) as Actor
	if me != null and get_parent().office().same_view(me.global_position, global_position):
		sound.play()

func _emit_feathers(count: int) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		particles.append({"p": global_position + Vector2(0, -42), "v": Vector2(cos(angle) * 55.0, sin(angle) * 38.0 - 20.0), "life": 0.7, "spin": angle})

func _process(delta: float) -> void:
	var actor := get_parent() as Actor
	age += delta
	burst = maxf(0.0, burst - delta)
	if not Net.is_enet_server():
		actor.carry_left = maxf(0.0, actor.carry_left - delta)
		actor.carry_windup = maxf(0.0, actor.carry_windup - delta)
		actor.carry_recovery = maxf(0.0, actor.carry_recovery - delta)
	trail_clock -= delta
	if actor.carrying_slot >= 0 and actor.velocity.length() > 10.0 and trail_clock <= 0.0:
		trail_clock = 0.08
		particles.append({"p": global_position + Vector2(0, -18), "v": -actor.velocity * 0.15 + Vector2(0, -12), "life": 0.5, "spin": age})
	for i in range(particles.size() - 1, -1, -1):
		particles[i]["life"] -= delta
		particles[i]["p"] += particles[i]["v"] * delta
		if particles[i]["life"] <= 0.0:
			particles.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var actor := get_parent() as Actor
	for particle in particles:
		var p: Vector2 = to_local(particle["p"])
		var alpha := clampf(float(particle["life"]) / 0.7, 0.0, 1.0)
		var direction := Vector2.from_angle(float(particle["spin"]) + age * 3.0)
		draw_line(p - direction * 4.0, p + direction * 4.0, Color(0.63, 0.86, 1.0, alpha * 0.8), 1.5, true)
		draw_line(p, p + direction.rotated(0.7) * 3.0, Color(0.88, 0.85, 1.0, alpha), 1.0, true)
	if burst > 0.0:
		var radius := 12.0 + (1.0 - burst / 0.65) * 42.0
		draw_set_transform(Vector2(0, -4), 0.0, Vector2(1, 0.35))
		draw_arc(Vector2.ZERO, radius, 0.2, TAU - 0.5, 36, Color(0.52, 0.75, 1.0, burst * 0.6), 1.5, true)
		draw_set_transform(Vector2.ZERO)
	if actor.carrying_slot < 0 or passenger_texture == null:
		return
	var side := 1.0 if actor._facing.x >= 0.0 else -1.0
	var t := clampf(age / Rules.CARRY_WINDUP, 0.0, 1.0)
	var ease := t * t * (3.0 - 2.0 * t)
	var bob := sin(age * 10.0) * 1.8
	var mouth := Vector2(side * 23.0, -49.0 + bob)
	var passenger_pos := (start_offset + Vector2(0, -36)).lerp(mouth + Vector2(0, -9), ease)
	passenger_pos.y -= sin(t * PI) * 21.0
	var size := lerpf(64.0, 37.0, ease)
	# The passenger rises into the mouth; the foreground pouch masks its lower body.
	draw_set_transform(passenger_pos, side * (sin(age * 8.0) * 0.08 + (1.0 - t) * 0.3), Vector2.ONE)
	draw_texture_rect(passenger_texture, Rect2(-size * 0.5, -size * 0.5, size, size), false)
	draw_set_transform(Vector2.ZERO)
	var open := sin(t * PI) * 5.0
	var points := PackedVector2Array()
	points.append(mouth + Vector2(-17, -open))
	points.append(mouth + Vector2(18, -open))
	for i in 13:
		var a := float(i) / 12.0 * PI
		points.append(mouth + Vector2(cos(a) * 18.0, sin(a) * (13.0 + bob * 0.5)))
	draw_colored_polygon(points, Color("ecac4d"))
	points.append(points[0])
	draw_polyline(points, Color("526771"), 2.0, true)
	draw_line(mouth + Vector2(-16, 0), mouth + Vector2(17, 0), Color("ffdc88"), 2.0, true)
	# Quiet cyan-violet motion accents around the loaded pouch.
	draw_arc(mouth, 24.0, age * 1.8, age * 1.8 + 1.6, 18, Color(0.62, 0.63, 1.0, 0.42), 1.3, true)
