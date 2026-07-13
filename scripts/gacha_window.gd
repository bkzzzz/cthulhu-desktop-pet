extends Window

signal draw_requested

const WINDOW_SIZE := Vector2i(560, 640)
const CONTENT_WIDTH := 508.0
const UI_FONT := "res://assets/ui/font/NormalFont.ttf"

var _faith_label: Label
var _cost_label: Label
var _multiplier_label: Label
var _progress_label: Label
var _result_label: RichTextLabel
var _history_label: RichTextLabel
var _draw_button: Button


func setup() -> void:
	name = "GachaWindow"
	title = "禁忌召唤"
	size = WINDOW_SIZE
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	unresizable = true
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	theme = _make_ui_theme()
	visible = false
	close_requested.connect(close_window)
	_create_content()
	_center_window()


func open_window() -> void:
	_center_window()
	visible = true


func close_window() -> void:
	visible = false


func refresh_state(
	faith_points: float,
	draw_count: int,
	next_cost: int,
	faith_multiplier: float,
	lifetime_faith: float,
	campaign_progress: float,
	history: Array
) -> void:
	if _faith_label == null:
		return

	var safe_cost := maxi(1, next_cost)
	_faith_label.text = "持有信仰：%s" % _format_number(maxf(0.0, faith_points))
	_cost_label.text = "第 %d 次召唤  ·  本次消耗：%s 信仰" % [maxi(0, draw_count) + 1, _format_number(float(safe_cost))]
	_multiplier_label.text = "永久信仰产出倍率：×%.3f" % maxf(1.0, faith_multiplier)
	_progress_label.text = "远古苏醒进度：%.4f%%  ·  累计信仰：%s" % [
		clampf(campaign_progress, 0.0, 1.0) * 100.0,
		_format_number(maxf(0.0, lifetime_faith))
	]

	_draw_button.disabled = int(floor(faith_points)) < safe_cost
	if _draw_button.disabled:
		_draw_button.text = "信仰不足（需要 %s）" % _format_number(float(safe_cost))
	else:
		_draw_button.text = "消耗 %s 信仰进行召唤" % _format_number(float(safe_cost))

	var lines: Array[String] = []
	for entry_value in history:
		var entry: Dictionary = entry_value
		lines.append("[color=%s]%s · %s[/color]  [color=#c7d878]+ %.0f%% 全局产出[/color]" % [
			String(entry.get("color", "#b8c4b2")),
			String(entry.get("rarity", "普通")),
			String(entry.get("name", "未知赐福")),
			maxf(0.0, float(entry.get("bonus", 0.0))) * 100.0
		])
	_history_label.text = "\n".join(lines) if not lines.is_empty() else "[color=#879087]尚未获得任何增量赐福。[/color]"


func show_result(buff: Dictionary) -> void:
	if _result_label == null or buff.is_empty():
		return

	_result_label.text = "[center][color=%s][font_size=25]%s[/font_size][/color]\n[color=#d7cfaa]%s · 永久全局产出 +%.0f%%[/color]\n[color=#98a397]%s[/color][/center]" % [
		String(buff.get("color", "#b8c4b2")),
		String(buff.get("name", "未知赐福")),
		String(buff.get("rarity", "普通")),
		maxf(0.0, float(buff.get("bonus", 0.0))) * 100.0,
		String(buff.get("description", ""))
	]


func _create_content() -> void:
	var root := PanelContainer.new()
	root.name = "GachaRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(margin)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(CONTENT_WIDTH, 1.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(CONTENT_WIDTH, 40.0)
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	var title_label := _make_label("禁忌召唤", 30, Color(0.94, 0.82, 0.52))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42, 38)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62))
	close_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.07, 0.06, 0.72), Color(0.32, 0.34, 0.25, 0.72)))
	close_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.14, 0.13, 0.09, 0.9), Color(0.68, 0.58, 0.3, 0.92)))
	close_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.2, 0.16, 0.08, 0.94), Color(0.82, 0.67, 0.31, 0.96)))
	close_button.pressed.connect(close_window)
	header.add_child(close_button)

	var subtitle := _make_label("献上信仰，获得永久增量赐福。每次召唤后，下次消耗都会提高。", 15, Color(0.67, 0.7, 0.62))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(CONTENT_WIDTH, 38.0)
	content.add_child(subtitle)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(CONTENT_WIDTH, 108.0)
	status_panel.add_theme_stylebox_override("panel", _make_section_style())
	content.add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 14)
	status_margin.add_theme_constant_override("margin_top", 8)
	status_margin.add_theme_constant_override("margin_right", 14)
	status_margin.add_theme_constant_override("margin_bottom", 8)
	status_panel.add_child(status_margin)

	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 3)
	status_margin.add_child(status)
	_faith_label = _make_label("持有信仰：0", 17, Color(0.82, 0.94, 0.72))
	_cost_label = _make_label("第 1 次召唤  ·  本次消耗：75 信仰", 17, Color(0.9, 0.8, 0.63))
	_multiplier_label = _make_label("永久信仰产出倍率：×1.000", 17, Color(0.68, 0.9, 0.82))
	_progress_label = _make_label("远古苏醒进度：0.0000%  ·  累计信仰：0", 15, Color(0.68, 0.7, 0.62))
	status.add_child(_faith_label)
	status.add_child(_cost_label)
	status.add_child(_multiplier_label)
	status.add_child(_progress_label)

	var result_panel := PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(CONTENT_WIDTH, 132.0)
	result_panel.add_theme_stylebox_override("panel", _make_result_style())
	content.add_child(result_panel)

	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 12)
	result_margin.add_theme_constant_override("margin_top", 12)
	result_margin.add_theme_constant_override("margin_right", 12)
	result_margin.add_theme_constant_override("margin_bottom", 12)
	result_panel.add_child(result_margin)

	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = false
	_result_label.scroll_active = false
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_label.text = "[center][color=#aab5a8]献上信仰，聆听深渊的回应。[/color]\n[color=#788278]抽取的赐福会永久叠加。[/color][/center]"
	_result_label.add_theme_font_size_override("normal_font_size", 16)
	_result_label.add_theme_color_override("default_color", Color(0.78, 0.82, 0.74))
	result_margin.add_child(_result_label)

	_draw_button = Button.new()
	_draw_button.text = "消耗 75 信仰进行召唤"
	_draw_button.custom_minimum_size = Vector2(CONTENT_WIDTH, 52.0)
	_draw_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_draw_button.add_theme_font_size_override("font_size", 20)
	_draw_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	_draw_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.76))
	_draw_button.add_theme_color_override("font_disabled_color", Color(0.48, 0.49, 0.43))
	_draw_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.13, 0.08, 0.96), Color(0.58, 0.53, 0.28, 0.94)))
	_draw_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.18, 0.19, 0.1, 0.98), Color(0.82, 0.7, 0.32, 0.98)))
	_draw_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.08, 0.1, 0.06, 0.98), Color(0.72, 0.79, 0.42, 0.98)))
	_draw_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.055, 0.06, 0.052, 0.94), Color(0.24, 0.25, 0.2, 0.9)))
	_draw_button.pressed.connect(_on_draw_button_pressed)
	content.add_child(_draw_button)

	var history_title := _make_label("最近获得的增量赐福", 17, Color(0.9, 0.82, 0.62))
	history_title.custom_minimum_size = Vector2(CONTENT_WIDTH, 24.0)
	history_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	content.add_child(history_title)

	var history_panel := PanelContainer.new()
	history_panel.custom_minimum_size = Vector2(CONTENT_WIDTH, 134.0)
	history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_panel.add_theme_stylebox_override("panel", _make_section_style())
	content.add_child(history_panel)

	var history_margin := MarginContainer.new()
	history_margin.add_theme_constant_override("margin_left", 12)
	history_margin.add_theme_constant_override("margin_top", 8)
	history_margin.add_theme_constant_override("margin_right", 12)
	history_margin.add_theme_constant_override("margin_bottom", 8)
	history_panel.add_child(history_margin)

	_history_label = RichTextLabel.new()
	_history_label.bbcode_enabled = true
	_history_label.scroll_active = true
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_label.text = "[color=#879087]尚未获得任何增量赐福。[/color]"
	_history_label.add_theme_font_size_override("normal_font_size", 15)
	_history_label.add_theme_color_override("default_color", Color(0.76, 0.8, 0.72))
	history_margin.add_child(_history_label)


func _on_draw_button_pressed() -> void:
	if _draw_button == null or _draw_button.disabled:
		return
	draw_requested.emit()


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.02))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	var font := load(UI_FONT) as Font
	if font != null:
		ui_theme.default_font = font
	return ui_theme


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.022, 0.985)
	style.border_color = Color(0.54, 0.48, 0.28, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 12
	return style


func _make_section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.037, 0.032, 0.86)
	style.border_color = Color(0.28, 0.34, 0.25, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _make_result_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.044, 0.035, 0.94)
	style.border_color = Color(0.48, 0.46, 0.25, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _center_window() -> void:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	position = usable.position + ((usable.size - size) / 2)


func _format_number(value: float) -> String:
	var absolute := absf(value)
	if absolute >= 1.0e15:
		return "%.2fQa" % (value / 1.0e15)
	if absolute >= 1.0e12:
		return "%.2fT" % (value / 1.0e12)
	if absolute >= 1.0e9:
		return "%.2fB" % (value / 1.0e9)
	if absolute >= 1.0e6:
		return "%.2fM" % (value / 1.0e6)
	if absolute >= 1000.0:
		return "%.2fK" % (value / 1000.0)
	if absolute >= 10.0:
		return "%.0f" % value
	return "%.2f" % value
