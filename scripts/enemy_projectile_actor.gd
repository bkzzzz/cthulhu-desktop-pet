extends Node2D

signal impacted(actor: Node2D, target: Node2D, damage: float, splash_radius: float, knockback: float)
signal swallowed(actor: Node2D)

const ARROW_TEXTURE := "res://assets/effects/bullets/arrow.png"
const BULLET_TEXTURE := "res://assets/effects/bullets/Laser Sprites/15.png"
const BULLET_CHROMA_SHADER := """
shader_type canvas_item;
uniform vec4 key_color : source_color = vec4(0.0, 0.3, 0.3, 1.0);
uniform float tolerance = 0.23;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (distance(source.rgb, key_color.rgb) <= tolerance) {
		source.a = 0.0;
	}
	COLOR = source;
}
"""
const TARGET_COLLISION_RADIUS := 38.0
const MISS_COAST_SECONDS := 1.35
const OFFSCREEN_CLEANUP_MARGIN := 180.0

static var _arrow_texture: Texture2D
static var _bullet_texture: Texture2D
static var _bullet_shader: Shader


static func warm_up() -> void:
	if _arrow_texture == null:
		_arrow_texture = load(ARROW_TEXTURE) as Texture2D
	if _bullet_texture == null:
		_bullet_texture = load(BULLET_TEXTURE) as Texture2D
	if _bullet_shader == null:
		_bullet_shader = Shader.new()
		_bullet_shader.code = BULLET_CHROMA_SHADER

var projectile_kind := "arrow"
var _target: Node2D
var _damage := 0.0
var _splash_radius := 0.0
var _knockback := 12.0
var _start_position := Vector2.ZERO
var _elapsed := 0.0
var _flight_duration := 0.5
var _maximum_lifetime := 1.85
var _arc_height := 0.0
var _sprite: Sprite2D
var _resolved := false
var _swallowable := false
var _being_swallowed := false
var _swallower: Node2D
var _swallow_start := Vector2.ZERO
var _swallow_progress := 0.0
var _rng := RandomNumberGenerator.new()
var _last_target_position := Vector2.ZERO
var _travel_direction := Vector2.RIGHT
var _coasting := false
var _collision_targets: Array[Node2D] = []
var _previous_target_positions := {}


func setup(
	new_kind: String,
	start_position: Vector2,
	target: Node2D,
	damage: float,
	power_scale := 1.0,
	collision_targets: Array[Node2D] = []
) -> void:
	projectile_kind = new_kind if new_kind in ["arrow", "victorian_bullet", "modern_shell", "modern_orb", "outer_bolt"] else "arrow"
	position = start_position
	_start_position = start_position
	_target = target
	_damage = maxf(0.0, damage)
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	var initial_target := _get_target_position()
	_last_target_position = initial_target
	var initial_direction := initial_target - start_position
	if initial_direction.length_squared() > 0.001:
		_travel_direction = initial_direction.normalized()
	var distance := maxf(1.0, start_position.distance_to(initial_target))
	if projectile_kind == "arrow":
		_flight_duration = clampf(distance / 610.0, 0.28, 1.25)
		_arc_height = clampf(distance * 0.09, 22.0, 66.0)
		_knockback = 11.0
		_swallowable = true
	elif projectile_kind == "victorian_bullet":
		_flight_duration = clampf(distance / 760.0, 0.22, 1.0)
		_splash_radius = clampf(92.0 + sqrt(maxf(0.0, power_scale)) * 24.0, 92.0, 210.0)
		_knockback = clampf(14.0 + sqrt(maxf(0.0, power_scale)) * 2.5, 14.0, 28.0)
		# Pet11 can catch ordinary shots, while charged rounds remain dangerous.
		_swallowable = _rng.randf() < 0.45
	elif projectile_kind == "modern_shell":
		_flight_duration = clampf(distance / 920.0, 0.18, 0.78)
		_splash_radius = clampf(138.0 + sqrt(maxf(0.0, power_scale)) * 28.0, 138.0, 260.0)
		_knockback = clampf(22.0 + sqrt(maxf(0.0, power_scale)) * 3.0, 22.0, 36.0)
		_swallowable = false
	elif projectile_kind == "modern_orb":
		_flight_duration = clampf(distance / 1080.0, 0.16, 0.68)
		_splash_radius = clampf(112.0 + sqrt(maxf(0.0, power_scale)) * 22.0, 112.0, 220.0)
		_knockback = clampf(18.0 + sqrt(maxf(0.0, power_scale)) * 2.5, 18.0, 32.0)
		_swallowable = _rng.randf() < 0.18
	else:
		_flight_duration = clampf(distance / 1320.0, 0.12, 0.54)
		_splash_radius = clampf(48.0 + sqrt(maxf(0.0, power_scale)) * 10.0, 48.0, 105.0)
		_knockback = clampf(8.0 + sqrt(maxf(0.0, power_scale)) * 1.5, 8.0, 18.0)
		_swallowable = _rng.randf() < 0.08
	_maximum_lifetime = _flight_duration + MISS_COAST_SECONDS
	_set_collision_targets(collision_targets, target)
	_create_sprite()


func _process(delta: float) -> void:
	if _resolved or _sprite == null:
		return
	var safe_delta := maxf(0.0, delta)
	if _being_swallowed:
		_update_swallowed(safe_delta)
		return
	if not _is_target_available():
		# Target loss never changes a launched shot's path or lifetime.
		_coasting = true
		_target = null
	_elapsed += safe_delta
	var previous_position := position
	var progress := _elapsed / maxf(0.01, _flight_duration)
	var next_position := _get_trajectory_position(progress)
	var travel := next_position - previous_position
	position = next_position
	if travel.length_squared() > 0.01:
		_travel_direction = travel.normalized()
		_sprite.rotation = travel.angle() + (0.0 if projectile_kind == "arrow" else PI)
	var collision := _find_swept_collision(previous_position, next_position)
	if not collision.is_empty():
		position = previous_position.lerp(next_position, float(collision.get("fraction", 1.0)))
		_resolve_impact(collision.get("target") as Node2D)
		return
	if _elapsed >= _maximum_lifetime or _is_outside_padded_viewport():
		_resolved = true
		queue_free()


func can_be_swallowed() -> bool:
	return _swallowable and not _resolved and not _being_swallowed and _sprite != null and _sprite.visible


func start_swallowed_by(swallower: Node2D) -> bool:
	if swallower == null or not is_instance_valid(swallower) or not can_be_swallowed():
		return false
	_being_swallowed = true
	_swallower = swallower
	_swallow_start = position
	_swallow_progress = 0.0
	_target = null
	return true


func is_enemy_projectile() -> bool:
	return true


func _create_sprite() -> void:
	warm_up()
	_sprite = Sprite2D.new()
	_sprite.name = "EnemyProjectileSprite"
	_sprite.texture = _arrow_texture if projectile_kind == "arrow" else _bullet_texture
	_sprite.centered = true
	_sprite.z_index = 300
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if projectile_kind == "arrow":
		_sprite.scale = Vector2.ONE * 0.080
	else:
		var projectile_scale := 0.28
		if projectile_kind == "modern_shell":
			projectile_scale = 0.42
		elif projectile_kind == "modern_orb":
			projectile_scale = 0.34
		elif projectile_kind == "outer_bolt":
			projectile_scale = 0.22
		_sprite.scale = Vector2.ONE * projectile_scale
		if projectile_kind == "modern_shell":
			_sprite.modulate = Color(1.0, 0.62, 0.24)
		elif projectile_kind == "modern_orb":
			_sprite.modulate = Color(0.48, 0.86, 1.0)
		elif projectile_kind == "outer_bolt":
			_sprite.modulate = Color(0.34, 0.78, 1.0)
		var material := ShaderMaterial.new()
		material.shader = _bullet_shader
		if _sprite.texture != null:
			var image := _sprite.texture.get_image()
			if image != null and not image.is_empty():
				material.set_shader_parameter("key_color", image.get_pixel(0, 0))
		_sprite.material = material
	add_child(_sprite)


func _get_target_position() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return _last_target_position
	if _target.has_method("get_battle_hit_position"):
		return _target.call("get_battle_hit_position")
	return _target.position + Vector2(0.0, -48.0)


func _is_target_available() -> bool:
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return false
	return true


func get_travel_direction() -> Vector2:
	return _travel_direction


func _get_trajectory_position(progress: float) -> Vector2:
	var displacement := _last_target_position - _start_position
	var trajectory_position := _start_position + displacement * progress
	if projectile_kind == "arrow":
		if progress <= 1.0:
			# Preserve the authored in-flight arc exactly up to the old aim point.
			trajectory_position.y -= sin(progress * PI) * _arc_height
		else:
			# Continue along the arc's terminal tangent instead of stopping or
			# evaluating another target position after the shot has launched.
			var terminal_motion := displacement + Vector2(0.0, PI * _arc_height)
			trajectory_position = _last_target_position + terminal_motion * (progress - 1.0)
	return trajectory_position


func _set_collision_targets(candidates: Array[Node2D], original_target: Node2D) -> void:
	_collision_targets.clear()
	_previous_target_positions.clear()
	for candidate in candidates:
		if candidate != null and is_instance_valid(candidate) and not _collision_targets.has(candidate):
			_collision_targets.append(candidate)
	if original_target != null and is_instance_valid(original_target) and not _collision_targets.has(original_target):
		_collision_targets.append(original_target)
	for candidate in _collision_targets:
		_previous_target_positions[str(candidate.get_instance_id())] = _get_actor_hit_position(candidate)


func _find_swept_collision(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var earliest_fraction := INF
	var hit_target: Node2D
	for candidate in _collision_targets:
		if not _is_collision_target_valid(candidate):
			continue
		var target_key := str(candidate.get_instance_id())
		var current_target_position := _get_actor_hit_position(candidate)
		var previous_target_position := Vector2(
			_previous_target_positions.get(target_key, current_target_position)
		)
		var relative_start := from_position - previous_target_position
		var relative_end := to_position - current_target_position
		var hit_fraction := _get_circle_sweep_fraction(relative_start, relative_end)
		_previous_target_positions[target_key] = current_target_position
		if hit_fraction < earliest_fraction:
			earliest_fraction = hit_fraction
			hit_target = candidate
	if hit_target == null:
		return {}
	return {"target": hit_target, "fraction": earliest_fraction}


func _get_circle_sweep_fraction(relative_start: Vector2, relative_end: Vector2) -> float:
	var radius_squared := TARGET_COLLISION_RADIUS * TARGET_COLLISION_RADIUS
	if relative_start.length_squared() <= radius_squared:
		return 0.0
	var relative_motion := relative_end - relative_start
	var quadratic_a := relative_motion.length_squared()
	if quadratic_a <= 0.000001:
		return INF
	var quadratic_b := 2.0 * relative_start.dot(relative_motion)
	var quadratic_c := relative_start.length_squared() - radius_squared
	var discriminant := quadratic_b * quadratic_b - 4.0 * quadratic_a * quadratic_c
	if discriminant < 0.0:
		return INF
	var hit_fraction := (-quadratic_b - sqrt(discriminant)) / (2.0 * quadratic_a)
	return hit_fraction if hit_fraction >= 0.0 and hit_fraction <= 1.0 else INF


func _get_actor_hit_position(actor: Node2D) -> Vector2:
	if actor.has_method("get_battle_hit_position"):
		return actor.call("get_battle_hit_position")
	return actor.position + Vector2(0.0, -48.0)


func _is_collision_target_valid(candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	if candidate.has_method("is_battle_collision_enabled"):
		return bool(candidate.call("is_battle_collision_enabled"))
	return true


func _is_outside_padded_viewport() -> bool:
	if not is_inside_tree():
		return false
	return not get_viewport_rect().grow(OFFSCREEN_CLEANUP_MARGIN).has_point(position)


func _resolve_impact(hit_target: Node2D) -> void:
	if _resolved:
		return
	_resolved = true
	impacted.emit(self, hit_target, _damage, _splash_radius, _knockback)
	queue_free()


func _update_swallowed(delta: float) -> void:
	if _swallower == null or not is_instance_valid(_swallower):
		_resolved = true
		queue_free()
		return
	_swallow_progress = minf(1.0, _swallow_progress + delta / 0.26)
	var eased := ease(_swallow_progress, 2.2)
	var mouth_position := _swallower.position
	if _swallower.has_method("get_swallow_mouth_position"):
		mouth_position = _swallower.call("get_swallow_mouth_position")
	position = _swallow_start.lerp(mouth_position, eased)
	_sprite.scale *= maxf(0.72, 1.0 - delta * 8.0)
	if _swallow_progress >= 1.0:
		_resolved = true
		swallowed.emit(self)
		queue_free()
