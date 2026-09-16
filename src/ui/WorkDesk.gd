extends Control
class_name WorkDesk

var dim: ColorRect
var panel: ColorRect
var header: ColorRect
var title: Label
var lead: Label
var date_lab: Label
var side: Label
var table: Label
var checks: Label
var note: Label
var warn: Label
var fill_bg: ColorRect
var fill: ColorRect
var ticks: Array[ColorRect] = []
var eta: Label
var hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.06, 0.09, 0.18)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = ColorRect.new()
	panel.color = Color(0.10, 0.14, 0.20, 0.52)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	header = ColorRect.new()
	header.color = Color(0.12, 0.16, 0.22, 0.58)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)
	title = _lab(26, Color(0.94, 0.97, 1.0))
	lead = _lab(14, Color(0.70, 0.78, 0.84))
	date_lab = _lab(14, Color(0.62, 0.70, 0.78))
	date_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side = _lab(15, Color(0.78, 0.86, 0.92))
	side.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	table = _lab(14, Color(0.90, 0.92, 0.96))
	table.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	checks = _lab(15, Color(0.88, 0.90, 0.94))
	checks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note = _lab(13, Color(0.72, 0.78, 0.84))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	warn = _lab(14, Color(1.0, 0.62, 0.56))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fill_bg = ColorRect.new()
	fill_bg.color = Color(0.08, 0.10, 0.14, 0.62)
	fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill_bg)
	fill = ColorRect.new()
	fill.color = Color(0.22, 0.78, 0.96)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill)
	for i in 2:
		var tick := ColorRect.new()
		tick.color = Color(1.0, 0.92, 0.55, 0.95)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tick)
		ticks.append(tick)
	eta = _lab(15, Color(0.86, 0.90, 0.94))
	hint = _lab(14, Color(0.70, 0.78, 0.84))
	resized.connect(_layout)
	_layout()


func _lab(size: int, color: Color) -> Label:
	var lab := Label.new()
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.07, 0.85))
	lab.add_theme_constant_override("outline_size", 5)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lab)
	return lab


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 8.0:
		return
	var w := minf(vp.x * 0.72, 980.0)
	var h := minf(vp.y * 0.58, 520.0)
	panel.position = Vector2((vp.x - w) * 0.5, vp.y * 0.16)
	panel.size = Vector2(w, h)
	header.position = Vector2.ZERO
	header.size = Vector2(w, 78)
	title.position = Vector2(24, 12)
	title.size = Vector2(w * 0.62, 34)
	lead.position = Vector2(24, 46)
	lead.size = Vector2(w * 0.62, 22)
	date_lab.position = Vector2(w * 0.62, 18)
	date_lab.size = Vector2(w * 0.36 - 20, 24)
	side.position = Vector2(16, 84)
	side.size = Vector2(140, h - 170)
	table.position = Vector2(164, 84)
	table.size = Vector2(w - 380, h - 180)
	checks.position = Vector2(w - 204, 84)
	checks.size = Vector2(188, 150)
	note.position = Vector2(w - 204, 238)
	note.size = Vector2(188, 72)
	warn.position = Vector2(w - 204, 314)
	warn.size = Vector2(188, 36)
	fill_bg.position = Vector2(20, h - 56)
	fill_bg.size = Vector2(w - 40, 14)
	fill.position = fill_bg.position
	eta.position = Vector2(20, h - 36)
	eta.size = Vector2(w * 0.5, 20)
	hint.position = Vector2(w * 0.5, h - 36)
	hint.size = Vector2(w * 0.5 - 20, 20)


func bind(actor: Actor) -> void:
	if actor == null or actor.kind != Rules.Kind.EMPLOYEE or not actor.tasking or actor.emp_state != Rules.EmpState.WORK:
		visible = false
		return
	visible = true
	_layout()
	var doc: Dictionary = Rules.task_doc(actor.tasks_done)
	title.text = "工作任务  ·  %s" % str(doc.get("title", Rules.task_name(actor.tasks_done)))
	lead.text = str(doc.get("lead", "把今天的事情做完。"))
	date_lab.text = "任务清单"
	var side_items: Array = doc.get("side", [])
	var side_txt := "任务类型\n"
	for i in side_items.size():
		var mark := "▸" if i == 0 else " "
		side_txt += "\n%s  %s" % [mark, str(side_items[i])]
	side.text = side_txt
	var cols: Array = doc.get("cols", [])
	var rows: Array = doc.get("rows", [])
	var col_names: PackedStringArray = PackedStringArray()
	for c in cols:
		col_names.append(str(c))
	var table_txt := "  ".join(col_names) + "\n"
	for row in rows:
		if row is Array:
			var cells: PackedStringArray = PackedStringArray()
			for cell in row:
				cells.append(str(cell))
			table_txt += "\n" + "  ".join(cells)
	table.text = table_txt
	var check_items: Array = doc.get("checks", [])
	var n := maxi(check_items.size(), 1)
	var p := clampf(actor.task_progress, 0.0, 1.0)
	var done_n := int(floor(p * float(n) + 0.001))
	var check_txt := "任务清单  %d/%d\n" % [done_n, n]
	for i in check_items.size():
		var box := "☑" if i < done_n else "☐"
		check_txt += "\n%s  %s" % [box, str(check_items[i])]
	checks.text = check_txt
	note.text = "工作备注\n\n%s" % str(doc.get("note", ""))
	warn.text = "⚠  %s" % str(doc.get("warn", "超过 deadline 将影响本月绩效评估。"))
	fill.size = Vector2(fill_bg.size.x * p, fill_bg.size.y)
	var saves := Rules.task_saves_for(actor.slot, actor.tasks_done)
	for i in ticks.size():
		if i < saves.size():
			ticks[i].visible = true
			ticks[i].position = Vector2(fill_bg.position.x + fill_bg.size.x * saves[i] - 2.0, fill_bg.position.y - 4.0)
			ticks[i].size = Vector2(4, fill_bg.size.y + 8.0)
			ticks[i].color = Color(0.45, 0.94, 0.62, 0.95) if p + 0.001 >= saves[i] else Color(1.0, 0.92, 0.55, 0.9)
		else:
			ticks[i].visible = false
	var cp := Rules.task_checkpoint_of(p, saves)
	eta.text = "任务进度  %.0f%%     上次存档  %.0f%%" % [p * 100.0, cp * 100.0]
	hint.text = "WASD 离开会丢掉未存档的进度    还差 %.0fs" % actor.task_remain_sec()
