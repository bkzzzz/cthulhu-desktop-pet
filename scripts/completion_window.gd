extends Window

signal endless_requested
signal continue_requested

const WINDOW_SIZE := Vector2i(680, 430)
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")

var _language := LanguageSettings.DEFAULT_LANGUAGE
var _total_runtime_seconds := 0.0
var _title_label: Label
var _body_label: Label
var _time_label: Label
var _continue_button: Button
var _endless_button: Button


func setup(language_code := LanguageSettings.DEFAULT_LANGUAGE) -> void:
	_language = LanguageSettings.sanitize(language_code)
	theme = LanguageSettings.make_ui_theme(_language)
	name = "CompletionWindow"
	title = "Campaign Complete" if _language == "en" else "游戏通关"
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	visible = false
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))
	if not close_requested.is_connected(_on_continue_pressed):
		close_requested.connect(_on_continue_pressed)
	if _title_label == null:
		_create_content()
	else:
		_refresh_copy()


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	theme = LanguageSettings.make_ui_theme(_language)
	title = "Campaign Complete" if _language == "en" else "游戏通关"
	_refresh_copy()


func open_window(total_runtime_seconds: float) -> void:
	if _title_label == null:
		setup(_language)
	_total_runtime_seconds = maxf(0.0, total_runtime_seconds)
	_refresh_copy()
	_center_window()
	visible = true
	grab_focus()


func close_window() -> void:
	visible = false


func _create_content() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	_title_label = _make_label("", 34, Color(0.96, 0.82, 0.38))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)

	var rule := HSeparator.new()
	rule.modulate = Color(0.72, 0.58, 0.25, 0.8)
	content.add_child(rule)

	_body_label = _make_label("", 18, Color(0.86, 0.91, 0.78))
	_body_label.custom_minimum_size = Vector2(550, 110)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_body_label)

	_time_label = _make_label("", 17, Color(0.67, 0.79, 0.62))
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_time_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)

	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.custom_minimum_size = Vector2(205, 48)
	_continue_button.pressed.connect(_on_continue_pressed)
	_style_button(_continue_button, false)
	actions.add_child(_continue_button)

	_endless_button = Button.new()
	_endless_button.name = "EndlessButton"
	_endless_button.custom_minimum_size = Vector2(235, 48)
	_endless_button.pressed.connect(_on_endless_pressed)
	_style_button(_endless_button, true)
	actions.add_child(_endless_button)
	_refresh_copy()


func _refresh_copy() -> void:
	if _title_label == null:
		return
	_title_label.text = "ALL PETS ASCENDED" if _language == "en" else "全员升格 · 游戏通关"
	_body_label.text = (
		"Every pet has reached Lv.100. The campaign is complete.\nKeep this final sanctuary, or enter Endless Mode where enemies grow with your pets."
		if _language == "en"
		else "所有宠物均已达到 Lv.100，主线成长已经完成。\n你可以留在终局，也可以进入无尽模式；敌人将继续随宠物等级同步增强。"
	)
	var hours := _total_runtime_seconds / 3600.0
	_time_label.text = (
		"TOTAL PLAY TIME  %.1f HOURS" % hours
		if _language == "en"
		else "累计历程  %.1f 小时" % hours
	)
	_continue_button.text = "STAY AT THE FINALE" if _language == "en" else "留在终局"
	_endless_button.text = "ENTER ENDLESS MODE" if _language == "en" else "进入无尽模式"


func _on_continue_pressed() -> void:
	if not visible:
		return
	visible = false
	continue_requested.emit()


func _on_endless_pressed() -> void:
	if not visible:
		return
	visible = false
	endless_requested.emit()


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.012, 0.01))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override(
		"font_color",
		Color(0.06, 0.09, 0.055) if primary else Color(0.86, 0.82, 0.65)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.83, 0.70, 0.30) if primary else Color(0.045, 0.09, 0.07)
	style.border_color = Color(0.98, 0.86, 0.42) if primary else Color(0.43, 0.48, 0.29)
	style.set_border_width_all(2 if primary else 1)
	style.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", style)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.007, 0.025, 0.019, 0.99)
	style.border_color = Color(0.72, 0.58, 0.24, 0.98)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.74)
	style.shadow_size = 18
	return style


func _center_window() -> void:
	var usable_rect := DisplayLayout.get_current_usable_rect(self)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, usable_rect)
