extends Window

signal purchase_requested(good_id: String)

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const TurretCatalog = preload("res://scripts/domain/turret_catalog.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")
const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")

const SHOP_PAGE_SIZE := Vector2i(1117, 1034)
# Keep a generous transparent gutter around the protruding category bookmarks.
# The extra space is intentional: bookmark hover uses a scale animation and
# must never be cut off by the native transparent window boundary.
const TAB_GUTTER_WIDTH := 230
const WINDOW_SIZE := Vector2i(SHOP_PAGE_SIZE.x + TAB_GUTTER_WIDTH, SHOP_PAGE_SIZE.y)
const PAGE_ORIGIN := Vector2(TAB_GUTTER_WIDTH, 0.0)
const SHOP_TEXTURE := "res://assets/ui/shop/商店ui.png"
const CROSS_TEXTURE := "res://assets/ui/inventory/cross.png"
const ARROW_TEXTURE := "res://assets/ui/inventory/arrow.png"
const BOOKMARK_TEXTURE := "res://assets/ui/newElements/书签.png"

const GOODS_PER_PAGE := 6
const MIN_TOTAL_PAGES := 1
const GOOD_ICON_SIZE := Vector2(134.0, 134.0)
const CATEGORY_TAB_SIZE := Vector2(258.0, 82.0)
# Deliberately overlap the parchment edge. This reads as a physical bookmark
# tucked into the shop, rather than two floating controls beside it.
const CATEGORY_TAB_PAGE_OVERLAP := 84.0
const CATEGORY_TAB_POSITIONS := [Vector2(56.0, 270.0), Vector2(56.0, 370.0)]
const CATEGORY_TAB_HOVER_SCALE := 1.045
const SHOP_SLOT_RECTS := [
	Rect2(148.0, 252.0, 252.0, 286.0),
	Rect2(438.0, 252.0, 252.0, 286.0),
	Rect2(728.0, 252.0, 252.0, 286.0),
	Rect2(148.0, 564.0, 252.0, 286.0),
	Rect2(438.0, 564.0, 252.0, 286.0),
	Rect2(728.0, 564.0, 252.0, 286.0)
]

var _root: Control
var _page_root: Control
var _category_layer: Control
var _category_hit_layer: Control
var _page_label: Label
var _coin_balance_label: Label
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
var _coin_balance := 0
var _coin_balance_dirty := false
var _owned_counts := {}
var _turret_states := {}
var _goods: Array[Dictionary] = []
var _category_buttons := {}
var _active_category := OfferingCatalog.KIND
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _language := LanguageSettings.DEFAULT_LANGUAGE


func setup() -> void:
	_goods = _make_default_goods()
	theme = LanguageSettings.make_ui_theme(_language)
	_configure_window()
	_create_content()
	_center_window()
	set_language(_language)


func open_window() -> void:
	if not visible:
		_center_window()
		# Coin changes can arrive while this window is hidden. Paint all cards
		# once here instead of rebuilding them for every desktop coin pickup.
		if _coin_balance_dirty:
			_refresh_page()
			_coin_balance_dirty = false
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


func set_coin_balance(coin_balance: int) -> void:
	var next_balance := maxi(0, coin_balance)
	if _coin_balance == next_balance:
		return
	_coin_balance = next_balance
	if not visible:
		_coin_balance_dirty = true
		# Keep the cached header state observable for setup/tests, while deferring
		# the expensive six-card rebuild until the window is opened.
		_refresh_coin_balance()
		return
	_refresh_coin_balance()
	_refresh_visible_slot_affordability()


func set_faith_points(legacy_balance: int) -> void:
	set_coin_balance(legacy_balance)


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	theme = LanguageSettings.make_ui_theme(_language)
	title = "Shop" if _language == "en" else "商店"
	_refresh_category_tabs()
	_refresh_page()


func set_owned_counts(owned_counts: Dictionary) -> void:
	_owned_counts = owned_counts.duplicate(true)
	_refresh_page()


func set_turret_states(turret_states: Dictionary) -> void:
	_turret_states = turret_states.duplicate(true)
	_refresh_page()


func set_goods(goods: Array[Dictionary]) -> void:
	_goods.clear()
	for good in goods:
		var normalized_good := _normalize_good(good)
		if not normalized_good.is_empty():
			_goods.append(normalized_good)
	if not _has_goods_in_category(_active_category):
		_active_category = OfferingCatalog.KIND
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
	_result_label.visible = not message.strip_edges().is_empty()
	_result_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.62, 1.0) if success else Color(1.0, 0.58, 0.46, 1.0))
	_refresh_page()

	var good := get_good(good_id)
	if not good.is_empty() and _info_panel != null and _info_panel.visible:
		_show_info_panel(good, _info_panel.position)


func _make_default_goods() -> Array[Dictionary]:
	return OfferingCatalog.make_shop_goods()


func _normalize_good(good: Dictionary) -> Dictionary:
	var good_id := String(good.get("id", "")).strip_edges()
	if good_id.is_empty():
		return {}
	if String(good.get("kind", "")) == OfferingCatalog.KIND:
		var offering := OfferingCatalog.normalize_offering(good)
		if offering.is_empty():
			return {}
		var authored_price := maxi(1, int(offering.get("price", 1)))
		offering["base_price"] = maxi(
			authored_price,
			int(good.get("base_price", authored_price))
		)
		# set_goods receives the trusted runtime catalog. Preserve its hidden
		# production-rate price instead of normalizing back to the authored floor.
		offering["price"] = maxi(authored_price, int(good.get("price", authored_price)))
		return offering
	if String(good.get("kind", "")) == TurretCatalog.KIND:
		return TurretCatalog.normalize_turret(good)

	var normalized_good := good.duplicate(true)
	normalized_good["id"] = good_id
	normalized_good["name"] = String(good.get("name", good_id))
	normalized_good["description"] = String(good.get("description", ""))
	normalized_good["texture"] = String(good.get("texture", ""))
	normalized_good["price"] = maxi(0, int(good.get("price", 0)))
	return normalized_good


func _configure_window() -> void:
	name = "ShopWindow"
	title = "Shop"
	borderless = true
	always_on_top = false
	unresizable = true
	transparent = true
	transparent_bg = true
	visible = false
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))
	size_changed.connect(_configure_mouse_passthrough)
	_configure_mouse_passthrough()


func _create_content() -> void:
	_root = Control.new()
	_root.name = "ShopRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_category_layer = Control.new()
	_category_layer.name = "ShopCategoryTabs"
	_category_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_category_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Let the parchment cover each bookmark's inner edge so it reads as tucked
	# into the shop instead of floating in front of it.
	_category_layer.z_index = 1
	_root.add_child(_category_layer)

	_category_hit_layer = Control.new()
	_category_hit_layer.name = "ShopCategoryTabHitAreas"
	_category_hit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_category_hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_hit_layer.z_index = 3
	_root.add_child(_category_hit_layer)
	_create_category_tabs()

	_page_root = Control.new()
	_page_root.name = "ShopPage"
	_page_root.position = PAGE_ORIGIN
	_page_root.size = Vector2(SHOP_PAGE_SIZE)
	_page_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_root.gui_input.connect(_on_root_gui_input)
	_page_root.z_index = 2
	_root.add_child(_page_root)

	var background := TextureRect.new()
	background.name = "ShopBackground"
	background.texture = load(SHOP_TEXTURE) as Texture2D
	background.size = Vector2(SHOP_PAGE_SIZE)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(background)

	_create_slots()
	_create_page_controls()
	_create_close_button()
	_create_coin_balance()
	_create_result_label()
	_create_info_panel()
	_configure_mouse_passthrough()


func _create_category_tabs() -> void:
	if _category_layer == null:
		return
	var categories := [OfferingCatalog.KIND, TurretCatalog.KIND]
	for index in categories.size():
		var kind := String(categories[index])
		var button := TextureButton.new()
		button.name = "%sCategoryTab" % kind.capitalize()
		# Use the same warm, illustrated bookmark as the side menu so navigation
		# reads as part of one UI system instead of a separate grey tab treatment.
		button.texture_normal = load(BOOKMARK_TEXTURE) as Texture2D
		button.texture_hover = button.texture_normal
		button.texture_pressed = button.texture_normal
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.size = CATEGORY_TAB_SIZE
		button.position = CATEGORY_TAB_POSITIONS[index]
		# Scale from the page-side edge. The left tail expands into the reserved
		# gutter rather than into the parchment or past the native window.
		button.pivot_offset = Vector2(button.size.x, button.size.y * 0.5)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_category_layer.add_child(button)
		_category_buttons[kind] = button

		var label := Label.new()
		label.name = "CategoryLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(74.0, 8.0)
		label.size = Vector2(124.0, 66.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
		label.add_theme_constant_override("outline_size", 3)
		button.add_child(label)

		var hit_area := Control.new()
		hit_area.name = "%sCategoryTabHitArea" % kind.capitalize()
		hit_area.position = button.position
		hit_area.size = CATEGORY_TAB_SIZE
		hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
		hit_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit_area.mouse_entered.connect(_animate_category_tab_hover.bind(button, true))
		hit_area.mouse_exited.connect(_animate_category_tab_hover.bind(button, false))
		hit_area.gui_input.connect(_on_category_tab_gui_input.bind(kind, button, hit_area))
		_category_hit_layer.add_child(hit_area)
	_refresh_category_tabs()


func _configure_mouse_passthrough() -> void:
	# Keep the empty parts of the expanded transparent window click-through, while
	# retaining the complete shop page and the two tab shapes as interactive areas.
	# Window passthrough points are native pixels, while the Controls are measured
	# in design-space coordinates because the page uses content scaling.
	var native_scale := Vector2(
		float(maxi(1, size.x)) / float(WINDOW_SIZE.x),
		float(maxi(1, size.y)) / float(WINDOW_SIZE.y)
	)
	var native_page_origin := PAGE_ORIGIN * native_scale
	var native_window_size := Vector2(size)
	var tab_top: float = CATEGORY_TAB_POSITIONS[0].y
	var tab_bottom: float = CATEGORY_TAB_POSITIONS[CATEGORY_TAB_POSITIONS.size() - 1].y + CATEGORY_TAB_SIZE.y
	var native_tab_top := tab_top * native_scale.y
	var native_tab_bottom := tab_bottom * native_scale.y
	mouse_passthrough_polygon = PackedVector2Array([
		Vector2(native_page_origin.x, 0.0),
		Vector2(native_window_size.x, 0.0),
		Vector2(native_window_size.x, native_window_size.y),
		Vector2(native_page_origin.x, native_window_size.y),
		Vector2(native_page_origin.x, native_tab_bottom),
		Vector2(0.0, native_tab_bottom),
		Vector2(0.0, native_tab_top),
		Vector2(native_page_origin.x, native_tab_top)
	])


func _apply_texture_click_mask(button: TextureButton) -> void:
	if button == null or button.texture_normal == null:
		return
	var image := button.texture_normal.get_image()
	if image == null or image.is_empty():
		return
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.08)
	button.texture_click_mask = mask


func _refresh_category_tabs() -> void:
	for kind_value in _category_buttons.keys():
		var kind := String(kind_value)
		var button := _category_buttons.get(kind) as TextureButton
		if button == null:
			continue
		var label := button.get_node_or_null("CategoryLabel") as Label
		button.modulate = Color.WHITE
		button.tooltip_text = _get_category_label(kind)
		if label != null:
			label.text = _get_category_label(kind)
			label.add_theme_color_override("font_color", Color(0.97, 0.89, 0.66, 1.0))


func _get_category_label(kind: String) -> String:
	if kind == TurretCatalog.KIND:
		return "TOWERS" if _language == "en" else "防御塔"
	return "FOOD" if _language == "en" else "食物"


func _on_category_tab_pressed(kind: String, button: TextureButton) -> void:
	if kind == _active_category:
		_animate_category_tab_press(button)
		return
	_active_category = kind
	_page = 0
	_hide_info_panel()
	if _result_label != null:
		_result_label.visible = false
	_refresh_category_tabs()
	_refresh_page()
	_animate_category_tab_press(button)


func _on_category_tab_gui_input(
	event: InputEvent,
	kind: String,
	button: TextureButton,
	hit_area: Control
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_on_category_tab_pressed(kind, button)
	hit_area.accept_event()


func _animate_category_tab_hover(button: TextureButton, hovered: bool) -> void:
	if button == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (CATEGORY_TAB_HOVER_SCALE if hovered else 1.0), 0.10)


func _animate_category_tab_press(button: TextureButton) -> void:
	if button == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * 0.95, 0.05)
	tween.tween_property(button, "scale", Vector2.ONE * 1.025, 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)


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
		_page_root.add_child(slot)
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
	_page_root.add_child(left_arrow)

	var right_arrow := _make_arrow_button(1)
	right_arrow.position = Vector2(682.0, 904.0)
	_page_root.add_child(right_arrow)

	_page_label = Label.new()
	_page_label.name = "ShopPageIndicator"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.position = Vector2(902.0, 121.0)
	_page_label.size = Vector2(96.0, 44.0)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_label.add_theme_font_size_override("font_size", 26)
	_page_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58, 1.0))
	_page_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	_page_label.add_theme_constant_override("outline_size", 5)
	_page_root.add_child(_page_label)


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
	_page_root.add_child(close_button)


func _create_result_label() -> void:
	_result_label = Label.new()
	_result_label.name = "ShopPurchaseResult"
	_result_label.text = ""
	_result_label.visible = false
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.position = Vector2(360.0, 870.0)
	_result_label.size = Vector2(400.0, 32.0)
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.68, 1.0))
	_result_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	_result_label.add_theme_constant_override("outline_size", 3)
	_page_root.add_child(_result_label)


func _create_coin_balance() -> void:
	_coin_balance_label = Label.new()
	_coin_balance_label.name = "ShopGoldBalance"
	_coin_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_balance_label.position = Vector2(610.0, 170.0)
	_coin_balance_label.size = Vector2(355.0, 50.0)
	_coin_balance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_balance_label.add_theme_font_size_override("font_size", 28)
	_coin_balance_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34, 1.0))
	_coin_balance_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	_coin_balance_label.add_theme_constant_override("outline_size", 5)
	_page_root.add_child(_coin_balance_label)


func _create_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.name = "GoodInfoPanel"
	_info_panel.visible = false
	_info_panel.size = Vector2(292.0, 150.0)
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.z_index = 20
	_info_panel.add_theme_stylebox_override("panel", _make_info_panel_style())
	_page_root.add_child(_info_panel)

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
	_info_desc_label.add_theme_font_size_override("font_size", 16)
	_info_desc_label.add_theme_constant_override("line_spacing", 3)
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

	_refresh_category_tabs()
	var category_goods := _get_category_goods()
	var page_count := _get_page_count()
	_page = clampi(_page, 0, page_count - 1)

	if _page_label != null:
		_page_label.text = "%d/%d" % [_page + 1, page_count]
	_refresh_coin_balance()
	var page_start := _page * GOODS_PER_PAGE
	for slot_index in _slot_controls.size():
		var good_index := page_start + slot_index
		var has_good := good_index < category_goods.size()
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

		var good: Dictionary = category_goods[good_index]
		var display_good := _localize_good(good)
		var price := int(good.get("price", 0))
		var offering := OfferingCatalog.is_offering(good)
		var turret := TurretCatalog.is_turret(good)
		var tower_state := _get_turret_state(String(good.get("id", ""))) if turret else {}
		var tower_owned := turret and bool(tower_state.get("owned", false))
		var affordable := tower_owned or _coin_balance >= price
		var owned := int(_owned_counts.get(String(good.get("id", "")), 0))
		icon.texture = load(String(good.get("texture", ""))) as Texture2D
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.62, 0.62, 0.62, 0.9)
		name_label.text = String(display_good.get("name", "Item" if _language == "en" else "商品"))
		price_label.text = ("PRICE  %s" if _language == "en" else "价格 %s") % CurrencyDisplay.format_compact(price)
		price_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.68, 1.0) if affordable else Color(1.0, 0.58, 0.46, 1.0))
		if turret:
			owned_label.visible = true
			owned_label.text = _get_turret_card_status(good, tower_state)
			if tower_owned:
				price_label.text = _get_turret_durability_text(good, tower_state)
				price_label.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 1.0))
			continue
		# Food descriptions already explain duration and multiplier. Keep cards
		# visually quiet and reserve this small line for durable inventory only.
		owned_label.visible = has_good and not offering
		owned_label.text = ("OWNED %d" if _language == "en" else "已拥有 %d") % owned
	_coin_balance_dirty = false


func _refresh_coin_balance() -> void:
	if _coin_balance_label == null:
		return
	var balance_text := CurrencyDisplay.format_compact(_coin_balance)
	if _coin_balance_label.text != balance_text:
		_coin_balance_label.text = balance_text
		_fit_coin_balance_text(balance_text)
	_coin_balance_label.tooltip_text = CurrencyDisplay.get_conversion_tooltip(_coin_balance, _language)


func _refresh_visible_slot_affordability() -> void:
	# Coin collection can happen frequently while the shop is open. Do not reload
	# card textures or rebuild all metadata for every coin tick: only the visible
	# cards' affordability tint changes here. Tower state changes still use the
	# full refresh through set_turret_states().
	var category_goods := _get_category_goods()
	var page_start := _page * GOODS_PER_PAGE
	for slot_index in _slot_controls.size():
		var good_index := page_start + slot_index
		if good_index < 0 or good_index >= category_goods.size():
			continue
		var good: Dictionary = category_goods[good_index]
		var turret := TurretCatalog.is_turret(good)
		var tower_state := _get_turret_state(String(good.get("id", ""))) if turret else {}
		var tower_owned := turret and bool(tower_state.get("owned", false))
		var affordable := tower_owned or _coin_balance >= int(good.get("price", 0))
		var icon := _slot_icons[slot_index]
		var price_label := _slot_price_labels[slot_index]
		icon.modulate = Color.WHITE if affordable else Color(0.62, 0.62, 0.62, 0.9)
		if not tower_owned:
			price_label.add_theme_color_override(
				"font_color",
				Color(0.82, 1.0, 0.68, 1.0) if affordable else Color(1.0, 0.58, 0.46, 1.0)
			)


func _get_page_count() -> int:
	var needed_pages := int(ceil(float(_get_category_goods().size()) / float(GOODS_PER_PAGE)))
	return maxi(MIN_TOTAL_PAGES, needed_pages)


func _has_goods_in_category(category: String) -> bool:
	for good in _goods:
		if String(good.get("kind", "")) == category:
			return true
	return false


func _get_category_goods() -> Array[Dictionary]:
	var category_goods: Array[Dictionary] = []
	for good in _goods:
		if String(good.get("kind", "")) == _active_category:
			category_goods.append(good)
	return category_goods


func _get_turret_state(turret_id: String) -> Dictionary:
	var state_value: Variant = _turret_states.get(turret_id, {})
	return state_value.duplicate(true) if state_value is Dictionary else {}


func _get_turret_card_status(_good: Dictionary, state: Dictionary) -> String:
	if not bool(state.get("owned", false)):
		return "BUY" if _language == "en" else "购买"
	if bool(state.get("deployed", false)):
		return "RECALL" if _language == "en" else "收回"
	return "DEPLOY" if _language == "en" else "放下"


func _get_turret_durability_text(good: Dictionary, state: Dictionary) -> String:
	var maximum_health := maxf(1.0, float(good.get("max_health", 1.0)))
	var current_health := clampf(float(state.get("current_hp", maximum_health)), 0.0, maximum_health)
	return (
		"DURABILITY  %d / %d" if _language == "en" else "耐久  %d / %d"
	) % [roundi(current_health), roundi(maximum_health)]


func _localize_good(good: Dictionary) -> Dictionary:
	if TurretCatalog.is_turret(good):
		return TurretCatalog.localize(good, _language)
	return OfferingCatalog.localize(good, _language)


func _turn_page(direction: int) -> void:
	_page = posmod(_page + direction, _get_page_count())
	_hide_info_panel()
	_refresh_page()


func _on_slot_hovered(slot_index: int, hovered: bool) -> void:
	if not hovered:
		_hide_info_panel()
		return

	var category_goods := _get_category_goods()
	var good_index := (_page * GOODS_PER_PAGE) + slot_index
	if good_index < 0 or good_index >= category_goods.size():
		return

	var slot := _slot_controls[slot_index]
	var position_hint := slot.position + Vector2(slot.size.x - 18.0, 18.0)
	if position_hint.x + _info_panel.size.x > float(SHOP_PAGE_SIZE.x) - 32.0:
		position_hint.x = slot.position.x - _info_panel.size.x + 18.0
	_show_info_panel(category_goods[good_index], position_hint)


func _show_info_panel(good: Dictionary, panel_position: Vector2) -> void:
	if _info_panel == null:
		return

	var display_good := _localize_good(good)
	_info_name_label.text = String(display_good.get("name", "Item" if _language == "en" else "商品"))
	_info_desc_label.text = String(display_good.get("description", ""))
	if TurretCatalog.is_turret(good):
		var state := _get_turret_state(String(good.get("id", "")))
		var action := _get_turret_card_status(good, state)
		_info_price_label.text = "%s  ·  %s" % [_get_turret_durability_text(good, state), action]
	elif OfferingCatalog.is_offering(good):
		_info_price_label.text = ("PRICE: %s" if _language == "en" else "价格：%s") % CurrencyDisplay.format_compact(int(good.get("price", 0)))
	else:
		_info_price_label.text = ("PRICE: %s    OWNED: %d" if _language == "en" else "价格：%s    已拥有：%d") % [
			CurrencyDisplay.format_compact(int(good.get("price", 0))),
			int(_owned_counts.get(String(good.get("id", "")), 0))
		]
	_info_panel.position = Vector2(
		clampf(panel_position.x, 24.0, float(SHOP_PAGE_SIZE.x) - _info_panel.size.x - 24.0),
		clampf(panel_position.y, 24.0, float(SHOP_PAGE_SIZE.y) - _info_panel.size.y - 24.0)
	)
	_info_panel.visible = true


func _fit_coin_balance_text(text: String) -> void:
	if _coin_balance_label == null:
		return
	var font := _coin_balance_label.get_theme_font("font")
	var font_size := 28
	var available_width := _coin_balance_label.size.x - 8.0
	while font != null and font_size > 14:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= available_width:
			break
		font_size -= 1
	_coin_balance_label.add_theme_font_size_override("font_size", font_size)


static func _format_compact_number(value: float) -> String:
	var absolute := absf(value)
	if absolute < 1000.0:
		return "%d" % int(round(value))

	var units := [
		{"threshold": 1.0e15, "suffix": "Qa"},
		{"threshold": 1.0e12, "suffix": "T"},
		{"threshold": 1.0e9, "suffix": "B"},
		{"threshold": 1.0e6, "suffix": "M"},
		{"threshold": 1.0e3, "suffix": "K"}
	]
	for unit in units:
		var threshold := float(unit.get("threshold", 1.0))
		if absolute < threshold:
			continue
		var scaled := value / threshold
		if absf(scaled) >= 100.0:
			return "%.0f%s" % [scaled, String(unit.get("suffix", ""))]
		if absf(scaled) >= 10.0:
			return "%.1f%s" % [scaled, String(unit.get("suffix", ""))]
		return "%.2f%s" % [scaled, String(unit.get("suffix", ""))]
	return "%d" % int(round(value))


func _hide_info_panel() -> void:
	if _info_panel != null:
		_info_panel.visible = false


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		var category_goods := _get_category_goods()
		var good_index := (_page * GOODS_PER_PAGE) + slot_index
		if good_index < 0 or good_index >= category_goods.size():
			return

		purchase_requested.emit(String(category_goods[good_index].get("id", "")))
		_slot_controls[slot_index].accept_event()


func _on_arrow_pressed(direction: int, button: Control) -> void:
	_animate_control_press(button)
	_turn_page(direction)


func _center_window() -> void:
	var usable_rect := DisplayLayout.get_current_usable_rect(self)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, usable_rect)
	_configure_mouse_passthrough()


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
		var desired := DisplayServer.mouse_get_position() - _drag_offset
		position = DisplayLayout.clamp_position(
			desired,
			size,
			DisplayLayout.get_current_usable_rect(self)
		)
		_root.accept_event()


func _get_current_screen_rect() -> Rect2i:
	return DisplayLayout.get_current_usable_rect(self)
