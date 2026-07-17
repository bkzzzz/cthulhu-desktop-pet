extends Window

const WINDOW_MAX_SIZE := Vector2i(760, 680)
const WINDOW_SCREEN_MARGIN := 24

var _root: PanelContainer
var _entry_list: VBoxContainer
var _status_label: Label
var _empty_label: Label
var _title_label: Label
var _close_button: Button
var _description_label: Label
var _scroller: ScrollContainer
var _entries: Array[Dictionary] = []
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _language := "zh"


func setup(initial_entries: Array[Dictionary]) -> void:
	_entries = initial_entries.duplicate(true)
	_configure_window()
	_create_content()
	_center_window()
	_refresh_entries()


func open_window() -> void:
	_refresh_entries()
	_center_window()
	if visible:
		grab_focus()
		return

	visible = true
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_root.scale = Vector2(0.97, 0.97)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate", Color.WHITE, 0.16)
	tween.parallel().tween_property(_root, "scale", Vector2.ONE, 0.16)
	call_deferred("_scroll_to_latest")


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries.duplicate(true)
	if _entry_list != null:
		_refresh_entries()


func add_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	_entries.push_front(entry.duplicate(true))
	if _entries.size() > 80:
		_entries.resize(80)
	if visible:
		_refresh_entries()


func set_language(language_code: String) -> void:
	_language = "en" if language_code == "en" else "zh"
	title = "Cult News Archive" if _language == "en" else "教团新闻档案"
	if _title_label != null:
		_title_label.text = "CULT NEWS ARCHIVE" if _language == "en" else "教团新闻档案"
	if _close_button != null:
		_close_button.text = "Close" if _language == "en" else "关闭"
	if _description_label != null:
		_description_label.text = (
			"Tracking the cult's expansion from one city and one ecosystem to the stars beyond."
			if _language == "en"
			else "持续记录教团扩张与理性污染：从一座城市、整个生态圈，直至星辰之间。"
		)
	_refresh_entries()


func _configure_window() -> void:
	name = "NewsWindow"
	title = "教团新闻档案"
	size = _get_fitted_window_size()
	borderless = true
	always_on_top = false
	unresizable = true
	transparent = true
	transparent_bg = true
	visible = false
	close_requested.connect(_close_window)


func _create_content() -> void:
	_root = PanelContainer.new()
	_root.name = "NewsArchiveRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.pivot_offset = Vector2(size) * 0.5
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_theme_stylebox_override("panel", _make_window_style())
	var theme := Theme.new()
	theme.default_font = _make_readable_font()
	_root.theme = theme
	add_child(_root)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 26)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 26)
	outer_margin.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(outer_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	outer_margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 46.0)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	_title_label = Label.new()
	_title_label.text = "教团新闻档案"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.91, 0.82, 0.52, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.035, 1.0))
	_title_label.add_theme_constant_override("outline_size", 4)
	header.add_child(_title_label)

	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.56, 0.82, 0.62, 1.0))
	header.add_child(_status_label)

	_close_button = Button.new()
	_close_button.text = "关闭"
	_close_button.custom_minimum_size = Vector2(72.0, 36.0)
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.add_theme_font_size_override("font_size", 15)
	_close_button.pressed.connect(_close_window)
	header.add_child(_close_button)

	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", _make_separator_style())
	content.add_child(divider)

	_description_label = Label.new()
	_description_label.text = "持续记录教团扩张与理性污染：从一座城市、整个生态圈，直至星辰之间。"
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(0.0, 42.0)
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.add_theme_color_override("font_color", Color(0.67, 0.72, 0.59, 1.0))
	content.add_child(_description_label)

	_scroller = ScrollContainer.new()
	_scroller.name = "NewsHistoryScroll"
	_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroller.add_theme_stylebox_override("panel", _make_scroll_style())
	content.add_child(_scroller)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 8)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_right", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 8)
	_scroller.add_child(scroll_margin)

	_entry_list = VBoxContainer.new()
	_entry_list.name = "NewsEntries"
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", 8)
	scroll_margin.add_child(_entry_list)

	_empty_label = Label.new()
	_empty_label.text = "暂无新消息，记者正在核对人数。"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(0.0, 160.0)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.52, 0.86))
	_entry_list.add_child(_empty_label)


func _refresh_entries() -> void:
	if _entry_list == null:
		return
	for child in _entry_list.get_children():
		_entry_list.remove_child(child)
		child.queue_free()

	if _entries.is_empty():
		_empty_label = Label.new()
		_empty_label.text = "No new reports. The newsroom is checking its figures." if _language == "en" else "暂无新消息，记者正在核对人数。"
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.custom_minimum_size = Vector2(0.0, 160.0)
		_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_label.add_theme_font_size_override("font_size", 18)
		_empty_label.add_theme_color_override("font_color", Color(0.52, 0.62, 0.52, 0.86))
		_entry_list.add_child(_empty_label)
	else:
		_empty_label = null
		for index in _entries.size():
			_entry_list.add_child(_make_entry_row(_entries[index], index))

	if _status_label != null:
		_status_label.text = (
			"● LIVE  ·  %d REPORTS" % _entries.size()
			if _language == "en"
			else "● 实时监听  ·  %d 条" % _entries.size()
		)
	call_deferred("_scroll_to_latest")


func _make_entry_row(entry: Dictionary, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "NewsEntry%d" % int(entry.get("id", index))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _make_entry_style(index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	row.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	margin.add_child(body)

	var meta := HBoxContainer.new()
	body.add_child(meta)

	var category := String(entry.get("category", "异闻"))
	var category_label := Label.new()
	category_label.text = "【%s】" % _get_localized_category(category)
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_label.add_theme_font_size_override("font_size", 16)
	category_label.add_theme_color_override("font_color", _get_category_color(category))
	meta.add_child(category_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(spacer)

	var time_label := Label.new()
	var clock_text := String(entry.get("time_text", "")).strip_edges()
	time_label.text = clock_text if not clock_text.is_empty() else ("ARCHIVE" if _language == "en" else "旧闻")
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color(0.48, 0.58, 0.51, 1.0))
	meta.add_child(time_label)

	var headline := Label.new()
	headline.text = String(entry.get("headline", ""))
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.custom_minimum_size = Vector2(0.0, 42.0)
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_theme_font_size_override("font_size", 20)
	headline.add_theme_color_override("font_color", Color(0.83, 0.88, 0.74, 1.0))
	headline.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.02, 1.0))
	headline.add_theme_constant_override("outline_size", 2)
	body.add_child(headline)
	return row


func _make_readable_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"PingFang SC",
		"Noto Sans CJK SC",
		"Noto Sans SC"
	])
	font.font_weight = 600
	return font


func _scroll_to_latest() -> void:
	if _scroller != null:
		_scroller.scroll_vertical = 0


func _close_window() -> void:
	visible = false
	_dragging = false


func _center_window() -> void:
	var screen_rect := _get_current_screen_usable_rect()
	size = _get_fitted_window_size()
	if _root != null:
		_root.pivot_offset = Vector2(size) * 0.5
	position = Vector2i(
		screen_rect.position.x + maxi(0, int((screen_rect.size.x - size.x) * 0.5)),
		screen_rect.position.y + maxi(0, int((screen_rect.size.y - size.y) * 0.5))
	)


func _get_fitted_window_size() -> Vector2i:
	var usable_rect := _get_current_screen_usable_rect()
	return fit_window_size(usable_rect.size)


static func fit_window_size(usable_size: Vector2i) -> Vector2i:
	if usable_size.x <= 0 or usable_size.y <= 0:
		return WINDOW_MAX_SIZE
	return Vector2i(
		maxi(1, mini(WINDOW_MAX_SIZE.x, usable_size.x - (WINDOW_SCREEN_MARGIN * 2))),
		maxi(1, mini(WINDOW_MAX_SIZE.y, usable_size.y - (WINDOW_SCREEN_MARGIN * 2)))
	)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			if _dragging:
				_drag_offset = DisplayServer.mouse_get_position() - position
	elif event is InputEventMouseMotion and _dragging:
		position = DisplayServer.mouse_get_position() - _drag_offset


func _get_current_screen_usable_rect() -> Rect2i:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_usable_rect(screen)


func _get_category_color(category: String) -> Color:
	match category:
		"公告":
			return Color(0.86, 0.78, 0.52, 1.0)
		"传播":
			return Color(0.48, 0.86, 0.68, 1.0)
		"信仰":
			return Color(0.68, 0.91, 0.46, 1.0)
		"宠物":
			return Color(0.74, 0.72, 0.94, 1.0)
		"教团":
			return Color(0.83, 0.62, 0.52, 1.0)
		_:
			return Color(0.66, 0.78, 0.72, 1.0)


func _get_localized_category(category: String) -> String:
	if _language != "en":
		return category
	var names := {
		"公告": "NOTICE",
		"传播": "SPREAD",
		"信仰": "FAITH",
		"宠物": "PETS",
		"教团": "CULT",
		"异闻": "REPORT"
	}
	return String(names.get(category, category))


func _make_window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.045, 0.97)
	style.border_color = Color(0.35, 0.56, 0.38, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 7.0)
	return style


func _make_scroll_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.025, 0.022, 0.72)
	style.border_color = Color(0.18, 0.32, 0.23, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _make_entry_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.105, 0.082, 0.88) if index % 2 == 0 else Color(0.043, 0.084, 0.069, 0.88)
	style.border_color = Color(0.18, 0.32, 0.23, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _make_separator_style() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = Color(0.34, 0.5, 0.32, 0.72)
	style.thickness = 1
	return style
