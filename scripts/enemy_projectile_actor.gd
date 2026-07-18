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

var projectile_kind := "arrow"
var _target: Node2D
var _damage := 0.0
var _splash_radius := 0.0
var _knockback := 12.0
var _start_position := Vector2.ZERO
var _elapsed := 0.0
var _flight_duration := 0.5
var _arc_height := 0.0
var _sprite: Sprite2D
var _resolved := false
var _swallowable := false
var _being_swallowed := false
var _swallower: Node2D
var _swallow_start := Vector2.ZERO
var _swallow_progress := 0.0
var _rng := RandomNumberGenerator.new()


func setup(
	new_kind: String,
	start_position: Vector2,
	target: Node2D,
	damage: float,
	power_scale := 1.0
) -> void:
	projectile_kind = new_kind if new_kind in ["arrow", "victorian_bullet"] else "arrow"
	position = start_position
	_start_position = start_position
	_target = target
	_damage = maxf(0.0, damage)
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	var initial_target := _get_target_position()
	var distance := maxf(1.0, start_position.distance_to(initial_target))
	if projectile_kind == "arrow":
		_flight_duration = clampf(distance / 610.0, 0.28, 1.25)
		_arc_height = clampf(distance * 0.09, 22.0, 66.0)
		_knockback = 11.0
		_swallowable = true
	else:
		_flight_duration = clampf(distance / 760.0, 0.22, 1.0)
		_splash_radius = clampf(92.0 + sqrt(maxf(0.0, power_scale)) * 24.0, 92.0, 210.0)
		_knockback = clampf(14.0 + sqrt(maxf(0.0, power_scale)) * 2.5, 14.0, 28.0)
		# Pet11 can catch ordinary shots, while charged rounds remain dangerous.
		_swallowable = _rng.randf() < 0.45
	_create_sprite()


func _process(delta: float) -> void:
	if _resolved or _sprite == null:
		return
	var safe_delta := maxf(0.0, delta)
	if _being_swallowed:
		_update_swallowed(safe_delta)
		return
	if _target == null or not is_instance_valid(_target):
		_resolved = true
		queue_free()
		return
	_elapsed += safe_delta
	var progress := minf(1.0, _elapsed / maxf(0.01, _flight_duration))
	var target_position := _get_target_position()
	var next_position := _start_position.lerp(target_position, progress)
	if projectile_kind == "arrow":
		next_position.y -= sin(progress * PI) * _arc_height
	var travel := next_position - position
	position = next_position
	if travel.length_squared() > 0.01:
		_sprite.rotation = travel.angle() + (PI if projectile_kind == "victorian_bullet" else 0.0)
	if progress >= 1.0:
		_resolved = true
		impacted.emit(self, _target, _damage, _splash_radius, _knockback)
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
	_sprite = Sprite2D.new()
	_sprite.name = "EnemyProjectileSprite"
	_sprite.texture = load(ARROW_TEXTURE if projectile_kind == "arrow" else BULLET_TEXTURE) as Texture2D
	_sprite.centered = true
	_sprite.z_index = 300
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if projectile_kind == "arrow":
		_sprite.scale = Vector2.ONE * 0.080
	else:
		_sprite.scale = Vector2.ONE * 0.28
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = BULLET_CHROMA_SHADER
		material.shader = shader
		if _sprite.texture != null:
			var image := _sprite.texture.get_image()
			if image != null and not image.is_empty():
				material.set_shader_parameter("key_color", image.get_pixel(0, 0))
		_sprite.material = material
	add_child(_sprite)


func _get_target_position() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return position
	if _target.has_method("get_battle_hit_position"):
		return _target.call("get_battle_hit_position")
	return _target.position + Vector2(0.0, -48.0)


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
