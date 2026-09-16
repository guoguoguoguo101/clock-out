extends Control
## A truly thin rail; ProgressBar's theme minimum height is too large for the roster.
var value := 0.0:
	set(next):
		value = clampf(next, 0, 100)
		queue_redraw()
var accent := Color("#91c8c4")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.85, 0.86, 0.18))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value / 100.0, size.y)), accent)
