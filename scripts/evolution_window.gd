extends Window

signal dismissed

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const WINDOW_SIZE := Vector2i(760, 470)

var _pet_id := ""
var _language := "zh"
var _root: Control
var _title_label: Label
var _before_icon: TextureRect
var _after_icon: TextureRect
var _before_label: Label
var _after_label: Label
var _hint_label: Label
var _confirm_button: Button
var _cancel_button: Button


func setup(language_code := "zh") -> void:
	_language = "en" if language_code == "en" else "zh"
	name = "EvolutionWindow"
	title = "Pet Evolution" if _language == "en" else "宠物进化"
	size = WINDOW_SIZE
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	always_on_top = false
	visible = false
	close_requested.connect(close_window)
	_create_content()


func set_language(language_code: String) -> void:
	_language = "en" if language_code == "en" else "zh"
	title = "Pet Evolution" if _language == "en" else "宠物进化"
	_refresh_language()


func open_for_pet(pet_id: String, display_name: String, level: int) -> void:
	if not PetCatalog.can_evolve(pet_id) or level < 100:
		return
	_pet_id = pet_id
	var base_data := PetCatalog.get_definition(pet_id)
	var evolved_data := PetCatalog.get_evolution_definition(pet_id)
	_before_icon.texture = PetCatalog.make_icon_texture(String(base_data.get("icon", "")), 8)
	_after_icon.texture = PetCatalog.make_icon_texture(String(evolved_data.get("icon", base_data.get("icon", ""))), 8)
	_before_label.text = "%s\nLv.%d" % [display_name, level]
	_after_label.text = String(evolved_data.get("evolution_name", "%s · 进化" % display_name))
	_hint_label.text = (
		"Evolution completed at Lv.100. Combat power is now ×%.2f and production ×%.2f."
		if _language == "en"
		else "达到 Lv.100 后进化完成。战斗力提升至 ×%.2f，信仰与金币产出提升至 ×%.2f。"
	) % [PetCatalog.EVOLUTION_POWER_MULTIPLIER, PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER]
	_cancel_button.visible = false
	_refresh_language()
	_center_window()
	visible = true
	_root.modulate = Color(1, 1, 1, 0)
	_root.scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate", Color.WHITE, 0.18)
	tween.parallel().tween_property(_root, "scale", Vector2.ONE, 0.18)


func close_window() -> void:
	var was_showing_pet := not _pet_id.is_empty()
	visible = false
	_pet_id = ""
	if was_showing_pet:
		dismissed.emit()


func _create_content() -> void:
	_root = Control.new()
	_root.name = "EvolutionRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.pivot_offset = Vector2(WINDOW_SIZE) * 0.5
	add_child(_root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	_title_label = _make_label("形态进化", 30, Color(0.96, 0.82, 0.42))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)
	var forms := HBoxContainer.new()
	forms.alignment = BoxContainer.ALIGNMENT_CENTER
	forms.add_theme_constant_override("separation", 22)
	content.add_child(forms)
	var before_panel := _make_form_panel()
	forms.add_child(before_panel)
	_before_icon = before_panel.get_node("FormContent/FormIcon") as TextureRect
	_before_label = before_panel.get_node("FormContent/FormLabel") as Label
	var arrow := _make_label("➜", 44, Color(0.88, 0.72, 0.34))
	arrow.custom_minimum_size = Vector2(64, 180)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forms.add_child(arrow)
	var after_panel := _make_form_panel()
	forms.add_child(after_panel)
	_after_icon = after_panel.get_node("FormContent/FormIcon") as TextureRect
	_after_label = after_panel.get_node("FormContent/FormLabel") as Label
	_hint_label = _make_label("", 15, Color(0.72, 0.76, 0.64))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)
	_cancel_button = Button.new()
	_cancel_button.custom_minimum_size = Vector2(150, 42)
	_cancel_button.pressed.connect(close_window)
	_style_button(_cancel_button, false)
	actions.add_child(_cancel_button)
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(210, 42)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_style_button(_confirm_button, true)
	actions.add_child(_confirm_button)
	_refresh_language()


func _make_form_panel() -> PanelContainer:
	var form_panel := PanelContainer.new()
	form_panel.custom_minimum_size = Vector2(245, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.045, 0.96)
	style.border_color = Color(0.42, 0.42, 0.24, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	form_panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.name = "FormContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	form_panel.add_child(content)
	var icon := TextureRect.new()
	icon.name = "FormIcon"
	icon.custom_minimum_size = Vector2(185, 158)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon)
	var label := _make_label("", 18, Color(0.9, 0.84, 0.64))
	label.name = "FormLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	return form_panel


func _on_confirm_pressed() -> void:
	if _pet_id.is_empty():
		return
	close_window()


func _refresh_language() -> void:
	if _title_label == null:
		return
	_title_label.text = "EVOLUTION COMPLETE" if _language == "en" else "进化完成"
	_cancel_button.text = "CLOSE" if _language == "en" else "关闭"
	_confirm_button.text = "GOT IT" if _language == "en" else "知道了"


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
	button.add_theme_color_override("font_color", Color(0.08, 0.1, 0.065) if primary else Color(0.86, 0.82, 0.64))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.7, 0.34) if primary else Color(0.055, 0.095, 0.075)
	style.border_color = Color(0.96, 0.84, 0.44) if primary else Color(0.4, 0.43, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.025, 0.021, 0.99)
	style.border_color = Color(0.72, 0.58, 0.25, 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 18
	return style


func _center_window() -> void:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	position = usable.position + ((usable.size - WINDOW_SIZE) / 2)
