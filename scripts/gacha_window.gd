extends Window

signal draw_requested(draw_amount: int)

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")
const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")

const WINDOW_SIZE := Vector2i(570, 798)
const CONTENT_WIDTH := 538.0
const GACHA_UI_TEXTURE := "res://assets/ui/gacha/gachaUI.png"
const GACHA_MACHINE_TEXTURE := "res://assets/ui/gacha/gacha.png"
const GACHA_EGG_TEXTURE := "res://assets/ui/gacha/egg.png"
const MACHINE_SIZE := Vector2(501.0, 501.0)
const EGG_NODE_SIZE := Vector2(72.0, 72.0)
const EGG_COUNT := 15
const EGG_MOTION_STEPS := 8
const EGG_MOTION_STEP_SECONDS := 0.15
const EGG_POSITION_BOUNDS := Rect2(115.0, 108.0, 193.0, 88.0)
const EGG_HOME_POSITIONS := [
	Vector2(132.0, 176.0),
	Vector2(164.0, 176.0),
	Vector2(196.0, 176.0),
	Vector2(228.0, 176.0),
	Vector2(260.0, 176.0),
	Vector2(292.0, 176.0),
	Vector2(146.0, 150.0),
	Vector2(180.0, 150.0),
	Vector2(214.0, 150.0),
	Vector2(248.0, 150.0),
	Vector2(282.0, 150.0),
	Vector2(164.0, 124.0),
	Vector2(204.0, 124.0),
	Vector2(244.0, 124.0),
	Vector2(284.0, 124.0)
]
const STAR_COLORS := [
	"#b8c4b2",
	"#a9c6a0",
	"#78c7b8",
	"#8caee8",
	"#f0cf86"
]

var _result_title: Label
var _result_detail: RichTextLabel
var _result_icon: TextureRect
var _result_progress: Label
var _result_action_button: Button
var _result_skip_all_button: Button
var _result_overlay: Control
var _draw_button: Button
var _progress_label: Label
var _draw_amount_buttons: Dictionary = {}
var _custom_draw_input: LineEdit
var _custom_draw_row: Control
var _selected_draw_preset := 1
var _updating_custom_input := false
var _machine_view: TextureRect
var _machine_stage: Control
var _egg_views: Array[TextureRect] = []
var _egg_home_positions: Array[Vector2] = []
var _animation_tween: Tween
var _animation_playing := false
var _draw_request_pending := false
var _pending_results: Array[Dictionary] = []
var _prepared_batch_summary: Dictionary = {}
var _result_index := 0
var _showing_batch_summary := false
var _coin_balance := 0.0
var _next_cost := GachaProgression.BASE_DRAW_COST
var _draw_count := 0
var _faith_growth_rate := 0.0
var _unlocked_pet_ids: Array = []
var _rng := RandomNumberGenerator.new()
var _language := LanguageSettings.DEFAULT_LANGUAGE


func setup() -> void:
	name = "GachaWindow"
	title = "宠物扭蛋"
	unresizable = true
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	theme = _make_ui_theme()
	visible = false
	_rng.randomize()
	close_requested.connect(close_window)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, DisplayLayout.get_current_usable_rect(self))
	_create_content()
	_create_result_overlay()
	set_language(_language)
	_center_window()


func open_window() -> void:
	_center_window()
	visible = true


func close_window() -> void:
	visible = false


func refresh_state(
	coin_balance: float,
	draw_count: int,
	next_cost: int,
	unlocked_pet_ids: Array,
	_pity_count: int,
	_history: Array,
	faith_growth_rate := 0.0
) -> void:
	_coin_balance = maxf(0.0, coin_balance)
	_draw_count = maxi(0, draw_count)
	_next_cost = maxi(1, next_cost)
	_unlocked_pet_ids = unlocked_pet_ids.duplicate()
	_faith_growth_rate = maxf(0.0, faith_growth_rate)
	_update_draw_button()
	_update_progress_label()


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	theme = _make_ui_theme()
	_refresh_draw_amount_labels()
	title = "Pet Gacha" if _language == "en" else "宠物扭蛋"
	if _result_skip_all_button != null:
		_result_skip_all_button.text = "SKIP ALL" if _language == "en" else "全部跳过"
	if _pending_results.is_empty() or _animation_playing:
		if _result_title != null:
			_result_title.text = "WAITING FOR DRAW" if _language == "en" else "等待抽取"
		if _result_detail != null:
			_result_detail.text = "[center]Waiting for a gacha result[/center]" if _language == "en" else "[center]等待扭蛋结果[/center]"
	elif _result_overlay != null and _result_overlay.visible:
		if _showing_batch_summary:
			_show_batch_summary()
		else:
			_reveal_current_result(false)
	_update_draw_button()
	_update_progress_label()


func show_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	show_results([result])


func show_results(results: Array, batch_summary: Dictionary = {}) -> void:
	_pending_results.clear()
	for result_value in results:
		if result_value is Dictionary and not (result_value as Dictionary).is_empty():
			_pending_results.append(result_value as Dictionary)
	_prepared_batch_summary = batch_summary.duplicate(true)
	_result_index = 0
	if not _animation_playing:
		_reveal_current_result()


func set_draw_request_pending(pending: bool) -> void:
	_draw_request_pending = pending
	_update_draw_button()


func is_draw_request_pending() -> bool:
	return _draw_request_pending


func _create_content() -> void:
	var root := Control.new()
	root.name = "GachaRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var background := TextureRect.new()
	background.name = "GachaBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = load(GACHA_UI_TEXTURE) as Texture2D
	root.add_child(background)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(CONTENT_WIDTH, 1.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var close_row := HBoxContainer.new()
	close_row.custom_minimum_size = Vector2(CONTENT_WIDTH, 36.0)
	content.add_child(close_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 23)
	_apply_button_styles(close_button, true)
	close_button.pressed.connect(close_window)
	close_row.add_child(close_button)

	var machine_center := CenterContainer.new()
	machine_center.custom_minimum_size = Vector2(CONTENT_WIDTH, MACHINE_SIZE.y)
	machine_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(machine_center)

	_machine_stage = Control.new()
	_machine_stage.name = "GachaMachineStage"
	_machine_stage.custom_minimum_size = MACHINE_SIZE
	_machine_stage.size = MACHINE_SIZE
	_machine_stage.clip_contents = true
	_machine_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine_center.add_child(_machine_stage)
	_create_egg_pile()

	_machine_view = TextureRect.new()
	_machine_view.name = "GachaMachine"
	_machine_view.position = Vector2.ZERO
	_machine_view.size = MACHINE_SIZE
	_machine_view.custom_minimum_size = MACHINE_SIZE
	_machine_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_machine_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_machine_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_machine_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine_view.texture = load(GACHA_MACHINE_TEXTURE) as Texture2D
	_machine_view.z_index = 10
	_machine_stage.add_child(_machine_view)

	var button_center := CenterContainer.new()
	button_center.custom_minimum_size = Vector2(CONTENT_WIDTH, 54.0)
	button_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(button_center)
	_draw_button = Button.new()
	_draw_button.name = "DrawPetButton"
	_draw_button.text = "扭蛋  ·  $%d 金币" % GachaProgression.draw_cost(0)
	_draw_button.custom_minimum_size = Vector2(332.0, 54.0)
	_draw_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_draw_button.add_theme_font_size_override("font_size", 21)
	_apply_button_styles(_draw_button, false)
	_draw_button.pressed.connect(_on_draw_button_pressed)
	button_center.add_child(_draw_button)
	_progress_label = _make_label("", 14, Color(0.72, 0.78, 0.60))
	_progress_label.name = "GachaFaithProgress"
	_progress_label.custom_minimum_size = Vector2(CONTENT_WIDTH, 25.0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(_progress_label)

	var amount_card := PanelContainer.new()
	amount_card.name = "DrawAmountCard"
	amount_card.custom_minimum_size = Vector2(CONTENT_WIDTH - 56.0, 86.0)
	amount_card.add_theme_stylebox_override(
		"panel",
		_make_button_style(Color(0.025, 0.075, 0.06, 0.96), Color(0.32, 0.38, 0.22, 0.9), false)
	)
	content.add_child(amount_card)
	var amount_margin := MarginContainer.new()
	amount_margin.add_theme_constant_override("margin_left", 12)
	amount_margin.add_theme_constant_override("margin_top", 8)
	amount_margin.add_theme_constant_override("margin_right", 12)
	amount_margin.add_theme_constant_override("margin_bottom", 8)
	amount_card.add_child(amount_margin)
	var amount_content := VBoxContainer.new()
	amount_content.add_theme_constant_override("separation", 7)
	amount_margin.add_child(amount_content)
	var amount_title := _make_label("抽取次数", 14, Color(0.69, 0.74, 0.57))
	amount_title.name = "DrawAmountTitle"
	amount_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_content.add_child(amount_title)
	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 7)
	amount_content.add_child(amount_row)
	for amount in [1, 10, 100, 1000, -1]:
		var amount_button := Button.new()
		amount_button.name = "DrawAmount%s" % ("Custom" if amount < 0 else str(amount))
		amount_button.text = "自定义" if amount < 0 else "×%d" % amount
		amount_button.custom_minimum_size = Vector2(86.0 if amount < 0 else 69.0, 35.0)
		amount_button.toggle_mode = true
		amount_button.button_pressed = amount == 1
		amount_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		amount_button.add_theme_font_size_override("font_size", 15)
		amount_button.pressed.connect(_on_draw_amount_preset_pressed.bind(amount))
		amount_row.add_child(amount_button)
		_draw_amount_buttons[amount] = amount_button
	_custom_draw_row = HBoxContainer.new()
	_custom_draw_row.name = "CustomDrawAmountRow"
	_custom_draw_row.visible = false
	(_custom_draw_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_custom_draw_row as HBoxContainer).add_theme_constant_override("separation", 8)
	amount_content.add_child(_custom_draw_row)
	var custom_label := _make_label("自定义数量", 14, Color(0.76, 0.79, 0.63))
	_custom_draw_row.add_child(custom_label)
	_custom_draw_input = LineEdit.new()
	_custom_draw_input.name = "CustomDrawAmount"
	_custom_draw_input.custom_minimum_size = Vector2(154.0, 35.0)
	_custom_draw_input.placeholder_text = "1 - %d" % GachaProgression.MAX_BATCH_DRAWS
	_custom_draw_input.text = "100"
	_custom_draw_input.max_length = 7
	_custom_draw_input.select_all_on_focus = true
	_custom_draw_input.add_theme_font_size_override("font_size", 17)
	_custom_draw_input.add_theme_color_override("font_color", Color(0.96, 0.88, 0.65))
	_custom_draw_input.add_theme_color_override("caret_color", Color(0.98, 0.82, 0.38))
	_custom_draw_input.add_theme_stylebox_override("normal", _make_button_style(Color(0.01, 0.04, 0.032, 1.0), Color(0.5, 0.48, 0.27, 0.92), true))
	_custom_draw_input.add_theme_stylebox_override("focus", _make_button_style(Color(0.035, 0.09, 0.07, 1.0), Color(0.86, 0.7, 0.3, 1.0), true))
	_custom_draw_input.text_changed.connect(_on_custom_draw_text_changed)
	_custom_draw_input.text_submitted.connect(_on_custom_draw_text_submitted)
	_custom_draw_row.add_child(_custom_draw_input)
	_refresh_draw_amount_labels()
	_update_draw_amount_button_styles()


func _create_egg_pile() -> void:
	_egg_views.clear()
	_egg_home_positions.clear()
	var egg_texture := load(GACHA_EGG_TEXTURE) as Texture2D
	if egg_texture == null:
		return
	for egg_index in EGG_COUNT:
		var egg := TextureRect.new()
		egg.name = "Egg%02d" % (egg_index + 1)
		egg.position = EGG_HOME_POSITIONS[egg_index]
		egg.size = EGG_NODE_SIZE
		egg.custom_minimum_size = EGG_NODE_SIZE
		egg.pivot_offset = EGG_NODE_SIZE * 0.5
		egg.rotation_degrees = _rng.randf_range(-32.0, 32.0)
		egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		egg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		egg.texture = egg_texture
		egg.z_index = 1 + egg_index % 4
		_machine_stage.add_child(egg)
		_egg_views.append(egg)
		_egg_home_positions.append(EGG_HOME_POSITIONS[egg_index])


func _create_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.name = "GachaResultOverlay"
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	_result_overlay.z_index = 100
	add_child(_result_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.01, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.add_child(center)

	var result_panel := PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(390.0, 474.0)
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.add_theme_stylebox_override("panel", _make_result_style())
	center.add_child(result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	result_panel.add_child(margin)

	var result_content := VBoxContainer.new()
	result_content.alignment = BoxContainer.ALIGNMENT_CENTER
	result_content.add_theme_constant_override("separation", 8)
	margin.add_child(result_content)

	_result_progress = _make_label("", 14, Color(0.64, 0.69, 0.61))
	_result_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_progress.custom_minimum_size = Vector2(342.0, 20.0)
	result_content.add_child(_result_progress)

	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(220.0, 220.0)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_content.add_child(_result_icon)

	_result_title = _make_label("等待抽取", 25, Color(0.84, 0.84, 0.72))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_content.add_child(_result_title)

	_result_detail = RichTextLabel.new()
	_result_detail.bbcode_enabled = true
	_result_detail.fit_content = false
	_result_detail.scroll_active = false
	_result_detail.custom_minimum_size = Vector2(342.0, 82.0)
	_result_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_detail.add_theme_font_size_override("normal_font_size", 18)
	_result_detail.add_theme_constant_override("line_separation", 3)
	_result_detail.add_theme_color_override("default_color", Color(0.74, 0.8, 0.72))
	_result_detail.text = "[center]等待扭蛋结果[/center]"
	result_content.add_child(_result_detail)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	result_content.add_child(action_row)
	_result_action_button = Button.new()
	_result_action_button.custom_minimum_size = Vector2(220.0, 46.0)
	_result_action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_result_action_button.add_theme_font_size_override("font_size", 18)
	_apply_button_styles(_result_action_button, false)
	_result_action_button.pressed.connect(_on_result_advance_pressed)
	action_row.add_child(_result_action_button)
	_result_skip_all_button = Button.new()
	_result_skip_all_button.custom_minimum_size = Vector2(112.0, 46.0)
	_result_skip_all_button.text = "SKIP ALL"
	_result_skip_all_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_result_skip_all_button.add_theme_font_size_override("font_size", 15)
	_apply_button_styles(_result_skip_all_button, true)
	_result_skip_all_button.pressed.connect(_show_batch_summary)
	_result_skip_all_button.visible = false
	action_row.add_child(_result_skip_all_button)


func _on_draw_button_pressed() -> void:
	if _draw_button == null or _draw_button.disabled or _animation_playing or _draw_request_pending:
		return
	_pending_results.clear()
	_prepared_batch_summary.clear()
	_result_index = 0
	_showing_batch_summary = false
	_result_overlay.visible = false
	_start_draw_animation()
	draw_requested.emit(_selected_draw_amount())


func _on_draw_amount_preset_pressed(amount: int) -> void:
	_selected_draw_preset = amount
	if _custom_draw_row != null:
		_custom_draw_row.visible = amount < 0
	_update_draw_amount_button_styles()
	_update_draw_button()
	if amount < 0 and _custom_draw_input != null:
		_custom_draw_input.call_deferred("grab_focus")


func _on_custom_draw_text_changed(new_text: String) -> void:
	if _updating_custom_input:
		return
	var digits := ""
	for index in new_text.length():
		var character := new_text.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
	if digits != new_text:
		_updating_custom_input = true
		_custom_draw_input.text = digits
		_custom_draw_input.caret_column = digits.length()
		_updating_custom_input = false
	_update_draw_button()


func _on_custom_draw_text_submitted(_new_text: String) -> void:
	_normalize_custom_draw_input()


func _normalize_custom_draw_input() -> void:
	if _custom_draw_input == null:
		return
	var amount := clampi(int(_custom_draw_input.text) if _custom_draw_input.text.is_valid_int() else 1, 1, GachaProgression.MAX_BATCH_DRAWS)
	_updating_custom_input = true
	_custom_draw_input.text = str(amount)
	_updating_custom_input = false
	_update_draw_button()


func _selected_draw_amount() -> int:
	if _selected_draw_preset > 0:
		return _selected_draw_preset
	if _custom_draw_input == null or not _custom_draw_input.text.is_valid_int():
		return 1
	return clampi(int(_custom_draw_input.text), 1, GachaProgression.MAX_BATCH_DRAWS)


func _selected_draw_cost() -> float:
	return GachaProgression.draw_cost_total(_draw_count, _selected_draw_amount())


func _start_draw_animation() -> void:
	_animation_playing = true
	_update_draw_button()
	if not is_inside_tree() or _egg_views.is_empty():
		_finish_draw_animation()
		return
	if _animation_tween != null and is_instance_valid(_animation_tween):
		_animation_tween.kill()
	_animation_tween = create_tween()
	for motion_step in EGG_MOTION_STEPS:
		_animation_tween.tween_callback(
			Callable(self, "_apply_egg_shuffle_step").bind(motion_step)
		)
		_animation_tween.tween_interval(EGG_MOTION_STEP_SECONDS)
	_animation_tween.tween_callback(_finish_draw_animation)


func _apply_egg_shuffle_step(motion_step: int) -> void:
	var shuffled_slots := _egg_home_positions.duplicate()
	for slot_index in range(shuffled_slots.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, slot_index)
		var slot_value: Vector2 = shuffled_slots[slot_index]
		shuffled_slots[slot_index] = shuffled_slots[swap_index]
		shuffled_slots[swap_index] = slot_value
	var is_final_beat := motion_step == EGG_MOTION_STEPS - 1
	for egg_index in _egg_views.size():
		var egg := _egg_views[egg_index]
		var throw_amount := 8.0 if is_final_beat else 24.0
		var target := Vector2(shuffled_slots[egg_index]) + Vector2(
			_rng.randf_range(-throw_amount, throw_amount),
			_rng.randf_range(-throw_amount * 0.8, throw_amount * 0.65)
		)
		egg.position = _clamp_egg_position(target)
		egg.rotation_degrees = _rng.randf_range(-58.0, 58.0)
		var squash := _rng.randf_range(0.88, 1.12)
		egg.scale = Vector2(squash, 2.0 - squash)
		egg.z_index = 1 + _rng.randi_range(0, 3)


func _clamp_egg_position(position_value: Vector2) -> Vector2:
	return Vector2(
		clampf(
			position_value.x,
			EGG_POSITION_BOUNDS.position.x,
			EGG_POSITION_BOUNDS.end.x - 0.001
		),
		clampf(
			position_value.y,
			EGG_POSITION_BOUNDS.position.y,
			EGG_POSITION_BOUNDS.end.y - 0.001
		)
	)


func _finish_draw_animation() -> void:
	_animation_playing = false
	_animation_tween = null
	_reveal_current_result()
	_update_draw_button()


func _reveal_current_result(animate := true) -> void:
	if _pending_results.is_empty() or _result_title == null:
		return
	_result_index = clampi(_result_index, 0, _pending_results.size() - 1)
	_showing_batch_summary = false
	var result := _pending_results[_result_index]
	var pet_id := String(result.get("pet_id", ""))
	var pet_data := PetCatalog.get_definition(pet_id)
	var pet_name := _get_result_pet_name(result)
	var stars := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
	var stars_text := "★".repeat(stars)
	var color := String(STAR_COLORS[stars - 1])
	var is_new := bool(result.get("is_new", false))
	_result_icon.texture = PetCatalog.make_icon_texture(String(pet_data.get("icon", "")), 10)
	_result_title.text = pet_name
	_result_title.add_theme_color_override(
		"font_color",
		Color.from_string(color, Color(0.9, 0.84, 0.62))
	)
	if is_new:
		_result_detail.text = (
			"[center][color=%s][font_size=21]%s[/font_size][/color]"
			+ ("\n[color=#b8c8b5]NEW PET  ·  SENT TO INVENTORY[/color][/center]" if _language == "en" else "\n[color=#b8c8b5]新宠物  ·  已进入仓库[/color][/center]")
		) % [color, stars_text]
	else:
		var duplicate_points := maxi(0, int(result.get("duplicate_faith", 0)))
		_result_detail.text = (
			"[center][color=%s][font_size=20]%s[/font_size][/color]"
			+ ("\n[color=#d8c675][font_size=29]DUPLICATE  +%s FAITH[/font_size][/color][/center]" if _language == "en" else "\n[color=#d8c675][font_size=29]重复获得  +%s 信仰[/font_size][/color][/center]")
		) % [color, stars_text, _format_number(float(duplicate_points))]
	_result_progress.text = (
		"%d / %d" % [_result_index + 1, _pending_results.size()]
		if _pending_results.size() > 1
		else ""
	)
	_result_action_button.text = (
		("SKIP  ›" if _language == "en" else "跳过  ›")
		if _result_index < _pending_results.size() - 1
		else (("DONE" if _pending_results.size() > 1 else "CLAIM") if _language == "en" else ("完成" if _pending_results.size() > 1 else "收下"))
	)
	if _result_skip_all_button != null:
		_result_skip_all_button.visible = _pending_results.size() > 1
	_result_overlay.visible = true
	_update_draw_button()
	if animate and is_inside_tree():
		_result_overlay.modulate = Color(1.0, 1.0, 1.0, 0.2)
		var tween := create_tween()
		tween.tween_property(_result_overlay, "modulate", Color.WHITE, 0.18)


func _on_result_advance_pressed() -> void:
	if _showing_batch_summary:
		_close_results()
		return
	if _result_index < _pending_results.size() - 1:
		_result_index += 1
		_reveal_current_result()
		return
	_close_results()


func _show_batch_summary() -> void:
	if _pending_results.is_empty():
		return
	var new_names: Array[String] = []
	var duplicate_faith_total := 0
	var first_new_pet_id := ""
	if not _prepared_batch_summary.is_empty():
		duplicate_faith_total = maxi(0, int(_prepared_batch_summary.get("duplicate_faith_total", 0)))
		first_new_pet_id = String(_prepared_batch_summary.get("first_new_pet_id", ""))
	var seen_new_ids := {}
	for result in _pending_results:
		if _prepared_batch_summary.is_empty():
			duplicate_faith_total += maxi(0, int(result.get("duplicate_faith", 0)))
		if not bool(result.get("is_new", false)):
			continue
		var pet_id := String(result.get("pet_id", ""))
		if seen_new_ids.has(pet_id):
			continue
		seen_new_ids[pet_id] = true
		if first_new_pet_id.is_empty():
			first_new_pet_id = pet_id
		new_names.append(_get_result_pet_name(result))
	_showing_batch_summary = true
	_result_progress.text = ("%d DRAWS" if _language == "en" else "%d 次") % _pending_results.size()
	_result_title.text = "BATCH RESULT" if _language == "en" else "批量扭蛋结果"
	if first_new_pet_id.is_empty():
		_result_icon.texture = load(GACHA_EGG_TEXTURE) as Texture2D
	else:
		var first_pet_data := PetCatalog.get_definition(first_new_pet_id)
		_result_icon.texture = PetCatalog.make_icon_texture(String(first_pet_data.get("icon", "")), 10)
	var new_text := "NONE" if new_names.is_empty() else (", " if _language == "en" else "、").join(new_names)
	_result_detail.text = (
		"[center]NEW PETS: %s\n[color=#d8c675][font_size=25]DUPLICATES  +%s FAITH[/font_size][/color][/center]"
		if _language == "en"
		else "[center]新宠物：%s\n[color=#d8c675][font_size=25]重复宠物合计  +%s 信仰[/font_size][/color][/center]"
	) % [new_text, _format_number(float(duplicate_faith_total))]
	_result_action_button.text = "DONE" if _language == "en" else "完成"
	_result_skip_all_button.visible = false


func _get_result_pet_name(result: Dictionary) -> String:
	var custom_name := String(result.get("custom_name", "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name
	var pet_id := String(result.get("pet_id", ""))
	if bool(result.get("use_localized_name", false)):
		return PetCatalog.get_localized_name(pet_id, _language)
	return String(result.get("name", PetCatalog.get_localized_name(pet_id, _language)))


func _close_results() -> void:
	_pending_results.clear()
	_prepared_batch_summary.clear()
	_result_index = 0
	_showing_batch_summary = false
	_result_overlay.visible = false
	_result_overlay.modulate = Color.WHITE
	if _result_skip_all_button != null:
		_result_skip_all_button.visible = false
	_update_draw_button()


func _refresh_draw_amount_labels() -> void:
	var title_label := find_child("DrawAmountTitle", true, false) as Label
	if title_label != null:
		title_label.text = "DRAW AMOUNT" if _language == "en" else "抽取次数"
	var custom_button := _draw_amount_buttons.get(-1) as Button
	if custom_button != null:
		custom_button.text = "CUSTOM" if _language == "en" else "自定义"
	if _custom_draw_row != null and _custom_draw_row.get_child_count() > 0:
		(_custom_draw_row.get_child(0) as Label).text = "Amount" if _language == "en" else "自定义数量"


func _update_draw_amount_button_styles() -> void:
	for amount_value in _draw_amount_buttons:
		var amount := int(amount_value)
		var button := _draw_amount_buttons[amount] as Button
		if button == null:
			continue
		var selected := amount == _selected_draw_preset
		button.set_pressed_no_signal(selected)
		button.add_theme_color_override("font_color", Color(0.08, 0.11, 0.07) if selected else Color(0.86, 0.84, 0.65))
		button.add_theme_stylebox_override(
			"normal",
			_make_button_style(
				Color(0.78, 0.72, 0.38, 1.0) if selected else Color(0.04, 0.11, 0.085, 1.0),
				Color(0.94, 0.82, 0.42, 1.0) if selected else Color(0.32, 0.4, 0.24, 0.9),
				true
			)
		)


func _update_draw_button() -> void:
	if _draw_button == null:
		return
	if _animation_playing or _draw_request_pending:
		_draw_button.disabled = true
		_draw_button.text = "DRAWING…" if _language == "en" else "扭蛋中…"
		return
	if _result_overlay != null and _result_overlay.visible:
		_draw_button.disabled = true
		return
	var draw_amount := _selected_draw_amount()
	var selected_cost := _selected_draw_cost()
	var selected_cost_text := CurrencyDisplay.format_compact(int(round(selected_cost)))
	_draw_button.disabled = floor(_coin_balance) < selected_cost
	if _draw_button.disabled:
		_draw_button.text = (
			"NOT ENOUGH GOLD  ·  %s" if _language == "en" else "金币不足  ·  %s"
		) % selected_cost_text
	elif draw_amount == 10:
		_draw_button.text = (
			"DRAW × 10  ·  %s" if _language == "en" else "扭蛋 × 10  ·  %s"
		) % selected_cost_text
	else:
		_draw_button.text = (
			"DRAW  ·  %s" if _language == "en" else "扭蛋  ·  %s"
		) % selected_cost_text
	if not _draw_button.disabled and draw_amount > 1:
		_draw_button.text = (
			"DRAW × %d  ·  %s" if _language == "en" else "扭蛋 × %d  ·  %s"
		) % [draw_amount, selected_cost_text]


func _update_progress_label() -> void:
	if _progress_label == null:
		return
	var owned_lookup := GachaProgression.make_unlocked_lookup(_unlocked_pet_ids)
	var next_entry := GachaProgression.get_next_progression_entry(owned_lookup)
	if next_entry.is_empty():
		_progress_label.text = (
			"ALL PET TIERS UNLOCKED"
			if _language == "en"
			else "鎵€鏈夊疇鐗╅樁绾у凡瑙ｉ攣"
		)
		return
	var pet_id := String(next_entry.get("pet_id", "pet"))
	var pet_tier := int(pet_id.trim_prefix("pet"))
	var required_rate := maxf(0.0, float(next_entry.get("min_faith_rate", 0.0)))
	if _faith_growth_rate + 0.000001 >= required_rate:
		_progress_label.text = (
			"PET %d AVAILABLE  ·  FAITH GATE OPEN" % pet_tier
			if _language == "en"
			else "\u5ba0\u7269 %d \u5df2\u8fdb\u5165\u5361\u6c60  ·  \u4fe1\u4ef0\u95e8\u69db\u5df2\u5f00\u542f" % pet_tier
		)
		return
	_progress_label.text = (
		"NEXT PET %d  ·  PERMANENT FAITH %s / %s per sec"
		if _language == "en"
		else "涓嬩竴瀹犵墿 %d  路  姘镐箙淇′话 %s / %s 姣忕"
	) % [
		pet_tier,
		_format_faith_rate(_faith_growth_rate),
		_format_faith_rate(required_rate)
	]


func _format_faith_rate(value: float) -> String:
	var safe_value := maxf(0.0, value)
	if safe_value < 10.0:
		return "%.2f" % safe_value
	return CurrencyDisplay.format_compact(int(round(safe_value)))


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.022))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_ui_theme() -> Theme:
	return LanguageSettings.make_ui_theme(_language)


func _make_result_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.07, 0.06, 0.995)
	style.border_color = Color(0.7, 0.58, 0.28, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	style.shadow_size = 18
	return style


func _apply_button_styles(button: Button, compact: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.45))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.13, 0.1, 0.98), Color(0.5, 0.48, 0.27, 0.92), compact))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.09, 0.2, 0.15, 0.99), Color(0.82, 0.7, 0.34, 0.98), compact))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.035, 0.1, 0.075, 0.99), Color(0.66, 0.77, 0.42, 0.98), compact))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.03, 0.065, 0.055, 0.96), Color(0.2, 0.27, 0.22, 0.9), compact))


func _make_button_style(background: Color, border: Color, compact: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8 if compact else 12
	style.content_margin_right = 8 if compact else 12
	return style


func _center_window() -> void:
	var usable_rect := DisplayLayout.get_current_usable_rect(self)
	DisplayLayout.apply_scaled_window(self, WINDOW_SIZE, usable_rect)


func _format_number(value: float) -> String:
	var absolute := absf(value)
	if absolute < 1000.0 and is_equal_approx(value, round(value)):
		return "%.0f" % value
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
