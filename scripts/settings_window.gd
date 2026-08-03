extends Window

signal activity_range_changed(range_mode: String)
signal language_changed(language_code: String)
signal quit_requested
signal reset_game_requested
signal save_slot_create_requested(slot_id: String)
signal save_slot_switch_requested(slot_id: String)
signal save_slot_rename_requested(slot_id: String, display_name: String)
signal save_slot_delete_requested(slot_id: String)
signal debug_economy_requested(faith_points: float, gold_coins: int)
signal debug_simulation_requested(enemy_power_scale: float, game_speed: float)
signal debug_event_requested(event_type: String)
signal debug_pet_levels_requested(levels: Dictionary)
signal debug_era_requested(era_index: int)

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")

const WINDOW_SIZE := Vector2i(720, 720)
const VALID_RANGE_MODES := ["full", "right", "left"]
const VALID_LANGUAGES := LanguageSettings.SUPPORTED_LANGUAGES

var _activity_range := "full"
var _language := LanguageSettings.DEFAULT_LANGUAGE
var _title_label: Label
var _range_label: Label
var _range_options: OptionButton
var _language_label: Label
var _language_options: OptionButton
var _exit_button: Button
var _close_button: Button
var _root: Control
var _debug_button: Button
var _credits_button: Button
var _credits_panel: PanelContainer
var _credits_title_label: Label
var _credits_copy_label: Label
var _credits_back_button: Button
var _debug_panel: PanelContainer
var _debug_title_label: Label
var _debug_hint_label: Label
var _debug_faith_label: Label
var _debug_coin_label: Label
var _debug_faith_spin: SpinBox
var _debug_coin_spin: SpinBox
var _debug_enemy_power_label: Label
var _debug_enemy_power_spin: SpinBox
var _debug_game_speed_label: Label
var _debug_game_speed_spin: SpinBox
var _debug_era_label: Label
var _debug_era_options: OptionButton
var _debug_pet_levels_title: Label
var _debug_pet_level_spins: Dictionary = {}
var _debug_apply_button: Button
var _debug_event_title_label: Label
var _debug_pilgrimage_button: Button
var _debug_battle_button: Button
var _debug_back_button: Button
var _debug_reset_button: Button
var _reset_confirmation: ConfirmationDialog
var _save_slots_button: Button
var _save_slots_panel: PanelContainer
var _save_slots_title_label: Label
var _save_slots_hint_label: Label
var _save_slots_notice_label: Label
var _save_slots_list: VBoxContainer
var _save_slots_back_button: Button
var _save_slot_action_confirmation: ConfirmationDialog
var _save_slot_rename_confirmation: ConfirmationDialog
var _save_slot_rename_input: LineEdit
var _save_slots: Array[Dictionary] = []
var _active_save_slot_id := ""
var _pending_save_slot_action := ""
var _pending_save_slot_id := ""
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


func set_save_slots(slots: Array, active_slot_id: String) -> void:
	_save_slots.clear()
	for slot_value in slots:
		if slot_value is Dictionary:
			_save_slots.append((slot_value as Dictionary).duplicate(true))
	_active_save_slot_id = active_slot_id
	if _save_slots_button != null:
		_save_slots_button.disabled = _save_slots.is_empty()
	_refresh_save_slots_panel()


func show_save_slot_notice(message: String) -> void:
	if _save_slots_notice_label == null:
		return
	_save_slots_notice_label.text = message.strip_edges()
	_save_slots_notice_label.visible = not _save_slots_notice_label.text.is_empty()


func open_window() -> void:
	_center_window()
	visible = true


func close_window() -> void:
	visible = false
	_dragging = false
	if _credits_panel != null:
		_credits_panel.visible = false
	if _debug_panel != null:
		_debug_panel.visible = false
	if _save_slots_panel != null:
		_save_slots_panel.visible = false
	if _reset_confirmation != null:
		_reset_confirmation.hide()
	if _save_slot_action_confirmation != null:
		_save_slot_action_confirmation.hide()
	if _save_slot_rename_confirmation != null:
		_save_slot_rename_confirmation.hide()
	_pending_save_slot_action = ""
	_pending_save_slot_id = ""


func refresh_debug_values(
	faith_points: float,
	gold_coins: int,
	enemy_power_scale := 1.0,
	game_speed := 1.0,
	pet_levels := {}
) -> void:
	if _debug_faith_spin != null:
		_debug_faith_spin.value = clampf(faith_points, 0.0, _debug_faith_spin.max_value)
	if _debug_coin_spin != null:
		_debug_coin_spin.value = clampf(float(gold_coins), 0.0, _debug_coin_spin.max_value)
	if _debug_enemy_power_spin != null:
		_debug_enemy_power_spin.value = clampf(enemy_power_scale, 0.0, _debug_enemy_power_spin.max_value)
	if _debug_game_speed_spin != null:
		_debug_game_speed_spin.value = clampf(game_speed, _debug_game_speed_spin.min_value, _debug_game_speed_spin.max_value)
	if pet_levels is Dictionary:
		for pet_id_value in _debug_pet_level_spins:
			var pet_id := String(pet_id_value)
			var spin := _debug_pet_level_spins[pet_id] as SpinBox
			if spin != null:
				spin.value = clampi(int((pet_levels as Dictionary).get(pet_id, spin.value)), 1, PetProgression.MAX_LEVEL)


func refresh_debug_era(era_index: int) -> void:
	if _debug_era_options == null:
		return
	_updating_controls = true
	_debug_era_options.select(clampi(era_index, 0, EraProgression.get_era_count() - 1))
	_updating_controls = false


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
	unresizable = true
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	visible = false
	close_requested.connect(close_window)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))


func _create_content() -> void:
	_root = Control.new()
	_root.name = "SettingsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.position = Vector2(142.0, 108.0)
	panel.size = Vector2(436.0, 504.0)
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
	content.add_theme_constant_override("separation", 12)
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

	_debug_button = Button.new()
	_debug_button.text = "调试选项"
	_debug_button.custom_minimum_size = Vector2(360.0, 38.0)
	_debug_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_debug_button.add_theme_font_size_override("font_size", 18)
	_debug_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.08, 0.07, 0.92), Color(0.42, 0.52, 0.38, 0.9)))
	_debug_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.14, 0.10, 0.98), Color(0.68, 0.76, 0.46, 1.0)))
	_debug_button.pressed.connect(_open_debug_panel)
	content.add_child(_debug_button)

	_credits_button = Button.new()
	_credits_button.name = "OpenCredits"
	_credits_button.text = "资源鸣谢"
	_credits_button.custom_minimum_size = Vector2(360.0, 38.0)
	_credits_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_credits_button.add_theme_font_size_override("font_size", 18)
	_credits_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.075, 0.10, 0.92), Color(0.38, 0.58, 0.66, 0.90)))
	_credits_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.08, 0.13, 0.18, 0.98), Color(0.52, 0.82, 0.92, 1.0)))
	_credits_button.pressed.connect(_open_credits_panel)
	content.add_child(_credits_button)

	_save_slots_button = Button.new()
	_save_slots_button.name = "OpenSaveSlots"
	_save_slots_button.text = "SAVE SLOTS"
	_save_slots_button.custom_minimum_size = Vector2(360.0, 38.0)
	_save_slots_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_slots_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_save_slots_button.add_theme_font_size_override("font_size", 18)
	_save_slots_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.06, 0.10, 0.94), Color(0.64, 0.48, 0.78, 0.94)))
	_save_slots_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.09, 0.20, 0.98), Color(0.86, 0.66, 1.0, 1.0)))
	_save_slots_button.pressed.connect(_open_save_slots_panel)
	_save_slots_button.disabled = true
	content.add_child(_save_slots_button)

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
	_close_button.position = Vector2(514.0, 140.0)
	_close_button.size = Vector2(54.0, 48.0)
	_close_button.z_index = 10
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.add_theme_font_size_override("font_size", 31)
	_close_button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.78, 1.0))
	_close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_close_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.9, 1.0))
	_close_button.add_theme_color_override("font_outline_color", Color(0.08, 0.015, 0.012, 1.0))
	_close_button.add_theme_constant_override("outline_size", 2)
	_close_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.24, 0.055, 0.045, 0.98), Color(0.92, 0.48, 0.32, 1.0)))
	_close_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.42, 0.08, 0.055, 1.0), Color(1.0, 0.72, 0.42, 1.0)))
	_close_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.14, 0.025, 0.02, 1.0), Color(1.0, 0.82, 0.54, 1.0)))
	_close_button.pressed.connect(close_window)
	_root.add_child(_close_button)
	_create_debug_panel()
	_create_credits_panel()
	_create_save_slots_panel()
	_create_reset_confirmation()
	_create_save_slot_action_confirmation()
	_create_save_slot_rename_confirmation()


func _create_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.position = Vector2(24.0, 24.0)
	_debug_panel.size = Vector2(672.0, 672.0)
	_debug_panel.visible = false
	_debug_panel.z_index = 20
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var debug_style := _make_panel_style()
	debug_style.bg_color = Color(0.008, 0.012, 0.010, 1.0)
	_debug_panel.add_theme_stylebox_override("panel", debug_style)
	_root.add_child(_debug_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_debug_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_debug_title_label = _make_label("调试选项", 28, Color(0.94, 0.84, 0.62, 1.0))
	_debug_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_title_label)
	_debug_hint_label = _make_label("经济数值写入存档；战力与速度仅当前运行", 14, Color(0.68, 0.74, 0.66, 1.0))
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

	var enemy_power_row := _make_setting_row()
	_debug_enemy_power_label = _make_label("敌军战力倍率", 18, Color(0.82, 0.86, 0.72, 1.0))
	_debug_enemy_power_label.custom_minimum_size = Vector2(120.0, 42.0)
	enemy_power_row.add_child(_debug_enemy_power_label)
	_debug_enemy_power_spin = _make_debug_multiplier_spin_box(0.0, 1_000_000_000_000_000.0, 0.05)
	enemy_power_row.add_child(_debug_enemy_power_spin)
	content.add_child(enemy_power_row)

	var game_speed_row := _make_setting_row()
	_debug_game_speed_label = _make_label("游戏速度倍率", 18, Color(0.82, 0.86, 0.72, 1.0))
	_debug_game_speed_label.custom_minimum_size = Vector2(120.0, 42.0)
	game_speed_row.add_child(_debug_game_speed_label)
	_debug_game_speed_spin = _make_debug_multiplier_spin_box(0.1, 20.0, 0.1)
	game_speed_row.add_child(_debug_game_speed_spin)
	content.add_child(game_speed_row)

	var era_row := _make_setting_row()
	_debug_era_label = _make_label("当前时代", 18, Color(0.82, 0.86, 0.72, 1.0))
	_debug_era_label.custom_minimum_size = Vector2(120.0, 42.0)
	era_row.add_child(_debug_era_label)
	_debug_era_options = _make_option_button()
	_debug_era_options.name = "DebugEraSelector"
	_debug_era_options.item_selected.connect(_on_debug_era_selected)
	era_row.add_child(_debug_era_options)
	content.add_child(era_row)

	_debug_pet_levels_title = _make_label("宠物等级（逐只设置）", 17, Color(0.9, 0.78, 0.52, 1.0))
	_debug_pet_levels_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_pet_levels_title)
	var pet_level_scroll := ScrollContainer.new()
	pet_level_scroll.name = "DebugPetLevelScroll"
	pet_level_scroll.custom_minimum_size = Vector2(600.0, 92.0)
	pet_level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(pet_level_scroll)
	var pet_level_grid := GridContainer.new()
	pet_level_grid.name = "DebugPetLevelGrid"
	pet_level_grid.columns = 4
	pet_level_grid.add_theme_constant_override("h_separation", 8)
	pet_level_grid.add_theme_constant_override("v_separation", 5)
	pet_level_scroll.add_child(pet_level_grid)
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var pet_label := _make_label(pet_id.to_upper(), 14, Color(0.74, 0.8, 0.68, 1.0))
		pet_label.custom_minimum_size = Vector2(66.0, 34.0)
		pet_level_grid.add_child(pet_label)
		var pet_level_spin := SpinBox.new()
		pet_level_spin.name = "Debug%sLevel" % pet_id.capitalize()
		pet_level_spin.min_value = 1.0
		pet_level_spin.max_value = float(PetProgression.MAX_LEVEL)
		pet_level_spin.step = 1.0
		pet_level_spin.rounded = true
		pet_level_spin.value = 1.0
		pet_level_spin.custom_minimum_size = Vector2(205.0, 34.0)
		pet_level_spin.add_theme_font_size_override("font_size", 15)
		pet_level_grid.add_child(pet_level_spin)
		_debug_pet_level_spins[pet_id] = pet_level_spin

	_debug_apply_button = Button.new()
	_debug_apply_button.text = "应用数值"
	_debug_apply_button.custom_minimum_size = Vector2(360.0, 38.0)
	_debug_apply_button.pressed.connect(_on_debug_apply_pressed)
	content.add_child(_debug_apply_button)

	var divider := HSeparator.new()
	content.add_child(divider)
	_debug_event_title_label = _make_label("投放事件邀请", 17, Color(0.82, 0.86, 0.72, 1.0))
	_debug_event_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_debug_event_title_label)
	var event_row := HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 10)
	content.add_child(event_row)
	_debug_pilgrimage_button = Button.new()
	_debug_pilgrimage_button.text = "投放朝拜邀请"
	_debug_pilgrimage_button.custom_minimum_size = Vector2(174.0, 40.0)
	_debug_pilgrimage_button.pressed.connect(_on_debug_event_pressed.bind("pilgrimage"))
	event_row.add_child(_debug_pilgrimage_button)
	_debug_battle_button = Button.new()
	_debug_battle_button.text = "投放战斗邀请"
	_debug_battle_button.custom_minimum_size = Vector2(174.0, 40.0)
	_debug_battle_button.pressed.connect(_on_debug_event_pressed.bind("battle"))
	event_row.add_child(_debug_battle_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var footer_actions := HBoxContainer.new()
	footer_actions.name = "DebugFooterActions"
	footer_actions.custom_minimum_size = Vector2(600.0, 38.0)
	footer_actions.add_theme_constant_override("separation", 10)
	content.add_child(footer_actions)
	_debug_back_button = Button.new()
	_debug_back_button.name = "DebugBackToSettings"
	_debug_back_button.text = "返回设置"
	_debug_back_button.custom_minimum_size = Vector2(0.0, 38.0)
	_debug_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_back_button.pressed.connect(_close_debug_panel)
	footer_actions.add_child(_debug_back_button)
	_debug_reset_button = Button.new()
	_debug_reset_button.name = "ResetAllProgress"
	_debug_reset_button.text = "重置全部进度"
	_debug_reset_button.tooltip_text = "需要再次确认；确认后将永久清除当前存档"
	_debug_reset_button.custom_minimum_size = Vector2(0.0, 38.0)
	_debug_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_reset_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_debug_reset_button.add_theme_font_size_override("font_size", 17)
	_debug_reset_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.8, 1.0))
	_debug_reset_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.25, 0.055, 0.05, 0.98), Color(0.78, 0.25, 0.18, 1.0)))
	_debug_reset_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.42, 0.075, 0.06, 1.0), Color(1.0, 0.48, 0.3, 1.0)))
	_debug_reset_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.15, 0.025, 0.022, 1.0), Color(1.0, 0.62, 0.4, 1.0)))
	_debug_reset_button.pressed.connect(_on_debug_reset_pressed)
	footer_actions.add_child(_debug_reset_button)


func _create_credits_panel() -> void:
	_credits_panel = PanelContainer.new()
	_credits_panel.name = "CreditsPanel"
	_credits_panel.position = Vector2(54.0, 96.0)
	_credits_panel.size = Vector2(612.0, 528.0)
	_credits_panel.visible = false
	_credits_panel.z_index = 30
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var credits_style := _make_panel_style()
	credits_style.bg_color = Color(0.008, 0.014, 0.022, 1.0)
	credits_style.border_color = Color(0.40, 0.66, 0.76, 0.82)
	_credits_panel.add_theme_stylebox_override("panel", credits_style)
	_root.add_child(_credits_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	_credits_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_credits_title_label = _make_label("资源鸣谢与许可", 28, Color(0.78, 0.90, 0.94, 1.0))
	_credits_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_title_label.custom_minimum_size = Vector2(552.0, 42.0)
	content.add_child(_credits_title_label)

	var divider := HSeparator.new()
	content.add_child(divider)
	_credits_copy_label = _make_label("", 17, Color(0.82, 0.86, 0.80, 1.0))
	_credits_copy_label.name = "CreditsCopy"
	_credits_copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_copy_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_credits_copy_label.custom_minimum_size = Vector2(552.0, 310.0)
	content.add_child(_credits_copy_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	_credits_back_button = Button.new()
	_credits_back_button.name = "CreditsBackToSettings"
	_credits_back_button.text = "返回设置"
	_credits_back_button.custom_minimum_size = Vector2(552.0, 40.0)
	_credits_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_credits_back_button.add_theme_font_size_override("font_size", 18)
	_credits_back_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.045, 0.09, 0.11, 0.98), Color(0.34, 0.64, 0.72, 0.92)))
	_credits_back_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.075, 0.15, 0.18, 1.0), Color(0.52, 0.84, 0.92, 1.0)))
	_credits_back_button.pressed.connect(_close_credits_panel)
	content.add_child(_credits_back_button)


func _create_save_slots_panel() -> void:
	_save_slots_panel = PanelContainer.new()
	_save_slots_panel.name = "SaveSlotsPanel"
	_save_slots_panel.position = Vector2(40.0, 48.0)
	_save_slots_panel.size = Vector2(640.0, 624.0)
	_save_slots_panel.visible = false
	_save_slots_panel.z_index = 30
	_save_slots_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _make_panel_style()
	panel_style.bg_color = Color(0.025, 0.012, 0.050, 1.0)
	panel_style.border_color = Color(0.72, 0.54, 0.92, 0.94)
	_save_slots_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_save_slots_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_save_slots_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	_save_slots_title_label = _make_label("SAVE SLOTS", 29, Color(0.92, 0.80, 1.0, 1.0))
	_save_slots_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_title_label.custom_minimum_size = Vector2(584.0, 42.0)
	content.add_child(_save_slots_title_label)
	_save_slots_hint_label = _make_label("Each slot keeps its own progress and backup.", 15, Color(0.76, 0.70, 0.88, 1.0))
	_save_slots_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_slots_hint_label.custom_minimum_size = Vector2(584.0, 38.0)
	content.add_child(_save_slots_hint_label)
	_save_slots_notice_label = _make_label("", 14, Color(1.0, 0.74, 0.54, 1.0))
	_save_slots_notice_label.name = "SaveSlotsNotice"
	_save_slots_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_slots_notice_label.custom_minimum_size = Vector2(584.0, 0.0)
	_save_slots_notice_label.visible = false
	content.add_child(_save_slots_notice_label)
	content.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "SaveSlotsScroll"
	scroll.custom_minimum_size = Vector2(584.0, 408.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(scroll)
	_save_slots_list = VBoxContainer.new()
	_save_slots_list.name = "SaveSlotsList"
	_save_slots_list.custom_minimum_size = Vector2(562.0, 0.0)
	_save_slots_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_save_slots_list)

	_save_slots_back_button = Button.new()
	_save_slots_back_button.name = "SaveSlotsBackToSettings"
	_save_slots_back_button.text = "BACK TO SETTINGS"
	_save_slots_back_button.custom_minimum_size = Vector2(584.0, 40.0)
	_save_slots_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_slots_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_save_slots_back_button.add_theme_font_size_override("font_size", 18)
	_save_slots_back_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.10, 0.06, 0.15, 0.98), Color(0.62, 0.52, 0.82, 0.94)))
	_save_slots_back_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.16, 0.10, 0.24, 1.0), Color(0.88, 0.72, 1.0, 1.0)))
	_save_slots_back_button.pressed.connect(_close_save_slots_panel)
	content.add_child(_save_slots_back_button)


func _create_save_slot_action_confirmation() -> void:
	_save_slot_action_confirmation = ConfirmationDialog.new()
	_save_slot_action_confirmation.name = "SaveSlotActionConfirmation"
	_save_slot_action_confirmation.unresizable = true
	_save_slot_action_confirmation.transient = true
	_save_slot_action_confirmation.exclusive = true
	_save_slot_action_confirmation.min_size = Vector2i(500, 220)
	_save_slot_action_confirmation.confirmed.connect(_on_save_slot_action_confirmed)
	add_child(_save_slot_action_confirmation)
	var confirm_button := _save_slot_action_confirmation.get_ok_button()
	confirm_button.add_theme_color_override("font_color", Color(1.0, 0.90, 0.82, 1.0))
	confirm_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.22, 0.08, 0.16, 1.0), Color(0.82, 0.40, 0.66, 1.0)))
	confirm_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.38, 0.10, 0.24, 1.0), Color(1.0, 0.62, 0.82, 1.0)))


func _create_save_slot_rename_confirmation() -> void:
	_save_slot_rename_confirmation = ConfirmationDialog.new()
	_save_slot_rename_confirmation.name = "RenameSaveSlotConfirmation"
	_save_slot_rename_confirmation.unresizable = true
	_save_slot_rename_confirmation.transient = true
	_save_slot_rename_confirmation.exclusive = true
	_save_slot_rename_confirmation.min_size = Vector2i(500, 220)
	_save_slot_rename_confirmation.confirmed.connect(_on_save_slot_rename_confirmed)
	add_child(_save_slot_rename_confirmation)
	var content := VBoxContainer.new()
	content.position = Vector2(24.0, 78.0)
	content.size = Vector2(452.0, 62.0)
	_save_slot_rename_confirmation.add_child(content)
	_save_slot_rename_input = LineEdit.new()
	_save_slot_rename_input.name = "SaveSlotRenameInput"
	_save_slot_rename_input.max_length = 32
	_save_slot_rename_input.custom_minimum_size = Vector2(452.0, 40.0)
	_save_slot_rename_input.add_theme_font_size_override("font_size", 18)
	_save_slot_rename_input.add_theme_color_override("font_color", Color(0.96, 0.88, 0.98, 1.0))
	_save_slot_rename_input.add_theme_color_override("font_placeholder_color", Color(0.64, 0.56, 0.70, 0.9))
	_save_slot_rename_input.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.035, 0.09, 1.0), Color(0.66, 0.52, 0.84, 0.94)))
	_save_slot_rename_input.add_theme_stylebox_override("focus", _make_button_style(Color(0.09, 0.055, 0.14, 1.0), Color(0.90, 0.72, 1.0, 1.0)))
	_save_slot_rename_input.text_submitted.connect(func(_text: String) -> void:
		if _save_slot_rename_confirmation != null:
			_save_slot_rename_confirmation.emit_signal("confirmed")
	)
	content.add_child(_save_slot_rename_input)


func _refresh_save_slots_panel() -> void:
	if _save_slots_list == null:
		return
	for child in _save_slots_list.get_children():
		child.queue_free()
	if _save_slots.is_empty():
		var unavailable_label := _make_label(
			"Save slots are unavailable in this session." if _language == "en" else "本次运行无法使用存档管理。",
			18,
			Color(0.78, 0.70, 0.86, 1.0)
		)
		unavailable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unavailable_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unavailable_label.custom_minimum_size = Vector2(550.0, 120.0)
		_save_slots_list.add_child(unavailable_label)
		return
	for slot in _save_slots:
		if slot is Dictionary:
			_create_save_slot_card(slot as Dictionary)


func _create_save_slot_card(slot: Dictionary) -> void:
	var slot_id := String(slot.get("id", ""))
	if slot_id.is_empty():
		return
	var has_data := bool(slot.get("has_data", false))
	var is_active := bool(slot.get("is_active", false)) or slot_id == _active_save_slot_id
	var card := PanelContainer.new()
	card.name = "SaveSlot_%s" % slot_id
	card.custom_minimum_size = Vector2(562.0, 120.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := _make_panel_style()
	card_style.bg_color = Color(0.09, 0.045, 0.15, 0.96) if is_active else Color(0.035, 0.025, 0.070, 0.94)
	card_style.border_color = Color(0.94, 0.72, 0.42, 0.96) if is_active else Color(0.54, 0.42, 0.70, 0.82)
	card.add_theme_stylebox_override("panel", card_style)
	_save_slots_list.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var name_label := _make_label(String(slot.get("display_name", slot_id)), 20, Color(0.98, 0.88, 0.72, 1.0))
	name_label.custom_minimum_size = Vector2(348.0, 30.0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(name_label)
	var state_label := _make_label(
		("ACTIVE" if _language == "en" else "当前使用") if is_active else ("EMPTY" if _language == "en" else "空槽位") if not has_data else ("READY" if _language == "en" else "可切换"),
		14,
		Color(1.0, 0.76, 0.42, 1.0) if is_active else Color(0.72, 0.74, 0.92, 1.0)
	)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.custom_minimum_size = Vector2(146.0, 30.0)
	header.add_child(state_label)
	var description := _make_label(_get_save_slot_description(slot), 14, Color(0.76, 0.70, 0.84, 1.0))
	description.custom_minimum_size = Vector2(528.0, 22.0)
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(description)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	if not has_data:
		if is_active:
			var active_empty_button := _make_save_slot_button("ACTIVE NEW SAVE" if _language == "en" else "当前新存档", Color(0.09, 0.09, 0.11, 0.98), Color(0.48, 0.48, 0.54, 0.88))
			active_empty_button.name = "ActiveEmptySaveSlot_%s" % slot_id
			active_empty_button.custom_minimum_size = Vector2(528.0, 34.0)
			active_empty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			active_empty_button.disabled = true
			actions.add_child(active_empty_button)
		else:
			var create_button := _make_save_slot_button("CREATE NEW SAVE" if _language == "en" else "新建存档", Color(0.10, 0.15, 0.12, 0.98), Color(0.50, 0.84, 0.58, 0.96))
			create_button.name = "CreateSaveSlot_%s" % slot_id
			create_button.custom_minimum_size = Vector2(528.0, 34.0)
			create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			create_button.pressed.connect(_on_save_slot_create_pressed.bind(slot_id))
			actions.add_child(create_button)
		return
	if not is_active:
		var switch_button := _make_save_slot_button("SWITCH" if _language == "en" else "切换", Color(0.09, 0.12, 0.19, 0.98), Color(0.44, 0.68, 0.98, 0.96))
		switch_button.name = "SwitchSaveSlot_%s" % slot_id
		switch_button.custom_minimum_size = Vector2(156.0, 34.0)
		switch_button.pressed.connect(_on_save_slot_switch_pressed.bind(slot_id))
		actions.add_child(switch_button)
	var rename_button := _make_save_slot_button("RENAME" if _language == "en" else "重命名", Color(0.14, 0.09, 0.18, 0.98), Color(0.72, 0.56, 0.94, 0.96))
	rename_button.name = "RenameSaveSlot_%s" % slot_id
	rename_button.custom_minimum_size = Vector2(218.0, 34.0)
	rename_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_button.pressed.connect(_on_save_slot_rename_pressed.bind(slot_id))
	actions.add_child(rename_button)
	if not is_active:
		var delete_button := _make_save_slot_button("DELETE" if _language == "en" else "删除", Color(0.22, 0.06, 0.08, 0.98), Color(0.90, 0.30, 0.34, 0.98))
		delete_button.name = "DeleteSaveSlot_%s" % slot_id
		delete_button.custom_minimum_size = Vector2(122.0, 34.0)
		delete_button.pressed.connect(_on_save_slot_delete_pressed.bind(slot_id))
		actions.add_child(delete_button)


func _make_save_slot_button(text_value: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _make_button_style(background, border))
	button.add_theme_stylebox_override("hover", _make_button_style(background.lightened(0.14), border.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _make_button_style(background.darkened(0.16), border))
	return button


func _get_save_slot_description(slot: Dictionary) -> String:
	if not bool(slot.get("has_data", false)):
		if bool(slot.get("is_active", false)) or String(slot.get("id", "")) == _active_save_slot_id:
			return "This is the active new game. Progress saves automatically." if _language == "en" else "这是当前使用的新游戏；进度会自动保存。"
		return "No progress yet. Creating it starts a fresh game." if _language == "en" else "尚无进度；新建后将从全新游戏开始。"
	var playtime_seconds := maxf(0.0, float(slot.get("playtime_seconds", 0.0)))
	var playtime_minutes := int(floor(playtime_seconds / 60.0))
	var recovered := bool(slot.get("recovered_from_backup", false))
	if _language == "en":
		return "Recovered from backup • %d min played" % playtime_minutes if recovered else "Saved progress • %d min played" % playtime_minutes
	return "已从备份恢复 · 已游玩 %d 分钟" % playtime_minutes if recovered else "已有进度 · 已游玩 %d 分钟" % playtime_minutes


func _create_reset_confirmation() -> void:
	_reset_confirmation = ConfirmationDialog.new()
	_reset_confirmation.name = "ResetGameConfirmation"
	_reset_confirmation.unresizable = true
	_reset_confirmation.transient = true
	_reset_confirmation.exclusive = true
	_reset_confirmation.min_size = Vector2i(500, 220)
	_reset_confirmation.confirmed.connect(_on_reset_confirmed)
	add_child(_reset_confirmation)

	var confirm_button := _reset_confirmation.get_ok_button()
	confirm_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.82, 1.0))
	confirm_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.28, 0.055, 0.05, 1.0), Color(0.82, 0.28, 0.2, 1.0)))
	confirm_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.46, 0.075, 0.06, 1.0), Color(1.0, 0.5, 0.32, 1.0)))
	confirm_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.16, 0.025, 0.02, 1.0), Color(1.0, 0.65, 0.42, 1.0)))


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


func _make_debug_multiplier_spin_box(minimum: float, maximum: float, value_step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = value_step
	spin.allow_greater = true
	spin.allow_lesser = false
	spin.suffix = "×"
	spin.custom_minimum_size = Vector2(230.0, 42.0)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", 17)
	return spin


func _open_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = true


func _open_credits_panel() -> void:
	if _credits_panel != null:
		_credits_panel.visible = true


func _open_save_slots_panel() -> void:
	if _save_slots_panel == null:
		return
	show_save_slot_notice("")
	_refresh_save_slots_panel()
	_save_slots_panel.visible = true


func _close_save_slots_panel() -> void:
	if _save_slots_panel != null:
		_save_slots_panel.visible = false
	if _save_slot_action_confirmation != null:
		_save_slot_action_confirmation.hide()
	if _save_slot_rename_confirmation != null:
		_save_slot_rename_confirmation.hide()
	_pending_save_slot_action = ""
	_pending_save_slot_id = ""


func _close_credits_panel() -> void:
	if _credits_panel != null:
		_credits_panel.visible = false


func _close_debug_panel() -> void:
	if _debug_panel != null:
		_debug_panel.visible = false
	if _reset_confirmation != null:
		_reset_confirmation.hide()


func _on_debug_reset_pressed() -> void:
	if _reset_confirmation != null:
		_reset_confirmation.popup_centered(Vector2i(500, 220))


func _on_reset_confirmed() -> void:
	reset_game_requested.emit()


func _on_save_slot_create_pressed(slot_id: String) -> void:
	if slot_id.is_empty():
		return
	save_slot_create_requested.emit(slot_id)


func _on_save_slot_switch_pressed(slot_id: String) -> void:
	_open_save_slot_action_confirmation("switch", slot_id)


func _on_save_slot_delete_pressed(slot_id: String) -> void:
	_open_save_slot_action_confirmation("delete", slot_id)


func _on_save_slot_rename_pressed(slot_id: String) -> void:
	if slot_id.is_empty() or _save_slot_rename_confirmation == null or _save_slot_rename_input == null:
		return
	_pending_save_slot_action = "rename"
	_pending_save_slot_id = slot_id
	_save_slot_rename_input.text = _get_save_slot_display_name(slot_id)
	_save_slot_rename_confirmation.title = "Rename save" if _language == "en" else "重命名存档"
	_save_slot_rename_confirmation.dialog_text = "Choose a short name for this save slot." if _language == "en" else "为该存档槽输入一个简短名称。"
	_save_slot_rename_confirmation.ok_button_text = "SAVE NAME" if _language == "en" else "保存名称"
	_save_slot_rename_confirmation.cancel_button_text = "CANCEL" if _language == "en" else "取消"
	if is_inside_tree():
		_save_slot_rename_confirmation.popup_centered(Vector2i(500, 220))
	else:
		_save_slot_rename_confirmation.visible = true
	_save_slot_rename_input.call_deferred("grab_focus")


func _on_save_slot_action_confirmed() -> void:
	var slot_id := _pending_save_slot_id
	var action := _pending_save_slot_action
	_pending_save_slot_action = ""
	_pending_save_slot_id = ""
	if slot_id.is_empty():
		return
	if action == "switch":
		save_slot_switch_requested.emit(slot_id)
	elif action == "delete":
		save_slot_delete_requested.emit(slot_id)


func _on_save_slot_rename_confirmed() -> void:
	var slot_id := _pending_save_slot_id
	_pending_save_slot_action = ""
	_pending_save_slot_id = ""
	if slot_id.is_empty() or _save_slot_rename_input == null:
		return
	save_slot_rename_requested.emit(slot_id, _save_slot_rename_input.text)


func _open_save_slot_action_confirmation(action: String, slot_id: String) -> void:
	if action not in ["switch", "delete"] or slot_id.is_empty() or _save_slot_action_confirmation == null:
		return
	_pending_save_slot_action = action
	_pending_save_slot_id = slot_id
	var slot_name := _get_save_slot_display_name(slot_id)
	var english := _language == "en"
	if action == "switch":
		_save_slot_action_confirmation.title = "Switch save slot" if english else "切换存档"
		_save_slot_action_confirmation.dialog_text = (
			"Switch to %s? The current slot will be saved first, then the game reloads." % slot_name
			if english
			else "要切换到“%s”吗？当前存档会先安全保存，然后游戏将重新加载。" % slot_name
		)
		_save_slot_action_confirmation.ok_button_text = "SAVE AND SWITCH" if english else "保存并切换"
	else:
		_save_slot_action_confirmation.title = "Delete save slot" if english else "删除存档"
		_save_slot_action_confirmation.dialog_text = (
			"Delete %s permanently? Its progress and backup will be removed. This cannot be undone." % slot_name
			if english
			else "要永久删除“%s”吗？该槽位的进度与备份都会被移除，且无法撤销。" % slot_name
		)
		_save_slot_action_confirmation.ok_button_text = "DELETE SAVE" if english else "删除存档"
	_save_slot_action_confirmation.cancel_button_text = "CANCEL" if english else "取消"
	if is_inside_tree():
		_save_slot_action_confirmation.popup_centered(Vector2i(500, 220))
	else:
		_save_slot_action_confirmation.visible = true


func _get_save_slot_display_name(slot_id: String) -> String:
	for slot in _save_slots:
		if slot is Dictionary and String((slot as Dictionary).get("id", "")) == slot_id:
			return String((slot as Dictionary).get("display_name", slot_id))
	return slot_id


func _on_debug_apply_pressed() -> void:
	_emit_debug_values()


func _on_debug_era_selected(index: int) -> void:
	if _updating_controls:
		return
	debug_era_requested.emit(clampi(index, 0, EraProgression.get_era_count() - 1))


func _emit_debug_values() -> void:
	if (
		_debug_faith_spin == null
		or _debug_coin_spin == null
		or _debug_enemy_power_spin == null
		or _debug_game_speed_spin == null
	):
		return
	var faith_points := _debug_faith_spin.value
	var gold_coins := int(round(_debug_coin_spin.value))
	var enemy_power_scale := _debug_enemy_power_spin.value
	var game_speed := _debug_game_speed_spin.value
	var pet_levels := {}
	for pet_id_value in _debug_pet_level_spins:
		var pet_id := String(pet_id_value)
		pet_levels[pet_id] = int(round((_debug_pet_level_spins[pet_id] as SpinBox).value))
	debug_economy_requested.emit(faith_points, gold_coins)
	debug_simulation_requested.emit(enemy_power_scale, game_speed)
	debug_pet_levels_requested.emit(pet_levels)


func _on_debug_event_pressed(event_type: String) -> void:
	if event_type not in ["pilgrimage", "battle"]:
		return
	_emit_debug_values()
	debug_event_requested.emit(event_type)
	close_window()


func _make_setting_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(360.0, 46.0)
	row.add_theme_constant_override("separation", 10)
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
	theme = LanguageSettings.make_ui_theme(_language)
	var english := _language == "en"
	title = "Settings" if english else "设置"
	_title_label.text = "SETTINGS" if english else "设置"
	_range_label.text = "Pet activity area" if english else "宠物活动范围"
	_language_label.text = "Language" if english else "语言"
	_exit_button.text = "EXIT GAME" if english else "退出游戏"
	if _debug_button != null:
		_debug_button.text = "DEBUG OPTIONS" if english else "调试选项"
	if _credits_button != null:
		_credits_button.text = "CREDITS & LICENSES" if english else "资源鸣谢与许可"
	if _credits_title_label != null:
		_credits_title_label.text = "CREDITS & LICENSES" if english else "资源鸣谢与许可"
	if _credits_copy_label != null:
		_credits_copy_label.text = _get_credits_copy(english)
	if _save_slots_button != null:
		_save_slots_button.text = "SAVE SLOTS" if english else "存档管理"
		_save_slots_button.tooltip_text = "Manage independent game saves" if english else "管理彼此独立的游戏存档"
	if _save_slots_title_label != null:
		_save_slots_title_label.text = "SAVE SLOTS" if english else "存档管理"
	if _save_slots_hint_label != null:
		_save_slots_hint_label.text = (
			"Each slot keeps its own progress and automatic backup."
			if english
			else "每个槽位都保存独立进度，并拥有自己的自动备份。"
		)
	if _save_slots_back_button != null:
		_save_slots_back_button.text = "BACK TO SETTINGS" if english else "返回设置"
	if _credits_back_button != null:
		_credits_back_button.text = "BACK TO SETTINGS" if english else "返回设置"
	if _debug_title_label != null:
		_debug_title_label.text = "DEBUG OPTIONS" if english else "调试选项"
	if _debug_hint_label != null:
		_debug_hint_label.text = "Economy saves; power and speed last for this run" if english else "经济数值写入存档；战力与速度仅当前运行"
	if _debug_faith_label != null:
		_debug_faith_label.text = "Faith" if english else "信仰值"
	if _debug_coin_label != null:
		_debug_coin_label.text = "Gold" if english else "金币"
	if _debug_enemy_power_label != null:
		_debug_enemy_power_label.text = "Enemy power" if english else "敌军战力倍率"
	if _debug_game_speed_label != null:
		_debug_game_speed_label.text = "Game speed" if english else "游戏速度倍率"
	if _debug_era_label != null:
		_debug_era_label.text = "Current era" if english else "当前时代"
	if _debug_pet_levels_title != null:
		_debug_pet_levels_title.text = "PET LEVELS (INDIVIDUAL)" if english else "宠物等级（逐只设置）"
	if _debug_apply_button != null:
		_debug_apply_button.text = "APPLY VALUES" if english else "应用数值"
	if _debug_event_title_label != null:
		_debug_event_title_label.text = "DROP EVENT INVITATION" if english else "投放事件邀请"
	if _debug_pilgrimage_button != null:
		_debug_pilgrimage_button.text = "DROP PILGRIMAGE INVITE" if english else "投放朝拜邀请"
	if _debug_battle_button != null:
		_debug_battle_button.text = "DROP BATTLE INVITE" if english else "投放战斗邀请"
	if _debug_back_button != null:
		_debug_back_button.text = "BACK TO SETTINGS" if english else "返回设置"
	if _debug_reset_button != null:
		_debug_reset_button.text = "RESET CURRENT SAVE" if english else "重置当前存档"
		_debug_reset_button.tooltip_text = (
			"Requires confirmation and permanently erases only the active save slot"
			if english
			else "需要再次确认；确认后仅会永久清除当前使用的存档槽。"
		)
	if _close_button != null:
		_close_button.tooltip_text = "Close settings" if english else "关闭设置"
	if _reset_confirmation != null:
		_reset_confirmation.title = "Reset current save" if english else "重置当前存档"
		_reset_confirmation.dialog_text = (
			"This permanently erases the active save slot and returns it to a new game. Other save slots are not affected."
			if english
			else "这会永久清除当前使用的存档槽并回到新游戏。其他存档槽不会受到影响。"
		)
		_reset_confirmation.ok_button_text = "RESET CURRENT SAVE" if english else "确认重置当前存档"
		_reset_confirmation.cancel_button_text = "CANCEL" if english else "取消"
	_updating_controls = true
	_range_options.clear()
	_range_options.add_item("Entire desktop" if english else "全桌面", 0)
	_range_options.add_item("Right side" if english else "靠右", 1)
	_range_options.add_item("Left side" if english else "靠左", 2)
	_language_options.clear()
	_language_options.add_item("English", 0)
	_language_options.add_item("中文", 1)
	if _debug_era_options != null:
		var selected_era := maxi(0, _debug_era_options.selected)
		_debug_era_options.clear()
		for era_index in EraProgression.get_era_count():
			var era_seconds := EraProgression.get_era_start_runtime_seconds(era_index)
			_debug_era_options.add_item(EraProgression.get_era_name(era_seconds, _language), era_index)
		_debug_era_options.select(clampi(selected_era, 0, EraProgression.get_era_count() - 1))
	_updating_controls = false
	_refresh_save_slots_panel()


func _get_credits_copy(english: bool) -> String:
	if english:
		return "Super Pixel Projectiles Pack 2\n\nCreated by Will Tice / unTied Games\n\nLicensed under Will's Public License for Using This Product.\nUsed in this game as projectile visual effects.\n\nLicense and warranty disclaimer:\nhttps://untiedgames.com/files/license.txt\n\nSource:\nhttps://untiedgames.com/"
	return "Super Pixel Projectiles Pack 2\n\n作者：Will Tice / unTied Games\n\n本游戏使用该资源包作为投射物视觉特效。\n授权：Will's Public License for Using This Product\n\n完整许可与免责声明：\nhttps://untiedgames.com/files/license.txt\n\n资源来源：\nhttps://untiedgames.com/"


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
		var desired := DisplayServer.mouse_get_position() - _drag_offset
		position = DisplayLayout.clamp_position(
			desired,
			size,
			DisplayLayout.get_current_usable_rect(self)
		)


func _center_window() -> void:
	var usable_rect := DisplayLayout.get_current_usable_rect(self)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, usable_rect)


static func _sanitize_range(value: String) -> String:
	return value if VALID_RANGE_MODES.has(value) else "full"


static func _sanitize_language(value: String) -> String:
	return LanguageSettings.sanitize(value)
