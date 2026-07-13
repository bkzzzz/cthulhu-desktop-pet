extends Node2D

# Dependencies
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const FollowerProgression = preload("res://scripts/domain/follower_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const InventoryWindowScript = preload("res://scripts/inventory_window.gd")
const ShopWindowScript = preload("res://scripts/shop_window.gd")
const GachaWindowScript = preload("res://scripts/gacha_window.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const NativeVisualClickthrough = preload("res://scripts/native_visual_clickthrough.gd")

# Window and actor layout
const PET_WINDOW_BASE_SIZE := Vector2i(820, 420)
const PET_TASKBAR_OVERLAP_PIXELS := 0
const PET_STAGE_MARGIN_X := 72.0
const PET_STAGE_RIGHT_MARGIN := 96.0
const PET_STAGE_START_SPACING := 132.0
const POSITION_RETRY_FRAMES := 90

# Pet interaction and offering tuning
const OFFERING_CURSOR_SIZE := Vector2i(52, 52)
const OFFERING_DROP_SCALE := 0.36
const OFFERING_GAIN_SECONDS := 20.0
const OFFERING_FEED_TIMEOUT_SECONDS := 12.0
const OFFERING_DROP_ZONE_HEIGHT := 420.0
const OFFERING_GROUND_MARGIN := 2.0
const SAFE_CANVAS_MARGIN := 12.0
const EMOTION_CONFUSED_TEXTURE := "res://assets/ui/emotions/confused.png"
const EMOTION_HAPPY_TEXTURE := "res://assets/ui/emotions/happy.png"
const EMOTION_LIKE_TEXTURE := "res://assets/ui/emotions/like.png"
const EMOTION_SLEEPY_TEXTURE := "res://assets/ui/emotions/sleepy.png"
const EMOTION_SUPRISED_TEXTURE := "res://assets/ui/emotions/suprised.png"
const EMOTION_SCALE := 0.28

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
const SAVE_PATH := "user://cthulu_save.cfg"
const SAVE_VERSION := 3
const AUTOSAVE_INTERVAL_SECONDS := 30.0
const OFFLINE_PROGRESS_MAX_SECONDS := 12.0 * 60.0 * 60.0
const OFFLINE_PROGRESS_EFFICIENCY := 0.5
const NO_SAVE_ARGUMENT := "--no-save"

# Runtime actors and input state
var _pets: Array[Node2D] = []
var _believers: Array[Node2D] = []
var _hovered_pet: Node2D
var _active_emotions: Dictionary = {}
var _active_emotion_tweens: Dictionary = {}
var _next_emotion_allowed_at: Dictionary = {}
var _next_ambient_emotion_at: Dictionary = {}
var _carried_offering: Dictionary = {}
var _current_cursor_texture: Texture2D
var _offering_cursor_texture: Texture2D
var _offering_cursor_path := ""
var _offering_cursor_size := Vector2i.ZERO
var _offering_cursor_active := false
var _offering_input_window: Window
var _offering_input_area: Control
var _pending_offering_feeds: Dictionary = {}
var _loaded_offering_choices: Array[Dictionary] = []
var _loaded_offering_next_stock_id := 1
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
var _gacha_window: Window
var _follower_count := 0.0
var _last_reported_follower_count := -1
var _shop_owned_counts := {}
var _side_drawer: Node
var _lifetime_faith := 0.0
var _gacha_draw_count := 0
var _gacha_pity_count := 0
var _gacha_total_bonus := 0.0
var _gacha_history: Array[Dictionary] = []
var _autosave_timer := 0.0
var _loaded_save_unix := 0.0
var _persistence_enabled := true


# Lifecycle
func _ready() -> void:
	Input.use_accumulated_input = false
	_rng.randomize()
	_persistence_enabled = (
		DisplayServer.get_name() != "headless"
		and not OS.get_cmdline_user_args().has(NO_SAVE_ARGUMENT)
	)
	if not _configure_pet_window():
		push_error("Desktop pets stopped because safe click-through setup failed.")
		get_tree().quit(2)
		return
	_load_game()
	_apply_offline_progress()
	_create_desktop_pets()
	_create_offering_input_window()
	_create_side_drawer()
	_create_inventory_window()
	_create_shop_window()
	_create_gacha_window()
	_refresh_pet_stats(true)
	var now := _get_now_seconds()
	_spawn_believer(true)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)

	_position_retry_frames = POSITION_RETRY_FRAMES
	call_deferred("_place_pet_window")
	call_deferred("_update_offering_input_window")


func _process(delta: float) -> void:
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_pet_window()

	_update_faith(delta)
	_update_followers(delta)
	_update_pet_emotions()
	_update_believers()
	_update_pet_hover()
	_update_offering_input_window()
	_update_offering_cursor_state()
	_update_pending_offerings()
	_update_autosave(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_all_pet_pointer_captures()
		call_deferred("_restore_desktop_input")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


# Window setup
func _configure_pet_window() -> bool:
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
	window.unfocusable = true
	window.unresizable = true
	window.visible = true

	get_viewport().transparent_bg = true

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if not NativeVisualClickthrough.apply(window):
		return false
	return true


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
	actor.petted.connect(_on_pet_petted)
	actor.recall_requested.connect(_on_pet_recall_requested)
	actor.forced_target_reached.connect(_on_pet_forced_target_reached)
	add_child(actor)
	_pets.append(actor)
	_schedule_next_ambient_emotion(pet_id)
	if _selected_pet_id.is_empty():
		_selected_pet_id = pet_id
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
func _create_side_drawer() -> void:
	_side_drawer = SideDrawerController.new()
	add_child(_side_drawer)
	_side_drawer.inventory_requested.connect(_on_inventory_requested)
	_side_drawer.shop_requested.connect(_on_shop_requested)
	_side_drawer.gacha_requested.connect(_on_gacha_requested)
	_side_drawer.quit_requested.connect(_on_quit_requested)
	_side_drawer.pet_count_upgrade_requested.connect(_on_pet_count_upgrade_requested)
	_side_drawer.pet_evolution_requested.connect(_on_pet_evolution_requested)
	_side_drawer.pet_rename_requested.connect(_on_inventory_pet_rename_requested)
	_side_drawer.faith_add_requested.connect(_on_faith_add_requested)
	_side_drawer.offering_drop_requested.connect(_on_offering_drop_requested)
	_side_drawer.setup()
	if _side_drawer.has_method("restore_offering_state"):
		_side_drawer.call(
			"restore_offering_state",
			_loaded_offering_choices,
			_loaded_offering_next_stock_id,
			not _carried_offering.is_empty()
		)
	if not _carried_offering.is_empty():
		_set_offering_cursor(String(_carried_offering.get("texture", "")))
		_update_offering_input_window()


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


func _create_gacha_window() -> void:
	_gacha_window = GachaWindowScript.new()
	add_child(_gacha_window)
	_gacha_window.draw_requested.connect(_on_gacha_draw_requested)
	_gacha_window.setup()
	_sync_gacha_state()


# Window clickthrough and hit testing
func _place_pet_window() -> void:
	var usable_rect := _get_current_screen_usable_rect()
	var window := get_window()
	_pet_window_size = _get_target_pet_window_size(usable_rect)
	window.size = _pet_window_size
	var target_x: int = usable_rect.position.x
	var target_y: int = usable_rect.position.y
	window.position = Vector2i(
		target_x,
		target_y
	)
	_update_actor_window_bounds()
	_update_offering_input_window()


func _get_target_pet_window_size(usable_rect: Rect2i) -> Vector2i:
	return Vector2i(
		maxi(PET_WINDOW_BASE_SIZE.x, usable_rect.size.x),
		maxi(PET_WINDOW_BASE_SIZE.y, usable_rect.size.y + PET_TASKBAR_OVERLAP_PIXELS)
	)


func _update_actor_window_bounds() -> void:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_window_bounds"):
			pet.call("set_window_bounds", _pet_window_size, min_x, max_x)

	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_window_size"):
			believer.call("set_window_size", _pet_window_size)


func _update_pet_hover() -> void:
	if _has_captured_pet_pointer():
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_cancel_all_pet_pointer_captures()
		return

	var mouse_position := _get_window_mouse_position(get_window())
	var hit_pet := _get_pet_at_position(mouse_position)
	_set_hovered_pet(hit_pet)


func _set_hovered_pet(next_pet: Node2D) -> void:
	if _hovered_pet == next_pet:
		return
	var previous_pet := _hovered_pet
	_hovered_pet = next_pet
	if previous_pet != null and is_instance_valid(previous_pet) and previous_pet.has_method("set_pointer_hovered"):
		previous_pet.call("set_pointer_hovered", false)
	if _hovered_pet != null and is_instance_valid(_hovered_pet) and _hovered_pet.has_method("set_pointer_hovered"):
		_hovered_pet.call("set_pointer_hovered", true)


func _cancel_all_pet_pointer_captures() -> void:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("cancel_pointer_capture"):
			pet.call("cancel_pointer_capture")


func _restore_desktop_input() -> void:
	if not is_inside_tree():
		return
	_set_hovered_pet(null)


func _is_offering_drop_zone(window_position: Vector2) -> bool:
	var usable_bottom := float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	return (
		window_position.x >= 0.0
		and window_position.x <= float(_pet_window_size.x)
		and window_position.y >= usable_bottom - OFFERING_DROP_ZONE_HEIGHT
		and window_position.y <= usable_bottom
	)


func _has_captured_pet_pointer() -> bool:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("is_pointer_captured"):
			if bool(pet.call("is_pointer_captured")):
				return true
	return false


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


func _exit_tree() -> void:
	_save_game()
	_clear_offering_cursor()


# Petting, cursors, and emotion effects
func _update_offering_cursor_state() -> void:
	if not _carried_offering.is_empty():
		if _is_offering_drop_zone(_get_window_mouse_position(get_window())):
			_refresh_offering_cursor()
		else:
			_clear_offering_cursor()
		return


func _create_offering_input_window() -> void:
	_offering_input_window = Window.new()
	_offering_input_window.name = "OfferingInputWindow"
	_offering_input_window.title = "Cthulu Offering Input"
	_offering_input_window.borderless = true
	_offering_input_window.transparent = true
	_offering_input_window.transparent_bg = true
	_offering_input_window.unfocusable = true
	_offering_input_window.unresizable = true
	_offering_input_window.always_on_top = false
	_offering_input_window.min_size = Vector2i.ZERO
	_offering_input_window.size = Vector2i(_pet_window_size.x, int(OFFERING_DROP_ZONE_HEIGHT))
	_offering_input_window.visible = false
	add_child(_offering_input_window)

	_offering_input_area = Control.new()
	_offering_input_area.name = "OfferingDropArea"
	_offering_input_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offering_input_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_offering_input_area.gui_input.connect(_on_offering_input)
	_offering_input_window.add_child(_offering_input_area)
	_update_offering_input_window()


func _update_offering_input_window() -> void:
	if _offering_input_window == null:
		return
	var usable_bottom := _pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS
	var zone_height := mini(int(OFFERING_DROP_ZONE_HEIGHT), usable_bottom)
	_offering_input_window.position = get_window().position + Vector2i(0, usable_bottom - zone_height)
	_offering_input_window.size = Vector2i(_pet_window_size.x, zone_height)
	_offering_input_window.visible = not _carried_offering.is_empty()


func _on_offering_input(event: InputEvent) -> void:
	if _carried_offering.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_drop_carried_offering(_get_window_mouse_position(get_window()))
		_offering_input_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_carried_offering()
		_offering_input_area.accept_event()


func _pet_the_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	_select_pet(actor)

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	var emotion := _choose_petting_emotion(pet_id)
	_spawn_emotion(actor, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
	if actor.has_method("react_to_petting"):
		actor.call("react_to_petting", emotion)


func _choose_petting_emotion(pet_id: String) -> String:
	return PetCatalog.choose_weighted_emotion(pet_id, _rng.randf(), "petting_emotion_weights")


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
	_next_ambient_emotion_at.erase(pet_id)


func _get_emotion_texture_path(emotion_name: String) -> String:
	match emotion_name:
		"confused":
			return EMOTION_CONFUSED_TEXTURE
		"happy":
			return EMOTION_HAPPY_TEXTURE
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
	if _gacha_window != null and _gacha_window.visible:
		_sync_gacha_state()


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


func _sync_gacha_state() -> void:
	if _gacha_window == null:
		return
	var next_cost := GachaProgression.draw_cost(_gacha_draw_count)
	_gacha_window.refresh_state(
		_faith_points,
		_gacha_draw_count,
		next_cost,
		1.0 + _gacha_total_bonus,
		_lifetime_faith,
		_get_campaign_progress(),
		_gacha_history
	)


func _load_game() -> void:
	if not _persistence_enabled:
		return
	var save := ConfigFile.new()
	var load_error := save.load(SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return
	if load_error != OK:
		push_warning("Could not load save data: %s" % error_string(load_error))
		return

	_faith_points = maxf(0.0, float(save.get_value("economy", "faith_points", 0.0)))
	_lifetime_faith = maxf(
		_faith_points,
		float(save.get_value("economy", "lifetime_faith", _faith_points))
	)
	_follower_count = maxf(0.0, float(save.get_value("economy", "followers", 0.0)))
	_selected_pet_id = String(save.get_value("pets", "selected_pet_id", ""))
	_pet_states = _sanitize_loaded_pet_states(save.get_value("pets", "states", {}))
	_shop_owned_counts = _sanitize_owned_counts(save.get_value("shop", "owned_counts", {}))
	_gacha_draw_count = clampi(int(save.get_value("gacha", "draw_count", 0)), 0, 1000000)
	_gacha_pity_count = clampi(int(save.get_value("gacha", "pity_count", 0)), 0, 11)
	_gacha_total_bonus = clampf(float(save.get_value("gacha", "total_bonus", 0.0)), 0.0, 1000.0)
	_gacha_history = _sanitize_gacha_history(save.get_value("gacha", "history", []))
	_loaded_offering_choices = _sanitize_loaded_offerings(
		save.get_value("offerings", "choices", [])
	)
	_loaded_offering_next_stock_id = maxi(
		1,
		int(save.get_value("offerings", "next_stock_id", 1))
	)
	var carried_value: Variant = save.get_value("offerings", "carried", {})
	if carried_value is Dictionary:
		_carried_offering = SideDrawerController.normalize_offering_entry(carried_value)
	else:
		_carried_offering.clear()
	_loaded_save_unix = maxf(0.0, float(save.get_value("meta", "saved_unix", 0.0)))


func _save_game() -> void:
	if not _persistence_enabled:
		return
	var save := ConfigFile.new()
	save.set_value("meta", "version", SAVE_VERSION)
	save.set_value("meta", "saved_unix", Time.get_unix_time_from_system())
	save.set_value("economy", "faith_points", maxf(0.0, _faith_points))
	save.set_value("economy", "lifetime_faith", maxf(0.0, _lifetime_faith))
	save.set_value("economy", "followers", maxf(0.0, _follower_count))
	save.set_value("pets", "selected_pet_id", _selected_pet_id)
	save.set_value("pets", "states", _pet_states.duplicate(true))
	save.set_value("shop", "owned_counts", _shop_owned_counts.duplicate(true))
	save.set_value("gacha", "draw_count", _gacha_draw_count)
	save.set_value("gacha", "pity_count", _gacha_pity_count)
	save.set_value("gacha", "total_bonus", _gacha_total_bonus)
	save.set_value("gacha", "history", _gacha_history.duplicate(true))
	var offering_state := {
		"choices": _loaded_offering_choices.duplicate(true),
		"next_stock_id": _loaded_offering_next_stock_id
	}
	if _side_drawer != null and _side_drawer.has_method("get_offering_state"):
		offering_state = _side_drawer.call("get_offering_state")
	save.set_value("offerings", "choices", offering_state.get("choices", []))
	save.set_value("offerings", "next_stock_id", maxi(1, int(offering_state.get("next_stock_id", 1))))
	save.set_value("offerings", "carried", _carried_offering.duplicate(true))
	var save_error := save.save(SAVE_PATH)
	if save_error != OK:
		push_warning("Could not save game data: %s" % error_string(save_error))


func _apply_offline_progress() -> void:
	if _loaded_save_unix <= 0.0:
		return
	var elapsed_seconds := clampf(
		Time.get_unix_time_from_system() - _loaded_save_unix,
		0.0,
		OFFLINE_PROGRESS_MAX_SECONDS
	)
	_loaded_save_unix = 0.0
	if elapsed_seconds < 1.0:
		return
	var effective_seconds := elapsed_seconds * OFFLINE_PROGRESS_EFFICIENCY
	var faith_rate := _get_faith_growth_rate()
	_grant_faith(faith_rate * effective_seconds)
	_follower_count = FollowerProgression.advance(_follower_count, faith_rate, effective_seconds)


func _update_autosave(delta: float) -> void:
	if not _persistence_enabled:
		return
	_autosave_timer += maxf(0.0, delta)
	if _autosave_timer < AUTOSAVE_INTERVAL_SECONDS:
		return
	_autosave_timer = 0.0
	_save_game()


func _sanitize_loaded_pet_states(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_states: Dictionary = raw_value
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state_value: Variant = raw_states.get(pet_id, {})
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value.duplicate(true)
		state["count"] = clampi(int(state.get("count", 1)), 1, 100000)
		state["upgrade_level"] = clampi(int(state.get("upgrade_level", state["count"])), 1, 100000)
		state["evolution_stage"] = clampi(int(state.get("evolution_stage", 0)), 0, 2)
		state.erase("leader_age")
		state.erase("trust")
		state.erase("favor")
		state.erase("next_trust_pet_at")
		state.erase("hungry")
		state.erase("last_fed_at")
		state.erase("next_hunger_notice_at")
		var custom_name := String(state.get("name", "")).strip_edges().left(40)
		if custom_name.is_empty():
			state.erase("name")
		else:
			state["name"] = custom_name
		sanitized[pet_id] = state
	return sanitized


func _sanitize_loaded_offerings(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	for entry_value in raw_value:
		if not entry_value is Dictionary:
			continue
		var entry := SideDrawerController.normalize_offering_entry(entry_value)
		if entry.is_empty():
			continue
		var duplicate_type := false
		var duplicate_stock := false
		for existing in sanitized:
			duplicate_type = duplicate_type or String(existing.get("id", "")) == String(entry.get("id", ""))
			duplicate_stock = duplicate_stock or String(existing.get("stock_id", "")) == String(entry.get("stock_id", ""))
		if duplicate_type or duplicate_stock:
			continue
		sanitized.append(entry)
		if sanitized.size() >= 2:
			break
	return sanitized


func _sanitize_owned_counts(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_counts: Dictionary = raw_value
	for key_value in raw_counts:
		var key := String(key_value)
		if key.is_empty():
			continue
		sanitized[key] = clampi(int(raw_counts[key_value]), 0, 100000)
	return sanitized


func _sanitize_gacha_history(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	for entry_value in raw_value:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_id := String(entry.get("id", ""))
		for buff_value in GachaProgression.BUFFS:
			var buff: Dictionary = buff_value
			if String(buff.get("id", "")) == entry_id:
				sanitized.append(buff.duplicate(true))
				break
		if sanitized.size() >= 10:
			break
	return sanitized


func _get_campaign_progress() -> float:
	var achieved := 0.0
	var upgrades_per_pet := maxi(1, GachaProgression.CAMPAIGN_PET_COUNT_TARGET - 1)
	var total_target := float(PetCatalog.ACTIVE_DESKTOP_PETS.size() * upgrades_per_pet)
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var count := int(_get_pet_state(String(pet_id_value)).get("count", 1))
		achieved += float(clampi(count - 1, 0, upgrades_per_pet))
	return clampf(achieved / maxf(1.0, total_target), 0.0, 1.0)


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
			"count": 1,
			"upgrade_level": 1,
			"evolution_stage": 0
		}
		return

	var state: Dictionary = _pet_states[pet_id]
	state.erase("trust")
	state.erase("favor")
	state.erase("next_trust_pet_at")
	state.erase("leader_age")
	if not state.has("upgrade_level"):
		state["upgrade_level"] = maxi(1, int(state.get("count", 1)))
	if not state.has("evolution_stage"):
		state["evolution_stage"] = 0
	_pet_states[pet_id] = state


func _get_pet_state(pet_id: String) -> Dictionary:
	_ensure_pet_state(pet_id)
	return _pet_states[pet_id]


func _get_pet_upgrade_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		var count := int(state.get("count", 1))
		var pet_data := PetCatalog.get_definition(pet_id)
		var evolution_stage := PetProgression.evolution_stage(state)
		var can_evolve := PetProgression.can_evolve(pet_data, state)
		var next_evolution_threshold := PetProgression.next_evolution_threshold(pet_data, state)
		var population_gain := PetProgression.population_gain(count)
		var cost := 0 if can_evolve else _get_upgrade_cost(pet_id)
		var next_state := state.duplicate(true)
		var next_count := count
		if can_evolve:
			next_state["evolution_stage"] = mini(PetProgression.MAX_EVOLUTION_STAGE, evolution_stage + 1)
		else:
			next_count = count + population_gain
			next_state["count"] = next_count
			next_state["upgrade_level"] = PetProgression.progression_level(state) + 1
		var current_fps := _get_pet_faith_per_second(pet_id, count, state) * _get_total_faith_multiplier()
		var next_fps := _get_pet_faith_per_second(pet_id, next_count, next_state) * _get_total_faith_multiplier()
		entries.append({
			"id": pet_id,
			"name": _get_pet_display_name(pet_id),
			"description": String(pet_data.get("description", "")),
			"count": count,
			"upgrade_level": PetProgression.progression_level(state),
			"evolution_stage": evolution_stage,
			"next_evolution_threshold": next_evolution_threshold,
			"can_evolve": can_evolve,
			"is_max_evolution": evolution_stage >= PetProgression.MAX_EVOLUTION_STAGE,
			"cost": cost,
			"base_fps": float(pet_data.get("base_fps", 0.05)),
			"cost_growth": float(pet_data.get("upgrade_cost_growth", 1.18)),
			"power_growth": float(pet_data.get("power_growth", 1.035)),
			"current_fps": current_fps,
			"next_fps": next_fps,
			"next_growth_bonus": maxf(0.0, next_fps - current_fps),
			"total_growth_bonus": current_fps,
			"affordable": can_evolve or int(floor(_faith_points)) >= cost
		})

	return entries


func _get_upgrade_cost(pet_id: String) -> int:
	var pet_data := PetCatalog.get_definition(pet_id)
	var state := _get_pet_state(pet_id)
	return PetProgression.upgrade_cost(pet_data, state)


func _get_faith_growth_rate() -> float:
	var total_fps := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		total_fps += _get_pet_faith_per_second(pet_id, int(state.get("count", 1)))

	return total_fps * _get_total_faith_multiplier()


func _get_follower_growth_rate() -> float:
	return FollowerProgression.followers_per_second(_get_faith_growth_rate())


func _get_pet_faith_per_second(pet_id: String, count: int, state_override := {}) -> float:
	var state: Dictionary = state_override if not state_override.is_empty() else _get_pet_state(pet_id)
	var base_output := PetProgression.faith_per_second(
		PetCatalog.get_definition(pet_id),
		count,
		PetProgression.progression_level(state)
	)
	var evolution_multiplier := PetProgression.evolution_multiplier(
		PetCatalog.get_definition(pet_id),
		state
	)
	return base_output * evolution_multiplier


func _get_total_faith_multiplier() -> float:
	return GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER * (1.0 + _gacha_total_bonus)


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


func _grant_faith(amount: float) -> void:
	var safe_amount := maxf(0.0, amount)
	if safe_amount <= 0.0:
		return
	_faith_points += safe_amount
	_lifetime_faith += safe_amount


func _update_faith(delta: float) -> void:
	_grant_faith(_get_faith_growth_rate() * delta)
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


func _update_pet_emotions() -> void:
	var now := _get_now_seconds()
	for pet in _pets:
		if not is_instance_valid(pet):
			continue

		var pet_id := _get_actor_pet_id(pet)
		if pet_id.is_empty():
			continue

		var next_emotion_at := float(_next_ambient_emotion_at.get(pet_id, 0.0))
		if now < next_emotion_at:
			continue

		var emotion := PetCatalog.choose_weighted_emotion(pet_id, _rng.randf())
		var spawned := _spawn_emotion(pet, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
		if spawned and pet.has_method("react_to_emotion"):
			pet.call("react_to_emotion", emotion)
		_schedule_next_ambient_emotion(pet_id, now)


func _schedule_next_ambient_emotion(pet_id: String, now := -1.0) -> void:
	var pet_data := PetCatalog.get_definition(pet_id)
	var interval_min := maxf(4.0, float(pet_data.get("ambient_emotion_interval_min", 18.0)))
	var interval_max := maxf(interval_min, float(pet_data.get("ambient_emotion_interval_max", 36.0)))
	var base_time := _get_now_seconds() if now < 0.0 else now
	_next_ambient_emotion_at[pet_id] = base_time + _rng.randf_range(interval_min, interval_max)


# Shared helpers
func _get_actor_pet_id(actor: Node2D) -> String:
	if actor != null and "pet_id" in actor:
		return String(actor.pet_id)

	return ""


func _get_now_seconds() -> float:
	return Time.get_unix_time_from_system()


func _get_current_screen_usable_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_get_current_screen())


func _get_current_screen() -> int:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return screen


# Event handlers
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

	if _selected_pet_id == pet_id:
		_selected_pet_id = _get_first_desktop_pet_id()

	_finish_pending_offering_for_actor(actor)
	_clear_pet_runtime_effects(pet_id)
	actor.queue_free()
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


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


func _on_gacha_requested() -> void:
	if _gacha_window == null:
		return
	_sync_gacha_state()
	_gacha_window.open_window()


func _on_gacha_draw_requested() -> void:
	if _gacha_window == null:
		return
	var cost := GachaProgression.draw_cost(_gacha_draw_count)
	if int(floor(_faith_points)) < cost:
		_sync_gacha_state()
		return

	_faith_points -= float(cost)
	var buff := GachaProgression.roll(_rng.randf(), _gacha_pity_count)
	if buff.is_empty():
		_faith_points += float(cost)
		_sync_gacha_state()
		return

	_gacha_total_bonus = GachaProgression.apply_buff(_gacha_total_bonus, buff)
	_gacha_pity_count = GachaProgression.next_pity_count(_gacha_pity_count, buff)
	_gacha_draw_count += 1
	_gacha_history.push_front(buff.duplicate(true))
	if _gacha_history.size() > 10:
		_gacha_history.resize(10)
	_gacha_window.show_result(buff)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_sync_gacha_state()
	_save_game()


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
	_save_game()


func _on_inventory_pet_deploy_requested(pet_id: String) -> void:
	if pet_id.is_empty():
		return

	var actor := _spawn_desktop_pet(pet_id)
	if actor == null:
		return

	_selected_pet_id = pet_id
	if _inventory_window != null and _inventory_window.has_method("remove_pet"):
		_inventory_window.call("remove_pet", pet_id)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


func _on_inventory_pet_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)


# Offerings
func _on_offering_drop_requested(offering: Dictionary) -> void:
	if offering.is_empty() or not _carried_offering.is_empty():
		return

	_carried_offering = offering.duplicate(true)
	_set_offering_cursor(String(_carried_offering.get("texture", "")))
	_update_offering_input_window()
	_save_game()


func _cancel_carried_offering() -> void:
	var cancelled_offering := _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	_return_offering_to_altar(cancelled_offering)
	call_deferred("_update_offering_input_window")
	_save_game()


func _return_offering_to_altar(offering: Dictionary) -> void:
	if offering.is_empty() or _side_drawer == null:
		return
	if _side_drawer.has_method("return_offering"):
		_side_drawer.call("return_offering", offering.duplicate(true))


func _drop_carried_offering(window_position: Vector2) -> void:
	if _carried_offering.is_empty():
		return

	var offering := _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	call_deferred("_update_offering_input_window")
	if _side_drawer != null and _side_drawer.has_method("complete_offering_choice"):
		_side_drawer.call("complete_offering_choice")
	_save_game()

	var texture := load(String(offering.get("texture", ""))) as Texture2D
	var faith_gain := _get_offering_faith_gain(offering)
	if texture == null:
		_finish_offering_consumed(null, faith_gain, window_position)
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

	var target := _get_offering_target_pet(drop_position.x)
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
		"expires_at": _get_now_seconds() + OFFERING_FEED_TIMEOUT_SECONDS,
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
	var scaled_gain := int(round(_get_faith_growth_rate() * OFFERING_GAIN_SECONDS))
	return maxi(base_gain, scaled_gain)


func _get_grounded_offering_position(click_x: float, texture: Texture2D, sprite_scale: float) -> Vector2:
	var scaled_size := texture.get_size() * sprite_scale
	var half_size := scaled_size * 0.5
	var x := clampf(click_x, half_size.x + SAFE_CANVAS_MARGIN, float(_pet_window_size.x) - half_size.x - SAFE_CANVAS_MARGIN)
	var y := float(_pet_window_size.y) - half_size.y - OFFERING_GROUND_MARGIN
	return _get_safe_sprite_position(Vector2(x, y), texture, sprite_scale, OFFERING_GROUND_MARGIN)


func _get_offering_target_pet(drop_x: float) -> Node2D:
	var nearest_pet: Node2D
	var nearest_distance := INF
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _pending_offering_feeds.has(str(pet.get_instance_id())):
			continue
		var distance := absf(pet.position.x - drop_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pet = pet
	return nearest_pet


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


func _update_pending_offerings() -> void:
	if _pending_offering_feeds.is_empty():
		return
	var now := _get_now_seconds()
	for target_key_value in _pending_offering_feeds.keys().duplicate():
		var target_key := String(target_key_value)
		var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
		if feed_data.is_empty():
			continue
		var actor := feed_data.get("target") as Node2D
		var expired := now >= float(feed_data.get("expires_at", now + OFFERING_FEED_TIMEOUT_SECONDS))
		if actor != null and is_instance_valid(actor) and not expired:
			continue

		_pending_offering_feeds.erase(target_key)
		var sprite := feed_data.get("sprite") as Sprite2D
		var faith_gain := int(feed_data.get("faith_gain", 1))
		var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size) * 0.5)
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
		_react_pet_to_offering(pet_id)
	_grant_faith(float(faith_gain))
	_refresh_pet_stats(true)
	_show_faith_gain_popup(popup_position, faith_gain)
	_save_game()


func _react_pet_to_offering(pet_id: String) -> void:
	var actor := _get_desktop_pet_by_id(pet_id)
	if actor != null:
		_clear_pet_runtime_effects(pet_id)
		_spawn_emotion(actor, "happy", Vector2(38.0, -10.0), 0.21, 0.0, true)


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
	var state := _get_pet_state(pet_id)
	var pet_data := PetCatalog.get_definition(pet_id)
	if PetProgression.can_evolve(pet_data, state):
		_on_pet_evolution_requested(pet_id)
		return

	var cost := _get_upgrade_cost(pet_id)
	if int(floor(_faith_points)) < cost:
		_refresh_pet_stats(true)
		return

	_faith_points = maxf(0.0, _faith_points - float(cost))
	var count := maxi(1, int(state.get("count", 1)))
	state["count"] = clampi(count + PetProgression.population_gain(count), 1, 100000)
	state["upgrade_level"] = clampi(PetProgression.progression_level(state) + 1, 1, 100000)
	_selected_pet_id = pet_id
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_save_game()


func _on_pet_evolution_requested(pet_id: String) -> void:
	if pet_id.is_empty() or not PetCatalog.DEFINITIONS.has(pet_id):
		return
	var state := _get_pet_state(pet_id)
	var pet_data := PetCatalog.get_definition(pet_id)
	if not PetProgression.can_evolve(pet_data, state):
		_refresh_pet_stats(true)
		return

	state["evolution_stage"] = mini(
		PetProgression.MAX_EVOLUTION_STAGE,
		PetProgression.evolution_stage(state) + 1
	)
	_selected_pet_id = pet_id
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	var actor := _get_desktop_pet_by_id(pet_id)
	if actor != null:
		_spawn_emotion(actor, "like", Vector2(38.0, -10.0), 0.24, 0.0, true)
	_save_game()


func _on_faith_add_requested(amount: int) -> void:
	_grant_faith(float(maxi(1, amount)))
	_refresh_pet_stats(true)
	_save_game()


func _on_quit_requested() -> void:
	_save_game()
	get_tree().quit()
