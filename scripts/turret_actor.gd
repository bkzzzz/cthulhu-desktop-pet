extends Node2D

const TurretCatalog = preload("res://scripts/domain/turret_catalog.gd")

signal grabbed_changed(actor: Node2D, grabbed: bool)
signal recall_requested(actor: Node2D)

const INPUT_PROXY_PADDING := 8.0
const INPUT_PROXY_REFRESH_SECONDS := 1.0 / 20.0
const DRAG_MARGIN := 6.0
const ATTACK_PULSE_SECONDS := 0.34

var turret_id := ""
var turret_data: Dictionary = {}

var _window_size := Vector2i(820, 420)
var _stage_min_x := 0.0
var _stage_max_x := 820.0
var _stage_ground_y := 420.0
var _durability := 1.0
var _max_durability := 1.0
var _battle_mode := false
var _destroyed := false
var _interaction_enabled := true
var _dragging := false
var _recall_pointer_held := false
var _grab_offset := Vector2.ZERO
var _aura_phase := 0.0
var _attack_pulse := 0.0
var _visual_scale := 0.5
var _aura_color := Color(0.32, 0.84, 1.0, 1.0)

var _sprite: Sprite2D
var _visual_window: Window
var _input_window: Window
var _interaction_area: Control
var _interaction_rect := Rect2()
var _input_proxy_elapsed := 0.0
var _last_proxy_position := Vector2i(-100000, -100000)
var _last_proxy_size := Vector2i.ZERO
var _last_proxy_visible := false
var _attack_tween: Tween
var _hit_tween: Tween


func _ready() -> void:
	_visual_window = get_window()
	_create_input_proxy()
	_refresh_input_proxy(true)


func _exit_tree() -> void:
	if _attack_tween != null and is_instance_valid(_attack_tween):
		_attack_tween.kill()
	if _hit_tween != null and is_instance_valid(_hit_tween):
		_hit_tween.kill()
	if _input_window != null and is_instance_valid(_input_window):
		_input_window.visible = false


func setup(new_turret_id: String, start_position: Vector2, window_size: Vector2i) -> void:
	var normalized := TurretCatalog.normalize_turret({"id": new_turret_id})
	if normalized.is_empty():
		normalized = TurretCatalog.normalize_turret({"id": "turret1"})
	turret_data = normalized
	turret_id = String(turret_data.get("id", "turret1"))
	_visual_scale = clampf(float(turret_data.get("visual_scale", 0.5)), 0.10, 2.0)
	var color_value: Variant = turret_data.get("aura_color", _aura_color)
	if color_value is Color:
		_aura_color = color_value
	_max_durability = maxf(
		1.0,
		float(turret_data.get("max_health", turret_data.get("max_durability", 1.0)))
	)
	_durability = _max_durability
	_destroyed = false
	_battle_mode = false
	_interaction_enabled = true
	_create_or_refresh_sprite()
	set_window_bounds(window_size)
	position = _clamp_to_window(start_position)
	if _sprite != null:
		_sprite.visible = true
		_sprite.modulate = Color.WHITE
	_update_health_bar()
	_refresh_input_proxy(true)
	queue_redraw()


# Towers intentionally retain their vertical placement; only their visible
# screen edges constrain a free desktop drag.
func set_window_bounds(new_window_size: Vector2i) -> void:
	_window_size = Vector2i(maxi(1, new_window_size.x), maxi(1, new_window_size.y))
	_stage_min_x = 0.0
	_stage_max_x = float(_window_size.x)
	_stage_ground_y = float(_window_size.y)
	position = _clamp_to_window(position)
	_refresh_input_proxy(true)


func set_battle_mode(enabled: bool) -> void:
	_battle_mode = enabled and not _destroyed and _durability > 0.0
	if _battle_mode:
		# A deployed tower holds its line during combat. This also clears a drag
		# that began immediately before the event transitioned into battle mode.
		_recall_pointer_held = false
		_finish_drag()
	if not _battle_mode:
		_attack_pulse = 0.0
		if _sprite != null:
			_sprite.modulate = Color.WHITE
	queue_redraw()


func set_durability(current_hp: float, maximum_hp: float) -> void:
	_max_durability = maxf(1.0, maximum_hp)
	_durability = clampf(current_hp, 0.0, _max_durability)
	_destroyed = _durability <= 0.0
	if _destroyed:
		_battle_mode = false
	_update_health_bar()
	_refresh_input_proxy(true)
	queue_redraw()


func get_durability() -> float:
	return _durability


func get_max_durability() -> float:
	return _max_durability


func get_durability_ratio() -> float:
	return _durability / maxf(0.000001, _max_durability)


func get_turret_id() -> String:
	return turret_id


func get_turret_definition() -> Dictionary:
	return turret_data.duplicate(true)


func get_attack_damage() -> float:
	return maxf(0.0, float(turret_data.get("damage", 0.0)))


func get_attack_cooldown() -> float:
	return maxf(0.05, float(turret_data.get("cooldown", 1.0)))


func get_attack_range() -> float:
	return maxf(1.0, float(turret_data.get("range", 1.0)))


func get_projectile_visual() -> String:
	return String(turret_data.get("projectile_visual", turret_id))


func get_battle_hit_position() -> Vector2:
	var visual_size := _get_visual_size()
	return position + Vector2(0.0, -visual_size.y * 0.13)


func get_battle_attack_origin(direction: float) -> Vector2:
	var visual_size := _get_visual_size()
	var facing := -1.0 if direction < 0.0 else 1.0
	var height_fraction := clampf(
		float(turret_data.get("attack_origin_height", 0.50)),
		0.10,
		0.90
	)
	return position + Vector2(
		facing * (visual_size.x * 0.24 + 8.0),
		-visual_size.y * height_fraction
	)


func is_battle_collision_enabled() -> bool:
	return (
		_battle_mode
		and not _destroyed
		and _durability > 0.0
		and _sprite != null
		and _sprite.visible
	)


func is_battle_ready() -> bool:
	return is_battle_collision_enabled() and not _dragging


func is_pointer_captured() -> bool:
	return _dragging


func is_destroyed() -> bool:
	return _destroyed or _durability <= 0.0


func cancel_pointer_capture() -> void:
	_recall_pointer_held = false
	_finish_drag()


func take_damage(amount: float, knockback := 0.0) -> float:
	if is_destroyed():
		return _durability
	set_durability(_durability - maxf(0.0, amount), _max_durability)
	receive_battle_hit(knockback)
	return _durability


func receive_battle_hit(knockback := 14.0) -> void:
	if is_destroyed() or _sprite == null or not _sprite.visible:
		return
	_attack_pulse = maxf(_attack_pulse, 0.42)
	if _hit_tween != null and is_instance_valid(_hit_tween):
		_hit_tween.kill()
	var resting_position := _sprite.position
	var resting_scale := Vector2.ONE * _visual_scale
	var nudge := clampf(knockback * 0.18, -7.0, 7.0)
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_SINE)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_sprite, "modulate", Color(1.0, 0.22, 0.28, 1.0), 0.05)
	_hit_tween.parallel().tween_property(
		_sprite,
		"position:x",
		resting_position.x + nudge,
		0.05
	)
	_hit_tween.parallel().tween_property(_sprite, "scale", resting_scale * 1.045, 0.05)
	_hit_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.16)
	_hit_tween.parallel().tween_property(_sprite, "position", resting_position, 0.16)
	_hit_tween.parallel().tween_property(_sprite, "scale", resting_scale, 0.16)
	queue_redraw()


func play_battle_attack_toward(_direction: float) -> void:
	if not is_battle_ready() or _sprite == null:
		return
	_attack_pulse = 1.0
	if _attack_tween != null and is_instance_valid(_attack_tween):
		_attack_tween.kill()
	var resting_scale := Vector2.ONE * _visual_scale
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_QUAD)
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(_sprite, "scale", resting_scale * 1.085, 0.07)
	_attack_tween.parallel().tween_property(
		_sprite,
		"modulate",
		_aura_color.lerp(Color.WHITE, 0.36),
		0.07
	)
	_attack_tween.tween_property(_sprite, "scale", resting_scale, 0.16)
	_attack_tween.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.16)
	queue_redraw()


func hide_for_battle_defeat() -> void:
	_durability = 0.0
	_destroyed = true
	_battle_mode = false
	_recall_pointer_held = false
	_finish_drag()
	if _sprite != null:
		_sprite.visible = false
	var health_bar := get_node_or_null("CombatHealthBar")
	if health_bar != null:
		health_bar.visible = false
	_set_input_proxy_enabled(false)
	queue_redraw()


func get_interaction_rect() -> Rect2:
	return _interaction_rect


func is_point_over_opaque_pixel(window_position: Vector2) -> bool:
	# The input proxy is already constrained to the tower's tightly padded visual
	# rectangle. This avoids costly alpha scans for a static furniture sprite.
	return not is_destroyed() and _interaction_rect.has_point(window_position)


func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_aura_phase = fposmod(_aura_phase + safe_delta * (2.4 if _battle_mode else 0.8), TAU)
	_attack_pulse = maxf(0.0, _attack_pulse - safe_delta / ATTACK_PULSE_SECONDS)
	if _dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_drag_position()
		else:
			_finish_drag()
	_input_proxy_elapsed += safe_delta
	if _dragging or _input_proxy_elapsed >= INPUT_PROXY_REFRESH_SECONDS:
		_input_proxy_elapsed = 0.0
		_refresh_input_proxy()
	if _battle_mode or _attack_pulse > 0.0:
		queue_redraw()


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


func _draw() -> void:
	if _sprite == null or not _sprite.visible:
		return
	var visual_size := _get_visual_size()
	var anchor := Vector2(0.0, -visual_size.y * 0.10)
	var base_radius := maxf(22.0, visual_size.x * 0.48)
	var active_strength := 0.24 if _battle_mode else 0.06
	var pulse_strength := _attack_pulse
	var core_color := _aura_color
	core_color.a = clampf(active_strength * 0.45 + pulse_strength * 0.32, 0.0, 0.46)
	draw_circle(anchor, base_radius * (0.82 + pulse_strength * 0.26), core_color)
	var ring_color := _aura_color
	ring_color.a = clampf(active_strength + pulse_strength * 0.72, 0.0, 0.92)
	var ring_radius := base_radius * (1.05 + sin(_aura_phase) * 0.08 + pulse_strength * 0.48)
	draw_arc(anchor, ring_radius, _aura_phase, _aura_phase + TAU * 0.78, 24, ring_color, 1.6, true)
	if pulse_strength > 0.01:
		var outer_color := _aura_color
		outer_color.a = pulse_strength * 0.76
		draw_arc(
			anchor,
			base_radius * (1.18 + (1.0 - pulse_strength) * 0.72),
			-_aura_phase * 1.4,
			-_aura_phase * 1.4 + TAU * 0.64,
			24,
			outer_color,
			2.4,
			true
		)


func _create_or_refresh_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "TurretSprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.z_index = 198
		add_child(_sprite)
	_sprite.texture = load(String(turret_data.get("texture", ""))) as Texture2D
	_sprite.scale = Vector2.ONE * _visual_scale
	_sprite.position = Vector2.ZERO
	_sprite.modulate = Color.WHITE


func _create_input_proxy() -> void:
	if _input_window != null:
		return
	_input_window = Window.new()
	_input_window.name = "TurretInputWindow"
	_input_window.title = "Cthulu Turret Input"
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
	_interaction_area.name = "TurretInteractionArea"
	_interaction_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interaction_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_interaction_area.gui_input.connect(_on_gui_input)
	_input_window.add_child(_interaction_area)


func _refresh_input_proxy(force := false) -> void:
	_interaction_rect = _get_visual_rect().grow(INPUT_PROXY_PADDING).intersection(
		Rect2(Vector2.ZERO, Vector2(_window_size))
	)
	if _input_window == null or _visual_window == null:
		return
	var should_be_visible := (
		_interaction_enabled
		and not is_destroyed()
		and _sprite != null
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
	if not event is InputEventMouseButton or is_destroyed():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			_begin_drag()
		elif _dragging:
			_finish_drag()
		_interaction_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and not _battle_mode:
		if mouse_event.pressed:
			_recall_pointer_held = true
		elif _recall_pointer_held:
			_finish_recall()
		_interaction_area.accept_event()


func _begin_drag() -> void:
	if is_destroyed() or _battle_mode or _dragging:
		return
	_dragging = true
	_recall_pointer_held = false
	_grab_offset = position - _get_pointer_position()
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
	grabbed_changed.emit(self, false)
	_refresh_input_proxy(true)


func _finish_recall() -> void:
	if not _recall_pointer_held:
		return
	_recall_pointer_held = false
	if not _battle_mode and not is_destroyed():
		recall_requested.emit(self)


func _get_pointer_position() -> Vector2:
	var window := _visual_window if _visual_window != null else get_window()
	if window == null:
		return get_viewport().get_mouse_position()
	return Vector2(DisplayServer.mouse_get_position() - window.position)


func _get_visual_size() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return Vector2(88.0, 180.0)
	return _sprite.texture.get_size() * Vector2(
		absf(_sprite.scale.x),
		absf(_sprite.scale.y)
	)


func _get_visual_rect() -> Rect2:
	var visual_size := _get_visual_size()
	return Rect2(position - visual_size * 0.5, visual_size)


func _clamp_to_window(candidate: Vector2) -> Vector2:
	var half_size := _get_visual_size() * 0.5
	var left := maxf(_stage_min_x, half_size.x + DRAG_MARGIN)
	var right := minf(_stage_max_x, float(_window_size.x) - half_size.x - DRAG_MARGIN)
	var top := half_size.y + DRAG_MARGIN
	var bottom := float(_window_size.y) - half_size.y - DRAG_MARGIN
	if right < left:
		left = float(_window_size.x) * 0.5
		right = left
	if bottom < top:
		top = float(_window_size.y) * 0.5
		bottom = top
	return Vector2(clampf(candidate.x, left, right), clampf(candidate.y, top, bottom))


func _update_health_bar() -> void:
	var health_bar := get_node_or_null("CombatHealthBar")
	if health_bar != null and health_bar.has_method("set_health"):
		health_bar.call("set_health", _durability, _max_durability)
