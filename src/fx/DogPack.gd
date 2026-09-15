extends Node2D
## Three JD-red pups that trail the dog and soak a lunge / weekly report each.

const Kit := preload("res://src/actor/CharKit.gd")
const Ride := preload("res://src/actor/RideKit.gd")

var alive: Array[bool] = [false, false, false]
var slots: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var pop_t: Array[float] = [0.0, 0.0, 0.0]
var age := 0.0
var sound: AudioStreamPlayer2D


func _ready() -> void:
	sound = AudioStreamPlayer2D.new()
	sound.max_distance = 420.0
	sound.volume_db = -8.0
	add_child(sound)
	z_index = 2


func active() -> bool:
	for on in alive:
		if on:
			return true
	return false


func count() -> int:
	var n := 0
	for on in alive:
		if on:
			n += 1
	return n


func summon() -> void:
	age = 0.0
	for i in 3:
		alive[i] = true
		pop_t[i] = 0.0
		slots[i] = _slot_offset(i)
	_play_yell()
	queue_redraw()


func dismiss() -> void:
	for i in 3:
		if alive[i]:
			alive[i] = false
			pop_t[i] = 0.35
	queue_redraw()


func pop_at(world: Vector2) -> bool:
	var best := -1
	var best_d := 9999.0
	for i in 3:
		if not alive[i]:
			continue
		var d := world_slot(i).distance_to(world)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	alive[best] = false
	pop_t[best] = 0.45
	queue_redraw()
	return true


func nearest_alive(world: Vector2, max_d: float) -> Vector2:
	var best := Vector2.INF
	var best_d := max_d
	for i in 3:
		if not alive[i]:
			continue
		var p := world_slot(i)
		var d := p.distance_to(world)
		if d < best_d:
			best_d = d
			best = p
	return best


func world_slot(i: int) -> Vector2:
	return global_position + slots[i]


func _slot_offset(i: int) -> Vector2:
	var actor := get_parent() as Actor
	var face := Vector2.DOWN
	if actor != null and actor._facing.length() > 0.12:
		face = actor._facing.normalized()
	var side := Vector2(-face.y, face.x)
	match i:
		0:
			return -face * 10.0 + side * 28.0
		1:
			return -face * 10.0 - side * 28.0
		_:
			return -face * 30.0


func _process(delta: float) -> void:
	age += delta
	var actor := get_parent() as Actor
	var moving := actor != null and actor.velocity.length() > 18.0
	for i in 3:
		pop_t[i] = maxf(0.0, pop_t[i] - delta)
		if not alive[i]:
			continue
		var goal := _slot_offset(i)
		if moving:
			goal += Vector2(sin(age * 11.0 + float(i) * 2.1) * 3.0, cos(age * 9.0 + float(i)) * 2.0)
		slots[i] = slots[i].lerp(goal, 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _play_yell() -> void:
	var data := PackedByteArray()
	var phase := 0.0
	for i in 9000:
		var t := float(i) / 9000.0
		var syllable := 0.0 if t < 0.46 else 1.0
		var local := t / 0.46 if syllable < 0.5 else (t - 0.46) / 0.54
		var f := lerpf(280.0, 520.0, local) if syllable < 0.5 else lerpf(420.0, 240.0, local)
		phase += TAU * f / 24000.0
		var env := sin(PI * clampf(local, 0.0, 1.0))
		var grit := sin(phase * 2.7) * 0.22
		var value := int(clampf(sin(phase) * 0.85 + grit, -1.0, 1.0) * env * 11000.0)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	stream.data = data
	sound.stream = stream
	var actor := get_parent() as Actor
	var me := Match.actors.get(Match.my_slot()) as Actor
	if me != null and actor != null and actor.office() != null and actor.office().same_view(me.global_position, global_position):
		sound.play()


func _draw() -> void:
	var actor := get_parent() as Actor
	if actor == null:
		return
	var moving := actor.velocity.length() > 24.0
	var anim := "run" if moving else "idle"
	var frames: PackedStringArray = Kit.loop_frames(anim)
	if frames.is_empty():
		return
	var fps := 12.0 if moving else 5.0
	var shot: String = frames[int(age * fps) % frames.size()]
	var body: Texture2D = _body(shot)
	var scarf: Texture2D = _scarf(shot)
	if body == null:
		return
	var sz := body.get_size()
	var sc := Rules.SPRITE_SCALE * 0.58 * (1024.0 / maxf(sz.y, 1.0))
	var font := ThemeDB.fallback_font
	for i in 3:
		if not alive[i] and pop_t[i] <= 0.0:
			continue
		var p: Vector2 = slots[i]
		if pop_t[i] > 0.0 and not alive[i]:
			var k := pop_t[i] / 0.45
			draw_arc(p + Vector2(0, -18), 8.0 + (1.0 - k) * 22.0, 0.0, TAU, 20, Color(0.88, 0.16, 0.14, k * 0.7), 2.0, true)
			continue
		var bob := sin(age * 10.0 + float(i) * 1.7) * 2.2
		var origin := p + Vector2(0, bob)
		var flip := actor._facing.x < 0.0
		draw_set_transform(origin, 0.0, Vector2(-sc if flip else sc, sc))
		draw_texture(body, Vector2(-sz.x * 0.5, -sz.y + Ride.FOOT_PAD))
		if scarf:
			draw_texture(scarf, Vector2(-sz.x * 0.5, -sz.y + Ride.FOOT_PAD), Rules.scarf_color(Rules.CharSkin.DOG))
		draw_set_transform(Vector2.ZERO)
		if font:
			draw_string(font, origin + Vector2(-14, -sz.y * sc - 2.0), "兄弟", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("E1251B"))


func _body(shot: String) -> Texture2D:
	var t: Texture2D = Rules.tex("res://assets/game/chars/bros/%s.png" % shot)
	if t != null:
		return t
	return Kit.tex(Rules.CharSkin.DOG, shot)


func _scarf(shot: String) -> Texture2D:
	var t: Texture2D = Rules.tex("res://assets/game/chars/bros/scarf/%s.png" % shot)
	if t != null:
		return t
	return Kit.scarf_tex(Rules.CharSkin.DOG, shot)
