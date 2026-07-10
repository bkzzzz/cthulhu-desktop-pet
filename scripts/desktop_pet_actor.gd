extends Node2D

signal hover_changed(actor: Node2D, hovered: bool)
signal petted(actor: Node2D)
signal recall_requested(actor: Node2D)
signal forced_target_reached(actor: Node2D)

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const DEFAULT_PET_SCALE := 1.65
const PET_WALK_SPEED := 34.0
const PET_OFFERING_WALK_SPEED := 190.0
const PET_SPEED_VARIANCE := 9.0
const PET_VISUAL_SIZE := Vector2(230.0, 310.0)
const SHEET_FRAME_CENTER_Y := 64.0
const SHEET_FRAME_FOOT_Y := 102
const HOVER_HINT_DELAY_SECONDS := 0.45

var pet_id := ""
var pet_data: Dictionary = {}
var display_name := ""

var _window_size := Vector2i(820, 420)
var _min_x := 120.0
var _max_x := 720.0
var _target_x := 0.0
var _idle_time := 0.0
var _is_walking := false
var _forced_target_pending := false
var _base_walk_speed := PET_WALK_SPEED
var _walk_speed := PET_WALK_SPEED
var _pet_scale := DEFAULT_PET_SCALE
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _interaction_area: Control
var _hover_hint: Label
var _hovering := false
var _hover_time := 0.0
var _frame_hit_images := {}


func setup(new_pet_id: String, window_size: Vector2i, min_x: float, max_x: float, start_x: float) -> void:
	pet_id = new_pet_id
	pet_data = PetCatalog.get_definition(pet_id)
	display_name = String(pet_data.get("name", pet_id))
	_window_size = window_size
	_pet_scale = float(pet_data.get("desktop_scale", DEFAULT_PET_SCALE))
	_set_safe_bounds(min_x, max_x)
	_rng.randomize()
	_base_walk_speed = PET_WALK_SPEED + _rng.randf_range(-PET_SPEED_VARIANCE, PET_SPEED_VARIANCE)
	_walk_speed = _base_walk_speed

	_create_sprite()
	_create_interaction_area()

	position = Vector2(clampf(start_x, _min_x, _max_x), _get_rest_y())
	_target_x = position.x
	_start_idle()


func set_display_name(new_display_name: String) -> void:
	display_name = new_display_name.strip_edges()
	if display_name.is_empty():
		display_name = String(pet_data.get("name", pet_id))
	_refresh_hover_hint_text()


func set_leader_tint(tint: Color) -> void:
	if _sprite != null:
		_sprite.modulate = tint


func set_window_bounds(window_size: Vector2i, min_x: float, max_x: float) -> void:
	_window_size = window_size
	_set_safe_bounds(min_x, max_x)
	position.x = clampf(position.x, _min_x, _max_x)
	_target_x = clampf(_target_x, _min_x, _max_x)
	_update_interaction_area()


func walk_to_offering_x(target_x: float) -> void:
	_target_x = clampf(target_x, _min_x, _max_x)
	_forced_target_pending = true
	_walk_speed = PET_OFFERING_WALK_SPEED
	if absf(_target_x - position.x) < 4.0:
		_is_walking = false
		_walk_speed = _base_walk_speed
		_start_idle()
		forced_target_reached.emit(self)
		return

	_is_walking = true
	if _sprite != null:
		_sprite.flip_h = _target_x > position.x
		_sprite.play("walk")


func _process(delta: float) -> void:
	_update_pet(delta)
	_update_interaction_area()
	_update_hover_hint(delta)


func get_interaction_rect() -> Rect2:
	if _interaction_area == null:
		return Rect2(position, Vector2.ZERO)

	return Rect2(position + _interaction_area.position, _interaction_area.size)


func is_point_over_opaque_pixel(window_position: Vector2) -> bool:
	if _sprite == null or _sprite.sprite_frames == null:
		return false

	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture == null:
		return false

	var image := _get_frame_hit_image(texture, _sprite.animation, _sprite.frame)
	if image == null or image.is_empty():
		return false

	var sprite_local := to_local(window_position) - _sprite.position
	var unscaled := Vector2(sprite_local.x / _sprite.scale.x, sprite_local.y / _sprite.scale.y)
	var pixel_x := int(floor(unscaled.x + (float(image.get_width()) * 0.5)))
	var pixel_y := int(floor(unscaled.y + (float(image.get_height()) * 0.5)))
	if _sprite.flip_h:
		pixel_x = image.get_width() - 1 - pixel_x

	if pixel_x < 0 or pixel_y < 0 or pixel_x >= image.get_width() or pixel_y >= image.get_height():
		return false

	return image.get_pixel(pixel_x, pixel_y).a > 0.05


func get_draw_rect() -> Rect2:
	var top_left := Vector2(
		position.x - (PET_VISUAL_SIZE.x * 0.5),
		position.y - PET_VISUAL_SIZE.y + 78.0
	)
	return Rect2(top_left, PET_VISUAL_SIZE)


func get_emotion_anchor() -> Vector2:
	return position + Vector2(0.0, -80.0)


func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "%sSprite" % pet_id
	_sprite.sprite_frames = PetCatalog.build_frames(pet_id)
	_sprite.animation = "idle"
	_sprite.scale = Vector2.ONE * _pet_scale
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play("idle")


func _get_frame_hit_image(texture: Texture2D, animation_name: String, frame: int) -> Image:
	var key := "%s:%d" % [animation_name, frame]
	var cached_image := _frame_hit_images.get(key) as Image
	if cached_image != null:
		return cached_image

	var image := texture.get_image()
	if image == null or image.is_empty():
		return null

	image.convert(Image.FORMAT_RGBA8)
	_frame_hit_images[key] = image
	return image


func _create_interaction_area() -> void:
	_interaction_area = Control.new()
	_interaction_area.name = "%sInteractionArea" % pet_id
	_interaction_area.size = PET_VISUAL_SIZE
	_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_interaction_area.z_index = 10
	_interaction_area.mouse_entered.connect(_on_mouse_entered)
	_interaction_area.mouse_exited.connect(_on_mouse_exited)
	_interaction_area.gui_input.connect(_on_gui_input)
	add_child(_interaction_area)
	_create_hover_hint()
	_update_interaction_area()


func _create_hover_hint() -> void:
	_hover_hint = Label.new()
	_hover_hint.name = "PetHoverHint"
	_refresh_hover_hint_text()
	_hover_hint.visible = false
	_hover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hover_hint.size = Vector2(190.0, 46.0)
	_hover_hint.position = Vector2(-95.0, -204.0)
	_hover_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_hint.z_index = 40
	_hover_hint.add_theme_font_size_override("font_size", 14)
	_hover_hint.add_theme_color_override("font_color", Color(0.94, 0.88, 0.64, 1.0))
	_hover_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_hover_hint.add_theme_constant_override("outline_size", 3)
	add_child(_hover_hint)


func _refresh_hover_hint_text() -> void:
	if _hover_hint == null:
		return
	_hover_hint.text = "%s\n左键抚摸  右键召回仓库" % display_name


func _update_pet(delta: float) -> void:
	position.y = _get_rest_y()

	if _is_walking:
		var step := _walk_speed * delta
		var distance := _target_x - position.x
		if absf(distance) <= step:
			position.x = _target_x
			var reached_forced_target := _forced_target_pending
			_forced_target_pending = false
			if reached_forced_target:
				_walk_speed = _base_walk_speed
			_start_idle()
			if reached_forced_target:
				forced_target_reached.emit(self)
		else:
			position.x += signf(distance) * step
			_sprite.flip_h = distance > 0.0
			if _sprite.animation != "walk":
				_sprite.play("walk")
		return

	_idle_time -= delta
	if _idle_time <= 0.0:
		_choose_walk_target()


func _choose_walk_target() -> void:
	var roll := _rng.randf()
	if roll < 0.22:
		var hop := _rng.randf_range(38.0, 125.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		_target_x = clampf(position.x + hop, _min_x, _max_x)
	elif roll < 0.42:
		var edge := _min_x if _rng.randf() < 0.5 else _max_x
		_target_x = clampf(edge + _rng.randf_range(-42.0, 42.0), _min_x, _max_x)
	else:
		_target_x = _rng.randf_range(_min_x, _max_x)

	if absf(_target_x - position.x) < 10.0:
		_start_idle()
		return

	_is_walking = true
	_walk_speed = _base_walk_speed
	_sprite.flip_h = _target_x > position.x
	_sprite.play("walk")


func _start_idle() -> void:
	_is_walking = false
	_idle_time = _rng.randf_range(0.7, 4.2)
	if _rng.randf() < 0.18:
		_idle_time += _rng.randf_range(1.0, 2.6)
	if _sprite != null:
		if _rng.randf() < 0.16:
			_sprite.flip_h = not _sprite.flip_h
		_sprite.play("idle")


func _set_safe_bounds(min_x: float, max_x: float) -> void:
	var half_width := (PET_VISUAL_SIZE.x * 0.5) + 8.0
	_min_x = maxf(min_x, half_width)
	_max_x = minf(max_x, float(_window_size.x) - half_width)
	if _max_x < _min_x:
		var center_x := float(_window_size.x) * 0.5
		_min_x = center_x
		_max_x = center_x


func _update_interaction_area() -> void:
	if _interaction_area == null:
		return

	_interaction_area.position = Vector2(
		-(PET_VISUAL_SIZE.x * 0.5),
		-PET_VISUAL_SIZE.y + 78.0
	)


func _update_hover_hint(delta: float) -> void:
	if _hover_hint == null:
		return
	if not _hovering:
		_hover_hint.visible = false
		return

	_hover_time += delta
	_hover_hint.visible = _hover_time >= HOVER_HINT_DELAY_SECONDS


func _get_rest_y() -> float:
	var foot_line_y := float(_window_size.y - 1)
	return foot_line_y - ((float(SHEET_FRAME_FOOT_Y) - SHEET_FRAME_CENTER_Y) * _pet_scale)


func _on_mouse_entered() -> void:
	_hovering = true
	_hover_time = 0.0
	hover_changed.emit(self, true)


func _on_mouse_exited() -> void:
	_hovering = false
	if _hover_hint != null:
		_hover_hint.visible = false
	hover_changed.emit(self, false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var window_position := get_viewport().get_mouse_position()
		if not is_point_over_opaque_pixel(window_position):
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			petted.emit(self)
			_interaction_area.accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			recall_requested.emit(self)
			_interaction_area.accept_event()
