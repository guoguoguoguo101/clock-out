extends Control
class_name StockDesk

const BG := preload("res://assets/game/ui/stock_bg.png")
const ALERT := preload("res://assets/game/ui/stock_bg_alert.png")

var dim: ColorRect
var panel: Control
var bg: TextureRect
var alert_bg: TextureRect
var veil: ColorRect
var chart: Control
var price_lab: Label
var value_lab: Label
var pos_lab: Label
var time_lab: Label
var hint_lab: Label
var warn_lab: Label
var _hist: PackedFloat32Array = PackedFloat32Array()
var _price := 100.0
var _start := 100.0
var _threat := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.02, 0.02, 0.03, 0.94)
	add_child(dim)
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	bg = TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	alert_bg = TextureRect.new()
	alert_bg.texture = ALERT
	alert_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alert_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	alert_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_bg.modulate.a = 0.0
	panel.add_child(alert_bg)
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.72, 0.04, 0.04, 0.0)
	panel.add_child(veil)
	var pane := ChartPane.new()
	pane.desk = self
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(pane)
	chart = pane
	time_lab = _lab(18, Color(0.98, 0.82, 0.42), HORIZONTAL_ALIGNMENT_RIGHT)
	price_lab = _lab(42, Color(0.55, 0.98, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	value_lab = _lab(28, Color(0.96, 0.92, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	pos_lab = _lab(16, Color(0.82, 0.88, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	hint_lab = _lab(15, Color(0.86, 0.90, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	warn_lab = _lab(20, Color(1.0, 0.42, 0.32), HORIZONTAL_ALIGNMENT_CENTER)
	resized.connect(_layout)
	_layout()


func _lab(size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = align
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lab)
	return lab


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 8.0:
		return
	var w := minf(vp.x * 0.92, 1100.0)
	var h := w * 9.0 / 16.0
	if h > vp.y * 0.86:
		h = vp.y * 0.86
		w = h * 16.0 / 9.0
	panel.position = (vp - Vector2(w, h)) * 0.5
	panel.size = Vector2(w, h)
	time_lab.position = Vector2(w * 0.62, h * 0.045)
	time_lab.size = Vector2(w * 0.34, 32)
	price_lab.position = Vector2(w * 0.07, h * 0.20)
	price_lab.size = Vector2(w * 0.50, 52)
	pos_lab.position = Vector2(w * 0.07, h * 0.28)
	pos_lab.size = Vector2(w * 0.40, 24)
	value_lab.position = Vector2(w * 0.28, h * 0.78)
	value_lab.size = Vector2(w * 0.44, 36)
	hint_lab.position = Vector2(w * 0.08, h * 0.90)
	hint_lab.size = Vector2(w * 0.84, 28)
	warn_lab.position = Vector2(w * 0.18, h * 0.12)
	warn_lab.size = Vector2(w * 0.64, 28)
	if chart:
		chart.queue_redraw()


func bind(actor: Actor, threat: float) -> void:
	if actor == null or actor.emp_state != Rules.EmpState.TRADE:
		visible = false
		return
	visible = true
	_hist = actor.trade_history
	_price = actor.trade_price
	_start = Rules.STOCK_START
	_threat = clampf(threat, 0.0, 1.0)
	var value := actor.trade_value()
	var pnl := value - Rules.STOCK_START
	var up := _price >= _start
	price_lab.text = "¥%.1f" % _price
	price_lab.add_theme_color_override("font_color", Color(0.42, 0.96, 0.58) if up else Color(0.98, 0.38, 0.34))
	value_lab.text = "账户 %.1f   %+0.1f" % [value, pnl]
	value_lab.add_theme_color_override("font_color", Color(0.55, 0.98, 0.62) if pnl >= 0.0 else Color(1.0, 0.46, 0.40))
	if actor.trade_holding:
		pos_lab.text = "持仓中 · 现价结算中"
		hint_lab.text = "F 卖出    E 平仓    赚了 +精力"
	else:
		pos_lab.text = "空仓 · 现金 %.1f" % actor.trade_cash
		hint_lab.text = "F 买入    E 撤了    赚了 +精力  亏了不扣"
	time_lab.text = "倒计时  %.1fs" % actor.trade_left
	alert_bg.modulate.a = _threat
	veil.color = Color(0.78, 0.05, 0.05, _threat * (0.18 + 0.38 * _threat))
	dim.color = Color(0.08 + 0.42 * _threat, 0.02, 0.02, 0.94)
	if _threat > 0.62:
		warn_lab.text = "督导靠近 · 页面发烫"
		warn_lab.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	elif _threat > 0.28:
		warn_lab.text = "走廊有动静"
		warn_lab.modulate.a = 0.70
	else:
		warn_lab.text = ""
		warn_lab.modulate.a = 0.0
	if chart:
		chart.queue_redraw()


func paint_chart(target: Control) -> void:
	if _hist.size() < 2 or panel == null:
		return
	var s := panel.size
	var rect := Rect2(s.x * 0.06, s.y * 0.34, s.x * 0.88, s.y * 0.40)
	var lo := 1e9
	var hi := -1e9
	for v in _hist:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	lo = minf(lo, _start) - 4.0
	hi = maxf(hi, _start) + 4.0
	var span := maxf(hi - lo, 8.0)
	var pts: PackedVector2Array = PackedVector2Array()
	var n := _hist.size()
	for i in n:
		var x := rect.position.x + rect.size.x * float(i) / float(max(n - 1, 1))
		var y := rect.position.y + rect.size.y * (1.0 - (_hist[i] - lo) / span)
		pts.append(Vector2(x, y))
	var col := Color(0.38, 0.96, 0.52) if _price >= _start else Color(0.98, 0.36, 0.32)
	if _threat > 0.45:
		col = col.lerp(Color(1.0, 0.28, 0.22), _threat * 0.55)
	target.draw_polyline(pts, col, 3.2, true)
	target.draw_circle(pts[pts.size() - 1], 5.0, col)


class ChartPane extends Control:
	var desk: StockDesk

	func _draw() -> void:
		if desk == null:
			return
		desk.paint_chart(self)
