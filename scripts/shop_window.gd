extends Window

signal purchase_requested(good_id: String)

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")

const WINDOW_SIZE := Vector2i(1117, 1034)
const SHOP_TEXTURE := "res://assets/ui/shop/商店ui.png"
const SEED1_TEXTURE := "res://assets/ui/shop/goods/seed1.png"
const CROSS_TEXTURE := "res://assets/ui/inventory/cross.png"
const ARROW_TEXTURE := "res://assets/ui/inventory/arrow.png"

const GOODS_PER_PAGE := 6
const MIN_TOTAL_PAGES := 1
const GOOD_ICON_SIZE := Vector2(134.0, 134.0)
const SHOP_SLOT_RECTS := [
	Rect2(148.0, 252.0, 252.0, 286.0),
	Rect2(438.0, 252.0, 252.0, 286.0),
	Rect2(728.0, 252.0, 252.0, 286.0),
	Rect2(148.0, 564.0, 252.0, 286.0),
	Rect2(438.0, 564.0, 252.0, 286.0),
	Rect2(728.0, 564.0, 252.0, 286.0)
]

var _root: Control
var _page_label: Label
var _result_label: Label
var _info_panel: PanelContainer
var _info_name_label: Label
var _info_desc_label: Label
var _info_price_label: Label
var _slot_controls: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _slot_name_labels: Array[Label] = []
var _slot_price_labels: Array[Label] = []
var _slot_owned_labels: Array[Label] = []
var _page := 0
var _faith_points := 0
var _owned_counts := {}
var _goods: Array[Dictionary] = []
var _dragging := false
var _drag_offset := Vector2i.ZERO


func setup() -> void:
	_goods = _make_default_goods()
	_configure_window()
	_create_content()
	_center_window()
	_refresh_page()


func open_window() -> void:
	if not visible:
		_center_window()
		visible = true
		_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_root.scale = Vector2(0.96, 0.96)

		var open_tween := create_tween()
		open_tween.set_trans(Tween.TRANS_BACK)
		open_tween.set_ease(Tween.EASE_OUT)
		open_tween.tween_property(_root, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16)
		open_tween.parallel().tween_property(_root, "scale", Vector2.ONE, 0.16)


func close_window() -> void:
	_close_window()


func set_faith_points(faith_points: int) -> void:
	_faith_points = maxi(0, faith_points)
	_refresh_page()


func set_owned_counts(owned_counts: Dictionary) -> void:
	_owned_counts = owned_counts.duplicate(true)
	_refresh_page()


func set_goods(goods: Array[Dictionary]) -> void:
	_goods.clear()
	for good in goods:
		var normalized_good := _normalize_good(good)
		if not normalized_good.is_empty():
			_goods.append(normalized_good)
	_page = 0
	_hide_info_panel()
	_refresh_page()


func get_good(good_id: String) -> Dictionary:
	for good in _goods:
		if String(good.get("id", "")) == good_id:
			return good.duplicate(true)
	return {}


func set_purchase_result(good_id: String, success: bool, message: String) -> void:
	if _result_label == null:
		return
	_result_label.text = message
	_result_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.62, 1.0) if success else Color(1.0, 0.58, 0.46, 1.0))
	_refresh_page()

	var good := get_good(good_id)
	if not good.is_empty() and _info_panel != null and _info_panel.visible:
		_show_info_panel(good, _info_panel.position)


func _make_default_goods() -> Array[Dictionary]:
	var goods: Array[Dictionary] = [
		{
			"id": "seed1",
			"name": "异梦种子",
			"description": "一颗潮湿的奇异种子。先买来存着，之后可以接入花园、献祭或养成系统。",
			"texture": SEED1_TEXTURE,
			"price": 25
		}
	]
	goods.append_array(OfferingCatalog.make_shop_goods())
	return goods


func _normalize_good(good: Dictionary) -> Dictionary:
	var good_id := String(good.get("id", "")).strip_edges()
	if good_id.is_empty():
		return {}
	if String(good.get("kind", "")) == OfferingCatalog.KIND:
		return OfferingCatalog.normalize_offering(good)

	var normalized_good := good.duplicate(true)
	normalized_good["id"] = good_id
	normalized_good["name"] = String(good.get("name", good_id))
	normalized_good["description"] = String(good.get("description", ""))
	normalized_good["texture"] = String(good.get("texture", ""))
	normalized_good["price"] = maxi(0, int(good.get("price", 0)))
	return normalized_good


func _configure_window() -> void:
	name = "ShopWindow"
	title = "商店"
	size = WINDOW_SIZE
	borderless = true
	always_on_top = false
	unresizable = true
	transparent = true
	transparent_bg = true
	visible = false


func _create_content() -> void:
	_root = Control.new()
	_root.name = "ShopRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var background := TextureRect.new()
	background.name = "ShopBackground"
	background.texture = load(SHOP_TEXTURE) as Texture2D
	background.size = Vector2(WINDOW_SIZE)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	_create_slots()
	_create_page_controls()
	_create_close_button()
	_create_result_label()
	_create_info_panel()


func _create_slots() -> void:
	_slot_controls.clear()
	_slot_icons.clear()
	_slot_name_labels.clear()
	_slot_price_labels.clear()
	_slot_owned_labels.clear()

	for index in SHOP_SLOT_RECTS.size():
		var slot_rect: Rect2 = SHOP_SLOT_RECTS[index]
		var slot := Control.new()
		slot.name = "ShopSlot%d" % index
		slot.position = slot_rect.position
		slot.size = slot_rect.size
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_entered.connect(_on_slot_hovered.bind(index, true))
		slot.mouse_exited.connect(_on_slot_hovered.bind(index, false))
		slot.gui_input.connect(_on_slot_gui_input.bind(index))
		_root.add_child(slot)
		_slot_controls.append(slot)

		var icon := TextureRect.new()
		icon.name = "GoodIcon%d" % index
		icon.position = Vector2((slot_rect.size.x - GOOD_ICON_SIZE.x) * 0.5, 28.0)
		icon.size = GOOD_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_slot_icons.append(icon)

		var name_label := _make_slot_label(18, Color(0.96, 0.88, 0.62, 1.0), 4)
		name_label.position = Vector2(18.0, 168.0)
		name_label.size = Vector2(slot_rect.size.x - 36.0, 30.0)
		slot.add_child(name_label)
		_slot_name_labels.append(name_label)

		var price_label := _make_slot_label(17, Color(0.78, 1.0, 0.68, 1.0), 3)
		price_label.position = Vector2(20.0, 206.0)
		price_label.size = Vector2(slot_rect.size.x - 40.0, 28.0)
		slot.add_child(price_label)
		_slot_price_labels.append(price_label)

		var owned_label := _make_slot_label(14, Color(0.68, 0.78, 0.66, 1.0), 2)
		owned_label.position = Vector2(20.0, 236.0)
		owned_label.size = Vector2(slot_rect.size.x - 40.0, 24.0)
		slot.add_child(owned_label)
		_slot_owned_labels.append(owned_label)


func _make_slot_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _create_page_controls() -> void:
	var left_arrow := _make_arrow_button(-1)
	left_arrow.position = Vector2(342.0, 904.0)
	left_arrow.scale = Vector2(-1.0, 1.0)
	_root.add_child(left_arrow)

	var right_arrow := _make_arrow_button(1)
	right_arrow.position = Vector2(682.0, 904.0)
	_root.add_child(right_arrow)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.position = Vector2(438.0, 904.0)
	_page_label.size = Vector2(240.0, 92.0)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_label.add_theme_font_size_override("font_size", 36)
	_page_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58, 1.0))
	_page_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	_page_label.add_theme_constant_override("outline_size", 5)
	_root.add_child(_page_label)


func _create_close_button() -> void:
	var close_button := TextureButton.new()
	close_button.name = "CloseShop"
	close_button.texture_normal = load(CROSS_TEXTURE) as Texture2D
	close_button.texture_hover = close_button.texture_normal
	close_button.texture_pressed = close_button.texture_normal
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_SCALE
	close_button.size = Vector2(62.0, 62.0)
	close_button.position = Vector2(1018.0, 72.0)
	close_button.pivot_offset = close_button.size * 0.5
	close_button.mouse_entered.connect(_animate_control_hover.bind(close_button, true))
	close_button.mouse_exited.connect(_animate_control_hover.bind(close_button, false))
	close_button.pressed.connect(_animate_control_press.bind(close_button))
	close_button.pressed.connect(_close_window)
	_root.add_child(close_button)


func _create_result_label() -> void:
	_result_label = Label.new()
	_result_label.text = "点击商品购买"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.position = Vector2(360.0, 870.0)
	_result_label.size = Vector2(400.0, 32.0)
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.68, 1.0))
	_result_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	_result_label.add_theme_constant_override("outline_size", 3)
	_root.add_child(_result_label)


func _create_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.name = "GoodInfoPanel"
	_info_panel.visible = false
	_info_panel.size = Vector2(292.0, 150.0)
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.z_index = 20
	_info_panel.add_theme_stylebox_override("panel", _make_info_panel_style())
	_root.add_child(_info_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_info_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_info_name_label = Label.new()
	_info_name_label.add_theme_font_size_override("font_size", 18)
	_info_name_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58, 1.0))
	content.add_child(_info_name_label)

	_info_desc_label = Label.new()
	_info_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc_label.custom_minimum_size = Vector2(260.0, 70.0)
	_info_desc_label.add_theme_font_size_override("font_size", 14)
	_info_desc_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.66, 1.0))
	content.add_child(_info_desc_label)

	_info_price_label = Label.new()
	_info_price_label.add_theme_font_size_override("font_size", 15)
	_info_price_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.68, 1.0))
	content.add_child(_info_price_label)


func _make_info_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.022, 0.95)
	style.border_color = Color(0.46, 0.62, 0.42, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_arrow_button(direction: int) -> TextureButton:
	var button := TextureButton.new()
	button.name = "ShopArrow%s" % direction
	button.texture_normal = load(ARROW_TEXTURE) as Texture2D
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = Vector2(92.0, 92.0)
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(_animate_control_hover.bind(button, true))
	button.mouse_exited.connect(_animate_control_hover.bind(button, false))
	button.pressed.connect(_on_arrow_pressed.bind(direction, button))
	return button


func _refresh_page() -> void:
	if _root == null:
		return

	var page_count := _get_page_count()
	_page = clampi(_page, 0, page_count - 1)

	if _page_label != null:
		_page_label.text = "第 %d / %d 页" % [_page + 1, page_count]

	var page_start := _page * GOODS_PER_PAGE
	for slot_index in _slot_controls.size():
		var good_index := page_start + slot_index
		var has_good := good_index < _goods.size()
		var slot := _slot_controls[slot_index]
		var icon := _slot_icons[slot_index]
		var name_label := _slot_name_labels[slot_index]
		var price_label := _slot_price_labels[slot_index]
		var owned_label := _slot_owned_labels[slot_index]

		slot.mouse_filter = Control.MOUSE_FILTER_STOP if has_good else Control.MOUSE_FILTER_IGNORE
		icon.visible = has_good
		name_label.visible = has_good
		price_label.visible = has_good
		owned_label.visible = has_good

		if not has_good:
			continue

		var good := _goods[good_index]
		var price := int(good.get("price", 0))
		var affordable := _faith_points >= price
		var offering := OfferingCatalog.is_offering(good)
		var owned := int(_owned_counts.get(String(good.get("id", "")), 0))
		icon.texture = load(String(good.get("texture", ""))) as Texture2D
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.62, 0.62, 0.62, 0.9)
		name_label.text = String(good.get("name", "商品"))
		price_label.text = "价格 %d 信仰" % price
		price_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.68, 1.0) if affordable else Color(1.0, 0.58, 0.46, 1.0))
		owned_label.text = "购买后随鼠标投放" if offering else "已拥有 %d" % owned


func _get_page_count() -> int:
	var needed_pages := int(ceil(float(_goods.size()) / float(GOODS_PER_PAGE)))
	return maxi(MIN_TOTAL_PAGES, needed_pages)


func _turn_page(direction: int) -> void:
	_page = posmod(_page + direction, _get_page_count())
	_hide_info_panel()
	_refresh_page()


func _on_slot_hovered(slot_index: int, hovered: bool) -> void:
	if not hovered:
		_hide_info_panel()
		return

	var good_index := (_page * GOODS_PER_PAGE) + slot_index
	if good_index < 0 or good_index >= _goods.size():
		return

	var slot := _slot_controls[slot_index]
	var position_hint := slot.position + Vector2(slot.size.x - 18.0, 18.0)
	if position_hint.x + _info_panel.size.x > float(WINDOW_SIZE.x) - 32.0:
		position_hint.x = slot.position.x - _info_panel.size.x + 18.0
	_show_info_panel(_goods[good_index], position_hint)


func _show_info_panel(good: Dictionary, panel_position: Vector2) -> void:
	if _info_panel == null:
		return

	_info_name_label.text = String(good.get("name", "商品"))
	_info_desc_label.text = String(good.get("description", ""))
	if OfferingCatalog.is_offering(good):
		_info_price_label.text = "价格：%d 信仰    进食返还：%d 信仰" % [
			int(good.get("price", 0)),
			int(good.get("faith", 0))
		]
	else:
		_info_price_label.text = "价格：%d 信仰    已拥有：%d" % [
			int(good.get("price", 0)),
			int(_owned_counts.get(String(good.get("id", "")), 0))
		]
	_info_panel.position = Vector2(
		clampf(panel_position.x, 24.0, float(WINDOW_SIZE.x) - _info_panel.size.x - 24.0),
		clampf(panel_position.y, 24.0, float(WINDOW_SIZE.y) - _info_panel.size.y - 24.0)
	)
	_info_panel.visible = true


func _hide_info_panel() -> void:
	if _info_panel != null:
		_info_panel.visible = false


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		var good_index := (_page * GOODS_PER_PAGE) + slot_index
		if good_index < 0 or good_index >= _goods.size():
			return

		purchase_requested.emit(String(_goods[good_index].get("id", "")))
		_slot_controls[slot_index].accept_event()


func _on_arrow_pressed(direction: int, button: Control) -> void:
	_animate_control_press(button)
	_turn_page(direction)


func _center_window() -> void:
	var screen_rect := _get_current_screen_rect()
	position = Vector2i(
		maxi(screen_rect.position.x, screen_rect.position.x + int((screen_rect.size.x - WINDOW_SIZE.x) * 0.5)),
		maxi(screen_rect.position.y, screen_rect.position.y + int((screen_rect.size.y - WINDOW_SIZE.y) * 0.5))
	)


func _close_window() -> void:
	visible = false
	_dragging = false
	_hide_info_panel()


func _animate_control_hover(control: Control, hovered: bool) -> void:
	if control == null:
		return

	var direction := -1.0 if control.scale.x < 0.0 else 1.0
	var factor := 1.05 if hovered else 1.0
	var target := Vector2(direction * factor, factor)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, 0.1)


func _animate_control_press(control: Control) -> void:
	if control == null:
		return

	var direction := -1.0 if control.scale.x < 0.0 else 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(direction * 0.94, 0.94), 0.05)
	tween.tween_property(control, "scale", Vector2(direction * 1.03, 1.03), 0.08)
	tween.tween_property(control, "scale", Vector2(direction, 1.0), 0.08)


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			if _dragging:
				_drag_offset = DisplayServer.mouse_get_position() - position
			_root.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position = DisplayServer.mouse_get_position() - _drag_offset
		_root.accept_event()


func _get_current_screen_rect() -> Rect2i:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
