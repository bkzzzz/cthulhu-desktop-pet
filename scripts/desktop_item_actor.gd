extends Node2D

const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const InteractionHintTheme = preload("res://scripts/domain/interaction_hint_theme.gd")

signal grabbed_changed(actor: Node2D, grabbed: bool)
signal recall_requested(actor: Node2D)

const INPUT_PROXY_PADDING := 8.0
const INPUT_PROXY_REFRESH_SECONDS := 1.0 / 20.0
const INTERACTION_HINT_MIN_WIDTH := 154.0
const INTERACTION_HINT_MAX_WIDTH := 292.0
const INTERACTION_HINT_HORIZONTAL_PADDING := 12.0
const INTERACTION_HINT_VERTICAL_PADDING := 5.0
const INTERACTION_HINT_FONT_SIZE := 15
const INTERACTION_HINT_MIN_FONT_SIZE := 11
const INTERACTION_HINT_SAFE_MARGIN := 8.0
const INTERACTION_HINT_GAP := 14.0

var item_id := ""
var item_data: Dictionary = {}

var _window_size := Vector2i(820, 420)
var _stage_ground_y := 420.0
var _dragging := false
var _recall_pointer_held := false
var _pointer_hovered := false
var _grab_offset := Vector2.ZERO
var _visual_scale := 0.5
var _language := "zh"

var _sprite: Sprite2D
var _visual_window: Window
var _input_window: Window
var _interaction_area: Control
var _interaction_hint: PanelContainer
var _interaction_hint_action_label: Label
var _interaction_rect := Rect2()
var _input_proxy_elapsed := 0.0
var _last_proxy_position := Vector2i(-100000, -100000)
var _last_proxy_size := Vector2i.ZERO
var _last_proxy_visible := false


func _ready() -> void:
	_visual_window = get_window()
	_create_input_proxy()
	_refresh_input_proxy(true)
	_refresh_interaction_hint()


func _exit_tree() -> void:
	if _input_window != null and is_instance_valid(_input_window):
		_input_window.visible = false


func setup(new_item_id: String, start_position: Vector2, window_size: Vector2i) -> void:
	item_data = DesktopItemCatalog.normalize_item({"id": new_item_id})
	item_id = String(item_data.get("id", ""))
	_visual_scale = clampf(float(item_data.get("visual_scale", 0.5)), 0.10, 2.0)
	_dragging = false
	_recall_pointer_held = false
	_pointer_hovered = false
	_create_or_refresh_sprite()
	_create_input_proxy()
	_create_interaction_hint()
	_refresh_interaction_cursor()
	set_window_bounds(window_size)
	position = _clamp_to_window(start_position)
	if _sprite != null:
		_sprite.visible = true
		_sprite.modulate = Color.WHITE
	_refresh_input_proxy(true)
	_refresh_interaction_hint()


func set_language(language_code: String) -> void:
	_language = "en" if language_code.strip_edges().to_lower() == "en" else "zh"
	_refresh_interaction_hint()


# Items always remain grounded. Their visual base meets the desktop window's
# bottom edge, which is the taskbar contact line, with no vertical drag axis.
func set_window_bounds(new_window_size: Vector2i) -> void:
	_window_size = Vector2i(maxi(1, new_window_size.x), maxi(1, new_window_size.y))
	_stage_ground_y = float(_window_size.y)
	position = _clamp_to_window(position)
	_refresh_input_proxy(true)
	_refresh_interaction_hint()


func get_item_id() -> String:
	return item_id


func get_item_definition() -> Dictionary:
	return item_data.duplicate(true)


func is_pointer_captured() -> bool:
	return _dragging


func cancel_pointer_capture() -> void:
	_recall_pointer_held = false
	_finish_drag()


func get_interaction_rect() -> Rect2:
	return _interaction_rect


func is_point_over_opaque_pixel(window_position: Vector2) -> bool:
	return _interaction_rect.has_point(window_position)


func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	if _dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_drag_position()
		else:
			_finish_drag()
	_input_proxy_elapsed += safe_delta
	if _dragging or _input_proxy_elapsed >= INPUT_PROXY_REFRESH_SECONDS:
		_input_proxy_elapsed = 0.0
		_refresh_input_proxy()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _dragging:
		_update_drag_position()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and _dragging:
		_finish_drag()
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed and _recall_pointer_held:
		_finish_recall()
		get_viewport().set_input_as_handled()


func _create_or_refresh_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "DesktopItemSprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	# The sofa is a support surface, not foreground scenery.  Its pixels must
	# always render behind a pet that is walking past or resting on it. Other
	# taskbar goods keep their existing foreground depth.
	_sprite.z_index = -10 if item_id == "sofa" else 198
	_sprite.texture = load(String(item_data.get("texture", ""))) as Texture2D
	_sprite.scale = Vector2.ONE * _visual_scale
	_sprite.position = Vector2.ZERO
	_sprite.modulate = Color.WHITE


func _create_input_proxy() -> void:
	if _input_window != null:
		return
	_input_window = Window.new()
	_input_window.name = "DesktopItemInputWindow"
	_input_window.title = "Cthulu Desktop Item Input"
	_input_window.borderless = true
	_input_window.transparent = true
	_input_window.transparent_bg = true
	_input_window.unfocusable = true
	_input_window.unresizable = true
	_input_window.always_on_top = false
	_input_window.min_size = Vector2i.ZERO
	_input_window.size = Vector2i(32, 32)
	_input_window.visible = false
	add_child(_input_window)

	_interaction_area = Control.new()
	_interaction_area.name = "DesktopItemInteractionArea"
	_interaction_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_interaction_area.mouse_entered.connect(_set_pointer_hovered.bind(true))
	_interaction_area.mouse_exited.connect(_set_pointer_hovered.bind(false))
	_interaction_area.gui_input.connect(_on_gui_input)
	_input_window.add_child(_interaction_area)
	_refresh_interaction_cursor()


func _create_interaction_hint() -> void:
	if _interaction_hint != null:
		return
	_interaction_hint = PanelContainer.new()
	_interaction_hint.name = "DesktopItemInteractionHint"
	_interaction_hint.size = Vector2(INTERACTION_HINT_MIN_WIDTH, 30.0)
	_interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_hint.visible = false
	_interaction_hint.z_index = 220
	_interaction_hint.clip_contents = false
	_interaction_hint.add_theme_stylebox_override("panel", _make_interaction_hint_style())
	add_child(_interaction_hint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(INTERACTION_HINT_HORIZONTAL_PADDING))
	margin.add_theme_constant_override("margin_top", int(INTERACTION_HINT_VERTICAL_PADDING))
	margin.add_theme_constant_override("margin_right", int(INTERACTION_HINT_HORIZONTAL_PADDING))
	margin.add_theme_constant_override("margin_bottom", int(INTERACTION_HINT_VERTICAL_PADDING))
	_interaction_hint.add_child(margin)

	_interaction_hint_action_label = Label.new()
	_interaction_hint_action_label.name = "InteractionHintAction"
	_interaction_hint_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_hint_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_hint_action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_interaction_hint_action_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_interaction_hint_action_label.add_theme_font_size_override("font_size", INTERACTION_HINT_FONT_SIZE)
	_interaction_hint_action_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.62, 1.0))
	_interaction_hint_action_label.add_theme_color_override("font_outline_color", Color(0.025, 0.018, 0.01, 1.0))
	_interaction_hint_action_label.add_theme_constant_override("outline_size", 1)
	margin.add_child(_interaction_hint_action_label)


func _make_interaction_hint_style() -> StyleBoxFlat:
	return InteractionHintTheme.make_plaque_style()


func _set_pointer_hovered(hovered: bool) -> void:
	if _pointer_hovered == hovered:
		return
	_pointer_hovered = hovered
	_refresh_interaction_hint()


func _refresh_interaction_cursor() -> void:
	if _interaction_area != null:
		_interaction_area.mouse_default_cursor_shape = Control.CURSOR_MOVE


func _refresh_interaction_hint() -> void:
	if _interaction_hint == null:
		return
	_interaction_hint_action_label.text = _get_interaction_hint_text()
	_resize_interaction_hint_to_text()
	var visual_size := _get_visual_size()
	var hint_size := _interaction_hint.size
	var desired_global_position := position + Vector2(
		-hint_size.x * 0.5,
		-visual_size.y * 0.5 - hint_size.y - INTERACTION_HINT_GAP
	)
	var max_hint_x := maxf(
		INTERACTION_HINT_SAFE_MARGIN,
		float(_window_size.x) - hint_size.x - INTERACTION_HINT_SAFE_MARGIN
	)
	var max_hint_y := maxf(
		INTERACTION_HINT_SAFE_MARGIN,
		_stage_ground_y - hint_size.y - INTERACTION_HINT_SAFE_MARGIN
	)
	desired_global_position.x = clampf(
		desired_global_position.x,
		INTERACTION_HINT_SAFE_MARGIN,
		max_hint_x
	)
	desired_global_position.y = clampf(
		desired_global_position.y,
		INTERACTION_HINT_SAFE_MARGIN,
		max_hint_y
	)
	_interaction_hint.position = Vector2(
		desired_global_position.x - position.x,
		desired_global_position.y - position.y
	)
	var should_show := _pointer_hovered or _dragging
	_interaction_hint.visible = should_show


func _get_interaction_hint_text() -> String:
	return "DRAG · RMB RETURN" if _language == "en" else "左右拖动 · 右键收回"


func _resize_interaction_hint_to_text() -> void:
	if _interaction_hint == null or _interaction_hint_action_label == null:
		return
	var available_width := maxf(
		1.0,
		float(_window_size.x) - INTERACTION_HINT_SAFE_MARGIN * 2.0
	)
	var maximum_width := minf(INTERACTION_HINT_MAX_WIDTH, available_width)
	var minimum_width := minf(INTERACTION_HINT_MIN_WIDTH, maximum_width)
	var maximum_text_width := maxf(
		1.0,
		maximum_width - INTERACTION_HINT_HORIZONTAL_PADDING * 2.0
	)
	var font := _interaction_hint_action_label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := INTERACTION_HINT_FONT_SIZE
	var text_width := font.get_string_size(
		_interaction_hint_action_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	while font_size > INTERACTION_HINT_MIN_FONT_SIZE and text_width > maximum_text_width:
		font_size -= 1
		text_width = font.get_string_size(
			_interaction_hint_action_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
	_interaction_hint_action_label.add_theme_font_size_override("font_size", font_size)
	var height := maxf(
		30.0,
		font.get_height(font_size) + INTERACTION_HINT_VERTICAL_PADDING * 2.0
	)
	var width := clampf(
		text_width + INTERACTION_HINT_HORIZONTAL_PADDING * 2.0,
		minimum_width,
		maximum_width
	)
	var hint_size := Vector2(width, height)
	_interaction_hint.custom_minimum_size = hint_size
	_interaction_hint.size = hint_size


func _refresh_input_proxy(force := false) -> void:
	_interaction_rect = _get_visual_rect().grow(INPUT_PROXY_PADDING).intersection(
		Rect2(Vector2.ZERO, Vector2(_window_size))
	)
	if _input_window == null or _visual_window == null:
		return
	var should_be_visible := (
		_sprite != null
		and _sprite.visible
		and _interaction_rect.size.x > 0.0
		and _interaction_rect.size.y > 0.0
	)
	if not should_be_visible:
		_set_input_proxy_enabled(false)
		return
	var local_position := Vector2i(
		int(floor(_interaction_rect.position.x)),
		int(floor(_interaction_rect.position.y))
	)
	var proxy_size := Vector2i(
		maxi(1, int(ceil(_interaction_rect.size.x))),
		maxi(1, int(ceil(_interaction_rect.size.y)))
	)
	var global_position := _visual_window.position + local_position
	if force or global_position != _last_proxy_position:
		_input_window.position = global_position
		_last_proxy_position = global_position
	if force or proxy_size != _last_proxy_size:
		_input_window.size = proxy_size
		_input_window.mouse_passthrough_polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(proxy_size.x, 0.0),
			Vector2(proxy_size),
			Vector2(0.0, proxy_size.y)
		])
		_last_proxy_size = proxy_size
	if force or not _last_proxy_visible:
		_input_window.visible = true
		_last_proxy_visible = true


func _set_input_proxy_enabled(enabled: bool) -> void:
	if _interaction_area != null:
		_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _input_window != null:
		_input_window.visible = enabled
	_last_proxy_visible = enabled


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			_begin_drag()
		elif _dragging:
			_finish_drag()
		_interaction_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_event.pressed:
			_recall_pointer_held = true
		elif _recall_pointer_held:
			_finish_recall()
		_interaction_area.accept_event()


func _begin_drag() -> void:
	if _dragging:
		return
	_dragging = true
	_recall_pointer_held = false
	_grab_offset = position - _get_pointer_position()
	_refresh_interaction_hint()
	grabbed_changed.emit(self, true)


func _update_drag_position() -> void:
	if not _dragging:
		return
	position = _clamp_to_window(_get_pointer_position() + _grab_offset)
	_refresh_input_proxy(true)


func _finish_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_refresh_interaction_hint()
	grabbed_changed.emit(self, false)
	_refresh_input_proxy(true)


func _finish_recall() -> void:
	if not _recall_pointer_held:
		return
	_recall_pointer_held = false
	recall_requested.emit(self)


func _get_pointer_position() -> Vector2:
	var window := _visual_window if _visual_window != null else get_window()
	if window == null:
		return get_viewport().get_mouse_position()
	return Vector2(DisplayServer.mouse_get_position() - window.position)


func _get_visual_size() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return Vector2(96.0, 96.0)
	return _sprite.texture.get_size() * Vector2(
		absf(_sprite.scale.x),
		absf(_sprite.scale.y)
	)


func _get_visual_rect() -> Rect2:
	var visual_size := _get_visual_size()
	return Rect2(position - visual_size * 0.5, visual_size)


func _clamp_to_window(candidate: Vector2) -> Vector2:
	var half_size := _get_visual_size() * 0.5
	var left := half_size.x
	var right := float(_window_size.x) - half_size.x
	if right < left:
		left = float(_window_size.x) * 0.5
		right = left
	# Do not add a bottom margin: the item base must visibly meet the taskbar.
	var grounded_y := maxf(half_size.y, _stage_ground_y - half_size.y)
	return Vector2(clampf(candidate.x, left, right), grounded_y)
