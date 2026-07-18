extends Window

signal activity_range_changed(range_mode: String)
signal language_changed(language_code: String)
signal quit_requested
signal debug_economy_requested(faith_points: float, gold_coins: int)
signal debug_event_requested(event_type: String)

const WINDOW_SIZE := Vector2i(720, 720)
const BACKGROUND_TEXTURE := "res://assets/ui/setting/settingUI.png"
const VALID_RANGE_MODES := ["full", "right", "left"]
const VALID_LANGUAGES := ["zh", "en"]

var _activity_range := "full"
var _language := "zh"
var _session_seconds := 0.0
var _total_seconds := 0.0
var _title_label: Label
var _range_label: Label
var _range_options: OptionButton
var _language_label: Label
var _language_options: OptionButton
var _session_title_label: Label
var _session_value_label: Label
var _total_title_label: Label
var _total_value_label: Label
var _exit_button: Button
var _close_button: Button
var _root: Control
var _debug_button: Button
var _debug_panel: PanelContainer
var _debug_title_label: Label
var _debug_hint_label: Label
var _debug_faith_label: Label
var _debug_coin_label: Label
var _debug_faith_spin: SpinBox
var _debug_coin_spin: SpinBox
var _debug_apply_button: Button
var _debug_event_title_label: Label
var _debug_pilgrimage_button: Button
var _debug_battle_button: Button
var _debug_back_button: Button
var _updating_controls := false
var _dragging := false
var _drag_offset := Vector2i.ZERO


func setup(activity_range: String, language_code: String) -> void:
	_activity_range = _sanitize_range(activity_range)
	_language = _sanitize_language(language_code)
	_configure_window()
	_create_content()
	_apply_language()
	_sync_option_selection()
	_center_window()


func open_window() -> void:
	_center_window()
	visible = true


func close_window() -> void:
	visible = false
	_dragging = false
	if _debug_panel != null:
		_debug_panel.visible = false


func refresh_runtime(session_seconds: float, total_seconds: float) -> void:
	_session_seconds = maxf(0.0, session_seconds)
	_total_seconds = maxf(_session_seconds, total_seconds)
	if _session_value_label != null:
		_session_value_label.text = _format_duration(_session_seconds)
	if _total_value_label != null:
		_total_value_label.text = _format_duration(_total_seconds)


func refresh_debug_values(faith_points: float, gold_coins: int) -> void:
	if _debug_faith_spin != null:
		_debug_faith_spin.value = clampf(faith_points, 0.0, _debug_faith_spin.max_value)
	if _debug_coin_spin != null:
		_debug_coin_spin.value = clampf(float(gold_coins), 0.0, _debug_coin_spin.max_value)


func set_activity_range(activity_range: String) -> void:
	_activity_range = _sanitize_range(activity_range)
	_sync_option_selection()


func set_language(language_code: String) -> void:
	_language = _sanitize_language(language_code)
	_apply_language()
	_sync_option_selection()


func get_activity_range() -> String:
	return _activity_range


func get_language() -> String:
	return _language


func _configure_window() -> void:
	name = "SettingsWindow"
	title = "设置"
	size = WINDOW_SIZE
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	unresizable = true
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	visible = false
	close_requested.connect(close_window)


func _create_content() -> void:
	_root = Control.new()
	_root.name = "SettingsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var background := TextureRect.new()
	background.name = "SettingsBackground"
	background.texture = load(BACKGROUND_TEXTURE) as Texture2D
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.position = Vector2(142.0, 105.0)
	panel.size = Vector2(436.0, 510.0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	_title_label = _make_label("设置", 34, Color(0.94, 0.84, 0.62, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.custom_minimum_size = Vector2(360.0, 48.0)
	content.add_child(_title_label)

	var range_row := _make_setting_row()
	content.add_child(range_row)
	_range_label = _make_label("宠物活动范围", 19, Color(0.82, 0.86, 0.72, 1.0))
	_range_label.custom_minimum_size = Vector2(164.0, 42.0)
	range_row.add_child(_range_label)
	_range_options = _make_option_button()
	_range_options.item_selected.connect(_on_range_selected)
	range_row.add_child(_range_options)

	var language_row := _make_setting_row()
	content.add_child(language_row)
	_language_label = _make_label("语言", 19, Color(0.82, 0.86, 0.72, 1.0))
	_language_label.custom_minimum_size = Vector2(164.0, 42.0)
	language_row.add_child(_language_label)
	_language_options = _make_option_button()
	_language_options.item_selected.connect(_on_language_selected)
	language_row.add_child(_language_options)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 8)
	content.add_child(divider)

	var session_row := _make_stat_row()
	content.add_child(session_row)
	_session_title_label = _make_label("本次运行时长", 18, Color(0.72, 0.78, 0.68, 1.0))
	_session_title_label.custom_minimum_size = Vector2(190.0, 36.0)
	session_row.add_child(_session_title_label)
	_session_value_label = _make_label(_format_duration(0.0), 21, Color(0.94, 0.84, 0.56, 1.0))
	_session_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_session_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_row.add_child(_session_value_label)

	var total_row := _make_stat_row()
	content.add_child(total_row)
	_total_title_label = _make_label("总运行时长", 18, Color(0.72, 0.78, 0.68, 1.0))
	_total_title_label.custom_minimum_size = Vector2(190.0, 36.0)
	total_row.add_child(_total_title_label)
	_total_value_label = _make_label(_format_duration(0.0), 21, Color(0.94, 0.84, 0.56, 1.0))
	_total_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(_total_value_label)

	_debug_button = Button.new()
	_debug_button.text = "调试选项"
	_debug_button.custom_minimum_size = Vector2(360.0, 38.0)
	_debug_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_debug_button.add_theme_font_size_override("font_size", 18)
	_debug_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.08, 0.07, 0.92), Color(0.42, 0.52, 0.38, 0.9)))
	_debug_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.14, 0.10, 0.98), Color(0.68, 0.76, 0.46, 1.0)))
	_debug_button.pressed.connect(_open_debug_panel)
	content.add_child(_debug_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	_exit_button = Button.new()
	_exit_button.text = "退出游戏"
	_exit_button.custom_minimum_size = Vector2(360.0, 52.0)
	_exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_exit_button.add_theme_font_size_override("font_size", 21)
	_exit_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.22, 0.10, 0.09, 0.96), Color(0.72, 0.36, 0.24, 1.0)))
	_exit_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.34, 0.14, 0.10, 0.98), Color(0.92, 0.58, 0.34, 1.0)))
	_exit_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.14, 0.07, 0.06, 1.0), Color(0.94, 0.68, 0.42, 1.0)))
	_exit_button.add_theme_color_override("font_color", Color(0.98, 0.84, 0.66, 1.0))
	_exit_button.pressed.connect(func() -> void: quit_requested.emit())
	content.add_child(_exit_button)

	_close_button = Button.new()
	_close_button.name = "CloseSettings"
	_close_button.text = "×"
	_close_button.position = Vector2(591.0, 76.0)
	_close_button.size = Vector2(54.0, 48.0)
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.add_theme_font_size_override("font_size", 28)
	_close_button.add_theme_color_override("font_color", Color(0.92, 0.82, 0.62, 1.0))
	_close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_close_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.18, 0.12, 0.08, 0.72), Color(0.72, 0.58, 0.36, 0.72)))
	_close_button.pressed.connect(close_window)
	_root.add_child(_close_button)
	_create_debug_panel()


func _create_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.position = Vector2(142.0, 105.0)
	_debug_panel.size = Vector2(436.0, 510.0)
	_debug_panel.visible = false
	_debug_panel.z_index = 20
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_debug_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_debug_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_debug_title_label = _make_label("调试选项", 28, Color(0.94, 0.84, 0.62, 1.0))
	_debug_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_title_label)
	_debug_hint_label = _make_label("数值会立即写入当前存档", 14, Color(0.68, 0.74, 0.66, 1.0))
	_debug_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_hint_label)

	var faith_row := _make_setting_row()
	_debug_faith_label = _make_label("信仰值", 18, Color(0.82, 0.86, 0.72, 1.0))
	_debug_faith_label.custom_minimum_size = Vector2(120.0, 42.0)
	faith_row.add_child(_debug_faith_label)
	_debug_faith_spin = _make_debug_spin_box()
	faith_row.add_child(_debug_faith_spin)
	content.add_child(faith_row)

	var coin_row := _make_setting_row()
	_debug_coin_label = _make_label("金币", 18, Color(0.82, 0.86, 0.72, 1.0))
	_debug_coin_label.custom_minimum_size = Vector2(120.0, 42.0)
	coin_row.add_child(_debug_coin_label)
	_debug_coin_spin = _make_debug_spin_box()
	coin_row.add_child(_debug_coin_spin)
	content.add_child(coin_row)

	_debug_apply_button = Button.new()
	_debug_apply_button.text = "应用数值"
	_debug_apply_button.custom_minimum_size = Vector2(360.0, 38.0)
	_debug_apply_button.pressed.connect(_on_debug_apply_pressed)
	content.add_child(_debug_apply_button)

	var divider := HSeparator.new()
	content.add_child(divider)
	_debug_event_title_label = _make_label("立即触发事件", 17, Color(0.82, 0.86, 0.72, 1.0))
	_debug_event_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_event_title_label)
	var event_row := HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 10)
	content.add_child(event_row)
	_debug_pilgrimage_button = Button.new()
	_debug_pilgrimage_button.text = "触发朝拜"
	_debug_pilgrimage_button.custom_minimum_size = Vector2(174.0, 40.0)
	_debug_pilgrimage_button.pressed.connect(_on_debug_event_pressed.bind("pilgrimage"))
	event_row.add_child(_debug_pilgrimage_button)
	_debug_battle_button = Button.new()
	_debug_battle_button.text = "触发战斗"
	_debug_battle_button.custom_minimum_size = Vector2(174.0, 40.0)
	_debug_battle_button.pressed.connect(_on_debug_event_pressed.bind("battle"))
	event_row.add_child(_debug_battle_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	_debug_back_button = Button.new()
	_debug_back_button.text = "返回设置"
	_debug_back_button.custom_minimum_size = Vector2(360.0, 38.0)
	_debug_back_button.pressed.connect(_close_debug_panel)
	content.add_child(_debug_back_button)


func _make_debug_spin_box() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = 1_000_000_000_000_000.0
	spin.step = 1.0
	spin.rounded = true
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(230.0, 42.0)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", 17)
	return spin


func _open_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = true


func _close_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = false


func _on_debug_apply_pressed() -> void:
	if _debug_faith_spin == null or _debug_coin_spin == null:
		return
	debug_economy_requested.emit(_debug_faith_spin.value, int(round(_debug_coin_spin.value)))


func _on_debug_event_pressed(event_type: String) -> void:
	if event_type not in ["pilgrimage", "battle"]:
		return
	debug_event_requested.emit(event_type)
	close_window()


func _make_setting_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(360.0, 46.0)
	row.add_theme_constant_override("separation", 10)
	return row


func _make_stat_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(360.0, 38.0)
	row.add_theme_constant_override("separation", 8)
	return row


func _make_option_button() -> OptionButton:
	var options := OptionButton.new()
	options.custom_minimum_size = Vector2(190.0, 42.0)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	options.add_theme_font_size_override("font_size", 17)
	options.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68, 1.0))
	options.add_theme_stylebox_override("normal", _make_button_style(Color(0.04, 0.055, 0.05, 0.94), Color(0.46, 0.54, 0.38, 0.9)))
	options.add_theme_stylebox_override("hover", _make_button_style(Color(0.08, 0.10, 0.075, 0.98), Color(0.68, 0.68, 0.42, 1.0)))
	return options


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.012, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.018, 0.016, 0.88)
	style.border_color = Color(0.44, 0.46, 0.34, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


func _apply_language() -> void:
	if _title_label == null:
		return
	var english := _language == "en"
	title = "Settings" if english else "设置"
	_title_label.text = "SETTINGS" if english else "设置"
	_range_label.text = "Pet activity area" if english else "宠物活动范围"
	_language_label.text = "Language" if english else "语言"
	_session_title_label.text = "Current session" if english else "本次运行时长"
	_total_title_label.text = "Total play time" if english else "总运行时长"
	_exit_button.text = "EXIT GAME" if english else "退出游戏"
	if _debug_button != null:
		_debug_button.text = "DEBUG OPTIONS" if english else "调试选项"
	if _debug_title_label != null:
		_debug_title_label.text = "DEBUG OPTIONS" if english else "调试选项"
	if _debug_hint_label != null:
		_debug_hint_label.text = "Values are written to the current save immediately" if english else "数值会立即写入当前存档"
	if _debug_faith_label != null:
		_debug_faith_label.text = "Faith" if english else "信仰值"
	if _debug_coin_label != null:
		_debug_coin_label.text = "Gold" if english else "金币"
	if _debug_apply_button != null:
		_debug_apply_button.text = "APPLY VALUES" if english else "应用数值"
	if _debug_event_title_label != null:
		_debug_event_title_label.text = "START EVENT NOW" if english else "立即触发事件"
	if _debug_pilgrimage_button != null:
		_debug_pilgrimage_button.text = "START PILGRIMAGE" if english else "触发朝拜"
	if _debug_battle_button != null:
		_debug_battle_button.text = "START BATTLE" if english else "触发战斗"
	if _debug_back_button != null:
		_debug_back_button.text = "BACK TO SETTINGS" if english else "返回设置"

	_updating_controls = true
	_range_options.clear()
	_range_options.add_item("Entire desktop" if english else "全桌面", 0)
	_range_options.add_item("Right side" if english else "靠右", 1)
	_range_options.add_item("Left side" if english else "靠左", 2)
	_language_options.clear()
	_language_options.add_item("中文", 0)
	_language_options.add_item("English", 1)
	_updating_controls = false


func _sync_option_selection() -> void:
	if _range_options == null or _language_options == null:
		return
	_updating_controls = true
	_range_options.select(VALID_RANGE_MODES.find(_activity_range))
	_language_options.select(VALID_LANGUAGES.find(_language))
	_updating_controls = false


func _on_range_selected(index: int) -> void:
	if _updating_controls:
		return
	_activity_range = VALID_RANGE_MODES[clampi(index, 0, VALID_RANGE_MODES.size() - 1)]
	activity_range_changed.emit(_activity_range)


func _on_language_selected(index: int) -> void:
	if _updating_controls:
		return
	_language = VALID_LANGUAGES[clampi(index, 0, VALID_LANGUAGES.size() - 1)]
	_apply_language()
	_sync_option_selection()
	language_changed.emit(_language)


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = mouse_event.pressed
		if _dragging:
			_drag_offset = DisplayServer.mouse_get_position() - position
		return
	if event is InputEventMouseMotion and _dragging:
		position = DisplayServer.mouse_get_position() - _drag_offset


func _center_window() -> void:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	var screen_rect := Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	position = Vector2i(
		screen_rect.position.x + maxi(0, int((screen_rect.size.x - WINDOW_SIZE.x) * 0.5)),
		screen_rect.position.y + maxi(0, int((screen_rect.size.y - WINDOW_SIZE.y) * 0.5))
	)


static func _format_duration(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var remaining_seconds := total % 60
	return "%02d:%02d:%02d" % [hours, minutes, remaining_seconds]


static func _sanitize_range(value: String) -> String:
	return value if VALID_RANGE_MODES.has(value) else "full"


static func _sanitize_language(value: String) -> String:
	return value if VALID_LANGUAGES.has(value) else "zh"
