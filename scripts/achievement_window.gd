extends Window

signal claim_requested(achievement_id: String)

const AchievementProgression = preload("res://scripts/domain/achievement_progression.gd")
const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")

const WINDOW_SIZE := Vector2i(720, 760)
const CARD_HEIGHT := 116.0

var _language := LanguageSettings.DEFAULT_LANGUAGE
var _metrics: Dictionary = {}
var _claimed_ids: Array[String] = []
var _state_revision := 0
var _title_label: Label
var _summary_label: Label
var _list: VBoxContainer


func setup() -> void:
	name = "AchievementWindow"
	title = "Achievements"
	unresizable = true
	borderless = true
	transparent = true
	transparent_bg = true
	visible = false
	theme = _make_theme()
	close_requested.connect(close_window)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))
	_create_content()
	set_language(_language)
	_center_window()


func open_window() -> void:
	_center_window()
	visible = true


func close_window() -> void:
	visible = false


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	theme = _make_theme()
	title = "Achievements" if _language == "en" else "成就"
	_rebuild_list()


func refresh_state(metrics: Dictionary, claimed_ids: Array) -> void:
	var next_metrics := metrics.duplicate(true)
	var next_claimed_ids := AchievementProgression.sanitize_claimed_ids(claimed_ids)
	if _metrics == next_metrics and _claimed_ids == next_claimed_ids:
		return
	_metrics = next_metrics
	_claimed_ids = next_claimed_ids
	_state_revision += 1
	_rebuild_list()


func _create_content() -> void:
	var root := PanelContainer.new()
	root.name = "AchievementRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	root.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48.0
	content.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.62))
	header.add_child(_title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(46.0, 42.0)
	close_button.pressed.connect(close_window)
	header.add_child(close_button)

	_summary_label = Label.new()
	_summary_label.custom_minimum_size.y = 28.0
	_summary_label.add_theme_font_size_override("font_size", 16)
	_summary_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.69))
	content.add_child(_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 640.0
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)


func _rebuild_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var completed_count := 0
	for definition_value in AchievementProgression.DEFINITIONS:
		var definition := definition_value as Dictionary
		if AchievementProgression.is_complete(definition, _metrics):
			completed_count += 1
		_list.add_child(_make_achievement_card(definition))
	_title_label.text = "ACHIEVEMENTS" if _language == "en" else "成就"
	_summary_label.text = (
		"Completed %d / %d · Claim substantial faith and gold rewards" % [completed_count, AchievementProgression.DEFINITIONS.size()]
		if _language == "en"
		else "已达成 %d / %d · 领取丰厚的信仰与金币奖励" % [completed_count, AchievementProgression.DEFINITIONS.size()]
	)


func _make_achievement_card(definition: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640.0, CARD_HEIGHT)
	var completed := AchievementProgression.is_complete(definition, _metrics)
	var claimed := _claimed_ids.has(String(definition.get("id", "")))
	card.add_theme_stylebox_override("panel", _make_card_style(completed, claimed))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = String(definition.get("name", "")) if _language == "en" else String(definition.get("name_zh", ""))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.64))
	copy.add_child(name_label)
	var progress := AchievementProgression.get_progress(definition, _metrics)
	var target := maxf(0.0, float(definition.get("target", 0.0)))
	var detail_label := Label.new()
	var description := String(definition.get("description", "")) if _language == "en" else String(definition.get("description_zh", ""))
	detail_label.text = "%s  (%s / %s)" % [description, _format_value(progress), _format_value(target)]
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.72))
	copy.add_child(detail_label)
	var reward_label := Label.new()
	reward_label.text = (
		"REWARD  %s  +  %s faith" % [CurrencyDisplay.format_compact(int(definition.get("gold", 0))), _format_value(float(definition.get("faith", 0.0)))]
		if _language == "en"
		else "奖励  %s  +  %s 信仰" % [CurrencyDisplay.format_compact(int(definition.get("gold", 0))), _format_value(float(definition.get("faith", 0.0)))]
	)
	reward_label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.34))
	copy.add_child(reward_label)
	var claim_button := Button.new()
	claim_button.custom_minimum_size = Vector2(112.0, 54.0)
	claim_button.disabled = not completed or claimed
	claim_button.text = ("CLAIMED" if claimed else "CLAIM" if completed else "LOCKED") if _language == "en" else ("已领取" if claimed else "领取" if completed else "未达成")
	claim_button.pressed.connect(_on_claim_pressed.bind(String(definition.get("id", ""))))
	row.add_child(claim_button)
	return card


func _on_claim_pressed(achievement_id: String) -> void:
	claim_requested.emit(achievement_id)


func _format_value(value: float) -> String:
	var safe_value := maxf(0.0, value) if is_finite(value) else 0.0
	if safe_value >= 1_000_000_000.0:
		return "%.2fB" % (safe_value / 1_000_000_000.0)
	if safe_value >= 1_000_000.0:
		return "%.2fM" % (safe_value / 1_000_000.0)
	if safe_value >= 1_000.0:
		return "%.2fK" % (safe_value / 1_000.0)
	return str(int(floor(safe_value)))


func _make_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = LanguageSettings.get_ui_font(_language)
	ui_theme.default_font_size = 16
	return ui_theme


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.022, 0.985)
	style.border_color = Color(0.70, 0.59, 0.38, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 16
	return style


func _make_card_style(completed: bool, claimed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.065, 0.044, 0.96) if completed else Color(0.052, 0.049, 0.044, 0.92)
	style.border_color = Color(0.78, 0.63, 0.32, 0.95) if completed and not claimed else Color(0.32, 0.31, 0.26, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _center_window() -> void:
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))
