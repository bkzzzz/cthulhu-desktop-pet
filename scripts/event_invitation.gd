extends Node2D

const LanguageSettings = preload("res://scripts/domain/language_settings.gd")

signal accepted(event_type: String)
signal discarded(event_type: String)
signal expired(event_type: String)

const INPUT_UPDATE_INTERVAL := 1.0 / 15.0
const ICON_SIZE := {
	"pilgrimage": Vector2(92.0, 92.0),
	"battle": Vector2(118.0, 86.0)
}

var event_type := ""
var _window_size := Vector2i.ZERO
var _ground_y := 0.0
var _velocity_y := 0.0
var _settled := false
var _age := 0.0
var _input_update_time := 0.0
var _visual_window: Window
var _input_window: Window
var _sprite: Sprite2D
var _icon_button: Button
var _prompt_panel: PanelContainer
var _prompt_open := false
var _resolved := false
var _language := LanguageSettings.DEFAULT_LANGUAGE
var _difficulty_text := ""
var _difficulty_text_en := ""
var _difficulty_text_zh := ""


func setup(
	new_event_type: String,
	texture_path: String,
	window_size: Vector2i,
	ground_y: float,
	spawn_x: float,
	language_code := LanguageSettings.DEFAULT_LANGUAGE,
	difficulty_text := "",
	difficulty_text_en := "",
	difficulty_text_zh := ""
) -> void:
	event_type = new_event_type
	_window_size = window_size
	_ground_y = ground_y
	_language = LanguageSettings.sanitize(language_code)
	_difficulty_text_en = difficulty_text_en.strip_edges()
	_difficulty_text_zh = difficulty_text_zh.strip_edges()
	if _difficulty_text_en.is_empty() and _language == "en":
		_difficulty_text_en = difficulty_text.strip_edges()
	if _difficulty_text_zh.is_empty() and _language == "zh":
		_difficulty_text_zh = difficulty_text.strip_edges()
	_refresh_difficulty_text(difficulty_text)
	position = Vector2(spawn_x, -72.0)
	_create_sprite(texture_path)


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	_refresh_difficulty_text()
	if _input_window != null:
		_input_window.theme = LanguageSettings.make_ui_theme(_language)
		_input_window.title = "Desktop Event" if _language == "en" else "桌面事件"
	_refresh_icon_tooltip()
	if _prompt_open and _prompt_panel != null:
		_input_window.remove_child(_prompt_panel)
		_prompt_panel.queue_free()
		_prompt_panel = null
		_prompt_open = false
		_open_prompt()


func _refresh_difficulty_text(fallback_text := "") -> void:
	var localized_text := _difficulty_text_en if _language == "en" else _difficulty_text_zh
	if localized_text.is_empty():
		localized_text = fallback_text.strip_edges()
	if localized_text.is_empty():
		localized_text = _difficulty_text
	_difficulty_text = localized_text


func _ready() -> void:
	_visual_window = get_window()
	_create_input_window()
	_update_input_window()


func set_window_bounds(window_size: Vector2i, ground_y: float) -> void:
	_window_size = window_size
	_ground_y = ground_y
	position.x = clampf(position.x, 56.0, maxf(56.0, float(_window_size.x) - 56.0))
	if _settled:
		position.y = _get_floor_y()
	_update_input_window()


func _exit_tree() -> void:
	if _input_window != null and is_instance_valid(_input_window):
		_input_window.visible = false


func _process(delta: float) -> void:
	if _resolved:
		return
	var safe_delta := maxf(0.0, delta)
	_age += safe_delta
	if not _settled:
		_velocity_y += 980.0 * safe_delta
		position.y += _velocity_y * safe_delta
		var floor_y := _get_floor_y()
		if position.y >= floor_y:
			position.y = floor_y
			if absf(_velocity_y) > 105.0:
				_velocity_y *= -0.28
			else:
				_velocity_y = 0.0
				_settled = true
				_start_settle_animation()
	elif not _prompt_open:
		position.y = _get_floor_y() + sin(_age * 2.4) * 2.5

	_input_update_time += safe_delta
	if _input_update_time >= INPUT_UPDATE_INTERVAL:
		_input_update_time = 0.0
		_update_input_window()


func _create_sprite(texture_path: String) -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "EventInviteIcon"
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.centered = true
	_sprite.z_index = 360
	if _sprite.texture != null:
		var target_size: Vector2 = ICON_SIZE.get(event_type, Vector2(92.0, 92.0))
		var texture_size := Vector2(_sprite.texture.get_size())
		var scale_factor := minf(target_size.x / maxf(1.0, texture_size.x), target_size.y / maxf(1.0, texture_size.y))
		_sprite.scale = Vector2.ONE * scale_factor
	add_child(_sprite)


func _create_input_window() -> void:
	_input_window = Window.new()
	_input_window.name = "EventInvitationInput"
	_input_window.title = "Desktop Event" if _language == "en" else "桌面事件"
	_input_window.borderless = true
	_input_window.transparent = true
	_input_window.transparent_bg = true
	_input_window.unresizable = true
	_input_window.always_on_top = false
	_input_window.unfocusable = true
	_input_window.theme = LanguageSettings.make_ui_theme(_language)
	add_child(_input_window)

	_icon_button = Button.new()
	_icon_button.name = "InvitationIconButton"
	_icon_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_button.flat = true
	_icon_button.text = ""
	_icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_icon_tooltip()
	_icon_button.pressed.connect(_open_prompt)
	_input_window.add_child(_icon_button)
	_input_window.visible = true


func _refresh_icon_tooltip() -> void:
	if _icon_button == null:
		return
	_icon_button.tooltip_text = (
		("Battle invitation" if event_type == "battle" else "Pilgrimage invitation")
		if _language == "en"
		else ("战斗事件邀请" if event_type == "battle" else "朝圣事件邀请")
	)
	if event_type == "battle" and not _difficulty_text.is_empty():
		_icon_button.tooltip_text += "\n%s" % _difficulty_text


func _open_prompt() -> void:
	if _prompt_open or _resolved:
		return
	_prompt_open = true
	_icon_button.visible = false
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.065, 0.075, 0.97)
	style.border_color = Color(0.72, 0.58, 0.30, 0.96) if event_type == "battle" else Color(0.58, 0.72, 0.42, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 10
	_prompt_panel.add_theme_stylebox_override("panel", style)
	_input_window.add_child(_prompt_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 13)
	_prompt_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var title_label := Label.new()
	title_label.text = (
		("BATTLE INVITATION" if event_type == "battle" else "PILGRIMAGE INVITATION")
		if _language == "en"
		else ("战斗事件来袭" if event_type == "battle" else "教徒朝圣邀请")
	)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56, 1.0))
	content.add_child(title_label)
	var description := Label.new()
	description.text = (
		("Enemies will attack from the left" if event_type == "battle" else "Enter a short pilgrimage challenge")
		if _language == "en"
		else ("敌人将从桌面左侧进攻" if event_type == "battle" else "接受后进入限时朝圣小游戏")
	)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.82, 0.82, 0.78, 1.0))
	content.add_child(description)
	if event_type == "battle" and not _difficulty_text.is_empty():
		var difficulty_label := Label.new()
		difficulty_label.name = "BattleDifficulty"
		difficulty_label.text = _difficulty_text
		difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		difficulty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		difficulty_label.custom_minimum_size = Vector2(0.0, 86.0)
		difficulty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty_label.add_theme_font_size_override("font_size", 16)
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.64, 0.32, 1.0))
		content.add_child(difficulty_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var accept_button := Button.new()
	accept_button.text = "ACCEPT" if _language == "en" else "接受"
	accept_button.custom_minimum_size = Vector2(104, 34)
	accept_button.pressed.connect(_resolve.bind(true, false))
	actions.add_child(accept_button)
	var discard_button := Button.new()
	discard_button.text = "DISCARD" if _language == "en" else "丢弃"
	discard_button.custom_minimum_size = Vector2(104, 34)
	discard_button.pressed.connect(_resolve.bind(false, false))
	actions.add_child(discard_button)
	_update_input_window()


func _update_input_window() -> void:
	if _input_window == null or _visual_window == null:
		return
	if _prompt_open:
		var available_width := maxi(280, _window_size.x - 16)
		var prompt_size := (
			Vector2i(mini(520, available_width), 258)
			if event_type == "battle" and not _difficulty_text.is_empty()
			else Vector2i(mini(360, available_width), 176)
		)
		prompt_size.y = mini(prompt_size.y, maxi(150, _window_size.y - 16))
		var local_x := clampi(int(round(position.x - prompt_size.x * 0.5)), 8, maxi(8, _window_size.x - prompt_size.x - 8))
		var local_y := clampi(int(round(position.y - prompt_size.y - 58.0)), 8, maxi(8, _window_size.y - prompt_size.y - 8))
		_input_window.position = _visual_window.position + Vector2i(local_x, local_y)
		_input_window.size = prompt_size
		_input_window.mouse_passthrough_polygon = PackedVector2Array()
		return
	var visual_size: Vector2 = ICON_SIZE.get(event_type, Vector2(92.0, 92.0))
	var proxy_size := Vector2i(int(ceil(visual_size.x + 16.0)), int(ceil(visual_size.y + 16.0)))
	var local_position := Vector2i(
		int(round(position.x - proxy_size.x * 0.5)),
		int(round(position.y - proxy_size.y * 0.5))
	)
	_input_window.position = _visual_window.position + local_position
	_input_window.size = proxy_size
	_input_window.mouse_passthrough_polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(proxy_size.x, 0.0),
		Vector2(proxy_size),
		Vector2(0.0, proxy_size.y)
	])


func _get_floor_y() -> float:
	var visual_size: Vector2 = ICON_SIZE.get(event_type, Vector2(92.0, 92.0))
	return _ground_y - visual_size.y * 0.5 - 2.0


func _start_settle_animation() -> void:
	if _sprite == null:
		return
	var base_scale := _sprite.scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", base_scale * Vector2(1.13, 0.88), 0.08)
	tween.tween_property(_sprite, "scale", base_scale, 0.18)


func _resolve(was_accepted: bool, was_expired := false) -> void:
	if _resolved:
		return
	_resolved = true
	if _input_window != null:
		_input_window.visible = false
	if was_expired:
		expired.emit(event_type)
	elif was_accepted:
		accepted.emit(event_type)
	else:
		discarded.emit(event_type)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.72, 0.18)
	tween.tween_callback(queue_free)
