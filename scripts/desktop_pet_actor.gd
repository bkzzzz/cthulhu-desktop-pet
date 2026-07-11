extends Node2D

signal hover_changed(actor: Node2D, hovered: bool)
signal petted(actor: Node2D)
signal recall_requested(actor: Node2D)
signal forced_target_reached(actor: Node2D)
signal grabbed_changed(actor: Node2D, grabbed: bool)

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const DEFAULT_PET_SCALE := 1.65
const PET_WALK_SPEED := 34.0
const PET_OFFERING_WALK_SPEED := 190.0
const PET_SPEED_VARIANCE := 9.0
const PET_VISUAL_SIZE := Vector2(230.0, 310.0)
const HOVER_HINT_DELAY_SECONDS := 0.45
const GRAB_HOLD_SECONDS := 0.38
const GRAB_CLICK_TOLERANCE := 12.0
const FALL_GRAVITY := 1250.0
const WALL_CRAWL_SPEED := 48.0

enum Behavior {
	IDLE,
	WALK,
	BURROW_DOWN,
	UNDERGROUND,
	BURROW_UP,
	SLEEP_CLOSING,
	SLEEPING,
	SLEEP_OPENING,
	WALL_CRAWL_UP,
	WALL_PAUSE,
	WALL_CRAWL_DOWN,
	GRABBED,
	FALLING
}

var pet_id := ""
var pet_data: Dictionary = {}
var display_name := ""

var _window_size := Vector2i(820, 420)
var _min_x := 120.0
var _max_x := 720.0
var _target_x := 0.0
var _idle_anchor_x := 0.0
var _idle_time := 0.0
var _special_time := 0.0
var _forced_target_pending := false
var _wall_pending := false
var _wall_edge := 0
var _wall_target_y := 0.0
var _base_walk_speed := PET_WALK_SPEED
var _walk_speed := PET_WALK_SPEED
var _pet_scale := DEFAULT_PET_SCALE
var _frame_center_y := 64.0
var _frame_foot_y := 102.0
var _ground_offset_y := 0.0
var _faces_right := false
var _float_phase := 0.0
var _fall_velocity := 0.0
var _behavior := Behavior.IDLE
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _interaction_area: Control
var _hover_hint: Label
var _hovering := false
var _hover_time := 0.0
var _pointer_held := false
var _pointer_hold_time := 0.0
var _press_position := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _frame_hit_images := {}


func setup(new_pet_id: String, window_size: Vector2i, min_x: float, max_x: float, start_x: float) -> void:
	pet_id = new_pet_id
	pet_data = PetCatalog.get_definition(pet_id)
	display_name = String(pet_data.get("name", pet_id))
	_window_size = window_size
	_pet_scale = float(pet_data.get("desktop_scale", DEFAULT_PET_SCALE))
	_frame_center_y = float(pet_data.get("frame_center_y", 64.0))
	_frame_foot_y = float(pet_data.get("frame_foot_y", 102.0))
	_ground_offset_y = float(pet_data.get("ground_offset_y", 0.0))
	_faces_right = bool(pet_data.get("faces_right", false))
	_set_safe_bounds(min_x, max_x)
	_rng.randomize()
	_float_phase = _rng.randf_range(0.0, TAU)
	_base_walk_speed = PET_WALK_SPEED + _rng.randf_range(-PET_SPEED_VARIANCE, PET_SPEED_VARIANCE)
	_walk_speed = _base_walk_speed

	_create_sprite()
	_create_interaction_area()

	position = Vector2(clampf(start_x, _min_x, _max_x), _get_rest_y())
	_target_x = position.x
	_face_direction(-1.0)
	_start_idle()


func set_display_name(new_display_name: String) -> void:
	display_name = new_display_name.strip_edges()
	if display_name.is_empty():
		display_name = String(pet_data.get("name", pet_id))
	_refresh_hover_hint_text()


func set_window_bounds(window_size: Vector2i, min_x: float, max_x: float) -> void:
	_window_size = window_size
	_set_safe_bounds(min_x, max_x)
	position.x = clampf(position.x, _get_drag_min_x(), _get_drag_max_x())
	_target_x = clampf(_target_x, _min_x, _max_x)
	_update_interaction_area()


func walk_to_offering_x(target_x: float) -> void:
	_cancel_special_behavior()
	_target_x = clampf(target_x, _min_x, _max_x)
	_forced_target_pending = true
	_walk_speed = PET_OFFERING_WALK_SPEED
	if absf(_target_x - position.x) < 4.0:
		_walk_speed = _base_walk_speed
		_start_idle()
		forced_target_reached.emit(self)
		return

	_behavior = Behavior.WALK
	_face_direction(_target_x - position.x)
	_sprite.play("walk")


func is_pointer_captured() -> bool:
	return _pointer_held or _behavior == Behavior.GRABBED


func _process(delta: float) -> void:
	_update_pointer_interaction(delta)
	_update_pet(delta)
	_update_interaction_area()
	_update_hover_hint(delta)


func get_interaction_rect() -> Rect2:
	if _interaction_area == null or _behavior == Behavior.UNDERGROUND:
		return Rect2(position, Vector2.ZERO)
	return Rect2(position + _interaction_area.position, _interaction_area.size)


func is_point_over_opaque_pixel(window_position: Vector2) -> bool:
	if _sprite == null or not _sprite.visible or _sprite.sprite_frames == null:
		return false

	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture == null:
		return false

	var image := _get_frame_hit_image(texture, _sprite.animation, _sprite.frame)
	if image == null or image.is_empty():
		return false

	var sprite_local := _sprite.to_local(window_position)
	var pixel_x := int(floor(sprite_local.x + (float(image.get_width()) * 0.5)))
	var pixel_y := int(floor(sprite_local.y + (float(image.get_height()) * 0.5)))
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
	_sprite.animation_finished.connect(_on_animation_finished)
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
	_hover_hint.size = Vector2(240.0, 52.0)
	_hover_hint.position = Vector2(-120.0, -204.0)
	_hover_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_hint.z_index = 40
	_hover_hint.add_theme_font_size_override("font_size", 14)
	_hover_hint.add_theme_color_override("font_color", Color(0.94, 0.88, 0.64, 1.0))
	_hover_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_hover_hint.add_theme_constant_override("outline_size", 3)
	add_child(_hover_hint)


func _refresh_hover_hint_text() -> void:
	if _hover_hint != null:
		_hover_hint.text = "%s\n左键抚摸 · 长按抓起  右键召回" % display_name


func _update_pet(delta: float) -> void:
	_float_phase += delta * 2.15
	match _behavior:
		Behavior.GRABBED:
			_update_grabbed_position()
		Behavior.FALLING:
			_update_falling(delta)
		Behavior.WALK:
			_update_walking(delta)
		Behavior.IDLE:
			_update_idle(delta)
		Behavior.UNDERGROUND:
			_special_time -= delta
			if _special_time <= 0.0:
				_start_emerging()
		Behavior.SLEEPING:
			_apply_grounded_position(true)
			_special_time -= delta
			if _special_time <= 0.0:
				_behavior = Behavior.SLEEP_OPENING
				_sprite.play("open_eye")
		Behavior.BURROW_DOWN, Behavior.BURROW_UP, Behavior.SLEEP_CLOSING, Behavior.SLEEP_OPENING:
			_apply_grounded_position(pet_id == "pet2")
		Behavior.WALL_CRAWL_UP:
			_update_wall_crawl(delta, -1.0)
		Behavior.WALL_PAUSE:
			_special_time -= delta
			if _special_time <= 0.0:
				_behavior = Behavior.WALL_CRAWL_DOWN
		Behavior.WALL_CRAWL_DOWN:
			_update_wall_crawl(delta, 1.0)


func _update_walking(delta: float) -> void:
	var step := _walk_speed * delta
	var distance := _target_x - position.x
	if absf(distance) <= step:
		position.x = _target_x
		if _wall_pending:
			_start_wall_crawl()
			return
		var reached_forced_target := _forced_target_pending
		_forced_target_pending = false
		if reached_forced_target:
			_walk_speed = _base_walk_speed
		_start_idle()
		if reached_forced_target:
			forced_target_reached.emit(self)
		return

	position.x += signf(distance) * step
	_face_direction(distance)
	if _sprite.animation != "walk":
		_sprite.play("walk")
	_apply_grounded_position(pet_id == "pet2")


func _update_idle(delta: float) -> void:
	_apply_grounded_position(pet_id == "pet2")
	if pet_id == "pet2":
		position.x = clampf(_idle_anchor_x + sin(_float_phase * 0.63) * 3.5, _min_x, _max_x)
	_idle_time -= delta
	if _idle_time <= 0.0:
		_choose_next_action()


func _choose_next_action() -> void:
	var special_roll := _rng.randf()
	if pet_id == "pet3" and special_roll < 0.24:
		_start_burrowing()
		return
	if pet_id == "pet2" and special_roll < 0.22:
		_start_sleeping()
		return
	if pet_id == "pet5" and special_roll < 0.22:
		_start_wall_trip()
		return
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
	_behavior = Behavior.WALK
	_walk_speed = _base_walk_speed
	_face_direction(_target_x - position.x)
	_sprite.play("walk")


func _start_idle() -> void:
	_behavior = Behavior.IDLE
	_idle_anchor_x = clampf(position.x, _min_x, _max_x)
	position.x = _idle_anchor_x
	_idle_time = _rng.randf_range(0.9, 4.6)
	if _rng.randf() < 0.18:
		_idle_time += _rng.randf_range(1.0, 2.6)
	_sprite.rotation = 0.0
	_sprite.visible = true
	_sprite.play("idle")
	_set_interaction_enabled(true)


func _start_burrowing() -> void:
	_behavior = Behavior.BURROW_DOWN
	_sprite.play("burrow")


func _start_emerging() -> void:
	position.x = _rng.randf_range(_min_x, _max_x)
	_behavior = Behavior.BURROW_UP
	_sprite.visible = true
	_set_interaction_enabled(true)
	_sprite.play("emerge")


func _start_sleeping() -> void:
	_behavior = Behavior.SLEEP_CLOSING
	_sprite.play("close_eye")


func _start_wall_trip() -> void:
	_wall_edge = -1 if _rng.randf() < 0.5 else 1
	_wall_pending = true
	_target_x = _get_wall_x()
	_behavior = Behavior.WALK
	_walk_speed = _base_walk_speed
	_face_direction(float(_wall_edge))
	_sprite.play("walk")


func _start_wall_crawl() -> void:
	_wall_pending = false
	_behavior = Behavior.WALL_CRAWL_UP
	position.x = _get_wall_x()
	_wall_target_y = _rng.randf_range(105.0, maxf(125.0, _get_rest_y() - 170.0))
	_face_direction(float(_wall_edge))
	_sprite.rotation = PI * 0.5 if _wall_edge < 0 else -PI * 0.5
	_sprite.play("walk")


func _update_wall_crawl(delta: float, direction: float) -> void:
	var destination_y := _wall_target_y if direction < 0.0 else _get_rest_y()
	position.y = move_toward(position.y, destination_y, WALL_CRAWL_SPEED * delta)
	if not is_equal_approx(position.y, destination_y):
		return
	if direction < 0.0:
		_behavior = Behavior.WALL_PAUSE
		_special_time = _rng.randf_range(1.0, 3.2)
		_sprite.play("idle")
	else:
		_sprite.rotation = 0.0
		_start_idle()


func _on_animation_finished() -> void:
	match _behavior:
		Behavior.BURROW_DOWN:
			_behavior = Behavior.UNDERGROUND
			_special_time = _rng.randf_range(1.6, 4.2)
			_sprite.visible = false
			_set_interaction_enabled(false)
		Behavior.BURROW_UP:
			_start_idle()
		Behavior.SLEEP_CLOSING:
			_behavior = Behavior.SLEEPING
			_special_time = _rng.randf_range(3.0, 7.5)
			_sprite.play("sleep")
		Behavior.SLEEP_OPENING:
			_start_idle()


func _cancel_special_behavior() -> void:
	_wall_pending = false
	_forced_target_pending = false
	_sprite.rotation = 0.0
	_sprite.visible = true
	_set_interaction_enabled(true)
	position.x = clampf(position.x, _min_x, _max_x)


func _face_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	var moving_right := direction > 0.0
	_sprite.flip_h = moving_right != _faces_right


func _apply_grounded_position(with_float: bool) -> void:
	var bob := sin(_float_phase) * 7.0 if with_float else 0.0
	position.y = _get_rest_y() + bob


func _update_pointer_interaction(delta: float) -> void:
	if not _pointer_held:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_pointer_hold()
		return
	_pointer_hold_time += delta
	if _behavior != Behavior.GRABBED and _pointer_hold_time >= GRAB_HOLD_SECONDS:
		_begin_grab()


func _begin_grab() -> void:
	_cancel_special_behavior()
	_behavior = Behavior.GRABBED
	_grab_offset = position - get_viewport().get_mouse_position()
	z_index = 500
	_sprite.play("idle")
	if _hover_hint != null:
		_hover_hint.visible = false
	grabbed_changed.emit(self, true)


func _update_grabbed_position() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var target := mouse_position + _grab_offset
	target.x = clampf(target.x, _get_drag_min_x(), _get_drag_max_x())
	target.y = clampf(target.y, 32.0, float(_window_size.y) - 12.0)
	position = target


func _finish_pointer_hold() -> void:
	if not _pointer_held:
		return
	_pointer_held = false
	if _behavior == Behavior.GRABBED:
		_behavior = Behavior.FALLING
		_fall_velocity = 0.0
		z_index = 0
		grabbed_changed.emit(self, false)
	elif get_viewport().get_mouse_position().distance_to(_press_position) <= GRAB_CLICK_TOLERANCE:
		petted.emit(self)
	_pointer_hold_time = 0.0


func _update_falling(delta: float) -> void:
	var rest_y := _get_rest_y()
	if position.y >= rest_y:
		position.y = rest_y
		_start_idle()
		return
	_fall_velocity += FALL_GRAVITY * delta
	position.y = minf(rest_y, position.y + (_fall_velocity * delta))
	if position.y >= rest_y:
		_start_idle()


func _set_safe_bounds(min_x: float, max_x: float) -> void:
	var half_width := (PET_VISUAL_SIZE.x * 0.5) + 8.0
	_min_x = maxf(min_x, half_width)
	_max_x = minf(max_x, float(_window_size.x) - half_width)
	if _max_x < _min_x:
		var center_x := float(_window_size.x) * 0.5
		_min_x = center_x
		_max_x = center_x


func _get_drag_min_x() -> float:
	return 48.0 if pet_id == "pet5" else _min_x


func _get_drag_max_x() -> float:
	return float(_window_size.x) - 48.0 if pet_id == "pet5" else _max_x


func _get_wall_x() -> float:
	return 48.0 if _wall_edge < 0 else float(_window_size.x) - 48.0


func _update_interaction_area() -> void:
	if _interaction_area != null:
		_interaction_area.position = Vector2(-(PET_VISUAL_SIZE.x * 0.5), -PET_VISUAL_SIZE.y + 78.0)


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_area != null:
		_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _update_hover_hint(delta: float) -> void:
	if _hover_hint == null:
		return
	if not _hovering or _behavior == Behavior.GRABBED or _behavior == Behavior.UNDERGROUND:
		_hover_hint.visible = false
		return
	_hover_time += delta
	_hover_hint.visible = _hover_time >= HOVER_HINT_DELAY_SECONDS


func _get_rest_y() -> float:
	var foot_line_y := float(_window_size.y - 1)
	return foot_line_y - ((_frame_foot_y - _frame_center_y) * _pet_scale) + _ground_offset_y


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
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	var window_position := get_viewport().get_mouse_position()
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			if not is_point_over_opaque_pixel(window_position):
				return
			_pointer_held = true
			_pointer_hold_time = 0.0
			_press_position = window_position
			_interaction_area.accept_event()
		elif _pointer_held:
			_finish_pointer_hold()
			_interaction_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if is_point_over_opaque_pixel(window_position):
			recall_requested.emit(self)
			_interaction_area.accept_event()
