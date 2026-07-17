extends Window

signal pet_deploy_requested(pet_id: String)
signal pet_rename_requested(pet_id: String, custom_name: String)

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const WINDOW_SIZE := Vector2i(1160, 850)
const DISPLAY_SIZE := Vector2(1128.0, 826.0)
const BOOK_POSITION := Vector2(16.0, 12.0)
const LEFT_GRID_POSITION := Vector2(164.0, 149.0)
const RIGHT_GRID_POSITION := Vector2(640.0, 149.0)
const SLOT_SIZE := Vector2(82.0, 82.0)
const GRID_COLUMNS := 4
const GRID_ROWS := 6
const GRID_H_SEPARATION := 12
const GRID_V_SEPARATION := 8
const SLOTS_PER_SIDE := GRID_COLUMNS * GRID_ROWS
const SLOTS_PER_PAGE := SLOTS_PER_SIDE * 2
const PET_ICON_SIZE := Vector2(72.0, 72.0)
const MIN_TOTAL_PAGES := 3

const INVENTORY_PANEL_TEXTURE := "res://assets/ui/inventory/inventory.png"
const ARROW_TEXTURE := "res://assets/ui/inventory/arrow.png"
const CROSS_TEXTURE := "res://assets/ui/inventory/cross.png"

var _root: Control
var _page_label: Label
var _slot_controls: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _empty_label: Label
var _detail_panel: PanelContainer
var _detail_icon: TextureRect
var _detail_name_edit: LineEdit
var _detail_desc_label: Label
var _detail_deploy_button: Button
var _detail_hint_label: Label
var _detail_close_button: Button
var _detail_slot_index := -1
var _page := 0
var _pets: Array[Dictionary] = []
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _language := "zh"


func setup(initial_pets: Array[Dictionary]) -> void:
	_pets = initial_pets.duplicate(true)
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


func add_pet(pet_id: String, custom_name := "") -> void:
	var entry := PetCatalog.make_inventory_entry(pet_id)
	if not custom_name.strip_edges().is_empty():
		entry["name"] = custom_name.strip_edges()
	_pets.append(entry)
	_refresh_page()


func remove_pet(pet_id: String) -> bool:
	for index in _pets.size():
		var entry := _pets[index]
		if String(entry.get("id", "")) == pet_id:
			_pets.remove_at(index)
			_refresh_page()
			return true

	return false


func set_pet_name(pet_id: String, custom_name: String) -> void:
	var next_name := custom_name.strip_edges().left(40)
	if next_name.is_empty():
		next_name = String(PetCatalog.get_definition(pet_id).get("name", pet_id))
	for index in _pets.size():
		var entry := _pets[index]
		if String(entry.get("id", "")) != pet_id:
			continue
		entry["name"] = next_name
		_pets[index] = entry
		if _detail_slot_index == index and _detail_name_edit != null and not _detail_name_edit.has_focus():
			_detail_name_edit.text = next_name
		break
	_refresh_page_icons_only()


func set_language(language_code: String) -> void:
	_language = "en" if language_code == "en" else "zh"
	title = "Inventory" if _language == "en" else "仓库"
	if _empty_label != null:
		_empty_label.text = "This page is empty" if _language == "en" else "这一页暂时空着"
	if _detail_name_edit != null:
		_detail_name_edit.placeholder_text = "Pet name" if _language == "en" else "宠物名字"
	if _detail_hint_label != null:
		_detail_hint_label.text = "Rename the pet here, then return it to the desktop" if _language == "en" else "可在这里改名，然后放回桌面"
	if _detail_close_button != null:
		_detail_close_button.text = "Close" if _language == "en" else "关闭"
	if _detail_deploy_button != null:
		_detail_deploy_button.text = "Return to desktop" if _language == "en" else "放回桌面"
	var left_arrow := get_node_or_null("InventoryRoot/InventoryArrow-1") as TextureButton
	var right_arrow := get_node_or_null("InventoryRoot/InventoryArrow1") as TextureButton
	if left_arrow != null:
		left_arrow.tooltip_text = "Previous page" if _language == "en" else "上一页"
	if right_arrow != null:
		right_arrow.tooltip_text = "Next page" if _language == "en" else "下一页"
	_refresh_page()


func _configure_window() -> void:
	name = "InventoryWindow"
	title = "仓库"
	size = WINDOW_SIZE
	borderless = true
	always_on_top = false
	unresizable = true
	transparent = true
	transparent_bg = true
	visible = false


func _create_content() -> void:
	_root = Control.new()
	_root.name = "InventoryRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var background := TextureRect.new()
	background.name = "InventoryBook"
	background.texture = load(INVENTORY_PANEL_TEXTURE) as Texture2D
	background.position = BOOK_POSITION
	background.size = DISPLAY_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	_create_slot_layer()
	_create_empty_label()
	_create_close_button()
	_create_page_controls()
	_create_detail_panel()


func _create_slot_layer() -> void:
	_slot_controls.clear()
	_slot_icons.clear()
	_root.add_child(_make_slot_grid("LeftInventorySlots", LEFT_GRID_POSITION, 0))
	_root.add_child(_make_slot_grid("RightInventorySlots", RIGHT_GRID_POSITION, SLOTS_PER_SIDE))


func _make_slot_grid(grid_name: String, grid_position: Vector2, slot_offset: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.position = grid_position
	grid.columns = GRID_COLUMNS
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)

	for index in SLOTS_PER_SIDE:
		var slot := Control.new()
		slot.name = "Slot%d" % (slot_offset + index)
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.gui_input.connect(_on_slot_gui_input.bind(slot_offset + index))
		grid.add_child(slot)
		_slot_controls.append(slot)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(center)

		var icon := TextureRect.new()
		icon.name = "PetIcon%d" % (slot_offset + index)
		icon.custom_minimum_size = PET_ICON_SIZE
		icon.size = PET_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		center.add_child(icon)
		_slot_icons.append(icon)

	return grid


func _create_empty_label() -> void:
	_empty_label = Label.new()
	_empty_label.text = "这一页暂时空着"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(438, 320)
	_empty_label.size = Vector2(280, 72)
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.14, 0.86))
	_root.add_child(_empty_label)


func _create_close_button() -> void:
	var close_button := TextureButton.new()
	close_button.name = "CloseInventory"
	close_button.texture_normal = load(CROSS_TEXTURE) as Texture2D
	close_button.texture_hover = close_button.texture_normal
	close_button.texture_pressed = close_button.texture_normal
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_SCALE
	close_button.size = Vector2(62, 62)
	close_button.position = Vector2(WINDOW_SIZE.x - 96, 28)
	close_button.pivot_offset = close_button.size * 0.5
	close_button.tooltip_text = "关闭仓库"
	close_button.mouse_entered.connect(_animate_control_hover.bind(close_button, true))
	close_button.mouse_exited.connect(_animate_control_hover.bind(close_button, false))
	close_button.pressed.connect(_animate_control_press.bind(close_button))
	close_button.pressed.connect(_close_window)
	_root.add_child(close_button)


func _create_page_controls() -> void:
	var left_arrow := _make_arrow_button(-1)
	left_arrow.position = Vector2(400, 754)
	left_arrow.scale = Vector2(-1.0, 1.0)
	_root.add_child(left_arrow)

	var right_arrow := _make_arrow_button(1)
	right_arrow.position = Vector2(692, 754)
	_root.add_child(right_arrow)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.position = Vector2(480, 754)
	_page_label.size = Vector2(200, 68)
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_label.add_theme_font_size_override("font_size", 32)
	_page_label.add_theme_color_override("font_color", Color(0.94, 0.78, 0.48, 1.0))
	_page_label.add_theme_color_override("font_outline_color", Color(0.08, 0.035, 0.045, 1.0))
	_page_label.add_theme_constant_override("outline_size", 4)
	_root.add_child(_page_label)


func _create_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "PetDetailPanel"
	_detail_panel.visible = false
	_detail_panel.position = Vector2(392.0, 218.0)
	_detail_panel.size = Vector2(376.0, 312.0)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_panel.add_theme_stylebox_override("panel", _make_detail_panel_style())
	_root.add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_detail_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	content.add_child(top)

	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(96, 96)
	top.add_child(icon_box)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(88, 88)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(_detail_icon)

	var top_text := VBoxContainer.new()
	top_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_text.add_theme_constant_override("separation", 6)
	top.add_child(top_text)

	_detail_name_edit = LineEdit.new()
	_detail_name_edit.placeholder_text = "宠物名字"
	_detail_name_edit.max_length = 40
	_detail_name_edit.custom_minimum_size = Vector2(220, 36)
	_detail_name_edit.add_theme_stylebox_override("normal", _make_detail_name_style(false))
	_detail_name_edit.add_theme_stylebox_override("focus", _make_detail_name_style(true))
	_detail_name_edit.add_theme_font_size_override("font_size", 18)
	_detail_name_edit.add_theme_color_override("font_color", Color(0.08, 0.035, 0.035, 1.0))
	_detail_name_edit.add_theme_color_override("font_placeholder_color", Color(0.32, 0.18, 0.14, 0.78))
	_detail_name_edit.add_theme_color_override("font_selected_color", Color(0.98, 0.9, 0.7, 1.0))
	_detail_name_edit.add_theme_color_override("selection_color", Color(0.28, 0.11, 0.1, 0.9))
	_detail_name_edit.add_theme_color_override("caret_color", Color(0.12, 0.04, 0.035, 1.0))
	_detail_name_edit.text_changed.connect(_on_detail_name_changed)
	top_text.add_child(_detail_name_edit)

	_detail_hint_label = Label.new()
	_detail_hint_label.text = "可在这里改名，然后放回桌面"
	_detail_hint_label.add_theme_font_size_override("font_size", 13)
	_detail_hint_label.add_theme_color_override("font_color", Color(0.34, 0.25, 0.23, 0.88))
	top_text.add_child(_detail_hint_label)

	_detail_desc_label = Label.new()
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.custom_minimum_size = Vector2(320, 88)
	_detail_desc_label.add_theme_font_size_override("font_size", 16)
	_detail_desc_label.add_theme_color_override("font_color", Color(0.18, 0.11, 0.13, 1.0))
	content.add_child(_detail_desc_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)

	_detail_close_button = Button.new()
	_detail_close_button.text = "关闭"
	_detail_close_button.custom_minimum_size = Vector2(86, 34)
	_detail_close_button.pressed.connect(_hide_detail_panel)
	actions.add_child(_detail_close_button)

	_detail_deploy_button = Button.new()
	_detail_deploy_button.text = "放回桌面"
	_detail_deploy_button.custom_minimum_size = Vector2(118, 34)
	_detail_deploy_button.pressed.connect(_deploy_detail_pet)
	actions.add_child(_detail_deploy_button)


func _make_detail_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.76, 0.58, 0.96)
	style.border_color = Color(0.18, 0.1, 0.11, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_detail_name_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.87, 0.68, 0.96)
	style.border_color = Color(0.24, 0.13, 0.14, 0.95) if focused else Color(0.38, 0.25, 0.2, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _make_arrow_button(direction: int) -> TextureButton:
	var button := TextureButton.new()
	button.name = "InventoryArrow%s" % direction
	button.texture_normal = load(ARROW_TEXTURE) as Texture2D
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.size = Vector2(68, 68)
	button.pivot_offset = button.size * 0.5
	button.tooltip_text = "上一页" if direction < 0 else "下一页"
	button.mouse_entered.connect(_animate_control_hover.bind(button, true))
	button.mouse_exited.connect(_animate_control_hover.bind(button, false))
	button.pressed.connect(_on_arrow_pressed.bind(direction, button))
	return button


func _refresh_page() -> void:
	var page_count := _get_page_count()
	_page = clampi(_page, 0, page_count - 1)

	if _page_label != null:
		_page_label.text = (
			"PAGE %d / %d" % [_page + 1, page_count]
			if _language == "en"
			else "第 %d / %d 页" % [_page + 1, page_count]
		)

	var page_start := _page * SLOTS_PER_PAGE
	var pet_count_on_page := 0
	for slot_index in _slot_icons.size():
		var pet_index := page_start + slot_index
		var slot := _slot_controls[slot_index]
		var icon := _slot_icons[slot_index]
		var has_pet := pet_index < _pets.size()
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if has_pet else Control.MOUSE_FILTER_IGNORE
		slot.tooltip_text = ""
		icon.visible = has_pet
		if has_pet:
			var pet_data := _pets[pet_index]
			icon.texture = PetCatalog.make_icon_texture(String(pet_data.get("texture", "")))
			slot.tooltip_text = ("View: %s" if _language == "en" else "查看：%s") % String(pet_data.get("name", pet_data.get("id", "")))
			pet_count_on_page += 1

	if _empty_label != null:
		_empty_label.visible = pet_count_on_page == 0
	if _detail_panel != null and _detail_panel.visible:
		_hide_detail_panel()


func _get_page_count() -> int:
	var needed_pages := int(ceil(float(_pets.size()) / float(SLOTS_PER_PAGE)))
	return maxi(MIN_TOTAL_PAGES, needed_pages)


func _turn_page(direction: int) -> void:
	_page = posmod(_page + direction, _get_page_count())
	_refresh_page()

	if _root != null:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_root, "position:x", float(direction) * -8.0, 0.06)
		tween.tween_property(_root, "position:x", 0.0, 0.12)


func _center_window() -> void:
	var screen_rect := _get_current_screen_rect()
	position = Vector2i(
		maxi(screen_rect.position.x, screen_rect.position.x + int((screen_rect.size.x - WINDOW_SIZE.x) * 0.5)),
		maxi(screen_rect.position.y, screen_rect.position.y + int((screen_rect.size.y - WINDOW_SIZE.y) * 0.5))
	)


func _close_window() -> void:
	visible = false
	_dragging = false


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


func _on_arrow_pressed(direction: int, button: Control) -> void:
	_animate_control_press(button)
	_turn_page(direction)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		var pet_index := (_page * SLOTS_PER_PAGE) + slot_index
		if pet_index < 0 or pet_index >= _pets.size():
			return

		var pet_data := _pets[pet_index]
		var pet_id := String(pet_data.get("id", ""))
		if not pet_id.is_empty():
			_show_detail_panel(pet_index)
		if slot_index >= 0 and slot_index < _slot_controls.size():
			_slot_controls[slot_index].accept_event()


func _show_detail_panel(pet_index: int) -> void:
	if pet_index < 0 or pet_index >= _pets.size() or _detail_panel == null:
		return

	_detail_slot_index = pet_index
	var entry := _pets[pet_index]
	var pet_id := String(entry.get("id", ""))
	var pet_data := PetCatalog.get_definition(pet_id)
	_detail_icon.texture = PetCatalog.make_icon_texture(String(entry.get("texture", pet_data.get("icon", ""))), 6)
	_detail_name_edit.text = String(entry.get("name", pet_data.get("name", pet_id)))
	var rarity_stars := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
	_detail_desc_label.text = ("Stars  %s\nAge  %s\nPersonality  %s" if _language == "en" else "星级  %s\n年龄  %s\n性格  %s") % [
		"★".repeat(rarity_stars),
		String(pet_data.get("age_text", pet_data.get("age", "不详"))),
		String(pet_data.get("personality", "不详"))
	]
	_detail_panel.visible = true


func _hide_detail_panel() -> void:
	if _detail_panel != null:
		_detail_panel.visible = false
	_detail_slot_index = -1


func _on_detail_name_changed(new_text: String) -> void:
	if _detail_slot_index < 0 or _detail_slot_index >= _pets.size():
		return

	var entry := _pets[_detail_slot_index]
	var pet_id := String(entry.get("id", ""))
	var custom_name := new_text.strip_edges().left(40)
	entry["name"] = custom_name
	_pets[_detail_slot_index] = entry
	if not pet_id.is_empty():
		pet_rename_requested.emit(pet_id, custom_name)
	_refresh_page_icons_only()


func _refresh_page_icons_only() -> void:
	var page_start := _page * SLOTS_PER_PAGE
	for slot_index in _slot_icons.size():
		var pet_index := page_start + slot_index
		if pet_index >= _pets.size():
			continue
		var entry := _pets[pet_index]
		var pet_id := String(entry.get("id", ""))
		var display_name := String(entry.get("name", "")).strip_edges()
		if display_name.is_empty():
			display_name = String(PetCatalog.get_definition(pet_id).get("name", pet_id))
		_slot_controls[slot_index].tooltip_text = ("View: %s" if _language == "en" else "查看：%s") % display_name


func _deploy_detail_pet() -> void:
	if _detail_slot_index < 0 or _detail_slot_index >= _pets.size():
		return

	var entry := _pets[_detail_slot_index]
	var pet_id := String(entry.get("id", ""))
	if pet_id.is_empty():
		return

	pet_deploy_requested.emit(pet_id)
	_hide_detail_panel()


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
