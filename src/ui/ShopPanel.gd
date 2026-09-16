extends Control
class_name ShopPanel

signal item_bought(item_id: int)
signal item_sold(slot_idx: int)

var actor: Actor
var _buttons: Dictionary = {}  # item_id -> Button
var _sell_buttons: Array[Button] = []
var _coin_label: Label
var _title_label: Label
var _desc_label: Label
var _inv_box: HBoxContainer
var _grid: GridContainer
var _close_btn: Button


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func open(p_actor: Actor) -> void:
	actor = p_actor
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	actor = null


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_sell_buttons.clear()
	if actor == null:
		return

	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.10, 0.92)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.offset_left = -340
	vbox.offset_top = -260
	vbox.offset_right = 340
	vbox.offset_bottom = 260
	add_child(vbox)

	# 标题行
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	_title_label = Label.new()
	_title_label.text = "☕ 自动贩卖机"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	hdr.add_child(_title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hdr.add_child(spacer)
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	hdr.add_child(_coin_label)

	# 装备栏
	var inv_title := Label.new()
	inv_title.text = "── 装备栏 ──"
	inv_title.add_theme_font_size_override("font_size", 13)
	inv_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(inv_title)

	_inv_box = HBoxContainer.new()
	vbox.add_child(_inv_box)

	# 商品区
	var shop_title := Label.new()
	shop_title.text = "── 商品 ──"
	shop_title.add_theme_font_size_override("font_size", 13)
	shop_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(shop_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 300)
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	scroll.add_child(_grid)

	# 描述
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(660, 36)
	vbox.add_child(_desc_label)

	# 关闭按钮
	_close_btn = Button.new()
	_close_btn.text = "关闭 [ESC]"
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)

	_refresh()


func _refresh() -> void:
	if actor == null:
		return
	_coin_label.text = "💰 %d 摸鱼币" % actor.coins

	# 装备栏
	for c in _inv_box.get_children():
		c.queue_free()
	_sell_buttons.clear()
	for i in range(ItemDB.MAX_SLOTS):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(200, 44)
		if i < actor.item_slots.size():
			var d := ItemDB.get_item(actor.item_slots[i])
			if d:
				slot_btn.text = "%s %s [卖 %d]" % [d.icon, d.name, ItemDB.sell_price(d.id)]
				var idx := i
				slot_btn.pressed.connect(func(): _on_sell(idx))
		else:
			slot_btn.text = "[ 空 ]"
			slot_btn.disabled = true
		_inv_box.add_child(slot_btn)
		_sell_buttons.append(slot_btn)

	# 商品列表
	for c in _grid.get_children():
		c.queue_free()
	_buttons.clear()
	var side := ItemDB.Side.BOSS if actor.kind == Rules.Kind.BOSS else ItemDB.Side.EMPLOYEE
	var all_items := ItemDB.items_for_side(side)
	for d in all_items:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(210, 56)
		var price_text := ""
		if d.recipe.is_empty():
			price_text = "%d 币" % d.cost
		else:
			var can := ItemDB.can_combine(actor.item_slots, d.id)
			if can:
				price_text = "合成 +%d 币" % d.combine_cost
			else:
				price_text = "合成 %d 币（缺材料）" % d.cost
		btn.text = "%s %s\n%s" % [d.icon, d.name, price_text]
		btn.tooltip_text = d.desc
		var item_id: int = d.id
		btn.pressed.connect(func(): _on_buy(item_id))
		btn.mouse_entered.connect(func(): _show_desc(item_id))
		# 能否买得起
		var affordable := false
		if d.recipe.is_empty():
			affordable = actor.coins >= d.cost and actor.item_slots.size() < ItemDB.MAX_SLOTS
		else:
			affordable = ItemDB.can_combine(actor.item_slots, d.id) and actor.coins >= d.combine_cost
		if not affordable:
			btn.modulate = Color(0.5, 0.5, 0.5)
		_grid.add_child(btn)
		_buttons[d.id] = btn


func _show_desc(item_id: int) -> void:
	var d := ItemDB.get_item(item_id)
	if d and _desc_label:
		var recipe_text := ""
		if not d.recipe.is_empty():
			var names := []
			for rid in d.recipe:
				var rd := ItemDB.get_item(rid)
				if rd:
					names.append(rd.icon + rd.name)
			recipe_text = " ← " + " + ".join(names)
		_desc_label.text = "%s %s%s\n%s" % [d.icon, d.name, recipe_text, d.desc]


func _on_buy(item_id: int) -> void:
	if actor == null:
		return
	if actor.buy_item(item_id):
		item_bought.emit(item_id)
		_refresh()


func _on_sell(slot_idx: int) -> void:
	if actor == null:
		return
	if actor.sell_item(slot_idx):
		item_sold.emit(slot_idx)
		_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
