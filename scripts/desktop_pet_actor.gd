extends Node2D

signal petted(actor: Node2D)
signal recall_requested(actor: Node2D)
signal forced_target_reached(actor: Node2D)
signal grabbed_changed(actor: Node2D, grabbed: bool)
signal notable_action(actor: Node2D, action_id: String)

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const DEFAULT_PET_SCALE := 1.65
const PET_WALK_SPEED := 34.0
const PET_OFFERING_WALK_SPEED := 190.0
const PET_SPEED_VARIANCE := 9.0
const PET_VISUAL_SIZE := Vector2(230.0, 310.0)
const HOVER_HINT_DELAY_SECONDS := 0.45
const GRAB_HOLD_SECONDS := 0.0
const GRAB_CLICK_TOLERANCE := 12.0
const PETTING_CLICK_MAX_SECONDS := 0.2
const POINTER_CAPTURE_TIMEOUT_SECONDS := 10.0
const HIT_SLOP_PIXELS := 4
const FALL_GRAVITY := 1250.0
const WALL_CRAWL_SPEED := 48.0
const WALL_CORNER_TURN_DURATION := 0.22
const FLOAT_BOB_AMPLITUDE := 14.0
const AIR_ROAM_SPEED := 52.0
const AIR_ROAM_MIN_HEIGHT := 42.0
const AIR_ROAM_MAX_HEIGHT := 118.0
const FLOATER_HEIGHT_RETURN_SPEED := 72.0
const AIR_ROAM_LEG_PAUSE_MIN := 0.35
const AIR_ROAM_LEG_PAUSE_MAX := 1.15
const INPUT_PROXY_PADDING := 10.0
const INPUT_WINDOW_UPDATE_INTERVAL := 1.0 / 15.0
const RANGED_BATTLE_PET_IDS := ["pet2", "pet7", "pet8", "pet9", "pet10", "pet11"]
const DOZE_ANIMATION_SPEED_SCALE := 0.28
const POP_DURATION_MIN := 0.48
const POP_DURATION_MAX := 0.82
const SWALLOW_IN_DURATION := 0.72
const SWALLOW_OUT_DURATION := 0.82
const SWALLOW_SPIT_DISTANCE_MIN := 120.0
const SWALLOW_SPIT_DISTANCE_MAX := 240.0

enum Behavior {
	IDLE,
	WALK,
	BURROW_DOWN,
	UNDERGROUND,
	BURROW_UP,
	SLEEP_CLOSING,
	SLEEPING,
	SLEEP_OPENING,
	DOZING,
	HIDDEN,
	POPPING,
	WALL_MOUNT,
	WALL_CRAWL_UP,
	WALL_PAUSE,
	WALL_CRAWL_DOWN,
	WALL_LANDING,
	AIR_ROAM_OUT,
	AIR_ROAM_PAUSE,
	AIR_ROAM_RETURN,
	GRABBED,
	FALLING,
	SWALLOWED
}

enum SwallowPhase {
	NONE,
	SUCKING_IN,
	HELD,
	SPITTING_OUT
}

var pet_id := ""
var pet_data: Dictionary = {}
var display_name := ""

var _window_size := Vector2i(820, 420)
var _stage_ground_y := 420.0
var _min_x := 120.0
var _max_x := 720.0
var _target_x := 0.0
var _idle_anchor_x := 0.0
var _idle_time := 0.0
var _special_time := 0.0
var _forced_target_pending := false
var _wall_pending := false
var _hide_pending := false
var _wall_edge := 0
var _wall_target_y := 0.0
var _wall_transition_progress := 0.0
var _wall_transition_start_rotation := 0.0
var _base_walk_speed := PET_WALK_SPEED
var _walk_speed := PET_WALK_SPEED
var _walk_distance_min := 40.0
var _walk_distance_max := 180.0
var _behavior_style := "wanderer"
var _activity_chance := 0.2
var _idle_time_min := 0.9
var _idle_time_max := 4.6
var _special_chance := 0.0
var _doze_chance := 0.0
var _hide_chance := 0.0
var _can_hide := false
var _wall_chance := 0.0
var _can_wall_crawl := false
var _air_roam_chance := 0.0
var _air_roam_legs_min := 1
var _air_roam_legs_max := 1
var _air_roam_legs_remaining := 0
var _special_time_min := 1.0
var _special_time_max := 3.0
var _doze_time_min := 5.0
var _doze_time_max := 12.0
var _hide_time_min := 3.0
var _hide_time_max := 8.0
var _pop_distance_min := 90.0
var _pop_distance_max := 220.0
var _pop_height_min := 40.0
var _pop_height_max := 80.0
var _pet_scale := DEFAULT_PET_SCALE
var _frame_center_y := 64.0
var _frame_foot_y := 102.0
var _ground_offset_y := 0.0
var _rolls_while_walking := false
var _walk_rotation_speed := 0.0
var _faces_right := false
var _float_bob_amplitude := FLOAT_BOB_AMPLITUDE
var _float_anchor_y := 0.0
var _float_phase := 0.0
var _air_path_start := Vector2.ZERO
var _air_path_target := Vector2.ZERO
var _air_path_progress := 0.0
var _air_path_duration := 1.0
var _sleep_anchor_position := Vector2.ZERO
var _doze_anchor_position := Vector2.ZERO
var _pop_start_position := Vector2.ZERO
var _pop_target_position := Vector2.ZERO
var _pop_progress := 0.0
var _pop_duration := 0.65
var _pop_height := 56.0
var _idle_turn_time := 0.0
var _fall_velocity := 0.0
var _behavior := Behavior.IDLE
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _visual_window: Window
var _input_window: Window
var _interaction_area: Control
var _interaction_rect := Rect2()
var _interaction_enabled := true
var _activity_restricted := false
var _autonomy_paused := false
var _autonomy_previous_speed_scale := 1.0
var _battle_mode := false
var _battle_motion_tween: Tween
var _battle_attack_animation := false
var _last_input_window_position := Vector2i(-100000, -100000)
var _last_input_window_size := Vector2i.ZERO
var _last_input_shape_flip := false
var _last_input_shape_rotation := INF
var _last_input_shape_scale := Vector2.ZERO
var _swallow_phase := SwallowPhase.NONE
var _swallow_progress := 0.0
var _swallow_hold_time := 0.0
var _swallow_start_position := Vector2.ZERO
var _swallow_target_position := Vector2.ZERO
var _swallower: Node2D
var _hover_hint: Label
var _hovering := false
var _hover_time := 0.0
var _pointer_held := false
var _pointer_hold_time := 0.0
var _press_position := Vector2.ZERO
var _press_actor_position := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _frame_hit_images := {}
var _stable_hit_image: Image
var _stable_hit_polygon := PackedVector2Array()
var _input_window_update_time := 0.0
var _language := "zh"


func _ready() -> void:
	_visual_window = get_window()
	_create_input_window()
	_update_interaction_area()


func setup(
	new_pet_id: String,
	window_size: Vector2i,
	min_x: float,
	max_x: float,
	start_x: float,
	ground_contact_y := -1.0,
	restrict_activity := false
) -> void:
	pet_id = new_pet_id
	pet_data = PetCatalog.get_definition(pet_id)
	display_name = String(pet_data.get("name", pet_id))
	_window_size = window_size
	_stage_ground_y = _resolve_stage_ground_y(float(ground_contact_y))
	_pet_scale = float(pet_data.get("desktop_scale", DEFAULT_PET_SCALE))
	_frame_center_y = float(pet_data.get("frame_center_y", 64.0))
	_frame_foot_y = float(pet_data.get("frame_foot_y", 102.0))
	_ground_offset_y = float(pet_data.get("ground_offset_y", 0.0))
	_rolls_while_walking = bool(pet_data.get("rolls_while_walking", false))
	_walk_rotation_speed = maxf(0.0, float(pet_data.get("walk_rotation_speed", 0.0)))
	_faces_right = bool(pet_data.get("faces_right", false))
	_activity_restricted = restrict_activity
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id()) ^ pet_id.hash()
	_float_phase = _rng.randf_range(0.0, TAU)
	_behavior_style = String(pet_data.get("behavior", "wanderer"))
	_activity_chance = clampf(float(pet_data.get("activity_chance", 0.2)), 0.0, 1.0)
	_idle_time_min = float(pet_data.get("idle_time_min", 0.9))
	_idle_time_max = maxf(_idle_time_min, float(pet_data.get("idle_time_max", 4.6)))
	_special_chance = clampf(float(pet_data.get("special_chance", 0.0)), 0.0, 1.0)
	_doze_chance = clampf(float(pet_data.get("doze_chance", 0.0)), 0.0, 1.0)
	_hide_chance = clampf(float(pet_data.get("hide_chance", 0.0)), 0.0, 1.0)
	_can_hide = bool(pet_data.get("can_hide", false))
	if not _can_hide:
		_hide_chance = 0.0
	_wall_chance = clampf(float(pet_data.get("wall_chance", 0.0)), 0.0, 1.0)
	_can_wall_crawl = bool(pet_data.get("can_wall_crawl", _wall_chance > 0.0))
	if not _can_wall_crawl:
		_wall_chance = 0.0
	_air_roam_chance = clampf(float(pet_data.get("air_roam_chance", 0.0)), 0.0, 1.0)
	_air_roam_legs_min = maxi(1, int(pet_data.get("air_roam_legs_min", 1)))
	_air_roam_legs_max = maxi(_air_roam_legs_min, int(pet_data.get("air_roam_legs_max", _air_roam_legs_min)))
	_special_time_min = float(pet_data.get("special_time_min", 1.0))
	_special_time_max = maxf(_special_time_min, float(pet_data.get("special_time_max", 3.0)))
	_doze_time_min = maxf(0.5, float(pet_data.get("doze_time_min", 5.0)))
	_doze_time_max = maxf(_doze_time_min, float(pet_data.get("doze_time_max", 12.0)))
	_hide_time_min = maxf(0.5, float(pet_data.get("hide_time_min", 3.0)))
	_hide_time_max = maxf(_hide_time_min, float(pet_data.get("hide_time_max", 8.0)))
	_pop_distance_min = maxf(20.0, float(pet_data.get("pop_distance_min", 90.0)))
	_pop_distance_max = maxf(_pop_distance_min, float(pet_data.get("pop_distance_max", 220.0)))
	_pop_height_min = maxf(10.0, float(pet_data.get("pop_height_min", 40.0)))
	_pop_height_max = maxf(_pop_height_min, float(pet_data.get("pop_height_max", 80.0)))
	var configured_speed := float(pet_data.get("walk_speed", PET_WALK_SPEED))
	var speed_variance := float(pet_data.get("walk_speed_variance", PET_SPEED_VARIANCE))
	_base_walk_speed = maxf(1.0, configured_speed + _rng.randf_range(-speed_variance, speed_variance))
	_walk_speed = _base_walk_speed
	_walk_distance_min = maxf(10.0, float(pet_data.get("walk_distance_min", 40.0)))
	_walk_distance_max = maxf(_walk_distance_min, float(pet_data.get("walk_distance_max", 180.0)))
	_float_bob_amplitude = maxf(0.0, float(pet_data.get("float_bob_amplitude", FLOAT_BOB_AMPLITUDE)))

	_create_sprite()
	_create_interaction_area()
	_set_safe_bounds(min_x, max_x)

	position = Vector2(clampf(start_x, _min_x, _max_x), _get_rest_y())
	_float_anchor_y = position.y
	if _behavior_style == "sleepy_floater":
		var initial_air_bounds := _get_air_roam_y_bounds()
		_float_anchor_y = _rng.randf_range(initial_air_bounds.x, initial_air_bounds.y)
		position.y = _float_anchor_y
	_target_x = position.x
	_face_direction(-1.0)
	_start_idle()


func set_display_name(new_display_name: String) -> void:
	display_name = new_display_name.strip_edges()
	if display_name.is_empty():
		display_name = String(pet_data.get("name", pet_id))
	_refresh_hover_hint_text()


func set_language(language_code: String) -> void:
	_language = "en" if language_code == "en" else "zh"
	_refresh_hover_hint_text()


func set_window_bounds(
	window_size: Vector2i,
	min_x: float,
	max_x: float,
	ground_contact_y := -1.0,
	restrict_activity := false
) -> void:
	var previous_stage_ground_y := _stage_ground_y
	_window_size = window_size
	_stage_ground_y = _resolve_stage_ground_y(float(ground_contact_y))
	var ground_shift := _stage_ground_y - previous_stage_ground_y
	if not is_zero_approx(ground_shift):
		position.y += ground_shift
		_float_anchor_y += ground_shift
		_sleep_anchor_position.y += ground_shift
		_doze_anchor_position.y += ground_shift
		_pop_start_position.y += ground_shift
		_pop_target_position.y += ground_shift
		_air_path_start.y += ground_shift
		_air_path_target.y += ground_shift
	_set_safe_bounds(min_x, max_x)
	_activity_restricted = restrict_activity
	position.x = clampf(position.x, _get_drag_min_x(), _get_drag_max_x())
	_target_x = clampf(_target_x, _min_x, _max_x)
	_pop_target_position.x = clampf(_pop_target_position.x, _min_x, _max_x)
	if _behavior_style == "sleepy_floater":
		_float_anchor_y = clampf(_float_anchor_y, _get_drag_min_y(), _get_rest_y())
	_update_interaction_area()


func set_autonomy_paused(paused: bool) -> void:
	if _autonomy_paused == paused:
		return
	_autonomy_paused = paused
	if _sprite == null:
		return
	if paused:
		if _behavior == Behavior.SWALLOWED:
			_finish_swallowed()
		_autonomy_previous_speed_scale = 1.0
		if _behavior not in [Behavior.GRABBED, Behavior.FALLING]:
			_cancel_special_behavior()
			_start_idle()
		_sprite.speed_scale = 1.0
	else:
		_sprite.speed_scale = maxf(0.01, _autonomy_previous_speed_scale)


func is_autonomy_paused() -> bool:
	return _autonomy_paused


func set_battle_mode(enabled: bool) -> void:
	if _battle_mode == enabled:
		return
	_battle_mode = enabled
	_battle_attack_animation = false
	if _battle_motion_tween != null and is_instance_valid(_battle_motion_tween):
		_battle_motion_tween.kill()
		_battle_motion_tween = null
	if enabled:
		cancel_pointer_capture()
		_cancel_special_behavior()
		set_autonomy_paused(true)
		# Battle placement is part of the gameplay: players may still grab a pet
		# and drop it beside a priority target.
		_set_interaction_enabled(true)
		z_index = 210
		_face_direction(-1.0)
	else:
		cancel_pointer_capture()
		z_index = 0
		set_autonomy_paused(false)
		_set_interaction_enabled(true)
		if _behavior_style != "sleepy_floater":
			position.y = _get_rest_y()
		_start_idle()


func battle_move_toward(target_x: float, delta: float, speed := 230.0) -> bool:
	if not _battle_mode or _sprite == null:
		return false
	var safe_target := clampf(target_x, _min_x, _max_x)
	var step := maxf(1.0, speed) * maxf(0.0, delta)
	position.x = move_toward(position.x, safe_target, step)
	_face_direction(safe_target - position.x if not is_equal_approx(position.x, safe_target) else -1.0)
	if absf(position.x - safe_target) > 2.0:
		if _sprite.animation != "walk":
			_sprite.play("walk")
	else:
		_sprite.play("idle")
	if _behavior_style != "sleepy_floater":
		position.y = _get_rest_y()
	else:
		_settle_floater_height(maxf(0.0, delta))
		_apply_floating_position(_float_bob_amplitude)
	return absf(position.x - safe_target) <= 2.0


func play_battle_attack() -> void:
	play_battle_attack_toward(-1.0)


func play_battle_attack_toward(direction: float) -> void:
	if not _battle_mode or _sprite == null:
		return
	if _battle_motion_tween != null and is_instance_valid(_battle_motion_tween):
		_battle_motion_tween.kill()
	var origin_x := position.x
	var attack_direction := -1.0 if direction < 0.0 else 1.0
	_face_direction(attack_direction)
	if (
		pet_id not in RANGED_BATTLE_PET_IDS
		and _sprite.sprite_frames != null
		and _sprite.sprite_frames.has_animation("attack")
		and _sprite.sprite_frames.get_frame_count("attack") > 0
	):
		_battle_attack_animation = true
		_sprite.speed_scale = 1.0
		_sprite.play("attack")
		return
	_battle_motion_tween = create_tween()
	_battle_motion_tween.set_trans(Tween.TRANS_QUAD)
	_battle_motion_tween.set_ease(Tween.EASE_OUT)
	_battle_motion_tween.tween_property(self, "position:x", origin_x + attack_direction * 22.0, 0.09)
	_battle_motion_tween.tween_property(self, "position:x", origin_x, 0.14)


func get_battle_attack_origin(direction: float) -> Vector2:
	var attack_direction := -1.0 if direction < 0.0 else 1.0
	var visual_rect := _get_sprite_visual_rect()
	var height_above_origin := maxf(34.0, position.y - visual_rect.position.y)
	return position + Vector2(attack_direction * 42.0, -height_above_origin * 0.45)


func get_battle_hit_position() -> Vector2:
	var visual_rect := _get_sprite_visual_rect()
	var height_above_origin := maxf(32.0, position.y - visual_rect.position.y)
	return position + Vector2(0.0, -height_above_origin * 0.48)


func get_swallow_mouth_position() -> Vector2:
	var visual_rect := _get_sprite_visual_rect()
	var height_above_origin := maxf(34.0, position.y - visual_rect.position.y)
	return position + Vector2(-24.0, -height_above_origin * 0.42)


func has_battle_attack_animation() -> bool:
	return (
		pet_id not in RANGED_BATTLE_PET_IDS
		and _sprite != null
		and _sprite.sprite_frames != null
		and _sprite.sprite_frames.has_animation("attack")
		and _sprite.sprite_frames.get_frame_count("attack") > 0
	)


func receive_battle_hit(knockback := 14.0) -> void:
	if not _battle_mode or _sprite == null:
		return
	position.x = clampf(
		position.x + maxf(0.0, knockback),
		_get_drag_min_x(),
		_get_drag_max_x()
	)
	var flash := create_tween()
	flash.tween_property(_sprite, "modulate", Color(1.0, 0.18, 0.18, 1.0), 0.05)
	flash.tween_property(_sprite, "modulate", Color.WHITE, 0.16)


func hide_for_battle_defeat() -> void:
	_battle_mode = false
	_set_interaction_enabled(false)
	if _sprite != null:
		_sprite.visible = false


func is_battle_ready() -> bool:
	return (
		_battle_mode
		and not _pointer_held
		and _behavior not in [Behavior.GRABBED, Behavior.FALLING, Behavior.SWALLOWED]
	)


func can_be_swallowed() -> bool:
	return (
		_sprite != null
		and _sprite.visible
		and not _pointer_held
		and not _autonomy_paused
		and not _forced_target_pending
		and _behavior not in [
			Behavior.GRABBED,
			Behavior.FALLING,
			Behavior.SWALLOWED,
			Behavior.UNDERGROUND,
			Behavior.HIDDEN
		]
	)


func start_swallowed_by(swallower: Node2D, hold_seconds: float) -> bool:
	if swallower == null or not is_instance_valid(swallower) or not can_be_swallowed():
		return false
	_cancel_special_behavior()
	_swallower = swallower
	_swallow_phase = SwallowPhase.SUCKING_IN
	_swallow_progress = 0.0
	_swallow_hold_time = clampf(hold_seconds, 1.0, 20.0)
	_swallow_start_position = position
	_behavior = Behavior.SWALLOWED
	z_index = 180
	_set_interaction_enabled(false)
	if _hover_hint != null:
		_hover_hint.visible = false
	return true


func is_swallowed() -> bool:
	return _behavior == Behavior.SWALLOWED


func walk_to_offering_x(target_x: float) -> void:
	_cancel_special_behavior()
	_target_x = clampf(target_x, _min_x, _max_x)
	_forced_target_pending = true
	_walk_speed = PET_OFFERING_WALK_SPEED
	if absf(_target_x - position.x) < 4.0:
		_walk_speed = _base_walk_speed
		_forced_target_pending = false
		_start_idle()
		forced_target_reached.emit(self)
		return

	_behavior = Behavior.WALK
	_face_direction(_target_x - position.x)
	_sprite.play("walk")


func is_pointer_captured() -> bool:
	return _pointer_held or _behavior == Behavior.GRABBED


func cancel_pointer_capture() -> void:
	if _pointer_held or _behavior == Behavior.GRABBED:
		_finish_pointer_hold(true)


func set_pointer_hovered(hovered: bool) -> void:
	if _hovering == hovered:
		return
	_hovering = hovered
	_hover_time = 0.0
	if not hovered and _hover_hint != null:
		_hover_hint.visible = false


func react_to_petting(emotion: String) -> void:
	_react_to_emotion(emotion)


func react_to_emotion(emotion: String) -> void:
	if _battle_mode and emotion == "sleepy":
		return
	_react_to_emotion(emotion)


func _react_to_emotion(emotion: String) -> void:
	if _pointer_held or _behavior == Behavior.GRABBED or _behavior == Behavior.FALLING:
		return
	if _forced_target_pending:
		return
	if _battle_mode:
		return
	if _behavior in [Behavior.HIDDEN, Behavior.POPPING]:
		return

	match _behavior_style:
		"sleepy_floater":
			if emotion == "sleepy" and _behavior not in [Behavior.SLEEP_CLOSING, Behavior.SLEEPING, Behavior.SLEEP_OPENING]:
				_cancel_special_behavior()
				_start_sleeping()
				return
		"burrower":
			if emotion == "confused" and _behavior not in [Behavior.BURROW_DOWN, Behavior.UNDERGROUND, Behavior.BURROW_UP]:
				_cancel_special_behavior()
				_start_burrowing()
				return
		"skitterer":
			if emotion == "suprised":
				_cancel_special_behavior()
				_choose_walk_target()
				return
		"wall_climber":
			if _can_wall_crawl and emotion == "suprised" and _behavior not in [Behavior.WALL_MOUNT, Behavior.WALL_CRAWL_UP, Behavior.WALL_PAUSE, Behavior.WALL_CRAWL_DOWN, Behavior.WALL_LANDING]:
				_cancel_special_behavior()
				_start_wall_trip()
				return

	if emotion == "sleepy" and _doze_chance > 0.0 and _behavior != Behavior.DOZING:
		_cancel_special_behavior()
		_start_dozing()


func _input(event: InputEvent) -> void:
	if not _pointer_held:
		return
	if event is InputEventMouseMotion:
		if _behavior == Behavior.GRABBED:
			_update_grabbed_position()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_pointer_hold()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_pointer_interaction(delta)
	_update_pet(delta)
	_input_window_update_time += maxf(0.0, delta)
	if _pointer_held or _input_window_update_time >= INPUT_WINDOW_UPDATE_INTERVAL:
		_input_window_update_time = 0.0
		_update_interaction_area()
	_update_hover_hint(delta)


func get_interaction_rect() -> Rect2:
	if _behavior in [Behavior.UNDERGROUND, Behavior.HIDDEN]:
		return Rect2(position, Vector2.ZERO)
	return _interaction_rect


func is_point_over_opaque_pixel(window_position: Vector2) -> bool:
	if _sprite == null or not _sprite.visible or _sprite.sprite_frames == null:
		return false

	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture == null:
		return false

	var image := _stable_hit_image
	if image == null:
		image = _get_frame_hit_image(texture, _sprite.animation, _sprite.frame)
	if image == null or image.is_empty():
		return false

	var sprite_local := _sprite.to_local(window_position)
	var pixel_x := int(floor(sprite_local.x + (float(image.get_width()) * 0.5)))
	var pixel_y := int(floor(sprite_local.y + (float(image.get_height()) * 0.5)))
	if _sprite.flip_h:
		pixel_x = image.get_width() - 1 - pixel_x

	if pixel_x < 0 or pixel_y < 0 or pixel_x >= image.get_width() or pixel_y >= image.get_height():
		return false
	var min_x := maxi(0, pixel_x - HIT_SLOP_PIXELS)
	var max_x := mini(image.get_width() - 1, pixel_x + HIT_SLOP_PIXELS)
	var min_y := maxi(0, pixel_y - HIT_SLOP_PIXELS)
	var max_y := mini(image.get_height() - 1, pixel_y + HIT_SLOP_PIXELS)
	for sample_y in range(min_y, max_y + 1):
		for sample_x in range(min_x, max_x + 1):
			if image.get_pixel(sample_x, sample_y).a > 0.04:
				return true
	return false


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
	_stable_hit_image = _build_stable_hit_image(_sprite.sprite_frames)
	_stable_hit_polygon = _build_stable_hit_polygon(_stable_hit_image)
	add_child(_sprite)
	_sprite.play("idle")


func _build_stable_hit_image(frames: SpriteFrames) -> Image:
	var stable_image: Image
	for animation_name in ["idle", "walk"]:
		if not frames.has_animation(animation_name):
			continue
		for frame_index in frames.get_frame_count(animation_name):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			if texture == null:
				continue
			var frame_image := texture.get_image()
			if frame_image == null or frame_image.is_empty():
				continue
			frame_image.convert(Image.FORMAT_RGBA8)
			if stable_image == null:
				stable_image = Image.create_empty(frame_image.get_width(), frame_image.get_height(), false, Image.FORMAT_RGBA8)
				stable_image.fill(Color.TRANSPARENT)
			if frame_image.get_size() != stable_image.get_size():
				continue
			stable_image.blend_rect(frame_image, Rect2i(Vector2i.ZERO, frame_image.get_size()), Vector2i.ZERO)
	return stable_image


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


func _build_stable_hit_polygon(image: Image) -> PackedVector2Array:
	if image == null or image.is_empty():
		return PackedVector2Array()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.04)
	var outlines := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.5)
	var points := PackedVector2Array()
	for outline_value in outlines:
		var outline: PackedVector2Array = outline_value
		points.append_array(outline)
	if points.size() < 3:
		return points
	return Geometry2D.convex_hull(points)


func _create_interaction_area() -> void:
	_create_hover_hint()


func _create_input_window() -> void:
	_input_window = Window.new()
	_input_window.name = "%sInputWindow" % pet_id
	_input_window.title = "Cthulu Pet Input"
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
	_interaction_area.name = "%sInteractionArea" % pet_id
	_interaction_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_interaction_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_interaction_area.gui_input.connect(_on_gui_input)
	_input_window.add_child(_interaction_area)


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
		_hover_hint.text = (
			"%s\nHold to drag · Click to pet · Right-click to recall"
			if _language == "en"
			else "%s\n按住拖动 · 短按抚摸  右键召回"
		) % display_name


func _update_pet(delta: float) -> void:
	_float_phase += delta * 2.15
	if _pointer_held and _behavior != Behavior.GRABBED:
		return
	if _autonomy_paused and _behavior not in [Behavior.GRABBED, Behavior.FALLING]:
		if _behavior_style == "sleepy_floater":
			_settle_floater_height(delta)
			_apply_floating_position(_float_bob_amplitude)
		return
	match _behavior:
		Behavior.GRABBED:
			_update_grabbed_position()
		Behavior.FALLING:
			_update_falling(delta)
		Behavior.SWALLOWED:
			_update_swallowed(delta)
		Behavior.WALK:
			_update_walking(delta)
		Behavior.IDLE:
			_update_idle(delta)
		Behavior.UNDERGROUND:
			_special_time -= delta
			if _special_time <= 0.0:
				_start_emerging()
		Behavior.SLEEPING:
			_apply_sleep_pose()
			_special_time -= delta
			if _special_time <= 0.0:
				_behavior = Behavior.SLEEP_OPENING
				_sprite.play("open_eye")
		Behavior.BURROW_DOWN, Behavior.BURROW_UP:
			_apply_grounded_position(false)
		Behavior.SLEEP_CLOSING, Behavior.SLEEP_OPENING:
			_apply_sleep_pose()
		Behavior.DOZING:
			_update_dozing(delta)
		Behavior.HIDDEN:
			_special_time -= delta
			if _special_time <= 0.0:
				_start_popping()
		Behavior.POPPING:
			_update_popping(delta)
		Behavior.WALL_MOUNT:
			_update_wall_mount(delta)
		Behavior.WALL_CRAWL_UP:
			_update_wall_crawl(delta, -1.0)
		Behavior.WALL_PAUSE:
			_special_time -= delta
			if _special_time <= 0.0:
				_start_wall_descent()
		Behavior.WALL_CRAWL_DOWN:
			_update_wall_crawl(delta, 1.0)
		Behavior.WALL_LANDING:
			_update_wall_landing(delta)
		Behavior.AIR_ROAM_OUT, Behavior.AIR_ROAM_RETURN:
			_update_air_roam(delta)
		Behavior.AIR_ROAM_PAUSE:
			_apply_air_pause_motion()
			_special_time -= delta
			if _special_time <= 0.0:
				if _air_roam_legs_remaining > 0:
					_start_next_air_roam_leg()
				else:
					_start_idle()


func _update_swallowed(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	match _swallow_phase:
		SwallowPhase.SUCKING_IN:
			_swallow_progress = minf(1.0, _swallow_progress + (safe_delta / SWALLOW_IN_DURATION))
			var eased_in := ease(_swallow_progress, 2.2)
			position = _swallow_start_position.lerp(_get_swallower_position(), eased_in)
			_sprite.scale = Vector2.ONE * _pet_scale * lerpf(1.0, 0.08, eased_in)
			_sprite.rotation += safe_delta * 8.0
			if _swallow_progress >= 1.0:
				_swallow_phase = SwallowPhase.HELD
				_sprite.visible = false
		SwallowPhase.HELD:
			position = _get_swallower_position()
			_swallow_hold_time -= safe_delta
			if _swallow_hold_time <= 0.0 or _swallower == null or not is_instance_valid(_swallower):
				_begin_swallow_spit()
		SwallowPhase.SPITTING_OUT:
			_swallow_progress = minf(1.0, _swallow_progress + (safe_delta / SWALLOW_OUT_DURATION))
			var eased_out := ease(_swallow_progress, -2.0)
			position = _swallow_start_position.lerp(_swallow_target_position, eased_out)
			position.y -= sin(_swallow_progress * PI) * 64.0
			_sprite.scale = Vector2.ONE * _pet_scale * lerpf(0.12, 1.0, eased_out)
			_sprite.rotation = lerpf(-0.8, 0.0, eased_out)
			if _swallow_progress >= 1.0:
				_finish_swallowed()
		_:
			_finish_swallowed()


func _get_swallower_position() -> Vector2:
	if _swallower != null and is_instance_valid(_swallower):
		return _swallower.position
	return position


func _begin_swallow_spit() -> void:
	_swallow_phase = SwallowPhase.SPITTING_OUT
	_swallow_progress = 0.0
	_swallow_start_position = _get_swallower_position()
	var direction := -1.0 if _swallow_start_position.x >= (_min_x + _max_x) * 0.5 else 1.0
	if _rng.randf() < 0.28:
		direction *= -1.0
	var target_x := clampf(
		_swallow_start_position.x + direction * _rng.randf_range(
			SWALLOW_SPIT_DISTANCE_MIN,
			SWALLOW_SPIT_DISTANCE_MAX
		),
		_min_x,
		_max_x
	)
	var target_y := _get_rest_y()
	if _behavior_style == "sleepy_floater":
		var air_bounds := _get_air_roam_y_bounds()
		target_y = clampf(
			_swallow_start_position.y + _rng.randf_range(-48.0, 48.0),
			air_bounds.x,
			_get_rest_y()
		)
	_swallow_target_position = Vector2(target_x, target_y)
	_sprite.visible = true


func _finish_swallowed() -> void:
	_swallow_phase = SwallowPhase.NONE
	_swallower = null
	position.x = clampf(position.x, _min_x, _max_x)
	if _swallow_target_position != Vector2.ZERO:
		position = _swallow_target_position
	_swallow_target_position = Vector2.ZERO
	z_index = 0
	_sprite.scale = Vector2.ONE * _pet_scale
	_sprite.rotation = 0.0
	_sprite.visible = true
	_set_interaction_enabled(true)
	if _behavior_style == "sleepy_floater":
		_float_anchor_y = position.y
	else:
		position.y = _get_rest_y()
	_start_idle()


func _update_walking(delta: float) -> void:
	var step := _walk_speed * delta
	var distance := _target_x - position.x
	if absf(distance) <= step:
		position.x = _target_x
		if _hide_pending:
			_start_hidden()
			return
		if _wall_pending:
			_start_wall_mount()
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
	if _rolls_while_walking:
		_sprite.rotation = wrapf(
			_sprite.rotation + (signf(distance) * _walk_rotation_speed * delta),
			-PI,
			PI
		)
	if _sprite.animation != "walk":
		_sprite.play("walk")
	if _behavior_style == "sleepy_floater":
		_settle_floater_height(delta)
		_apply_floating_position(_float_bob_amplitude)
	else:
		_apply_grounded_position(false)


func _update_idle(delta: float) -> void:
	if _behavior_style == "sleepy_floater":
		_settle_floater_height(delta)
	_apply_grounded_position(_behavior_style == "sleepy_floater")
	if _behavior_style == "sleepy_floater":
		position.x = clampf(_idle_anchor_x + sin(_float_phase * 0.63) * 3.5, _min_x, _max_x)
	elif _behavior_style == "watcher":
		_idle_turn_time -= delta
		if _idle_turn_time <= 0.0:
			_face_direction(-1.0 if _rng.randf() < 0.5 else 1.0)
			_idle_turn_time = _rng.randf_range(12.0, 30.0)
	_idle_time -= delta
	if _idle_time <= 0.0:
		_choose_next_action()


func _choose_next_action() -> void:
	if _rng.randf() >= _activity_chance:
		_start_idle()
		return
	var special_roll := _rng.randf()
	var action_threshold := 0.0
	if _behavior_style == "burrower":
		action_threshold += _special_chance
		if special_roll < action_threshold:
			_start_burrowing()
			return
	elif _behavior_style == "sleepy_floater":
		action_threshold += _special_chance
		if special_roll < action_threshold:
			_start_sleeping()
			return
		action_threshold += _air_roam_chance
		if special_roll < action_threshold:
			_start_air_roam()
			return

	action_threshold += _doze_chance
	if special_roll < action_threshold:
		_start_dozing()
		return
	action_threshold += _hide_chance
	if special_roll < action_threshold:
		_start_hiding()
		return
	action_threshold += _wall_chance if _can_wall_crawl and not _activity_restricted else 0.0
	if special_roll < action_threshold:
		_start_wall_trip()
		return
	_choose_walk_target()


func _choose_walk_target() -> void:
	_choose_general_walk_target()
	_begin_walk_to_selected_target()


func _choose_general_walk_target() -> void:
	var distance := _rng.randf_range(_walk_distance_min, _walk_distance_max)
	var direction := -1.0 if _rng.randf() < 0.5 else 1.0
	var first_target := clampf(position.x + (distance * direction), _min_x, _max_x)
	var opposite_target := clampf(position.x - (distance * direction), _min_x, _max_x)
	_target_x = first_target
	var first_distance := absf(first_target - position.x)
	var opposite_distance := absf(opposite_target - position.x)
	if first_distance < _walk_distance_min and opposite_distance > first_distance:
		_target_x = opposite_target


func _begin_walk_to_selected_target() -> void:
	if absf(_target_x - position.x) < 10.0:
		_start_idle()
		return
	_behavior = Behavior.WALK
	_walk_speed = _base_walk_speed
	_face_direction(_target_x - position.x)
	_sprite.play("walk")


func _start_idle() -> void:
	_behavior = Behavior.IDLE
	_hide_pending = false
	_idle_anchor_x = clampf(position.x, _min_x, _max_x)
	position.x = _idle_anchor_x
	_idle_time = _rng.randf_range(_idle_time_min, _idle_time_max)
	_idle_turn_time = _rng.randf_range(12.0, 30.0)
	_sprite.rotation = 0.0
	_sprite.speed_scale = 1.0
	_sprite.visible = true
	_sprite.play("idle")
	_set_interaction_enabled(true)


func _start_burrowing() -> void:
	_behavior = Behavior.BURROW_DOWN
	_sprite.play("burrow")
	notable_action.emit(self, "burrow")


func _start_emerging() -> void:
	position.x = _rng.randf_range(_min_x, _max_x)
	_behavior = Behavior.BURROW_UP
	_sprite.visible = true
	_set_interaction_enabled(true)
	_sprite.play("emerge")


func _start_sleeping() -> void:
	if _battle_mode:
		_start_idle()
		return
	_sleep_anchor_position = position
	if _behavior_style == "sleepy_floater":
		_float_anchor_y = position.y
	_behavior = Behavior.SLEEP_CLOSING
	_sprite.play("close_eye")
	notable_action.emit(self, "sleep")


func _start_dozing() -> void:
	if _battle_mode:
		_start_idle()
		return
	_doze_anchor_position = position
	_behavior = Behavior.DOZING
	_special_time = _rng.randf_range(_doze_time_min, _doze_time_max)
	_sprite.rotation = 0.0
	_sprite.speed_scale = DOZE_ANIMATION_SPEED_SCALE
	_sprite.play("idle")
	notable_action.emit(self, "sleep")


func _update_dozing(delta: float) -> void:
	position = _doze_anchor_position + Vector2(0.0, sin(_float_phase * 0.55) * 1.2)
	_sprite.rotation = sin(_float_phase * 0.36) * 0.018
	_special_time -= delta
	if _special_time <= 0.0:
		_start_idle()


func _start_hiding() -> void:
	if not _can_hide:
		_start_idle()
		return
	_hide_pending = true
	_wall_pending = false
	_forced_target_pending = false
	_target_x = clampf(_min_x + _rng.randf_range(0.0, minf(42.0, (_max_x - _min_x) * 0.08)), _min_x, _max_x)
	_walk_speed = _base_walk_speed
	_sprite.rotation = 0.0
	_sprite.speed_scale = 1.0
	if absf(_target_x - position.x) < 4.0:
		_start_hidden()
		return
	_behavior = Behavior.WALK
	_face_direction(_target_x - position.x)
	_sprite.play("walk")


func _start_hidden() -> void:
	_hide_pending = false
	_behavior = Behavior.HIDDEN
	_special_time = _rng.randf_range(_hide_time_min, _hide_time_max)
	position.y = _get_rest_y()
	_sprite.visible = false
	_set_interaction_enabled(false)
	notable_action.emit(self, "hide")


func _start_popping() -> void:
	_behavior = Behavior.POPPING
	_pop_progress = 0.0
	_pop_duration = _rng.randf_range(POP_DURATION_MIN, POP_DURATION_MAX)
	_pop_height = _rng.randf_range(_pop_height_min, _pop_height_max)
	_pop_start_position = Vector2(clampf(position.x, _min_x, _max_x), _get_rest_y())
	var pop_distance := _rng.randf_range(_pop_distance_min, _pop_distance_max)
	var direction := 1.0 if _pop_start_position.x <= (_min_x + _max_x) * 0.5 else -1.0
	var target_x := clampf(_pop_start_position.x + (pop_distance * direction), _min_x, _max_x)
	if absf(target_x - _pop_start_position.x) < minf(40.0, (_max_x - _min_x) * 0.25):
		target_x = clampf(_pop_start_position.x - (pop_distance * direction), _min_x, _max_x)
	_pop_target_position = Vector2(target_x, _get_rest_y())
	position = _pop_start_position
	_sprite.rotation = 0.0
	_sprite.speed_scale = 1.0
	_sprite.visible = true
	_set_interaction_enabled(true)
	_face_direction(_pop_target_position.x - position.x)
	_sprite.play("walk")
	notable_action.emit(self, "ambush")


func _update_popping(delta: float) -> void:
	_pop_progress = minf(1.0, _pop_progress + (delta / maxf(0.01, _pop_duration)))
	var eased_progress := smoothstep(0.0, 1.0, _pop_progress)
	position = _pop_start_position.lerp(_pop_target_position, eased_progress)
	position.y -= sin(_pop_progress * PI) * _pop_height
	if _pop_progress >= 1.0:
		position = _pop_target_position
		if _behavior_style == "sleepy_floater":
			_float_anchor_y = _pop_target_position.y
		_start_idle()


func _start_air_roam() -> void:
	_air_roam_legs_remaining = _rng.randi_range(_air_roam_legs_min, _air_roam_legs_max)
	notable_action.emit(self, "air_roam")
	_start_next_air_roam_leg()


func _start_next_air_roam_leg() -> void:
	if _air_roam_legs_remaining <= 0:
		_start_idle()
		return
	_air_roam_legs_remaining -= 1
	_begin_air_path(_choose_air_roam_destination(), Behavior.AIR_ROAM_OUT)


func _choose_air_roam_destination() -> Vector2:
	var y_bounds := _get_air_roam_y_bounds()
	var best_destination := Vector2(
		_rng.randf_range(_min_x, _max_x),
		_rng.randf_range(y_bounds.x, y_bounds.y)
	)
	var best_distance := position.distance_to(best_destination)
	# A few candidates keep consecutive legs visibly different without making
	# the route deterministic or biased toward a single height band.
	for _attempt in 3:
		var candidate := Vector2(
			_rng.randf_range(_min_x, _max_x),
			_rng.randf_range(y_bounds.x, y_bounds.y)
		)
		var candidate_distance := position.distance_to(candidate)
		if candidate_distance > best_distance:
			best_destination = candidate
			best_distance = candidate_distance
	return best_destination


func _get_air_roam_y_bounds() -> Vector2:
	var rest_y := _get_rest_y()
	var upper_y := maxf(_get_drag_min_y(), rest_y - AIR_ROAM_MAX_HEIGHT)
	var lower_y := clampf(rest_y - AIR_ROAM_MIN_HEIGHT, upper_y, rest_y)
	return Vector2(upper_y, lower_y)


func _settle_floater_height(delta: float) -> void:
	if _behavior_style != "sleepy_floater":
		return
	var low_air_bounds := _get_air_roam_y_bounds()
	var target_y := clampf(_float_anchor_y, low_air_bounds.x, low_air_bounds.y)
	_float_anchor_y = move_toward(
		_float_anchor_y,
		target_y,
		FLOATER_HEIGHT_RETURN_SPEED * maxf(0.0, delta)
	)


func _start_air_return() -> void:
	_air_roam_legs_remaining = 0
	var destination := Vector2(clampf(position.x, _min_x, _max_x), _get_rest_y())
	_begin_air_path(destination, Behavior.AIR_ROAM_RETURN)


func _begin_air_path(destination: Vector2, next_behavior: int) -> void:
	_air_path_start = position
	_air_path_target = destination
	_air_path_progress = 0.0
	_air_path_duration = maxf(0.8, _air_path_start.distance_to(destination) / AIR_ROAM_SPEED)
	_behavior = next_behavior
	_face_direction(destination.x - position.x)
	_sprite.play("walk")


func _update_air_roam(delta: float) -> void:
	_air_path_progress = minf(1.0, _air_path_progress + (delta / _air_path_duration))
	var eased_progress := smoothstep(0.0, 1.0, _air_path_progress)
	var path_direction := _air_path_target - _air_path_start
	var perpendicular := Vector2(-path_direction.y, path_direction.x).normalized()
	var wave_envelope := sin(_air_path_progress * PI)
	var curved_offset := perpendicular * sin(_air_path_progress * PI * 3.0) * 18.0 * wave_envelope
	var bob_offset := Vector2(0.0, sin(_float_phase * 1.35) * 5.0 * wave_envelope)
	position = _air_path_start.lerp(_air_path_target, eased_progress) + curved_offset + bob_offset
	if _air_path_progress < 1.0:
		return

	position = _air_path_target
	_float_anchor_y = position.y
	if _behavior == Behavior.AIR_ROAM_OUT:
		_behavior = Behavior.AIR_ROAM_PAUSE
		_special_time = (
			_rng.randf_range(AIR_ROAM_LEG_PAUSE_MIN, AIR_ROAM_LEG_PAUSE_MAX)
			if _air_roam_legs_remaining > 0
			else _rng.randf_range(2.5, 6.0)
		)
		_sprite.play("idle")
	else:
		_start_idle()


func _apply_air_pause_motion() -> void:
	position = _air_path_target + Vector2(
		sin(_float_phase * 0.58) * 7.0,
		sin(_float_phase * 1.12) * 11.0
	)


func _start_wall_trip() -> void:
	if not _can_wall_crawl or _activity_restricted:
		_wall_pending = false
		_choose_walk_target()
		return
	_wall_edge = -1 if _rng.randf() < 0.5 else 1
	_wall_pending = true
	_behavior = Behavior.WALK
	_walk_speed = _base_walk_speed
	_face_direction(float(_wall_edge))
	_sprite.rotation = 0.0
	_target_x = _get_wall_approach_x()
	_sprite.play("walk")


func _start_wall_mount() -> void:
	if not _can_wall_crawl or _activity_restricted:
		_wall_pending = false
		_start_idle()
		return
	_wall_pending = false
	_behavior = Behavior.WALL_MOUNT
	_wall_transition_progress = 0.0
	_wall_transition_start_rotation = 0.0
	_sprite.rotation = 0.0
	_face_direction(float(_wall_edge))
	_snap_to_wall()
	_snap_to_ground()
	_sprite.play("walk")


func _update_wall_mount(delta: float) -> void:
	_wall_transition_progress = minf(
		1.0,
		_wall_transition_progress + (delta / WALL_CORNER_TURN_DURATION)
	)
	var eased_progress := smoothstep(0.0, 1.0, _wall_transition_progress)
	_sprite.rotation = lerpf(0.0, _get_wall_rotation(), eased_progress)
	_snap_to_wall()
	_snap_to_ground()
	if _wall_transition_progress >= 1.0:
		_start_wall_crawl()


func _start_wall_crawl() -> void:
	if not _can_wall_crawl or _activity_restricted:
		_wall_pending = false
		_start_idle()
		return
	_wall_pending = false
	_behavior = Behavior.WALL_CRAWL_UP
	position.x = _get_wall_x()
	_wall_target_y = _rng.randf_range(105.0, maxf(125.0, _get_rest_y() - 170.0))
	_apply_wall_orientation(true)
	_sprite.play("walk")
	notable_action.emit(self, "wall_crawl")


func _start_wall_descent() -> void:
	_behavior = Behavior.WALL_CRAWL_DOWN
	_apply_wall_orientation(false)
	_sprite.play("walk")


func _apply_wall_orientation(climbing_up: bool) -> void:
	# The sprite's local bottom is the contact surface. Keeping the rotation fixed
	# for each wall keeps that same surface attached while flip_h changes only
	# whether the head points up or down.
	_face_direction(float(_wall_edge if climbing_up else -_wall_edge))
	_sprite.rotation = _get_wall_rotation()
	_snap_to_wall()


func _get_wall_rotation() -> float:
	return PI * 0.5 if _wall_edge < 0 else -PI * 0.5


func _snap_to_wall() -> void:
	var visual_rect := _get_sprite_visual_rect()
	if visual_rect.size == Vector2.ZERO:
		return
	if _wall_edge < 0:
		position.x -= visual_rect.position.x
	else:
		position.x += float(_window_size.x) - (visual_rect.position.x + visual_rect.size.x)
	_target_x = position.x


func _snap_to_ground() -> void:
	var visual_rect := _get_sprite_visual_rect()
	if visual_rect.size == Vector2.ZERO:
		return
	position.y += _get_ground_contact_y() - visual_rect.end.y


func _get_wall_floor_target_y() -> float:
	var visual_rect := _get_sprite_visual_rect()
	if visual_rect.size == Vector2.ZERO:
		return _get_rest_y()
	return position.y + (_get_ground_contact_y() - visual_rect.end.y)


func _update_wall_crawl(delta: float, direction: float) -> void:
	var destination_y := _wall_target_y if direction < 0.0 else _get_wall_floor_target_y()
	position.y = move_toward(position.y, destination_y, WALL_CRAWL_SPEED * delta)
	if not is_equal_approx(position.y, destination_y):
		return
	if direction < 0.0:
		_behavior = Behavior.WALL_PAUSE
		_special_time = _rng.randf_range(_special_time_min, _special_time_max)
		_sprite.play("idle")
	else:
		_start_wall_landing()


func _start_wall_landing() -> void:
	_behavior = Behavior.WALL_LANDING
	_wall_transition_progress = 0.0
	_wall_transition_start_rotation = _sprite.rotation
	_snap_to_wall()
	_snap_to_ground()
	_sprite.play("walk")


func _update_wall_landing(delta: float) -> void:
	_wall_transition_progress = minf(
		1.0,
		_wall_transition_progress + (delta / WALL_CORNER_TURN_DURATION)
	)
	var eased_progress := smoothstep(0.0, 1.0, _wall_transition_progress)
	_sprite.rotation = lerpf(_wall_transition_start_rotation, 0.0, eased_progress)
	_snap_to_wall()
	_snap_to_ground()
	if _wall_transition_progress >= 1.0:
		_finish_wall_landing()


func _finish_wall_landing() -> void:
	_sprite.rotation = 0.0
	_face_direction(float(-_wall_edge))
	_snap_to_wall()
	_snap_to_ground()
	_behavior = Behavior.WALK
	_walk_speed = _base_walk_speed
	_target_x = _min_x if _wall_edge < 0 else _max_x
	_sprite.play("walk")
	if absf(_target_x - position.x) < 1.0:
		_start_idle()


func _on_animation_finished() -> void:
	if _battle_attack_animation and _sprite != null and _sprite.animation == "attack":
		_battle_attack_animation = false
		if _battle_mode:
			_sprite.play("idle")
		return
	match _behavior:
		Behavior.BURROW_DOWN:
			_behavior = Behavior.UNDERGROUND
			_special_time = _rng.randf_range(_special_time_min, _special_time_max)
			_sprite.visible = false
			_set_interaction_enabled(false)
		Behavior.BURROW_UP:
			_start_idle()
		Behavior.SLEEP_CLOSING:
			_behavior = Behavior.SLEEPING
			_special_time = _rng.randf_range(_special_time_min, _special_time_max)
			_sprite.play("sleep")
		Behavior.SLEEP_OPENING:
			_float_anchor_y = _sleep_anchor_position.y
			_start_idle()


func _cancel_special_behavior() -> void:
	var restore_ground := _hide_pending or _behavior in [Behavior.DOZING, Behavior.HIDDEN, Behavior.POPPING]
	_wall_pending = false
	_hide_pending = false
	_air_roam_legs_remaining = 0
	_forced_target_pending = false
	_sprite.rotation = 0.0
	_sprite.speed_scale = 1.0
	_sprite.visible = true
	_set_interaction_enabled(true)
	position.x = clampf(position.x, _min_x, _max_x)
	if restore_ground and _behavior_style != "sleepy_floater":
		position.y = _get_rest_y()
	if _behavior_style == "sleepy_floater":
		_float_anchor_y = position.y


func _face_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return
	var moving_right := direction > 0.0
	_sprite.flip_h = moving_right != _faces_right


func _apply_grounded_position(with_float: bool) -> void:
	_apply_floating_position(_float_bob_amplitude if with_float else 0.0)


func _apply_floating_position(amplitude: float) -> void:
	var primary_wave := sin(_float_phase) * 0.78
	var secondary_wave := sin((_float_phase * 0.47) + 1.2) * 0.22
	var anchor_y := _float_anchor_y if _behavior_style == "sleepy_floater" else _get_rest_y()
	position.y = anchor_y + ((primary_wave + secondary_wave) * amplitude)


func _apply_sleep_pose() -> void:
	position = _sleep_anchor_position + Vector2(0.0, sin(_float_phase * 0.55) * 1.8)


func _update_pointer_interaction(delta: float) -> void:
	if not _pointer_held:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_pointer_hold()
		return
	_pointer_hold_time += delta
	if (
		_behavior != Behavior.GRABBED
		and _get_pointer_position().distance_to(_press_position) > GRAB_CLICK_TOLERANCE
	):
		_begin_grab()
	if _pointer_hold_time >= POINTER_CAPTURE_TIMEOUT_SECONDS:
		_finish_pointer_hold(true)


func _begin_grab() -> void:
	if _battle_motion_tween != null and is_instance_valid(_battle_motion_tween):
		_battle_motion_tween.kill()
		_battle_motion_tween = null
	_cancel_special_behavior()
	_battle_attack_animation = false
	_behavior = Behavior.GRABBED
	z_index = 500
	if _interaction_area != null:
		_interaction_area.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_sprite.play("idle")
	if _hover_hint != null:
		_hover_hint.visible = false
	grabbed_changed.emit(self, true)


func _update_grabbed_position() -> void:
	var mouse_position := _get_pointer_position()
	var target := mouse_position + _grab_offset
	target.x = clampf(target.x, _get_drag_min_x(), _get_drag_max_x())
	target.y = clampf(target.y, _get_drag_min_y(), _get_drag_max_y())
	position = target


func _finish_pointer_hold(force_cancel := false) -> void:
	if not _pointer_held and _behavior != Behavior.GRABBED:
		return
	_pointer_held = false
	if _behavior != Behavior.GRABBED:
		var pointer_distance := INF if force_cancel else _get_pointer_position().distance_to(_press_position)
		var is_petting_click := not force_cancel and _pointer_hold_time <= PETTING_CLICK_MAX_SECONDS and pointer_distance <= GRAB_CLICK_TOLERANCE
		_pointer_hold_time = 0.0
		if is_petting_click:
			petted.emit(self)
		return
	if _behavior == Behavior.GRABBED:
		z_index = 210 if _battle_mode else 0
		if _interaction_area != null:
			_interaction_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		grabbed_changed.emit(self, false)
		var pointer_distance := INF
		if not force_cancel:
			pointer_distance = _get_pointer_position().distance_to(_press_position)
		var is_petting_click := not force_cancel and _pointer_hold_time <= PETTING_CLICK_MAX_SECONDS and pointer_distance <= GRAB_CLICK_TOLERANCE
		if is_petting_click:
			position = _press_actor_position
			_start_idle()
			petted.emit(self)
		elif _behavior_style == "sleepy_floater":
			_float_anchor_y = clampf(position.y, _get_drag_min_y(), _get_rest_y())
			position.y = _float_anchor_y
			_start_idle()
		else:
			_behavior = Behavior.FALLING
			_fall_velocity = 0.0
	_pointer_hold_time = 0.0


func _update_falling(delta: float) -> void:
	var rest_y := _get_rest_y()
	if position.y >= rest_y:
		position.y = rest_y
		if _behavior_style == "sleepy_floater":
			_float_anchor_y = rest_y
		_start_idle()
		return
	_fall_velocity += FALL_GRAVITY * delta
	position.y = minf(rest_y, position.y + (_fall_velocity * delta))
	if position.y >= rest_y:
		if _behavior_style == "sleepy_floater":
			_float_anchor_y = rest_y
		_start_idle()


func _get_pointer_position() -> Vector2:
	var window := _visual_window if _visual_window != null else get_window()
	if window == null:
		return get_viewport().get_mouse_position()
	var global_mouse := DisplayServer.mouse_get_position()
	return Vector2(global_mouse - window.position)


func _set_safe_bounds(min_x: float, max_x: float) -> void:
	var left_inset := 48.0
	var right_inset := 48.0
	if _stable_hit_image != null and not _stable_hit_image.is_empty():
		var visible_bounds := _stable_hit_image.get_used_rect()
		if visible_bounds.size != Vector2i.ZERO:
			var half_frame_width := float(_stable_hit_image.get_width()) * 0.5
			var local_left := float(visible_bounds.position.x) - half_frame_width
			var local_right := float(visible_bounds.end.x) - half_frame_width
			left_inset = maxf(24.0, -local_left * _pet_scale + 6.0)
			right_inset = maxf(24.0, local_right * _pet_scale + 6.0)
	_min_x = maxf(min_x, left_inset)
	_max_x = minf(max_x, float(_window_size.x) - right_inset)
	if _max_x < _min_x:
		var center_x := float(_window_size.x) * 0.5
		_min_x = center_x
		_max_x = center_x


func _get_drag_min_x() -> float:
	return _min_x


func _get_drag_max_x() -> float:
	return _max_x


func _get_drag_min_y() -> float:
	if _stable_hit_image == null or _stable_hit_image.is_empty():
		return 32.0
	var bounds := _stable_hit_image.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return 32.0
	var local_top := float(bounds.position.y) - (float(_stable_hit_image.get_height()) * 0.5)
	return maxf(24.0, (-local_top * _pet_scale) + 6.0)


func _get_drag_max_y() -> float:
	if _stable_hit_image == null or _stable_hit_image.is_empty():
		return float(_window_size.y) - 12.0
	var bounds := _stable_hit_image.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return float(_window_size.y) - 12.0
	var local_bottom := float(bounds.end.y) - (float(_stable_hit_image.get_height()) * 0.5)
	var bottom_inset := maxf(12.0, (local_bottom * _pet_scale) + 6.0)
	return maxf(_get_drag_min_y(), clampf(_stage_ground_y, 0.0, float(_window_size.y)) - bottom_inset)


func _get_wall_x() -> float:
	if _stable_hit_image == null or _stable_hit_image.is_empty() or _sprite == null:
		return 48.0 if _wall_edge < 0 else float(_window_size.x) - 48.0
	var bounds := _stable_hit_image.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return 48.0 if _wall_edge < 0 else float(_window_size.x) - 48.0
	var local_bottom := float(bounds.end.y) - (float(_stable_hit_image.get_height()) * 0.5)
	var wall_inset := local_bottom * absf(_sprite.scale.y)
	return wall_inset if _wall_edge < 0 else float(_window_size.x) - wall_inset


func _get_wall_approach_x() -> float:
	var visual_rect := _get_sprite_visual_rect()
	if visual_rect.size == Vector2.ZERO:
		return _get_wall_x()
	if _wall_edge < 0:
		return position.x - visual_rect.position.x
	return position.x + float(_window_size.x) - visual_rect.end.x


func _update_interaction_area() -> void:
	_interaction_rect = _get_sprite_input_rect().intersection(
		Rect2(Vector2.ZERO, Vector2(float(_window_size.x), clampf(_stage_ground_y, 0.0, float(_window_size.y))))
	)
	if _input_window == null or _visual_window == null:
		return
	if _interaction_rect.size.x <= 0.0 or _interaction_rect.size.y <= 0.0:
		_input_window.visible = false
		return

	var local_position := Vector2i(
		int(floor(_interaction_rect.position.x)),
		int(floor(_interaction_rect.position.y))
	)
	var proxy_size := Vector2i(
		maxi(1, int(ceil(_interaction_rect.size.x))),
		maxi(1, int(ceil(_interaction_rect.size.y)))
	)
	var next_window_position := _visual_window.position + local_position
	if next_window_position != _last_input_window_position:
		_input_window.position = next_window_position
		_last_input_window_position = next_window_position
	var shape_changed := (
		proxy_size != _last_input_window_size
		or _sprite.flip_h != _last_input_shape_flip
		or not is_equal_approx(_sprite.rotation, _last_input_shape_rotation)
		or not _sprite.scale.is_equal_approx(_last_input_shape_scale)
	)
	if proxy_size != _last_input_window_size:
		_input_window.size = proxy_size
		_last_input_window_size = proxy_size
	if shape_changed:
		_input_window.mouse_passthrough_polygon = _get_proxy_hit_polygon(Vector2(local_position), proxy_size)
		_last_input_shape_flip = _sprite.flip_h
		_last_input_shape_rotation = _sprite.rotation
		_last_input_shape_scale = _sprite.scale
	_input_window.visible = _interaction_enabled and _sprite != null and _sprite.visible and _behavior != Behavior.UNDERGROUND


func _get_sprite_input_rect() -> Rect2:
	return _get_sprite_visual_rect().grow(INPUT_PROXY_PADDING)


func _get_sprite_visual_rect() -> Rect2:
	if _stable_hit_image == null or _stable_hit_image.is_empty() or _sprite == null:
		return get_draw_rect()
	var bounds := _stable_hit_image.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		return get_draw_rect()

	var half_size := Vector2(_stable_hit_image.get_size()) * 0.5
	var left := float(bounds.position.x) - half_size.x
	var top := float(bounds.position.y) - half_size.y
	var right := float(bounds.position.x + bounds.size.x) - half_size.x
	var bottom := float(bounds.position.y + bounds.size.y) - half_size.y
	var corners := [
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner_value in corners:
		var corner: Vector2 = corner_value
		if _sprite.flip_h:
			corner.x = -corner.x
		var transformed := position + (_sprite.transform * corner)
		minimum.x = minf(minimum.x, transformed.x)
		minimum.y = minf(minimum.y, transformed.y)
		maximum.x = maxf(maximum.x, transformed.x)
		maximum.y = maxf(maximum.y, transformed.y)
	return Rect2(minimum, maximum - minimum)


func _get_proxy_hit_polygon(proxy_origin: Vector2, proxy_size: Vector2i) -> PackedVector2Array:
	if _stable_hit_polygon.size() < 3 or _sprite == null or _stable_hit_image == null:
		return PackedVector2Array([
			Vector2.ZERO,
			Vector2(proxy_size.x, 0.0),
			Vector2(proxy_size),
			Vector2(0.0, proxy_size.y)
		])
	var half_size := Vector2(_stable_hit_image.get_size()) * 0.5
	var transformed := PackedVector2Array()
	for point_value in _stable_hit_polygon:
		var point := point_value - half_size
		if _sprite.flip_h:
			point.x = -point.x
		transformed.append(position + (_sprite.transform * point) - proxy_origin)
	return transformed


func _set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if _interaction_area != null:
		_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _input_window != null:
		_input_window.visible = enabled


func _update_hover_hint(delta: float) -> void:
	if _hover_hint == null:
		return
	if not _hovering or _behavior == Behavior.GRABBED or _behavior in [Behavior.UNDERGROUND, Behavior.HIDDEN, Behavior.SWALLOWED] or not _sprite.visible:
		_hover_hint.visible = false
		return
	_hover_time += delta
	_hover_hint.visible = _hover_time >= HOVER_HINT_DELAY_SECONDS


func _get_rest_y() -> float:
	# frame_foot_y names the final occupied source pixel, while Rect2.end and
	# the window height are exclusive boundaries. The +1 keeps the last foot
	# pixel visible all the way to the taskbar without leaving a transparent row.
	var scaled_foot_bottom := (_frame_foot_y + 1.0 - _frame_center_y) * _pet_scale
	return _get_ground_contact_y() - scaled_foot_bottom


func _get_ground_contact_y() -> float:
	return _stage_ground_y + _ground_offset_y


func _resolve_stage_ground_y(configured_ground_y: float) -> float:
	if configured_ground_y < 0.0:
		return float(_window_size.y)
	return clampf(configured_ground_y, 0.0, float(_window_size.y))


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	var window_position := _get_pointer_position()
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			if not is_point_over_opaque_pixel(window_position):
				return
			_pointer_held = true
			_pointer_hold_time = 0.0
			_press_position = window_position
			_press_actor_position = position
			_grab_offset = position - window_position
			_interaction_area.accept_event()
		elif _pointer_held:
			_finish_pointer_hold()
			_interaction_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if not _battle_mode and is_point_over_opaque_pixel(window_position):
			recall_requested.emit(self)
			_interaction_area.accept_event()
