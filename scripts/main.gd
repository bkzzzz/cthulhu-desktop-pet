extends Node2D

# Dependencies
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const FollowerProgression = preload("res://scripts/domain/follower_progression.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const InventoryWindowScript = preload("res://scripts/inventory_window.gd")
const ShopWindowScript = preload("res://scripts/shop_window.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const WindowsClickthroughController = preload("res://scripts/windows_clickthrough_controller.gd")

# Window and actor layout
const PET_WINDOW_BASE_SIZE := Vector2i(820, 420)
const PET_WINDOW_HEIGHT := 420
const PET_STAGE_MARGIN_X := 72.0
const PET_STAGE_RIGHT_MARGIN := 96.0
const PET_STAGE_START_SPACING := 132.0
const POSITION_RETRY_FRAMES := 90

# Pet interaction and offering tuning
const PETTING_TEXTURE := "res://assets/ui/emotions/petting.png"
const PETTING_HOVER_TEXTURE := "res://assets/ui/emotions/pettingHovering.png"
const PETTING_CURSOR_SIZE := Vector2i(56, 56)
const OFFERING_CURSOR_SIZE := Vector2i(52, 52)
const OFFERING_DROP_SCALE := 0.36
const OFFERING_GAIN_SECONDS := 20.0
const OFFERING_GROUND_MARGIN := 2.0
const SAFE_CANVAS_MARGIN := 12.0
const EMOTION_CONFUSED_TEXTURE := "res://assets/ui/emotions/confused.png"
const EMOTION_HAPPY_TEXTURE := "res://assets/ui/emotions/happy.png"
const EMOTION_HUNGRY_TEXTURE := "res://assets/ui/emotions/hungry.png"
const EMOTION_LIKE_TEXTURE := "res://assets/ui/emotions/like.png"
const EMOTION_SLEEPY_TEXTURE := "res://assets/ui/emotions/sleepy.png"
const EMOTION_SUPRISED_TEXTURE := "res://assets/ui/emotions/suprised.png"
const PETTING_EMOTIONS := ["happy", "confused", "sleepy", "suprised"]
const EMOTION_SCALE := 0.28
const TRUST_GAIN_ON_HAPPY := 1
const TRUST_GAIN_ON_HAPPY_CHANCE := 0.05
const TRUST_PET_COOLDOWN_MIN_SECONDS := 1800.0
const TRUST_PET_COOLDOWN_MAX_SECONDS := 3600.0
const PET_HUNGER_AFTER_SECONDS := 300.0
const PET_HUNGER_NOTICE_MIN_SECONDS := 18.0
const PET_HUNGER_NOTICE_MAX_SECONDS := 34.0
const OFFERING_FAVOR_GAIN := 2
const FAVOR_COST_REDUCTION_PER_POINT := 0.004
const FAVOR_COST_REDUCTION_MAX := 0.4

# Simulation and refresh cadence
const EMOTION_MIN_INTERVAL_SECONDS := 2.8
const EMOTION_HOLD_SECONDS := 3.2
const GLOBAL_FAITH_MULTIPLIER := 1.0
const BUFF_FAITH_MULTIPLIER := 1.0
const BELIEVER_MIN_ACTIVE := 2
const BELIEVER_MAX_ACTIVE := 4
const BELIEVER_SPAWN_MIN_SECONDS := 8.0
const BELIEVER_SPAWN_MAX_SECONDS := 18.0
const BELIEVER_FORCE_SPAWN_SECONDS := 60.0
const UI_REFRESH_INTERVAL := 0.25
const PET_MOUSE_HIT_HOLD_SECONDS := 0.08

# Runtime actors and input state
var _pets: Array[Node2D] = []
var _believers: Array[Node2D] = []
var _hovered_pet: Node2D
var _petting_hover_cursor_texture: Texture2D
var _petting_click_cursor_texture: Texture2D
var _active_emotions: Dictionary = {}
var _active_emotion_tweens: Dictionary = {}
var _next_emotion_allowed_at: Dictionary = {}
var _petting_active := false
var _petting_tween: Tween
var _petting_cursor_active := false
var _carried_offering: Dictionary = {}
var _current_cursor_texture: Texture2D
var _offering_cursor_texture: Texture2D
var _offering_cursor_path := ""
var _offering_cursor_size := Vector2i.ZERO
var _offering_cursor_active := false
var _pending_offering_feeds: Dictionary = {}
var _pet_window_mouse_passthrough := false
var _pet_mouse_hit_hold_time := 0.0
var _pet_clickthrough_controller: RefCounted
var _position_retry_frames := 0
var _pet_window_size := PET_WINDOW_BASE_SIZE
var _rng := RandomNumberGenerator.new()

# Economy and UI state
var _selected_pet_id := ""
var _pet_states: Dictionary = {}
var _faith_points := 0.0
var _stats_refresh_timer := 0.0
var _last_reported_faith_count := -1
var _last_reported_growth_rate := -1.0
var _pet_upgrade_stats_dirty := true
var _next_believer_spawn_at := 0.0
var _last_believer_spawn_at := 0.0
var _inventory_window: Window
var _shop_window: Window
var _follower_count := 0.0
var _last_reported_follower_count := -1
var _shop_owned_counts := {}
var _side_drawer: Node


# Lifecycle
func _ready() -> void:
	_rng.randomize()
	_configure_pet_window()
	_create_desktop_pets()
	_prepare_petting_cursors()
	_create_side_drawer()
	_create_inventory_window()
	_create_shop_window()
	_refresh_pet_stats(true)
	var now := _get_now_seconds()
	_spawn_believer(true)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)

	_position_retry_frames = POSITION_RETRY_FRAMES
	call_deferred("_place_pet_window")
	call_deferred("_update_pet_window_mouse_passthrough")


func _process(delta: float) -> void:
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_pet_window()

	_update_faith(delta)
	_update_followers(delta)
	_update_pet_hunger()
	_update_believers()
	_update_pet_window_mouse_passthrough(delta)
	_update_petting_cursor()


func _input(event: InputEvent) -> void:
	if _carried_offering.is_empty():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_drop_carried_offering(get_viewport().get_mouse_position())
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_carried_offering()
			get_viewport().set_input_as_handled()


# Window setup
func _configure_pet_window() -> void:
	var window := get_window()
	var usable_rect := _get_current_screen_usable_rect()
	_pet_window_size = _get_target_pet_window_size(usable_rect)
	window.title = "Cthulu Desktop Pets"
	window.min_size = Vector2i.ZERO
	window.size = _pet_window_size
	window.transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = false
	window.unresizable = true
	window.visible = true

	get_viewport().transparent_bg = true

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_pet_clickthrough_controller = WindowsClickthroughController.new()
	_pet_clickthrough_controller.setup(window, "pet_window")
	_set_window_mouse_passthrough(window, true, true)


# Desktop actors
func _create_desktop_pets() -> void:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()

	for index in PetCatalog.ACTIVE_DESKTOP_PETS.size():
		var pet_id := String(PetCatalog.ACTIVE_DESKTOP_PETS[index])
		var start_x := max_x - (float(index) * PET_STAGE_START_SPACING)
		if start_x < min_x:
			start_x = lerpf(min_x, max_x, float(index % 5) / 4.0)

		_spawn_desktop_pet(pet_id, start_x)


func _spawn_desktop_pet(pet_id: String, start_x := -1.0) -> Node2D:
	if pet_id.is_empty():
		return null

	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	var spawn_x := start_x
	if spawn_x < 0.0:
		spawn_x = _get_next_pet_start_x()

	var actor := DesktopPetActor.new()
	actor.setup(pet_id, _pet_window_size, min_x, max_x, spawn_x)
	_ensure_pet_state(pet_id)
	if actor.has_method("set_display_name"):
		actor.call("set_display_name", _get_pet_display_name(pet_id))
	actor.hover_changed.connect(_on_pet_hover_changed)
	actor.petted.connect(_on_pet_petted)
	actor.recall_requested.connect(_on_pet_recall_requested)
	actor.forced_target_reached.connect(_on_pet_forced_target_reached)
	add_child(actor)
	_pets.append(actor)
	if _selected_pet_id.is_empty():
		_selected_pet_id = pet_id
	call_deferred("_update_pet_window_mouse_passthrough")
	return actor


func _get_next_pet_start_x() -> float:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	var start_x := max_x - (float(_pets.size()) * PET_STAGE_START_SPACING)
	if start_x < min_x:
		start_x = _rng.randf_range(min_x, max_x)
	return start_x


func _get_pet_stage_min_x() -> float:
	return PET_STAGE_MARGIN_X


func _get_pet_stage_max_x() -> float:
	return maxf(_get_pet_stage_min_x() + 1.0, float(_pet_window_size.x) - PET_STAGE_RIGHT_MARGIN)


# Believers
func _update_believers() -> void:
	_cleanup_believers()
	var threat_positions := _get_believer_threat_positions()
	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_threat_positions"):
			believer.call("set_threat_positions", threat_positions)

	var now := _get_now_seconds()
	if _believers.size() < BELIEVER_MIN_ACTIVE:
		_spawn_believer(false)
		_last_believer_spawn_at = now
		_schedule_next_believer_spawn(now)
		return

	if now < _next_believer_spawn_at:
		return

	if _believers.size() >= BELIEVER_MAX_ACTIVE:
		_schedule_next_believer_spawn(now)
		return

	_spawn_believer(false)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)


func _schedule_next_believer_spawn(now: float) -> void:
	var random_delay := _rng.randf_range(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_SPAWN_MAX_SECONDS)
	var time_since_last_spawn := maxf(0.0, now - _last_believer_spawn_at)
	var force_delay := maxf(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_FORCE_SPAWN_SECONDS - time_since_last_spawn)
	_next_believer_spawn_at = now + minf(random_delay, force_delay)


func _spawn_believer(visible_on_spawn := false) -> void:
	var believer: Node2D = BelieverActor.new()
	var spawn_from_left: bool = _rng.randf() < 0.5
	if visible_on_spawn and believer.has_method("setup_visible"):
		believer.call("setup_visible", _pet_window_size)
	else:
		believer.call("setup", _pet_window_size, spawn_from_left)
	believer.connect("exited", Callable(self, "_on_believer_exited"))
	add_child(believer)
	_believers.append(believer)
	if believer.has_method("set_threat_positions"):
		believer.call("set_threat_positions", _get_believer_threat_positions())


func _cleanup_believers() -> void:
	for index in range(_believers.size() - 1, -1, -1):
		if not is_instance_valid(_believers[index]):
			_believers.remove_at(index)


func _get_believer_threat_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		positions.append(pet.position)
	return positions


# UI windows
func _prepare_petting_cursors() -> void:
	_petting_hover_cursor_texture = _make_cursor_texture(PETTING_HOVER_TEXTURE, PETTING_CURSOR_SIZE)
	_petting_click_cursor_texture = _make_cursor_texture(PETTING_TEXTURE, PETTING_CURSOR_SIZE)


func _create_side_drawer() -> void:
	_side_drawer = SideDrawerController.new()
	add_child(_side_drawer)
	_side_drawer.inventory_requested.connect(_on_inventory_requested)
	_side_drawer.shop_requested.connect(_on_shop_requested)
	_side_drawer.quit_requested.connect(_on_quit_requested)
	_side_drawer.pet_count_upgrade_requested.connect(_on_pet_count_upgrade_requested)
	_side_drawer.pet_rename_requested.connect(_on_inventory_pet_rename_requested)
	_side_drawer.faith_add_requested.connect(_on_faith_add_requested)
	_side_drawer.offering_drop_requested.connect(_on_offering_drop_requested)
	_side_drawer.setup()


func _create_inventory_window() -> void:
	_inventory_window = InventoryWindowScript.new()
	add_child(_inventory_window)
	_inventory_window.connect("pet_deploy_requested", Callable(self, "_on_inventory_pet_deploy_requested"))
	_inventory_window.connect("pet_rename_requested", Callable(self, "_on_inventory_pet_rename_requested"))
	_inventory_window.setup(PetCatalog.make_inventory_entries([]))


func _create_shop_window() -> void:
	_shop_window = ShopWindowScript.new()
	add_child(_shop_window)
	_shop_window.connect("purchase_requested", Callable(self, "_on_shop_purchase_requested"))
	_shop_window.call("setup")
	_sync_shop_state()


# Window clickthrough and hit testing
func _place_pet_window() -> void:
	var usable_rect := _get_current_screen_usable_rect()
	var window := get_window()
	_pet_window_size = _get_target_pet_window_size(usable_rect)
	window.size = _pet_window_size
	var target_x: int = usable_rect.position.x
	var target_y: int = usable_rect.position.y + usable_rect.size.y - _pet_window_size.y
	window.position = Vector2i(
		target_x,
		target_y
	)
	_update_actor_window_bounds()
	_set_window_mouse_passthrough(window, _pet_window_mouse_passthrough, true)


func _get_target_pet_window_size(usable_rect: Rect2i) -> Vector2i:
	return Vector2i(maxi(PET_WINDOW_BASE_SIZE.x, usable_rect.size.x), PET_WINDOW_HEIGHT)


func _update_actor_window_bounds() -> void:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_window_bounds"):
			pet.call("set_window_bounds", _pet_window_size, min_x, max_x)

	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_window_size"):
			believer.call("set_window_size", _pet_window_size)


func _update_pet_window_mouse_passthrough(delta := 0.0) -> void:
	var window := get_window()
	if not _carried_offering.is_empty():
		_pet_mouse_hit_hold_time = PET_MOUSE_HIT_HOLD_SECONDS
		_set_window_mouse_passthrough(window, false)
		return

	var mouse_position := _get_window_mouse_position(window)
	var hit_pet := _get_pet_at_position(mouse_position)
	if hit_pet == null:
		_pet_mouse_hit_hold_time = maxf(0.0, _pet_mouse_hit_hold_time - delta)
		if _pet_mouse_hit_hold_time > 0.0:
			_set_window_mouse_passthrough(window, false)
		else:
			_set_window_mouse_passthrough(window, true)
		if _hovered_pet != null and not _petting_active:
			_hovered_pet = null
			_clear_petting_cursor()
		return

	_pet_mouse_hit_hold_time = PET_MOUSE_HIT_HOLD_SECONDS
	_set_window_mouse_passthrough(window, false)
	if _hovered_pet != hit_pet:
		_hovered_pet = hit_pet


func _get_pet_at_position(window_position: Vector2) -> Node2D:
	for index in range(_pets.size() - 1, -1, -1):
		var pet := _pets[index]
		if not is_instance_valid(pet):
			continue

		var rect := _get_pet_input_rect(pet)
		if rect.has_point(window_position) and _is_pet_pixel_hit(pet, window_position):
			return pet

	return null


func _get_pet_input_rect(pet: Node2D) -> Rect2:
	if pet.has_method("get_interaction_rect"):
		return pet.call("get_interaction_rect")
	if pet.has_method("get_draw_rect"):
		return pet.call("get_draw_rect")
	return Rect2()


func _is_pet_pixel_hit(pet: Node2D, window_position: Vector2) -> bool:
	if pet.has_method("is_point_over_opaque_pixel"):
		return bool(pet.call("is_point_over_opaque_pixel", window_position))
	return true


func _get_window_mouse_position(window: Window) -> Vector2:
	var global_mouse := DisplayServer.mouse_get_position()
	var window_position := window.position
	return Vector2(global_mouse.x - window_position.x, global_mouse.y - window_position.y)


func _set_window_mouse_passthrough(window: Window, enabled: bool, force := false) -> void:
	if window == null or (not force and _pet_window_mouse_passthrough == enabled):
		return

	_pet_window_mouse_passthrough = enabled
	if _pet_clickthrough_controller != null and _pet_clickthrough_controller.call("set_clickthrough", enabled, force):
		return

	var window_id := window.get_window_id()
	if window_id <= 0:
		return

	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,
		enabled,
		window_id
	)


func _exit_tree() -> void:
	if _pet_clickthrough_controller != null:
		_pet_clickthrough_controller.call("shutdown")


# Petting, cursors, and emotion effects
func _update_petting_cursor() -> void:
	if not _carried_offering.is_empty():
		_clear_petting_cursor()
		_refresh_offering_cursor()
		return

	if _petting_active:
		return

	if _hovered_pet == null or not is_instance_valid(_hovered_pet):
		_clear_petting_cursor()
		return

	_set_petting_cursor(_petting_hover_cursor_texture)


func _pet_the_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	_select_pet(actor)
	_play_petting_animation(actor)

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	var now := _get_now_seconds()
	var state := _get_pet_state(pet_id)
	var next_trust_pet_at := float(state.get("next_trust_pet_at", 0.0))
	var emotion := String(PETTING_EMOTIONS[_rng.randi_range(0, PETTING_EMOTIONS.size() - 1)])
	var spawned := _spawn_emotion(actor, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)

	if spawned and emotion == "happy" and now >= next_trust_pet_at and _rng.randf() <= TRUST_GAIN_ON_HAPPY_CHANCE:
		state["trust"] = int(state.get("trust", 0)) + TRUST_GAIN_ON_HAPPY
		state["favor"] = int(state.get("favor", state.get("trust", 0))) + TRUST_GAIN_ON_HAPPY
		state["next_trust_pet_at"] = now + _rng.randf_range(TRUST_PET_COOLDOWN_MIN_SECONDS, TRUST_PET_COOLDOWN_MAX_SECONDS)
		_refresh_pet_stats(true)
		_spawn_emotion(actor, "like", Vector2(38.0, -10.0), 0.21, 0.16)


func _play_petting_animation(_actor: Node2D) -> void:
	if _petting_tween != null and is_instance_valid(_petting_tween):
		_petting_tween.kill()

	_petting_active = true
	_set_petting_cursor(_petting_click_cursor_texture)

	_petting_tween = create_tween()
	_petting_tween.set_trans(Tween.TRANS_SINE)
	_petting_tween.set_ease(Tween.EASE_IN_OUT)
	_petting_tween.tween_interval(0.08)
	_petting_tween.tween_callback(_set_petting_cursor.bind(_petting_hover_cursor_texture))
	_petting_tween.tween_interval(0.06)
	_petting_tween.tween_callback(_set_petting_cursor.bind(_petting_click_cursor_texture))
	_petting_tween.tween_interval(0.08)
	_petting_tween.tween_callback(_finish_petting_animation)


func _finish_petting_animation() -> void:
	_petting_active = false

	if _hovered_pet != null and is_instance_valid(_hovered_pet):
		_set_petting_cursor(_petting_hover_cursor_texture)
	else:
		_clear_petting_cursor()


func _set_petting_cursor(texture: Texture2D) -> void:
	if texture == null:
		return
	if _current_cursor_texture == texture and _petting_cursor_active:
		return

	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(6.0, 9.0))
	_current_cursor_texture = texture
	_petting_cursor_active = true


func _clear_petting_cursor() -> void:
	if not _petting_cursor_active:
		return

	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_current_cursor_texture = null
	_petting_cursor_active = false


func _set_offering_cursor(texture_path: String) -> void:
	var cursor_size := _get_scaled_cursor_size(texture_path, OFFERING_DROP_SCALE, OFFERING_CURSOR_SIZE)
	if texture_path != _offering_cursor_path or cursor_size != _offering_cursor_size:
		_offering_cursor_texture = _make_cursor_texture(texture_path, cursor_size)
		_offering_cursor_path = texture_path
		_offering_cursor_size = cursor_size
	if _offering_cursor_texture == null:
		return
	if _current_cursor_texture == _offering_cursor_texture and _offering_cursor_active:
		return

	Input.set_custom_mouse_cursor(_offering_cursor_texture, Input.CURSOR_ARROW, Vector2(float(cursor_size.x), float(cursor_size.y)) * 0.5)
	_current_cursor_texture = _offering_cursor_texture
	_offering_cursor_active = true


func _refresh_offering_cursor() -> void:
	if _carried_offering.is_empty():
		return

	_set_offering_cursor(String(_carried_offering.get("texture", "")))


func _clear_offering_cursor() -> void:
	if not _offering_cursor_active:
		return

	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_current_cursor_texture = null
	_offering_cursor_active = false


func _make_cursor_texture(texture_path: String, target_size: Vector2i) -> Texture2D:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var used_rect := image.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		image = image.get_region(used_rect)
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _get_scaled_cursor_size(texture_path: String, sprite_scale: float, fallback_size: Vector2i) -> Vector2i:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return fallback_size

	var source_size := texture.get_size()
	var image := texture.get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		var used_rect := image.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			source_size = Vector2(used_rect.size)

	return Vector2i(
		maxi(1, int(round(source_size.x * sprite_scale))),
		maxi(1, int(round(source_size.y * sprite_scale)))
	)


func _spawn_emotion(actor: Node2D, emotion_name: String, offset: Vector2, effect_scale: float, delay := 0.0, primary := false) -> bool:
	var texture_path := _get_emotion_texture_path(emotion_name)
	if texture_path.is_empty():
		return false

	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false

	var now := _get_now_seconds()
	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		pet_id = str(actor.get_instance_id())

	if primary:
		var active_emotion := _active_emotions.get(pet_id) as Sprite2D
		var next_emotion_allowed_at := float(_next_emotion_allowed_at.get(pet_id, 0.0))
		if active_emotion != null and is_instance_valid(active_emotion) and now < next_emotion_allowed_at:
			_pulse_active_emotion(actor, pet_id)
			return false

		var active_emotion_tween := _active_emotion_tweens.get(pet_id) as Tween
		if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
			active_emotion_tween.kill()

		if active_emotion != null and is_instance_valid(active_emotion):
			active_emotion.queue_free()

	var sprite := Sprite2D.new()
	sprite.name = "Emotion_%s" % emotion_name
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * effect_scale
	sprite.position = _get_safe_emotion_position(actor, offset, texture, effect_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.z_index = 250
	add_child(sprite)

	if primary:
		_active_emotions[pet_id] = sprite
		_next_emotion_allowed_at[pet_id] = now + EMOTION_MIN_INTERVAL_SECONDS

	var start_position := sprite.position
	var end_position := _get_safe_sprite_position(start_position + Vector2(0.0, -24.0), texture, effect_scale * 1.08, SAFE_CANVAS_MARGIN)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * effect_scale * 1.08, 0.1)
	tween.tween_interval(EMOTION_HOLD_SECONDS if primary else 0.48)
	tween.tween_property(sprite, "position", end_position, 0.42)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.42)
	if primary:
		_active_emotion_tweens[pet_id] = tween
		tween.tween_callback(_clear_active_emotion.bind(pet_id, sprite))
	else:
		tween.tween_callback(Callable(sprite, "queue_free"))

	return true


func _get_safe_emotion_position(actor: Node2D, offset: Vector2, texture: Texture2D, sprite_scale: float) -> Vector2:
	var anchor: Vector2 = actor.position
	if actor.has_method("get_emotion_anchor"):
		anchor = actor.call("get_emotion_anchor")
	return _get_safe_sprite_position(anchor + offset, texture, sprite_scale, SAFE_CANVAS_MARGIN + 26.0)


func _get_safe_sprite_position(raw_position: Vector2, texture: Texture2D, sprite_scale: float, margin: float) -> Vector2:
	if texture == null:
		return raw_position

	var scaled_size := texture.get_size() * sprite_scale
	var half_size := scaled_size * 0.5
	var left := half_size.x + margin
	var right := float(_pet_window_size.x) - half_size.x - margin
	var top := half_size.y + margin
	var bottom := float(_pet_window_size.y) - half_size.y - margin

	if right < left:
		raw_position.x = float(_pet_window_size.x) * 0.5
	else:
		raw_position.x = clampf(raw_position.x, left, right)

	if bottom < top:
		raw_position.y = float(_pet_window_size.y) * 0.5
	else:
		raw_position.y = clampf(raw_position.y, top, bottom)

	return raw_position


func _pulse_active_emotion(actor: Node2D, pet_id: String) -> void:
	var active_emotion := _active_emotions.get(pet_id) as Sprite2D
	if active_emotion == null or not is_instance_valid(active_emotion):
		return

	var texture := active_emotion.texture
	if texture != null:
		active_emotion.position = _get_safe_emotion_position(actor, Vector2(-12.0, -18.0), texture, EMOTION_SCALE)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(active_emotion, "scale", Vector2.ONE * EMOTION_SCALE * 1.14, 0.08)
	tween.tween_property(active_emotion, "scale", Vector2.ONE * EMOTION_SCALE, 0.14)


func _clear_active_emotion(pet_id: String, sprite: Sprite2D) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	if _active_emotions.get(pet_id) == sprite:
		_active_emotions.erase(pet_id)
		_active_emotion_tweens.erase(pet_id)


func _clear_pet_runtime_effects(pet_id: String) -> void:
	var active_emotion_tween := _active_emotion_tweens.get(pet_id) as Tween
	if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
		active_emotion_tween.kill()

	var active_emotion := _active_emotions.get(pet_id) as Sprite2D
	if active_emotion != null and is_instance_valid(active_emotion):
		active_emotion.queue_free()

	_active_emotions.erase(pet_id)
	_active_emotion_tweens.erase(pet_id)
	_next_emotion_allowed_at.erase(pet_id)


func _get_emotion_texture_path(emotion_name: String) -> String:
	match emotion_name:
		"confused":
			return EMOTION_CONFUSED_TEXTURE
		"happy":
			return EMOTION_HAPPY_TEXTURE
		"hungry":
			return EMOTION_HUNGRY_TEXTURE
		"like":
			return EMOTION_LIKE_TEXTURE
		"sleepy":
			return EMOTION_SLEEPY_TEXTURE
		"suprised":
			return EMOTION_SUPRISED_TEXTURE
		_:
			return ""


# Economy and progression
func _refresh_pet_stats(force := false) -> void:
	if _side_drawer == null:
		return

	var faith_count := int(floor(_faith_points))
	var growth_rate := _get_faith_growth_rate()
	var faith_changed := faith_count != _last_reported_faith_count
	var growth_changed := not is_equal_approx(growth_rate, _last_reported_growth_rate)

	if force:
		_refresh_faith_display()
		_refresh_follower_display()
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate

	if _side_drawer.has_method("refresh_pet_upgrade_counts") and (force or faith_changed or growth_changed or _pet_upgrade_stats_dirty):
		_side_drawer.refresh_pet_upgrade_counts(_get_pet_upgrade_entries())
		_pet_upgrade_stats_dirty = false
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate
		if growth_changed:
			_refresh_follower_display()


func _refresh_faith_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_faith"):
		_side_drawer.refresh_faith(_faith_points, _get_faith_growth_rate())
	if _shop_window != null and _shop_window.has_method("set_faith_points"):
		_shop_window.call("set_faith_points", int(floor(_faith_points)))


func _refresh_follower_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_followers"):
		_side_drawer.call(
			"refresh_followers",
			int(floor(_follower_count)),
			_get_follower_growth_rate()
		)


func _sync_shop_state() -> void:
	if _shop_window == null:
		return
	if _shop_window.has_method("set_faith_points"):
		_shop_window.call("set_faith_points", int(floor(_faith_points)))
	if _shop_window.has_method("set_owned_counts"):
		_shop_window.call("set_owned_counts", _shop_owned_counts)


func _select_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	_selected_pet_id = pet_id
	_ensure_pet_state(pet_id)
	_refresh_pet_stats()


func _ensure_pet_state(pet_id: String) -> void:
	if not _pet_states.has(pet_id):
		_pet_states[pet_id] = {
			"trust": 0,
			"favor": 0,
			"count": 1,
			"leader_age": _make_leader_age(pet_id),
			"hungry": false,
			"last_fed_at": _get_now_seconds(),
			"next_hunger_notice_at": _get_now_seconds() + PET_HUNGER_AFTER_SECONDS,
			"next_trust_pet_at": _get_now_seconds() + _rng.randf_range(TRUST_PET_COOLDOWN_MIN_SECONDS, TRUST_PET_COOLDOWN_MAX_SECONDS)
		}
		return

	var state: Dictionary = _pet_states[pet_id]
	if not state.has("leader_age"):
		state["leader_age"] = _make_leader_age(pet_id)
	_pet_states[pet_id] = state


func _make_leader_age(pet_id: String) -> int:
	var pet_index := maxi(0, PetCatalog.ACTIVE_DESKTOP_PETS.find(pet_id))
	return 24 + (pet_index * 9) + _rng.randi_range(0, 7)


func _get_pet_state(pet_id: String) -> Dictionary:
	_ensure_pet_state(pet_id)
	return _pet_states[pet_id]


func _get_pet_upgrade_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		var count := int(state.get("count", 1))
		var cost := _get_upgrade_cost(pet_id)
		var pet_data := PetCatalog.get_definition(pet_id)
		var favor := _get_pet_favor(pet_id)
		var discount := _get_pet_upgrade_discount(pet_id)
		var current_fps := _get_pet_faith_per_second(pet_id, count) * _get_total_faith_multiplier()
		var next_fps := _get_pet_faith_per_second(pet_id, count + 1) * _get_total_faith_multiplier()
		entries.append({
			"id": pet_id,
			"name": _get_pet_display_name(pet_id),
			"description": String(pet_data.get("description", "")),
			"count": count,
			"favor": favor,
			"hungry": _is_pet_hungry(pet_id),
			"upgrade_discount": discount,
			"cost": cost,
			"base_fps": float(pet_data.get("base_fps", 0.05)),
			"cost_growth": float(pet_data.get("upgrade_cost_growth", 1.18)),
			"power_growth": float(pet_data.get("power_growth", 1.035)),
			"leader_age": _get_pet_leader_age(pet_id),
			"current_fps": current_fps,
			"next_fps": next_fps,
			"next_growth_bonus": maxf(0.0, next_fps - current_fps),
			"total_growth_bonus": current_fps,
			"affordable": int(floor(_faith_points)) >= cost
		})

	return entries


func _get_upgrade_cost(pet_id: String) -> int:
	var pet_data := PetCatalog.get_definition(pet_id)
	var state := _get_pet_state(pet_id)
	return PetProgression.upgrade_cost(
		pet_data,
		state,
		FAVOR_COST_REDUCTION_PER_POINT,
		FAVOR_COST_REDUCTION_MAX
	)


func _get_pet_favor(pet_id: String) -> int:
	return PetProgression.favor(_get_pet_state(pet_id))


func _get_pet_upgrade_discount(pet_id: String) -> float:
	return PetProgression.upgrade_discount(
		_get_pet_state(pet_id),
		FAVOR_COST_REDUCTION_PER_POINT,
		FAVOR_COST_REDUCTION_MAX
	)


func _get_pet_leader_age(pet_id: String) -> int:
	var state := _get_pet_state(pet_id)
	if not state.has("leader_age"):
		state["leader_age"] = _make_leader_age(pet_id)
		_pet_states[pet_id] = state
	return maxi(1, int(state.get("leader_age", 24)))


func _is_pet_hungry(pet_id: String) -> bool:
	var state := _get_pet_state(pet_id)
	if bool(state.get("hungry", false)):
		return true
	return _get_now_seconds() - float(state.get("last_fed_at", _get_now_seconds())) >= PET_HUNGER_AFTER_SECONDS


func _get_faith_growth_rate() -> float:
	var total_fps := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		total_fps += _get_pet_faith_per_second(pet_id, int(state.get("count", 1)))

	return total_fps * _get_total_faith_multiplier()


func _get_follower_growth_rate() -> float:
	return FollowerProgression.followers_per_second(_get_faith_growth_rate())


func _get_pet_faith_per_second(pet_id: String, level: int) -> float:
	return PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)


func _get_total_faith_multiplier() -> float:
	return GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER


func _get_pet_display_name(pet_id: String) -> String:
	var state := _get_pet_state(pet_id)
	var custom_name := String(state.get("name", "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name

	var pet_data := PetCatalog.get_definition(pet_id)
	return String(pet_data.get("name", pet_id))


func _apply_pet_display_name(pet_id: String) -> void:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _get_actor_pet_id(pet) != pet_id:
			continue
		if pet.has_method("set_display_name"):
			pet.call("set_display_name", _get_pet_display_name(pet_id))


func _set_pet_custom_name(pet_id: String, custom_name: String) -> void:
	if pet_id.is_empty():
		return

	var state := _get_pet_state(pet_id)
	custom_name = custom_name.strip_edges()
	if custom_name.is_empty():
		state.erase("name")
	else:
		state["name"] = custom_name
	_pet_states[pet_id] = state

	_apply_pet_display_name(pet_id)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


func _update_faith(delta: float) -> void:
	_faith_points += _get_faith_growth_rate() * delta
	_refresh_faith_display()
	_stats_refresh_timer += delta
	if _stats_refresh_timer >= UI_REFRESH_INTERVAL:
		_stats_refresh_timer = 0.0
		_refresh_pet_stats()


func _update_followers(delta: float) -> void:
	_follower_count = FollowerProgression.advance(
		_follower_count,
		_get_faith_growth_rate(),
		delta
	)
	var follower_count := int(floor(_follower_count))
	if follower_count != _last_reported_follower_count:
		_last_reported_follower_count = follower_count
		_refresh_follower_display()


func _update_pet_hunger() -> void:
	var now := _get_now_seconds()
	for pet in _pets:
		if not is_instance_valid(pet):
			continue

		var pet_id := _get_actor_pet_id(pet)
		if pet_id.is_empty():
			continue

		var state := _get_pet_state(pet_id)
		var last_fed_at := float(state.get("last_fed_at", now))
		if now - last_fed_at < PET_HUNGER_AFTER_SECONDS:
			continue

		if not bool(state.get("hungry", false)):
			state["hungry"] = true
			state["next_hunger_notice_at"] = now
			_pet_upgrade_stats_dirty = true

		var next_notice_at := float(state.get("next_hunger_notice_at", now))
		if now >= next_notice_at:
			_spawn_emotion(pet, "hungry", Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
			state["next_hunger_notice_at"] = now + _rng.randf_range(PET_HUNGER_NOTICE_MIN_SECONDS, PET_HUNGER_NOTICE_MAX_SECONDS)


# Shared helpers
func _get_actor_pet_id(actor: Node2D) -> String:
	if actor != null and "pet_id" in actor:
		return String(actor.pet_id)

	return ""


func _get_now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _get_current_screen_usable_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_get_current_screen())


func _get_current_screen() -> int:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return screen


# Event handlers
func _on_pet_hover_changed(actor: Node2D, hovered: bool) -> void:
	if hovered:
		_hovered_pet = actor
	elif _hovered_pet == actor:
		_hovered_pet = null
		if not _petting_active:
			_clear_petting_cursor()


func _on_pet_petted(actor: Node2D) -> void:
	_hovered_pet = actor
	_pet_the_pet(actor)


func _on_pet_recall_requested(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	if _inventory_window != null and _inventory_window.has_method("add_pet"):
		_inventory_window.call("add_pet", pet_id, _get_pet_display_name(pet_id))

	_pets.erase(actor)
	if _hovered_pet == actor:
		_hovered_pet = null
		_clear_petting_cursor()

	if _selected_pet_id == pet_id:
		_selected_pet_id = _get_first_desktop_pet_id()

	_finish_pending_offering_for_actor(actor)
	_clear_pet_runtime_effects(pet_id)
	actor.queue_free()
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	call_deferred("_update_pet_window_mouse_passthrough")


func _finish_pending_offering_for_actor(actor: Node2D) -> void:
	if actor == null:
		return

	var target_key := str(actor.get_instance_id())
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var pet_id := _get_actor_pet_id(actor)
	var sprite := feed_data.get("sprite") as Sprite2D
	var faith_gain := int(feed_data.get("faith_gain", 1))
	var drop_position: Vector2 = feed_data.get("drop_position", actor.position)
	_finish_offering_consumed(sprite, faith_gain, drop_position, pet_id)


func _on_believer_exited(actor: Node2D) -> void:
	if actor != null:
		_believers.erase(actor)


func _get_first_desktop_pet_id() -> String:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id := _get_actor_pet_id(pet)
		if not pet_id.is_empty():
			return pet_id

	return ""


func _on_inventory_requested() -> void:
	if _inventory_window != null and _inventory_window.has_method("open_window"):
		_inventory_window.open_window()


func _on_shop_requested() -> void:
	if _shop_window == null:
		return

	_sync_shop_state()
	if _shop_window.has_method("open_window"):
		_shop_window.call("open_window")


func _on_shop_purchase_requested(good_id: String) -> void:
	if _shop_window == null or good_id.is_empty():
		return

	var good: Dictionary = _shop_window.call("get_good", good_id)
	if good.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "商品不存在")
		return

	var price := maxi(0, int(good.get("price", 0)))
	if int(floor(_faith_points)) < price:
		_shop_window.call("set_purchase_result", good_id, false, "信仰不足")
		return

	_faith_points -= float(price)
	_shop_owned_counts[good_id] = int(_shop_owned_counts.get(good_id, 0)) + 1
	_sync_shop_state()
	_shop_window.call("set_purchase_result", good_id, true, "购买成功：%s" % String(good.get("name", "商品")))
	_refresh_pet_stats(true)


func _on_inventory_pet_deploy_requested(pet_id: String) -> void:
	if pet_id.is_empty():
		return

	var actor := _spawn_desktop_pet(pet_id)
	if actor == null:
		return

	_selected_pet_id = pet_id
	if _inventory_window != null and _inventory_window.has_method("remove_pet"):
		_inventory_window.call("remove_pet", pet_id)
	if _side_drawer != null and _side_drawer.has_method("try_spawn_offering"):
		_side_drawer.call("try_spawn_offering")
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


func _on_inventory_pet_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)


# Offerings
func _on_offering_drop_requested(offering: Dictionary) -> void:
	if offering.is_empty():
		return

	_carried_offering = offering.duplicate(true)
	_clear_petting_cursor()
	_set_offering_cursor(String(_carried_offering.get("texture", "")))
	_update_pet_window_mouse_passthrough()


func _cancel_carried_offering() -> void:
	_carried_offering.clear()
	_clear_offering_cursor()
	call_deferred("_update_pet_window_mouse_passthrough")


func _drop_carried_offering(window_position: Vector2) -> void:
	if _carried_offering.is_empty():
		return

	var offering := _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	call_deferred("_update_pet_window_mouse_passthrough")

	var texture := load(String(offering.get("texture", ""))) as Texture2D
	var faith_gain := _get_offering_faith_gain(offering)
	if texture == null:
		_faith_points += float(faith_gain)
		_refresh_pet_stats(true)
		_show_faith_gain_popup(window_position, faith_gain)
		return

	var sprite := Sprite2D.new()
	sprite.name = "Offering_%s" % String(offering.get("name", "Food"))
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * (OFFERING_DROP_SCALE * 0.78)
	sprite.z_index = 260

	var drop_position := _get_grounded_offering_position(window_position.x, texture, OFFERING_DROP_SCALE)
	sprite.position = _get_safe_sprite_position(drop_position + Vector2(0.0, -58.0), texture, OFFERING_DROP_SCALE * 0.78, SAFE_CANVAS_MARGIN)
	add_child(sprite)

	var drop_tween := create_tween()
	drop_tween.set_trans(Tween.TRANS_BACK)
	drop_tween.set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(sprite, "position", drop_position, 0.28)
	drop_tween.parallel().tween_property(sprite, "scale", Vector2.ONE * OFFERING_DROP_SCALE, 0.28)

	var target := _get_random_offering_target_pet()
	if target == null or not is_instance_valid(target):
		drop_tween.tween_interval(0.18)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, faith_gain, drop_position))
		return

	var target_key := str(target.get_instance_id())
	_pending_offering_feeds[target_key] = {
		"sprite": sprite,
		"faith_gain": faith_gain,
		"drop_position": drop_position,
		"target": target,
		"landed": false,
		"arrived": false
	}

	if target.has_method("walk_to_offering_x"):
		drop_tween.tween_callback(_mark_offering_landed.bind(target_key))
		_send_pet_to_offering(target, target_key, drop_position.x)
	else:
		_pending_offering_feeds.erase(target_key)
		drop_tween.tween_interval(0.42)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, faith_gain, drop_position))


func _get_offering_faith_gain(offering: Dictionary) -> int:
	var base_gain := maxi(1, int(offering.get("faith", 1)))
	var scaled_gain := int(round(_get_faith_growth_rate() * float(base_gain) * OFFERING_GAIN_SECONDS))
	return maxi(base_gain, scaled_gain)


func _get_grounded_offering_position(click_x: float, texture: Texture2D, sprite_scale: float) -> Vector2:
	var scaled_size := texture.get_size() * sprite_scale
	var half_size := scaled_size * 0.5
	var x := clampf(click_x, half_size.x + SAFE_CANVAS_MARGIN, float(_pet_window_size.x) - half_size.x - SAFE_CANVAS_MARGIN)
	var y := float(_pet_window_size.y) - half_size.y - OFFERING_GROUND_MARGIN
	return _get_safe_sprite_position(Vector2(x, y), texture, sprite_scale, OFFERING_GROUND_MARGIN)


func _get_random_offering_target_pet() -> Node2D:
	var hungry_candidates: Array[Node2D] = []
	var candidates: Array[Node2D] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		candidates.append(pet)
		var pet_id := _get_actor_pet_id(pet)
		if not pet_id.is_empty() and _is_pet_hungry(pet_id):
			hungry_candidates.append(pet)

	if not hungry_candidates.is_empty():
		return hungry_candidates[_rng.randi_range(0, hungry_candidates.size() - 1)]

	if candidates.is_empty():
		return null

	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _send_pet_to_offering(target: Node2D, target_key: String, target_x: float) -> void:
	if target != null and is_instance_valid(target) and target.has_method("walk_to_offering_x"):
		target.call("walk_to_offering_x", target_x)
		return

	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var sprite := feed_data.get("sprite") as Sprite2D
	var faith_gain := int(feed_data.get("faith_gain", 1))
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := feed_data.get("target") as Node2D
	var pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
	_finish_offering_consumed(sprite, faith_gain, drop_position, pet_id)


func _mark_offering_landed(target_key: String) -> void:
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	feed_data["landed"] = true
	_pending_offering_feeds[target_key] = feed_data
	if bool(feed_data.get("arrived", false)):
		_consume_pending_offering(target_key)


func _on_pet_forced_target_reached(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var target_key := str(actor.get_instance_id())
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	if not bool(feed_data.get("landed", true)):
		feed_data["arrived"] = true
		_pending_offering_feeds[target_key] = feed_data
		return

	_consume_pending_offering(target_key)


func _consume_pending_offering(target_key: String) -> void:
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var sprite := feed_data.get("sprite") as Sprite2D
	var faith_gain := int(feed_data.get("faith_gain", 1))
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := feed_data.get("target") as Node2D
	if sprite == null or not is_instance_valid(sprite):
		_finish_offering_consumed(null, faith_gain, drop_position)
		return

	var actor_position := actor.position if actor != null and is_instance_valid(actor) else drop_position
	var pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
	var eat_position := _get_safe_sprite_position(actor_position + Vector2(0.0, -30.0), sprite.texture, OFFERING_DROP_SCALE, SAFE_CANVAS_MARGIN)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", eat_position, 0.18)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * 0.12, 0.18)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
	tween.tween_callback(_finish_offering_consumed.bind(sprite, faith_gain, eat_position, pet_id))


func _finish_offering_consumed(sprite: Sprite2D, faith_gain: int, popup_position: Vector2, pet_id := "") -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	if not pet_id.is_empty():
		_apply_pet_fed(pet_id)
	_faith_points += float(faith_gain)
	_refresh_pet_stats(true)
	_show_faith_gain_popup(popup_position, faith_gain)


func _apply_pet_fed(pet_id: String) -> void:
	var state := _get_pet_state(pet_id)
	var now := _get_now_seconds()
	state["favor"] = _get_pet_favor(pet_id) + OFFERING_FAVOR_GAIN
	state["trust"] = int(state.get("trust", 0)) + OFFERING_FAVOR_GAIN
	state["hungry"] = false
	state["last_fed_at"] = now
	state["next_hunger_notice_at"] = now + PET_HUNGER_AFTER_SECONDS
	_pet_upgrade_stats_dirty = true

	var actor := _get_desktop_pet_by_id(pet_id)
	if actor != null:
		_clear_pet_runtime_effects(pet_id)
		_spawn_emotion(actor, "like", Vector2(38.0, -10.0), 0.21, 0.0, true)


func _get_desktop_pet_by_id(pet_id: String) -> Node2D:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _get_actor_pet_id(pet) == pet_id:
			return pet
	return null


func _show_faith_gain_popup(anchor: Vector2, faith_gain: int) -> void:
	var label := Label.new()
	label.text = "+%d 信仰" % faith_gain
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(116.0, 30.0)
	label.position = _get_safe_control_position(anchor + Vector2(-58.0, -96.0), label.size, SAFE_CANVAS_MARGIN)
	label.z_index = 360
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", _get_safe_control_position(label.position + Vector2(0.0, -28.0), label.size, SAFE_CANVAS_MARGIN), 0.58)
	tween.parallel().tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.58)
	tween.tween_callback(Callable(label, "queue_free"))


func _get_safe_control_position(raw_position: Vector2, size: Vector2, margin: float) -> Vector2:
	var right := float(_pet_window_size.x) - size.x - margin
	var bottom := float(_pet_window_size.y) - size.y - margin
	raw_position.x = clampf(raw_position.x, margin, maxf(margin, right))
	raw_position.y = clampf(raw_position.y, margin, maxf(margin, bottom))
	return raw_position


# Upgrade and global commands
func _on_pet_count_upgrade_requested(pet_id: String) -> void:
	if pet_id.is_empty():
		return

	var cost := _get_upgrade_cost(pet_id)
	if int(floor(_faith_points)) < cost:
		_refresh_pet_stats(true)
		return

	_faith_points = maxf(0.0, _faith_points - float(cost))
	var state := _get_pet_state(pet_id)
	state["count"] = int(state.get("count", 1)) + 1
	_selected_pet_id = pet_id
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


func _on_faith_add_requested(amount: int) -> void:
	_faith_points += float(maxi(1, amount))
	_refresh_pet_stats(true)


func _on_quit_requested() -> void:
	get_tree().quit()
