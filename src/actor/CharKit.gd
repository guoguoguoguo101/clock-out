extends RefCounted
class_name CharKit

const PACK := {
	Rules.CharSkin.HORSE: "horse",
	Rules.CharSkin.RABBIT: "rabbit",
	Rules.CharSkin.COW: "cow",
	Rules.CharSkin.PELICAN: "pelican",
	Rules.CharSkin.KANGAROO: "kangaroo",
	Rules.CharSkin.TIGER: "tiger",
	Rules.CharSkin.DOG: "dog",
}

const IDLE := ["idle_0", "idle_1", "idle_2", "idle_3"]
const WALK := ["walk_0", "walk_1", "walk_2", "walk_3"]
const RUN := ["run_0", "run_1", "run_2", "run_3"]
const WORK := ["work_0", "work_1", "work_2", "work_3"]
const SLEEP := ["sleep_0", "sleep_1", "sleep_2", "sleep_3"]
const TOILET := ["toilet_0", "toilet_1", "toilet_2", "toilet_3"]
const RIDE := ["ride_0", "ride_1", "ride_2", "ride_3"]
const TRADE := ["trade_0", "trade_1"]
const FALLBACK := {
	"work": "work_0",
	"sleep": "sleep_0",
	"toilet": "toilet_0",
	"ride": "idle_0",
	"trade": "trade_0",
}

static var _cache: Dictionary = {}


static func pack_id(skin: int) -> String:
	return str(PACK.get(skin, "horse"))


static func tex(skin: int, pose: String) -> Texture2D:
	var pack := pack_id(skin)
	var key := "%s/%s" % [pack, pose]
	if not _cache.has(key):
		_cache[key] = _load_pose(pack, pose)
	return _cache[key] as Texture2D


static func has_scarf_layer(skin: int) -> bool:
	return scarf_tex(skin, "idle_0") != null


static func bowl_tex(skin: int) -> Texture2D:
	var pack := pack_id(skin)
	var key := "%s/bowl" % pack
	if _cache.has(key):
		return _cache[key] as Texture2D
	var tex := _try_tex("res://assets/game/chars/%s/bowl.png" % pack)
	if tex == null and pack in ["pelican", "dog"]:
		tex = _try_tex("res://assets/game/props/toilet_sit_layer.png")
	_cache[key] = tex
	return tex


static func scarf_tex(skin: int, pose: String) -> Texture2D:
	var pack := pack_id(skin)
	var key := "%s/scarf/%s" % [pack, pose]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var tex := _try_tex("res://assets/game/chars/%s/scarf/%s.png" % [pack, pose])
	if tex == null:
		var fb := str(FALLBACK.get(pose, "idle_0"))
		tex = _try_tex("res://assets/game/chars/%s/scarf/%s.png" % [pack, fb])
	_cache[key] = tex
	return tex


static func _load_pose(pack: String, pose: String) -> Texture2D:
	var path := "res://assets/game/chars/%s/%s.png" % [pack, pose]
	var tex := _try_tex(path)
	if tex != null:
		return tex
	var fb := str(FALLBACK.get(pose, "idle_0"))
	if pose.begins_with("ride"):
		fb = "idle_0"
	tex = _try_tex("res://assets/game/chars/%s/%s.png" % [pack, fb])
	if tex != null:
		return tex
	return _try_tex("res://assets/game/chars/horse/idle_0.png")


static func _try_tex(path: String) -> Texture2D:
	return Rules.tex(path)


static func loop_frames(anim: String) -> PackedStringArray:
	match anim:
		"walk":
			return PackedStringArray(WALK)
		"run":
			return PackedStringArray(RUN)
		"work":
			return PackedStringArray(WORK)
		"sleep":
			return PackedStringArray(SLEEP)
		"toilet":
			return PackedStringArray(TOILET)
		"ride":
			return PackedStringArray(RIDE)
		"trade":
			return PackedStringArray(TRADE)
		_:
			return PackedStringArray(IDLE)
