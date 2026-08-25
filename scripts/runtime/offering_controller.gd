extends "res://scripts/runtime/main_context.gd"

# Transient feedback is deliberately kept out of permanent HUD cards.  Keep a
# small per-area lane so simultaneous coin, faith, and food feedback does not
# render directly on top of itself.
var _status_popup_lanes := {}

func _update_offering_cursor_state() -> void:
	if not _carried_offering.is_empty():
		_refresh_offering_cursor()
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
	_offering_input_window.transient = true
	_offering_input_window.min_size = Vector2i.ZERO
	_offering_input_window.size = Vector2i(
		_pet_window_size.x,
		_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS
	)
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
	if _carried_offering.is_empty():
		if _offering_input_window.visible:
			_offering_input_window.visible = false
		return
	var was_visible = _offering_input_window.visible
	var usable_bottom = _pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS
	var target_position = get_window().position
	var target_size = Vector2i(_pet_window_size.x, usable_bottom)
	if _offering_input_window.position != target_position:
		_offering_input_window.position = target_position
	if _offering_input_window.size != target_size:
		_offering_input_window.size = target_size
	# Native child windows keep the z-order they had when first shown. Creating
	# this transparent click receiver while the Shop window is still active can
	# leave it behind the shop (and sometimes behind the desktop pet window), so
	# the next click never reaches OfferingDropArea.
	if not was_visible:
		_offering_input_window.visible = true
		_offering_input_window.move_to_foreground()

func _on_offering_input(event: InputEvent) -> void:
	if _carried_offering.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_drop_carried_offering(_host._get_window_mouse_position(get_window()))
		_offering_input_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_carried_offering()
		_offering_input_area.accept_event()

func _set_offering_cursor(texture_path: String) -> void:
	var cursor_size = _offering_cursor_size
	if texture_path != _offering_cursor_path or cursor_size == Vector2i.ZERO:
		cursor_size = _get_scaled_cursor_size(texture_path, OFFERING_DROP_SCALE, OFFERING_CURSOR_SIZE)
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
	var texture = load(texture_path) as Texture2D
	if texture == null:
		return null

	var image = texture.get_image()
	if image == null or image.is_empty():
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var used_rect = image.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		image = image.get_region(used_rect)
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _get_scaled_cursor_size(texture_path: String, sprite_scale: float, fallback_size: Vector2i) -> Vector2i:
	var texture = load(texture_path) as Texture2D
	if texture == null:
		return fallback_size

	var source_size = texture.get_size()
	var image = texture.get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		var used_rect = image.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			source_size = Vector2(used_rect.size)

	return Vector2i(
		maxi(1, int(round(source_size.x * sprite_scale))),
		maxi(1, int(round(source_size.y * sprite_scale)))
	)

func _cancel_carried_offering() -> void:
	var cancelled_offering = _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	var refund = maxi(0, int(cancelled_offering.get("purchase_price", 0)))
	if refund > 0:
		_gold_coins = CurrencyDisplay.add_gold(_gold_coins, refund)
		_show_coin_change_popup(_host._get_window_mouse_position(get_window()), refund)
		_host._sync_shop_state()
		_host._refresh_coin_display()
		if _shop_window != null and _shop_window.has_method("set_purchase_result"):
			_shop_window.call(
				"set_purchase_result",
				String(cancelled_offering.get("id", "")),
				true,
				("Placement cancelled. Refunded %s" if _language == "en" else "已取消投放，返还 %s") % CurrencyDisplay.format_compact(refund)
			)
	call_deferred("_update_offering_input_window")
	_host._request_save()

func _drop_carried_offering(window_position: Vector2) -> void:
	if _carried_offering.is_empty():
		return

	var offering = _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	call_deferred("_update_offering_input_window")
	_host._request_save()

	var texture = load(String(offering.get("texture", ""))) as Texture2D
	if texture == null:
		_finish_offering_consumed(null, offering, window_position, "")
		return

	var sprite = Sprite2D.new()
	sprite.name = "Offering_%s" % String(offering.get("name", "Food"))
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * (OFFERING_DROP_SCALE * 0.78)
	sprite.z_index = 260

	var drop_position = _get_grounded_offering_position(window_position.x, texture, OFFERING_DROP_SCALE)
	sprite.position = _host._get_safe_sprite_position(drop_position + Vector2(0.0, -58.0), texture, OFFERING_DROP_SCALE * 0.78, SAFE_CANVAS_MARGIN)
	add_child(sprite)

	var drop_tween = create_tween()
	drop_tween.set_trans(Tween.TRANS_BACK)
	drop_tween.set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(sprite, "position", drop_position, 0.28)
	drop_tween.parallel().tween_property(sprite, "scale", Vector2.ONE * OFFERING_DROP_SCALE, 0.28)

	var target = _get_offering_target_pet(drop_position.x)
	if target == null or not is_instance_valid(target):
		drop_tween.tween_interval(0.18)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, drop_position, ""))
		return

	var target_key = str(target.get_instance_id())
	_pending_offering_feeds[target_key] = {
		"sprite": sprite,
		"offering": offering,
		"drop_position": drop_position,
		"target": target,
		"pet_id": _host._get_actor_pet_id(target),
		"expires_at": _host._get_now_seconds() + OFFERING_FEED_TIMEOUT_SECONDS,
		"landed": false,
		"arrived": false
	}

	if target.has_method("walk_to_offering_x"):
		drop_tween.tween_callback(_mark_offering_landed.bind(target_key))
		_send_pet_to_offering(target, target_key, drop_position.x)
	else:
		_pending_offering_feeds.erase(target_key)
		drop_tween.tween_interval(0.42)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, drop_position, ""))

func _get_grounded_offering_position(click_x: float, texture: Texture2D, sprite_scale: float) -> Vector2:
	var scaled_size = texture.get_size() * sprite_scale
	var half_size = scaled_size * 0.5
	var x = clampf(click_x, half_size.x + SAFE_CANVAS_MARGIN, float(_pet_window_size.x) - half_size.x - SAFE_CANVAS_MARGIN)
	var usable_bottom = float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	var y = usable_bottom - half_size.y - OFFERING_GROUND_MARGIN
	return _host._get_safe_sprite_position(Vector2(x, y), texture, sprite_scale, OFFERING_GROUND_MARGIN)

func _get_offering_target_pet(drop_x: float) -> Node2D:
	var nearest_pet: Node2D
	var nearest_distance = INF
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if pet.has_method("is_swallowed") and bool(pet.call("is_swallowed")):
			continue
		if _pending_offering_feeds.has(str(pet.get_instance_id())):
			continue
		var distance = absf(pet.position.x - drop_x)
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
	var sprite := _as_valid_sprite_2d(feed_data.get("sprite"))
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := _as_valid_node_2d(feed_data.get("target"))
	var pet_id := String(feed_data.get("pet_id", ""))
	if pet_id.is_empty() and actor != null:
		pet_id = _host._get_actor_pet_id(actor)
	var offering: Dictionary = feed_data.get("offering", {})
	_finish_offering_consumed(sprite, offering, drop_position, pet_id)

func _update_pending_offerings() -> void:
	if _pending_offering_feeds.is_empty():
		return
	var now = _host._get_now_seconds()
	for target_key_value in _pending_offering_feeds.keys().duplicate():
		var target_key = String(target_key_value)
		var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
		if feed_data.is_empty():
			continue
		var actor := _as_valid_node_2d(feed_data.get("target"))
		var expired = now >= float(feed_data.get("expires_at", now + OFFERING_FEED_TIMEOUT_SECONDS))
		if actor != null and not expired:
			continue

		_pending_offering_feeds.erase(target_key)
		var sprite := _as_valid_sprite_2d(feed_data.get("sprite"))
		var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size) * 0.5)
		var pet_id := String(feed_data.get("pet_id", ""))
		if pet_id.is_empty() and actor != null:
			pet_id = _host._get_actor_pet_id(actor)
		var offering: Dictionary = feed_data.get("offering", {})
		_finish_offering_consumed(sprite, offering, drop_position, pet_id)

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

	var target_key = str(actor.get_instance_id())
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
	var sprite := _as_valid_sprite_2d(feed_data.get("sprite"))
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := _as_valid_node_2d(feed_data.get("target"))
	var offering: Dictionary = feed_data.get("offering", {})
	if sprite == null:
		var fallback_pet_id := String(feed_data.get("pet_id", ""))
		if fallback_pet_id.is_empty() and actor != null:
			fallback_pet_id = _host._get_actor_pet_id(actor)
		_finish_offering_consumed(null, offering, drop_position, fallback_pet_id)
		return

	var actor_position = actor.position if actor != null else drop_position
	var pet_id := String(feed_data.get("pet_id", ""))
	if pet_id.is_empty() and actor != null:
		pet_id = _host._get_actor_pet_id(actor)
	var eat_position = _host._get_safe_sprite_position(actor_position + Vector2(0.0, -30.0), sprite.texture, OFFERING_DROP_SCALE, SAFE_CANVAS_MARGIN)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", eat_position, 0.18)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * 0.12, 0.18)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
	tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, eat_position, pet_id))

func _finish_offering_consumed(
	sprite: Sprite2D,
	offering: Dictionary,
	popup_position: Vector2,
	pet_id := ""
) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	if not pet_id.is_empty():
		_apply_pet_offering_buff(pet_id, offering)
		_react_pet_to_offering(pet_id)
		var localized_offering_en := OfferingCatalog.localize(offering, "en")
		var localized_offering_zh := OfferingCatalog.localize(offering, "zh")
		var offering_name = String(OfferingCatalog.localize(offering, _language).get("name", "Offering" if _language == "en" else "贡品"))
		_host._try_queue_news_event(
			"offering",
			{
				"item_name": offering_name,
				"item_name_en": String(localized_offering_en.get("name", offering_name)),
				"item_name_zh": String(localized_offering_zh.get("name", offering_name))
			},
			"offering:%s" % pet_id,
			24.0,
			0.72
		)
		_show_offering_buff_popup(popup_position, pet_id, offering)
	else:
		_show_status_popup(popup_position, "No pet collected the offering" if _language == "en" else "没有宠物接取贡品", Color(1.0, 0.68, 0.48, 1.0))
	_host._refresh_pet_stats(true)
	_host._request_save()

func _apply_pet_offering_buff(pet_id: String, offering: Dictionary) -> void:
	if pet_id.is_empty() or not _host._is_pet_unlocked(pet_id):
		return
	var multiplier = clampf(float(offering.get("multiplier", 1.0)), 1.0, 100.0)
	var duration_seconds = clampf(float(offering.get("duration_seconds", 60.0)), 1.0, 3600.0)
	if multiplier <= 1.0:
		return
	_pet_offering_buffs[pet_id] = {
		"multiplier": multiplier,
		"expires_at": _host._get_now_seconds() + duration_seconds,
		"offering_name": String(offering.get("name", "贡品")).strip_edges().left(40)
	}
	_pet_upgrade_stats_dirty = true

func _react_pet_to_offering(pet_id: String) -> void:
	var actor = _get_desktop_pet_by_id(pet_id)
	if actor != null:
		_host._clear_pet_runtime_effects(pet_id)
		_host._spawn_emotion(actor, "happy", Vector2(38.0, -10.0), 0.21, 0.0, true)

func _get_desktop_pet_by_id(pet_id: String) -> Node2D:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _host._get_actor_pet_id(pet) == pet_id:
			return pet
	return null

func _show_offering_buff_popup(anchor: Vector2, pet_id: String, offering: Dictionary) -> void:
	var multiplier = maxf(1.0, float(offering.get("multiplier", 1.0)))
	var duration_seconds = maxi(1, int(round(float(offering.get("duration_seconds", 60.0)))))
	_show_status_popup(
		anchor,
		("%s  ×%s · %ds" if _language == "en" else "%s  ×%s · %d秒") % [
			_host._get_pet_display_name(pet_id),
			_format_multiplier(multiplier),
			duration_seconds
		],
		Color(0.88, 1.0, 0.64, 1.0)
	)

func _show_faith_change_popup(anchor: Vector2, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var prefix = "+" if amount > 0.0 else "-"
	var color = Color(0.88, 1.0, 0.78, 1.0) if amount > 0.0 else Color(1.0, 0.58, 0.46, 1.0)
	_show_status_popup(
		anchor,
		("%s%s FAITH" if _language == "en" else "%s%s 信仰") % [prefix, _format_faith_amount(absf(amount))],
		color
	)

func _show_coin_change_popup(anchor: Vector2, amount: int, coin_type := "") -> void:
	if amount == 0:
		return
	var prefix = "+" if amount > 0 else "-"
	var color = Color(1.0, 0.84, 0.32, 1.0) if amount > 0 else Color(1.0, 0.58, 0.46, 1.0)
	if amount > 0:
		match coin_type:
			"C":
				color = Color(0.94, 0.47, 0.28, 1.0)
			"S":
				color = Color(0.78, 0.86, 0.94, 1.0)
			"G":
				color = Color(1.0, 0.92, 0.24, 1.0)
	_show_status_popup(
		anchor,
		"%s%s" % [prefix, CurrencyDisplay.format_compact(absi(amount))],
		color
	)

func _show_status_popup(anchor: Vector2, text_value: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var lane_key := _get_status_popup_lane_key(anchor)
	var label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(300.0, 42.0)
	var lane_index := _register_status_popup(lane_key, label)
	var horizontal_stagger := (float((lane_index % 3) - 1)) * 16.0
	var vertical_stagger := float(mini(lane_index, 4)) * 21.0
	label.position = _get_safe_control_position(
		anchor + Vector2(-label.size.x * 0.5 + horizontal_stagger, -92.0 - vertical_stagger),
		label.size,
		SAFE_CANVAS_MARGIN
	)
	label.z_index = 360
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", LanguageSettings.get_ui_font(_language))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", _get_safe_control_position(label.position + Vector2(0.0, -24.0), label.size, SAFE_CANVAS_MARGIN), 0.62)
	tween.parallel().tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.62)
	tween.tween_callback(_release_status_popup_lane.bind(lane_key, label))
	tween.tween_callback(Callable(label, "queue_free"))


func _get_status_popup_lane_key(anchor: Vector2) -> String:
	return "%d:%d" % [int(round(anchor.x / 180.0)), int(round(anchor.y / 160.0))]


func _register_status_popup(lane_key: String, label: Label) -> int:
	var active_labels: Array[Label] = []
	for label_value in _status_popup_lanes.get(lane_key, []):
		if not is_instance_valid(label_value) or not label_value is Label:
			continue
		var existing_label := label_value as Label
		if existing_label != null and is_instance_valid(existing_label) and not existing_label.is_queued_for_deletion():
			active_labels.append(existing_label)
	var lane_index := active_labels.size()
	active_labels.append(label)
	_status_popup_lanes[lane_key] = active_labels
	return lane_index


func _release_status_popup_lane(lane_key: String, label: Label) -> void:
	if not _status_popup_lanes.has(lane_key):
		return
	var remaining_labels: Array[Label] = []
	for label_value in _status_popup_lanes.get(lane_key, []):
		if not is_instance_valid(label_value) or not label_value is Label:
			continue
		var existing_label := label_value as Label
		if (
			existing_label != null
			and existing_label != label
			and is_instance_valid(existing_label)
			and not existing_label.is_queued_for_deletion()
		):
			remaining_labels.append(existing_label)
	if remaining_labels.is_empty():
		_status_popup_lanes.erase(lane_key)
	else:
		_status_popup_lanes[lane_key] = remaining_labels

func _get_safe_control_position(raw_position: Vector2, size: Vector2, margin: float) -> Vector2:
	var right = float(_pet_window_size.x) - size.x - margin
	var bottom = float(_pet_window_size.y) - size.y - margin
	raw_position.x = clampf(raw_position.x, margin, maxf(margin, right))
	raw_position.y = clampf(raw_position.y, margin, maxf(margin, bottom))
	return raw_position
