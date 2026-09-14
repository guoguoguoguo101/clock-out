extends RefCounted
class_name CharKit

const PACK := {
	Rules.CharSkin.HORSE: "horse",
	Rules.CharSkin.RABBIT: "rabbit",
	Rules.CharSkin.COW: "cow",
	Rules.CharSkin.PELICAN: "pelican",
	Rules.CharSkin.TIGER: "tiger",
}

const IDLE := ["idle_0", "idle_1", "idle_2", "idle_3"]
const WALK := ["walk_0", "walk_1", "walk_2", "walk_3"]
const RUN := ["run_0", "run_1", "run_2", "run_3"]
const WORK := ["work_0", "work_1", "work_2", "work_3"]
const SLEEP := ["sleep_0", "sleep_1", "sleep_2", "sleep_3"]
const TOILET := ["toilet_0", "toilet_1", "toilet_2", "toilet_3"]
const FALLBACK := {
	"work": "work_0",
	"sleep": "sleep_0",
	"toilet": "toilet_0",
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


static func _load_pose(pack: String, pose: String) -> Texture2D:
	var path := "res://assets/game/chars/%s/%s.png" % [pack, pose]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var fb := str(FALLBACK.get(pose, "idle_0"))
	var fb_path := "res://assets/game/chars/%s/%s.png" % [pack, fb]
	if ResourceLoader.exists(fb_path):
		return load(fb_path) as Texture2D
	return load("res://assets/game/chars/horse/idle_0.png") as Texture2D


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
		_:
			return PackedStringArray(IDLE)
