extends "res://scripts/runtime/main_context.gd"

const DisplayLayout = preload("res://scripts/domain/display_layout.gd")
const CoinCollectorShovel = preload("res://scripts/coin_collector_shovel.gd")

func _configure_pet_window() -> void:
	var window = get_window()
	var usable_rect = _get_current_screen_usable_rect()
	_pet_window_size = _get_target_pet_window_size(usable_rect)
	window.title = "Cthulu Desktop Pets"
	window.mode = Window.MODE_WINDOWED
	window.min_size = Vector2i.ZERO
	window.size = _pet_window_size
	window.transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = false
	window.unfocusable = true
	window.unresizable = true

	get_viewport().transparent_bg = true

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if not NativeVisualClickthrough.apply(window):
		# The native helper is an enhancement for Windows click-through, not a
		# prerequisite for booting the game.  It can be unavailable temporarily
		# while PowerShell, the GPU, or the desktop compositor is restarting.
		# Godot's own mouse_passthrough has already been enabled by the helper
		# attempt, so keep the desktop layer alive instead of terminating at boot.
		push_warning("Native desktop click-through is unavailable; continuing with Godot's fallback input handling.")


func _create_desktop_pets() -> void:
	var min_x = _get_pet_stage_min_x()
	var max_x = _get_pet_stage_max_x()

	for index in _deployed_pet_ids.size():
		var pet_id = String(_deployed_pet_ids[index])
		if not _host._is_pet_unlocked(pet_id):
			continue
		var start_x = max_x - (float(index) * PET_STAGE_START_SPACING)
		if start_x < min_x:
			start_x = lerpf(min_x, max_x, float(index % 5) / 4.0)

		_spawn_desktop_pet(pet_id, start_x)


func _create_desktop_items() -> void:
	for item_id_value in DesktopItemCatalog.ITEM_IDS:
		var item_id := String(item_id_value)
		var state_value: Variant = _item_states.get(item_id, {})
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		if not bool(state.get("owned", false)) or not bool(state.get("deployed", false)):
			continue
		_spawn_desktop_item(item_id, float(state.get("position_x", -1.0)))

func _spawn_desktop_pet(pet_id: String, start_x := -1.0) -> Node2D:
	if pet_id.is_empty():
		return null

	var min_x = _get_pet_stage_min_x()
	var max_x = _get_pet_stage_max_x()
	var spawn_x = start_x
	if spawn_x < 0.0:
		spawn_x = _get_next_pet_start_x()

	var actor = DesktopPetActor.new()
	actor.setup(
		pet_id,
		_pet_window_size,
		min_x,
		max_x,
		spawn_x,
		float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
		_get_effective_pet_activity_range() != "full",
		bool(_host._get_pet_state(pet_id).get("evolved", false)),
		PetProgression.progression_level(_host._get_pet_state(pet_id))
	)
	_host._ensure_pet_state(pet_id)
	if actor.has_method("set_display_name"):
		actor.call("set_display_name", _host._get_pet_display_name(pet_id))
	if actor.has_method("set_language"):
		actor.call("set_language", _language)
	actor.petted.connect(_on_pet_petted)
	actor.recall_requested.connect(_on_pet_recall_requested)
	actor.forced_target_reached.connect(_host._on_pet_forced_target_reached)
	actor.notable_action.connect(_on_pet_notable_action)
	actor.grabbed_changed.connect(_on_pet_grabbed_changed)
	actor.drag_released.connect(_on_pet_drag_released)
	actor.battle_roll_swept.connect(_host._on_pet5_battle_roll_swept)
	actor.battle_roll_finished.connect(_host._on_pet5_battle_roll_finished)
	actor.sofa_reached.connect(_host._on_pet_sofa_reached)
	actor.sofa_departed.connect(_host._on_pet_sofa_departed)
	add_child(actor)
	_pets.append(actor)
	_host._schedule_pet_coin_drop(actor, _get_now_seconds())
	if _pilgrimage_active and actor.has_method("set_autonomy_paused"):
		actor.call("set_autonomy_paused", true)
	elif _battle_active and actor.has_method("set_battle_mode"):
		actor.call("set_battle_mode", true)
	_schedule_next_ambient_emotion(pet_id)
	if _selected_pet_id.is_empty():
		_selected_pet_id = pet_id
	return actor


func _spawn_desktop_item(item_id: String, start_x := -1.0) -> Node2D:
	var definition := DesktopItemCatalog.get_definition(item_id)
	# Invalid IDs must never create a phantom click-through input window on the desktop.
	if item_id.is_empty() or definition.is_empty():
		return null
	var existing := _get_desktop_item(item_id)
	if existing != null:
		return existing
	var state_value: Variant = _item_states.get(item_id, {})
	if not state_value is Dictionary:
		return null
	var state: Dictionary = state_value
	if not bool(state.get("owned", false)):
		return null

	var spawn_x := start_x
	if spawn_x < 0.0:
		spawn_x = _get_default_item_position(item_id)
	var actor := DesktopItemActor.new()
	actor.setup(item_id, Vector2(spawn_x, float(_pet_window_size.y)), _pet_window_size)
	if item_id == "coin_collector":
		# The shovel is an animated child of the collector, never a separate
		# purchasable desktop item. Attach it before the actor enters the tree so
		# it appears with the collector on purchase, placement, and save restore.
		var shovel := CoinCollectorShovel.new()
		shovel.name = "CoinCollectorShovel"
		actor.add_child(shovel)
		shovel.call("setup")
	if actor.has_method("set_language"):
		actor.call("set_language", _language)
	actor.grabbed_changed.connect(_on_item_grabbed_changed)
	actor.recall_requested.connect(_on_item_recall_requested)
	add_child(actor)
	_desktop_items.append(actor)
	return actor


func _get_desktop_item(item_id: String) -> Node2D:
	for item in _desktop_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("get_item_id") and String(item.call("get_item_id")) == item_id:
			return item
	return null


func _get_default_item_position(item_id: String) -> float:
	var definition := DesktopItemCatalog.get_definition(item_id)
	return float(_pet_window_size.x) * clampf(
		float(definition.get("default_x_fraction", 0.5)),
		0.0,
		1.0
	)


func _deploy_item(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var state_value: Variant = _item_states.get(item_id, {})
	if not state_value is Dictionary:
		return false
	var state: Dictionary = state_value
	if not bool(state.get("owned", false)):
		return false
	if _get_desktop_item(item_id) != null:
		return true
	state["deployed"] = true
	_item_states[item_id] = state
	var actor := _spawn_desktop_item(item_id, float(state.get("position_x", -1.0)))
	if actor == null:
		state["deployed"] = false
		_item_states[item_id] = state
		return false
	_update_item_state_from_actor(actor)
	if item_id == "sofa":
		_host._on_sofa_deployed()
	return true


func _recall_item(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var actor := _get_desktop_item(item_id)
	if actor == null:
		return false
	if item_id == "sofa":
		# Returning the sofa must release its sole occupant before its actor is
		# removed, so no production multiplier can outlive the furniture.
		_host._release_sofa_interaction("", true)
	# CoinCollectorShovel is an owned child of the collector actor. Stop its
	# pickup before queue_free so a coin can never finish an old collection after
	# the collector has been returned to the shop.
	var collector_shovel := actor.get_node_or_null("CoinCollectorShovel") as Node2D
	if collector_shovel != null and collector_shovel.has_method("cancel_collection"):
		collector_shovel.call("cancel_collection")
	_update_item_state_from_actor(actor)
	var state_value: Variant = _item_states.get(item_id, {})
	if state_value is Dictionary:
		var state: Dictionary = state_value
		state["deployed"] = false
		_item_states[item_id] = state
	_desktop_items.erase(actor)
	actor.queue_free()
	return true


func _on_item_grabbed_changed(actor: Node2D, grabbed: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if grabbed and actor.has_method("get_item_id") and String(actor.call("get_item_id")) == "sofa":
		# A pet cannot remain seated at a moving target. It walks down as soon as
		# the sofa starts moving and may revisit after the drag is complete.
		_host._release_sofa_interaction("", true)
	if not grabbed:
		_update_item_state_from_actor(actor)
		_host._sync_shop_state()
		_host._request_save()


func _on_item_recall_requested(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var item_id := String(actor.call("get_item_id")) if actor.has_method("get_item_id") else ""
	if item_id.is_empty() or not _recall_item(item_id):
		return
	_host._sync_shop_state()
	_host._request_save()


func _update_item_state_from_actor(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("get_item_id"):
		return
	var item_id := String(actor.call("get_item_id"))
	var state_value: Variant = _item_states.get(item_id, {})
	if not state_value is Dictionary:
		return
	var state: Dictionary = state_value
	state["owned"] = true
	state["deployed"] = true
	state["position_x"] = actor.position.x
	_item_states[item_id] = state

func _get_next_pet_start_x() -> float:
	var min_x = _get_pet_stage_min_x()
	var max_x = _get_pet_stage_max_x()
	var start_x = max_x - (float(_pets.size()) * PET_STAGE_START_SPACING)
	if start_x < min_x:
		start_x = _rng.randf_range(min_x, max_x)
	return start_x

func _get_pet_stage_min_x() -> float:
	if _get_effective_pet_activity_range() == "right":
		return maxf(PET_STAGE_MARGIN_X, float(_pet_window_size.x) * 0.5 + 24.0)
	return PET_STAGE_MARGIN_X

func _get_pet_stage_max_x() -> float:
	var full_max = float(_pet_window_size.x) - PET_STAGE_RIGHT_MARGIN
	if _get_effective_pet_activity_range() == "left":
		return maxf(_get_pet_stage_min_x() + 1.0, float(_pet_window_size.x) * 0.5 - 24.0)
	return maxf(_get_pet_stage_min_x() + 1.0, full_max)

func _get_effective_pet_activity_range() -> String:
	return "full" if _pilgrimage_active or _battle_active else _pet_activity_range


func _place_pet_window() -> void:
	var usable_rect = _get_current_screen_usable_rect()
	var window = get_window()
	var target_size = _get_target_pet_window_size(usable_rect)
	var target_x: int = usable_rect.position.x
	var target_y: int = usable_rect.position.y
	var target_position = Vector2i(target_x, target_y)
	var bounds_changed = window.size != target_size or window.position != target_position
	_pet_window_size = target_size
	if window.size != target_size:
		window.size = target_size
	if window.position != target_position:
		window.position = target_position
	if bounds_changed:
		_update_actor_window_bounds()
		_host._update_offering_input_window()

func _get_target_pet_window_size(usable_rect: Rect2i) -> Vector2i:
	return DisplayLayout.desktop_window_rect(usable_rect).size

func _update_actor_window_bounds() -> void:
	var min_x = _get_pet_stage_min_x()
	var max_x = _get_pet_stage_max_x()
	var restrict_activity = _get_effective_pet_activity_range() != "full"
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_window_bounds"):
			pet.call(
				"set_window_bounds",
				_pet_window_size,
				min_x,
				max_x,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
				restrict_activity
			)

	for item in _desktop_items:
		if is_instance_valid(item) and item.has_method("set_window_bounds"):
			item.call("set_window_bounds", _pet_window_size)

	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_window_size"):
			believer.call(
				"set_window_size",
				_pet_window_size,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
			)

	for coin in _coin_drops:
		if is_instance_valid(coin) and coin.has_method("set_window_bounds"):
			coin.call(
				"set_window_bounds",
				_pet_window_size,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
			)

	if _event_invitation != null and is_instance_valid(_event_invitation) and _event_invitation.has_method("set_window_bounds"):
		_event_invitation.call(
			"set_window_bounds",
			_pet_window_size,
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
		)

func _update_pet_hover() -> void:
	if _has_captured_pet_pointer():
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_cancel_all_pet_pointer_captures()
		return

	var mouse_position = _get_window_mouse_position(get_window())
	var hit_pet = _get_pet_at_position(mouse_position)
	if hit_pet != null and hit_pet.has_method("raise_input_proxy"):
		hit_pet.call("raise_input_proxy")
	_set_hovered_pet(hit_pet)

func _set_hovered_pet(next_pet: Node2D) -> void:
	if _hovered_pet == next_pet:
		return
	var previous_pet = _hovered_pet
	_hovered_pet = next_pet
	if previous_pet != null and is_instance_valid(previous_pet) and previous_pet.has_method("set_pointer_hovered"):
		previous_pet.call("set_pointer_hovered", false)
	if _hovered_pet != null and is_instance_valid(_hovered_pet) and _hovered_pet.has_method("set_pointer_hovered"):
		_hovered_pet.call("set_pointer_hovered", true)

func _cancel_all_pet_pointer_captures() -> void:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("cancel_pointer_capture"):
			pet.call("cancel_pointer_capture")
	for item in _desktop_items:
		if is_instance_valid(item) and item.has_method("cancel_pointer_capture"):
			item.call("cancel_pointer_capture")

func _restore_desktop_input() -> void:
	if not is_inside_tree():
		return
	_set_hovered_pet(null)

func _is_offering_drop_zone(window_position: Vector2) -> bool:
	var usable_bottom = float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	return (
		window_position.x >= 0.0
		and window_position.x <= float(_pet_window_size.x)
		and window_position.y >= 0.0
		and window_position.y <= usable_bottom
	)

func _has_captured_pet_pointer() -> bool:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("is_pointer_captured"):
			if bool(pet.call("is_pointer_captured")):
				return true
	for item in _desktop_items:
		if is_instance_valid(item) and item.has_method("is_pointer_captured"):
			if bool(item.call("is_pointer_captured")):
				return true
	return false

func _get_pet_at_position(window_position: Vector2) -> Node2D:
	for index in range(_pets.size() - 1, -1, -1):
		var pet = _pets[index]
		if not is_instance_valid(pet):
			continue

		var rect = _get_pet_input_rect(pet)
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
	if window == null:
		return Vector2(_pet_window_size) * 0.5
	var global_mouse = DisplayServer.mouse_get_position()
	var window_position = window.position
	return Vector2(global_mouse.x - window_position.x, global_mouse.y - window_position.y)

func _pet_the_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	_host._select_pet(actor)

	var pet_id = _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	var emotion = _choose_petting_emotion(pet_id)
	_spawn_emotion(actor, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
	if actor.has_method("react_to_petting"):
		actor.call("react_to_petting", emotion)

func _choose_petting_emotion(pet_id: String) -> String:
	return PetCatalog.choose_weighted_emotion(pet_id, _rng.randf(), "petting_emotion_weights")

func _spawn_emotion(actor: Node2D, emotion_name: String, offset: Vector2, effect_scale: float, delay := 0.0, primary := false) -> bool:
	var texture_path = _get_emotion_texture_path(emotion_name)
	if texture_path.is_empty():
		return false

	var texture = load(texture_path) as Texture2D
	if texture == null:
		return false

	var now = _get_now_seconds()
	var pet_id = _get_actor_pet_id(actor)
	if pet_id.is_empty():
		pet_id = str(actor.get_instance_id())

	if primary:
		var active_emotion = _active_emotions.get(pet_id) as Sprite2D
		var next_emotion_allowed_at = float(_next_emotion_allowed_at.get(pet_id, 0.0))
		if active_emotion != null and is_instance_valid(active_emotion) and now < next_emotion_allowed_at:
			_pulse_active_emotion(actor, pet_id)
			return false

		var active_emotion_tween = _active_emotion_tweens.get(pet_id) as Tween
		if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
			active_emotion_tween.kill()

		if active_emotion != null and is_instance_valid(active_emotion):
			active_emotion.queue_free()

	var sprite = Sprite2D.new()
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

	var start_position = sprite.position
	var end_position = _get_safe_sprite_position(start_position + Vector2(0.0, -24.0), texture, effect_scale * 1.08, SAFE_CANVAS_MARGIN)
	var tween = create_tween()
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

	var scaled_size = texture.get_size() * sprite_scale
	var half_size = scaled_size * 0.5
	var left = half_size.x + margin
	var right = float(_pet_window_size.x) - half_size.x - margin
	var top = half_size.y + margin
	var bottom = float(_pet_window_size.y) - half_size.y - margin

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
	var active_emotion = _active_emotions.get(pet_id) as Sprite2D
	if active_emotion == null or not is_instance_valid(active_emotion):
		return

	var texture = active_emotion.texture
	if texture != null:
		active_emotion.position = _get_safe_emotion_position(actor, Vector2(-12.0, -18.0), texture, EMOTION_SCALE)

	var tween = create_tween()
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
	var active_emotion_tween = _active_emotion_tweens.get(pet_id) as Tween
	if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
		active_emotion_tween.kill()

	var active_emotion = _active_emotions.get(pet_id) as Sprite2D
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


func _update_pet_emotions() -> void:
	var now = _get_now_seconds()
	for pet in _pets:
		if not is_instance_valid(pet):
			continue

		var pet_id = _get_actor_pet_id(pet)
		if pet_id.is_empty():
			continue

		var next_emotion_at = float(_next_ambient_emotion_at.get(pet_id, 0.0))
		if now < next_emotion_at:
			continue

		var emotion = PetCatalog.choose_weighted_emotion(pet_id, _rng.randf())
		_spawn_emotion(pet, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
		_schedule_next_ambient_emotion(pet_id, now)

func _schedule_next_ambient_emotion(pet_id: String, now := -1.0) -> void:
	var pet_data = PetCatalog.get_definition(pet_id)
	var interval_min = maxf(4.0, float(pet_data.get("ambient_emotion_interval_min", 18.0)))
	var interval_max = maxf(interval_min, float(pet_data.get("ambient_emotion_interval_max", 36.0)))
	var base_time = _get_now_seconds() if now < 0.0 else now
	_next_ambient_emotion_at[pet_id] = base_time + _rng.randf_range(interval_min, interval_max)


func _get_actor_pet_id(actor: Node2D) -> String:
	if actor != null and "pet_id" in actor:
		return String(actor.pet_id)

	return ""

func _get_now_seconds() -> float:
	return _simulation_now_seconds if _simulation_now_seconds > 0.0 else Time.get_unix_time_from_system()

func _get_news_runtime_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _get_current_screen_usable_rect() -> Rect2i:
	return DisplayLayout.get_current_usable_rect(get_window(), false)

func _get_current_screen() -> int:
	return DisplayLayout.get_current_screen(get_window(), false)


func _on_pet_petted(actor: Node2D) -> void:
	_hovered_pet = actor
	_pet_the_pet(actor)
	_host._spawn_pet_coin(actor)
	var pet_id = _get_actor_pet_id(actor)
	if not pet_id.is_empty():
		_host._try_queue_news_event(
			"petting",
			{},
			"petting:%s" % pet_id,
			35.0,
			0.55
		)

func _on_pet_grabbed_changed(actor: Node2D, grabbed: bool) -> void:
	if not _battle_active or actor == null or not is_instance_valid(actor):
		return
	if grabbed:
		_battle_pet_formed[str(actor.get_instance_id())] = true
	else:
		_battle_pet_attack_at[str(actor.get_instance_id())] = _get_now_seconds() + 0.06


func _on_pet_drag_released(actor: Node2D) -> void:
	if (
		actor == null
		or not is_instance_valid(actor)
		or _battle_active
		or _pilgrimage_active
	):
		return
	_host._try_begin_manual_sofa_visit(actor)

func _on_pet_notable_action(actor: Node2D, action_id: String) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if action_id not in ["burrow", "sleep", "air_roam", "wall_crawl", "hide"]:
		return
	var pet_id = _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	_host._try_queue_news_event(
		action_id,
		{},
		"pet_action:%s:%s" % [pet_id, action_id],
		75.0
	)

func _on_pet_recall_requested(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id = _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	_host._release_sofa_interaction(pet_id, false)

	_deployed_pet_ids.erase(pet_id)
	if _inventory_window != null:
		_host._sync_inventory_window()

	_pets.erase(actor)
	var actor_key = str(actor.get_instance_id())
	_next_pet_coin_drop_at.erase(actor_key)
	_pet_coin_drop_intervals.erase(actor_key)
	if _hovered_pet == actor:
		_hovered_pet = null

	if _selected_pet_id == pet_id:
		_selected_pet_id = _get_first_desktop_pet_id()

	_finish_pending_offering_for_actor(actor)
	_clear_pet_runtime_effects(pet_id)
	actor.queue_free()
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._request_save()

func _finish_pending_offering_for_actor(actor: Node2D) -> void:
	if actor == null:
		return

	var target_key = str(actor.get_instance_id())
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var pet_id = _get_actor_pet_id(actor)
	var sprite = feed_data.get("sprite") as Sprite2D
	var drop_position: Vector2 = feed_data.get("drop_position", actor.position)
	var offering: Dictionary = feed_data.get("offering", {})
	_host._finish_offering_consumed(sprite, offering, drop_position, pet_id)

func _on_believer_exited(actor: Node2D) -> void:
	if actor != null:
		_believers.erase(actor)

func _get_first_desktop_pet_id() -> String:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id = _get_actor_pet_id(pet)
		if not pet_id.is_empty():
			return pet_id

	return ""
