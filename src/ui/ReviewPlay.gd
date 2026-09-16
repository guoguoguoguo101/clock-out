extends Control
class_name ReviewPlay

var dim: ColorRect
var panel: ColorRect
var header: ColorRect
var title: Label
var alert: Label
var quote: Label
var issues: Label
var steps: Label
var status: Label
var help_lab: Label
var flash: Label
var hint: Label
var fill_bg: ColorRect
var fill: ColorRect
var track: ColorRect
var zone: ColorRect
var needle: ColorRect
var eta: Label
var _kind := ""
var _helper := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.04, 0.20)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = ColorRect.new()
	panel.color = Color(0.10, 0.12, 0.16, 0.50)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	header = ColorRect.new()
	header.color = Color(0.16, 0.08, 0.08, 0.55)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header)
	title = _lab(28, Color(0.94, 0.97, 1.0))
	alert = _lab(16, Color(1.0, 0.78, 0.76))
	quote = _lab(13, Color(0.62, 0.72, 0.82))
	issues = _lab(15, Color(0.88, 0.90, 0.94))
	issues.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	steps = _lab(15, Color(0.88, 0.90, 0.94))
	steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status = _lab(15, Color(0.88, 0.90, 0.94))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_lab = _lab(15, Color(0.72, 0.92, 0.86))
	help_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flash = _lab(22, Color(0.45, 0.92, 1.0))
	hint = _lab(15, Color(0.70, 0.78, 0.84))
	fill_bg = ColorRect.new()
	fill_bg.color = Color(0.08, 0.10, 0.14, 0.62)
	fill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill_bg)
	fill = ColorRect.new()
	fill.color = Color(0.22, 0.78, 0.96)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill)
	track = ColorRect.new()
	track.color = Color(0.16, 0.18, 0.24, 0.70)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	zone = ColorRect.new()
	zone.color = Color(0.18, 0.72, 0.92, 0.55)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(zone)
	needle = ColorRect.new()
	needle.color = Color(1.0, 0.92, 0.55)
	needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(needle)
	eta = _lab(16, Color(0.86, 0.90, 0.94))
	resized.connect(_layout)
	_layout()


func _lab(size: int, color: Color) -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.04, 0.88))
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
	header.size = Vector2(w, 72)
	title.position = Vector2(22, 10)
	title.size = Vector2(w * 0.46, 32)
	alert.position = Vector2(w * 0.48, 14)
	alert.size = Vector2(w * 0.48, 26)
	quote.position = Vector2(22, 44)
	quote.size = Vector2(w - 44, 22)
	var col_w := (w - 60.0) / 3.0
	issues.position = Vector2(18, 86)
	issues.size = Vector2(col_w, h - 210.0)
	steps.position = Vector2(30 + col_w, 86)
	steps.size = Vector2(col_w, h - 210.0)
	status.position = Vector2(42 + col_w * 2.0, 86)
	status.size = Vector2(col_w, 100)
	help_lab.position = Vector2(42 + col_w * 2.0, 190)
	help_lab.size = Vector2(col_w, 90)
	flash.position = Vector2(18, h - 118)
	flash.size = Vector2(w - 36, 26)
	fill_bg.position = Vector2(18, h - 86)
	fill_bg.size = Vector2(w - 36, 16)
	fill.position = fill_bg.position
	track.position = Vector2(18, h - 62)
	track.size = Vector2(w - 36, 14)
	zone.size = Vector2(track.size.x * 0.18, 14)
	needle.size = Vector2(6, 20)
	eta.position = Vector2(18, h - 40)
	eta.size = Vector2(w * 0.5, 22)
	hint.position = Vector2(w * 0.5, h - 40)
	hint.size = Vector2(w * 0.5 - 18, 22)


func bind(me: Actor) -> void:
	if me == null or me.kind != Rules.Kind.EMPLOYEE:
		visible = false
		return
	var view := me
	_helper = false
	if me.emp_state != Rules.EmpState.TALK and me.rescue_left > 0.0:
		var vic: Actor = Match.actors.get(me.rescue_slot) as Actor
		if vic != null and vic.emp_state == Rules.EmpState.TALK:
			view = vic
			_helper = true
	if view.emp_state == Rules.EmpState.TALK:
		visible = true
		_kind = "review"
		_layout()
		_bind_review(view)
	elif me.emp_state == Rules.EmpState.MEETING:
		visible = true
		_kind = "meeting"
		_layout()
		_bind_meeting(me)
	else:
		visible = false


func _bind_review(actor: Actor) -> void:
	var helpers := Match.review_helper_count(actor)
	title.text = "复盘模式"
	alert.text = "⚠ 主管盯上你了"
	quote.text = "被主管发现，进入工作复盘。请在限定时间内完成自我检视与修正。"
	issues.text = "问题记录 · 3 项\n\n· 重要邮件回复延迟\n  客户邮件超过 24 小时未回复\n\n· 项目数据出现错误\n  Q4 销售数据统计有误差\n\n· 会议材料未准备\n  周会汇报 PPT 内容不完整"
	var p := clampf(actor.talk_progress, 0.0, 1.0)
	var s1 := "✓" if p >= 0.25 else "1"
	var s2 := "✓" if p >= 0.50 else "2"
	var s3 := "✓" if p >= 0.75 else "3"
	var s4 := "✓" if p >= 1.00 else "4"
	steps.text = "复盘步骤\n\n%s  确认问题\n%s  整理解释\n%s  修正内容\n%s  恢复状态" % [s1, s2, s3, s4]
	var danger := "高" if actor.perf_hp <= 55.0 else "中"
	status.text = "当前状态\n\n主管压力：%s\n绩效 %.0f / 100\n「这种基础问题也会出错？」" % [danger, actor.perf_hp]
	if helpers > 0:
		help_lab.text = "同事支援\n\n%d 位同事正在援助\n恢复速度 +%.0f%%" % [helpers, float(helpers) * Rules.REVIEW_HELP_MUL * 100.0]
	else:
		help_lab.text = "同事支援\n\n暂无援助\n靠近倒地的人按 E 帮忙填条"
	if actor.review_boost_flash > 0.0:
		flash.text = "QTE成功 +25%    立即恢复一截！"
	elif _helper:
		flash.text = "你正在帮忙填条    人越多越快"
	else:
		flash.text = actor.play_msg if actor.play_msg != "" else "对准蓝带按 E"
	fill.visible = true
	fill_bg.visible = true
	fill.color = Color(0.22, 0.78, 0.96)
	fill.size = Vector2(fill_bg.size.x * p, fill_bg.size.y)
	track.visible = not _helper
	zone.visible = not _helper
	needle.visible = not _helper
	if not _helper:
		var tw: float = track.size.x
		var z0 := clampf(actor.play_mark - 0.09, 0.04, 0.78)
		zone.position = track.position + Vector2(tw * z0, 0)
		zone.size = Vector2(tw * 0.18, track.size.y)
		needle.position = track.position + Vector2(tw * clampf(actor.play_t, 0.0, 1.0) - 3.0, -3)
	var remain := (1.0 - p) / maxf(Rules.review_fill_rate(helpers), 0.001)
	eta.text = "复盘进度  %.0f%%     预计恢复  %02d:%02d" % [p * 100.0, int(remain) / 60, int(remain) % 60]
	hint.text = "绩效持续掉    救助者也能看到这条进度"


func _bind_meeting(actor: Actor) -> void:
	title.text = "强制开会"
	alert.text = "⚠ 绑在会议室椅子上"
	quote.text = "不能自救。按 E 减慢扣绩效，等同事开门来捞。"
	issues.text = "会议记录\n\n· 你被拖进会议室\n· 绩效仍在掉\n· 只能把掉血按慢一点"
	steps.text = "自救步骤\n\n1  按住节奏点 E\n2  等同事来捞\n3  离开会议室"
	status.text = "当前状态\n\n绩效 %.0f / 100\n剩余 %.0fs" % [actor.perf_hp, actor.meeting_left]
	help_lab.text = "同事支援\n\n贴着椅子按 E 救人"
	flash.text = "按 E 减慢扣绩效"
	fill.visible = true
	fill_bg.visible = true
	fill.color = Color(0.92, 0.38, 0.28)
	fill.size = Vector2(fill_bg.size.x * clampf(actor.meet_qte_left / 1.2, 0.0, 1.0), fill_bg.size.y)
	track.visible = false
	zone.visible = false
	needle.visible = false
	eta.text = "开会中"
	hint.text = "你动不了    只能把掉血按慢一点"
