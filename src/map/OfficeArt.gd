extends RefCounted
## Bright campus furniture. Individual PNGs, black/magenta already punched.

const DIR := "res://assets/game/props/campus/"
const FLOOR_PATH := "res://assets/game/campus/carpet.png"
const NAMES: PackedStringArray = [
	"desk", "chair", "cabinet", "plant", "sofa", "coffee", "water", "copier",
	"meeting", "toilet", "sink", "punch", "whiteboard", "window", "divider", "camera",
	"wayfinding", "glass_wall", "poster",
]

static var textures: Dictionary = {}


static func prepare() -> void:
	if not textures.is_empty():
		return
	for name: String in NAMES:
		var path: String = DIR + name + ".png"
		if ResourceLoader.exists(path):
			var loaded: Resource = load(path)
			if loaded is Texture2D:
				textures[name] = loaded
				continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			textures[name] = ImageTexture.create_from_image(img)


static func prop(kind: String) -> Texture2D:
	prepare()
	return textures.get(kind) as Texture2D
