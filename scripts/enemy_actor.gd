extends Node2D

signal attack_landed(actor: Node2D, target: Node2D, damage: float)
signal projectile_requested(actor: Node2D, target: Node2D, damage: float, projectile_kind: String, power_scale: float)
signal defeated(actor: Node2D, reward_count: int)
signal swallowed(actor: Node2D, reward_count: int)

const CHROMA_SHADER := """
shader_type canvas_item;
uniform vec4 key_color : source_color = vec4(0.2, 0.8, 0.1, 1.0);
uniform float tolerance = 0.24;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (distance(source.rgb, key_color.rgb) <= tolerance) {
		source.a = 0.0;
	}
	COLOR = source;
}
"""

const DEFINITIONS := {
	"villager1": {
		"move": "res://assets/enemyCharacter/villagers/villager1Run.png",
		"attack": "res://assets/enemyCharacter/villagers/villager1Attack.png",
		"hp": 2.6, "damage": 0.16, "speed": 154.0, "reward": 7, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4
	},
	"villager2": {
		"move": "res://assets/enemyCharacter/villagers/villager2Run.png",
		"attack": "res://assets/enemyCharacter/villagers/villager2Attack.png",
		"hp": 2.8, "damage": 0.17, "speed": 148.0, "reward": 8, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4
	},
	"soldier1": {
		"move": "res://assets/enemyCharacter/soldiers/soldier1Idle.png",
		"attack": "res://assets/enemyCharacter/soldiers/soldier1Attack.png",
		"hp": 3.8, "damage": 0.23, "speed": 136.0, "reward": 11, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4
	},
	"soldier2": {
		"move": "res://assets/enemyCharacter/soldiers/soldier2Run.png",
		"attack": "res://assets/enemyCharacter/soldiers/soldier2Attack.png",
		"hp": 3.1, "damage": 0.19, "speed": 124.0, "reward": 12, "ranged": true,
		"projectile": "arrow", "run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4,
		"visual_scale": 0.95, "run_animation_speed": 11.5, "run_bob": 0.45, "run_tilt": 0.004
	},
	"victorian1": {
		"move": "res://assets/enemyCharacter/victorian/victorian1Run.png",
		"attack": "res://assets/enemyCharacter/victorian/victorian1Attack.png",
		"hp": 5.2, "damage": 0.34, "speed": 142.0, "reward": 16, "ranged": true,
		"projectile": "victorian_bullet", "run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4,
		"visual_scale": 0.88
	},
	"victorian2": {
		"move": "res://assets/enemyCharacter/victorian/victorian2Run.png",
		"attack": "res://assets/enemyCharacter/victorian/victorian2Attack.png",
		"hp": 6.2, "damage": 0.31, "speed": 151.0, "reward": 17, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 3,
		"visual_scale": 0.90
	},
	"victorian_boss": {
		"move": "res://assets/enemyCharacter/victorian/victorianBossRun.png",
		"attack": "res://assets/enemyCharacter/victorian/victorianBossAttack.png",
		"hp": 10.5, "damage": 0.43, "speed": 129.0, "reward": 24, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 3,
		"visual_scale": 1.02
	}
}

const MELEE_STOP_DISTANCE := 68.0
const MELEE_HIT_RANGE := 92.0
const FOOT_TASKBAR_OVERLAP := 6.0
const CHROMA_TOLERANCE := 0.24
const SWALLOW_ROTATIONS := 0.85

static var _frames_cache := {}
static var _alignment_cache := {}
static var _chroma_shader: Shader

var enemy_id := "villager1"
var is_ranged := false
var health := 1.0
var max_health := 1.0
var _damage := 0.2
var _move_speed := 60.0
var _reward_count := 5
var _power_scale := 1.0
var _projectile_kind := ""
var _swallow_resistant := false
var _target: Node2D
var _sprite: AnimatedSprite2D
var _attack_cooldown := 0.0
var _attack_windup := 0.0
var _attack_pending := false
var _attack_animation_remaining := 0.0
var _dead := false
var _entered := false
var _entry_x := 120.0
var _ground_y := 0.0
var _visual_scale := 0.84
var _run_motion_active := false
var _run_phase := 0.0
var _run_bob_amount := 2.2
var _run_tilt_amount := 0.018
var _battle_state := "run"
var _rng := RandomNumberGenerator.new()
var _being_swallowed := false
var _swallower: Node2D
var _swallow_start_position := Vector2.ZERO
var _swallow_start_visual_position := Vector2.ZERO
var _swallow_start_sprite_position := Vector2.ZERO
var _swallow_start_sprite_rotation := 0.0
var _swallow_progress := 0.0
var _swallow_duration := 0.55
var _swallow_arc_height := 72.0
var _launched := false
var _launch_velocity := Vector2.ZERO
var _launch_spin := 0.0


func setup(
	new_enemy_id: String,
	spawn_position: Vector2,
	ground_y: float,
	power_scale := 1.0,
	entry_x := 120.0
) -> void:
	enemy_id = new_enemy_id if DEFINITIONS.has(new_enemy_id) else "villager1"
	var data: Dictionary = DEFINITIONS[enemy_id]
	var safe_power := clampf(power_scale, 0.0, 1_000_000_000_000_000.0)
	_power_scale = safe_power
	var health_scale := clampf(pow(maxf(0.01, safe_power), 0.68), 0.05, 100_000.0)
	max_health = float(data.get("hp", 2.0)) * health_scale
	health = max_health
	_damage = float(data.get("damage", 0.3)) * safe_power
	_move_speed = float(data.get("speed", 60.0))
	_reward_count = int(data.get("reward", 6))
	is_ranged = bool(data.get("ranged", false))
	_projectile_kind = String(data.get("projectile", ""))
	_swallow_resistant = bool(data.get("swallow_resistant", false))
	_run_bob_amount = float(data.get("run_bob", 2.2))
	_run_tilt_amount = float(data.get("run_tilt", 0.018))
	_ground_y = ground_y
	_entry_x = entry_x
	position = spawn_position
	position.y = _ground_y
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_create_sprite(data)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	var safe_delta := maxf(0.0, delta)
	if _launched:
		_update_launched(safe_delta)
		return
	if _being_swallowed:
		_update_swallowed(safe_delta)
		return
	if _dead:
		return
	position.y = _ground_y
	_run_motion_active = false
	_attack_cooldown = maxf(0.0, _attack_cooldown - safe_delta)
	if _attack_animation_remaining > 0.0:
		_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - safe_delta)
	if _attack_pending:
		_attack_windup -= safe_delta
		if _attack_windup <= 0.0:
			_attack_pending = false
			if _target != null and is_instance_valid(_target) and _is_target_in_attack_range():
				if is_ranged and not _projectile_kind.is_empty():
					projectile_requested.emit(self, _target, _damage, _projectile_kind, _power_scale)
				else:
					attack_landed.emit(self, _target, _damage)
	if _attack_animation_remaining > 0.0:
		_update_sprite_pose(safe_delta)
		return

	if not _entered:
		var entry_distance := _entry_x - position.x
		if absf(entry_distance) > 1.0:
			_face_target(entry_distance)
			position.x = move_toward(position.x, _entry_x, _move_speed * safe_delta)
			_play_run(true)
			_update_sprite_pose(safe_delta)
			return
		position.x = _entry_x
		_entered = true

	if _target == null or not is_instance_valid(_target):
		_play_run(false, 0.45)
		_update_sprite_pose(safe_delta)
		return

	var distance_x := _target.position.x - position.x
	_face_target(distance_x)
	if is_ranged:
		# Archers claim a firing post after entering. They never chase a pet;
		# dragging a pet onto that post is how the player can break their backline.
		if _attack_cooldown <= 0.0:
			_begin_attack()
		else:
			_play_run(false, 0.55)
	elif absf(distance_x) > MELEE_STOP_DISTANCE:
		position.x += signf(distance_x) * minf(
			absf(distance_x) - MELEE_STOP_DISTANCE,
			_move_speed * safe_delta
		)
		_play_run(true)
	elif _attack_cooldown <= 0.0:
		_begin_attack()
	else:
		_play_run(false, 0.45)
	_update_sprite_pose(safe_delta)


func set_target(target: Node2D) -> void:
	_target = target


func take_damage(amount: float, knockback := 12.0, launch_velocity := Vector2.ZERO) -> void:
	if _dead:
		return
	health -= maxf(0.0, amount)
	var battlefield_width := _get_battlefield_width()
	position.x = clampf(position.x - maxf(0.0, knockback), -20.0, battlefield_width + 20.0)
	_flash_red()
	if health <= 0.0:
		if launch_velocity.length_squared() > 1.0:
			launch_offscreen(launch_velocity)
		else:
			_dead = true
			if _sprite != null:
				_sprite.visible = false
			defeated.emit(self, _reward_count)


func get_health() -> float:
	return health


func can_be_swallowed() -> bool:
	return not _dead and not _being_swallowed and not _swallow_resistant and _sprite != null and _sprite.visible


func start_swallowed_by(swallower: Node2D) -> bool:
	if swallower == null or not is_instance_valid(swallower) or not can_be_swallowed():
		return false
	_being_swallowed = true
	_swallower = swallower
	_swallow_start_position = position
	_swallow_start_sprite_position = _sprite.position if _sprite != null else Vector2.ZERO
	_swallow_start_sprite_rotation = _sprite.rotation if _sprite != null else 0.0
	_swallow_start_visual_position = position + _swallow_start_sprite_position
	_swallow_progress = 0.0
	var mouth_position := swallower.position
	if swallower.has_method("get_swallow_mouth_position"):
		mouth_position = swallower.call("get_swallow_mouth_position")
	var swallow_distance := _swallow_start_visual_position.distance_to(mouth_position)
	_swallow_duration = clampf(swallow_distance / 500.0, 1.25, 2.8)
	_swallow_arc_height = clampf(swallow_distance * 0.018, 6.0, 22.0)
	_attack_pending = false
	_target = null
	_battle_state = "swallowed"
	if _sprite != null:
		_sprite.z_index = 330
	return true


func is_being_swallowed() -> bool:
	return _being_swallowed


func launch_offscreen(velocity: Vector2) -> void:
	if _dead or _being_swallowed:
		return
	health = 0.0
	_dead = true
	_launched = true
	_launch_velocity = velocity if velocity.length_squared() > 1.0 else Vector2(-720.0, -210.0)
	_launch_spin = _rng.randf_range(-8.0, 8.0)
	_attack_pending = false
	_target = null
	_battle_state = "launched"
	defeated.emit(self, _reward_count)


func is_launched() -> bool:
	return _launched


func is_defeated() -> bool:
	return _dead or _being_swallowed


func has_entered_battlefield() -> bool:
	return _entered


func get_battle_state() -> String:
	return _battle_state


func get_battle_hit_position() -> Vector2:
	return position + Vector2(0.0, -52.0)


func get_projectile_origin() -> Vector2:
	var height := 66.0 if enemy_id == "soldier2" else 78.0
	var direction := 1.0
	if _target != null and is_instance_valid(_target) and _target.position.x < position.x:
		direction = -1.0
	return position + Vector2(direction * 38.0, -height)


func _create_sprite(data: Dictionary) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "EnemySprite"
	_sprite.sprite_frames = _get_or_build_frames(enemy_id, data)
	_sprite.centered = true
	_visual_scale = float(data.get("visual_scale", 0.82 if enemy_id.begins_with("villager") else 0.86))
	_sprite.scale = Vector2.ONE * _visual_scale
	_sprite.flip_h = false
	_sprite.z_index = 180
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = _get_chroma_shader()
	var move_texture := load(String(data.get("move", ""))) as Texture2D
	if move_texture != null:
		var image := move_texture.get_image()
		if image != null and not image.is_empty():
			material.set_shader_parameter("key_color", image.get_pixel(0, 0))
	_sprite.material = material
	add_child(_sprite)
	_play_run(true)
	_update_sprite_pose(0.0)


static func _get_chroma_shader() -> Shader:
	if _chroma_shader == null:
		_chroma_shader = Shader.new()
		_chroma_shader.code = CHROMA_SHADER
	return _chroma_shader


static func _get_or_build_frames(cache_key: String, data: Dictionary) -> SpriteFrames:
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_atlas_animation(
		frames, "run", String(data.get("move", "")),
		int(data.get("run_columns", 4)), int(data.get("run_rows", 3)),
		float(data.get("run_animation_speed", 10.0)), true
	)
	_add_atlas_animation(
		frames, "attack", String(data.get("attack", "")),
		int(data.get("attack_columns", 4)), int(data.get("attack_rows", 4)), 12.0, false
	)
	_frames_cache[cache_key] = frames
	return frames


static func _add_atlas_animation(
	frames: SpriteFrames,
	animation_name: String,
	texture_path: String,
	columns: int,
	rows: int,
	speed: float,
	looped: bool
) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, looped)
	var frame_size := Vector2(float(texture.get_width()) / columns, float(texture.get_height()) / rows)
	for row in rows:
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			frames.add_frame(animation_name, atlas)


func _play_run(moving: bool, speed_scale := 1.0) -> void:
	_battle_state = "run"
	_run_motion_active = moving
	_sprite.speed_scale = maxf(0.05, speed_scale)
	if _sprite.animation != "run" or not _sprite.is_playing():
		_sprite.play("run")


func _begin_attack() -> void:
	_battle_state = "attack"
	_attack_cooldown = _rng.randf_range(1.36, 1.62) if is_ranged else _rng.randf_range(1.30, 1.58)
	_attack_windup = 0.58 if is_ranged else 0.31
	_attack_pending = true
	_attack_animation_remaining = 1.30
	_run_motion_active = false
	_sprite.speed_scale = 1.0
	_sprite.play("attack")


func _is_target_in_attack_range() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if is_ranged:
		return _entered
	return absf(_target.position.x - position.x) <= MELEE_HIT_RANGE


func _face_target(distance_x: float) -> void:
	if _sprite == null or is_zero_approx(distance_x):
		return
	# All current sheets are authored facing right.
	_sprite.flip_h = distance_x < 0.0


func _update_sprite_pose(delta: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _run_motion_active and _sprite.animation == "run":
		_run_phase += maxf(0.0, delta) * 11.0
	var base_position := _get_animation_alignment(String(_sprite.animation))
	var run_bob := sin(_run_phase) * _run_bob_amount if _run_motion_active and _sprite.animation == "run" else 0.0
	_sprite.position = base_position + Vector2(0.0, run_bob)
	_sprite.rotation = sin(_run_phase * 0.5) * _run_tilt_amount if _run_motion_active and _sprite.animation == "run" else 0.0


func _get_animation_alignment(animation_name: String) -> Vector2:
	var cache_key := "%s:%s" % [enemy_id, animation_name]
	if not _alignment_cache.has(cache_key):
		var alignment := Vector2(0.0, 60.0)
		if _sprite.sprite_frames.has_animation(animation_name) and _sprite.sprite_frames.get_frame_count(animation_name) > 0:
			var frame_texture := _sprite.sprite_frames.get_frame_texture(animation_name, 0)
			var frame_image := _get_atlas_frame_image(frame_texture)
			if frame_image != null and not frame_image.is_empty():
				var bounds := _get_visible_bounds(frame_image)
				if bounds.size != Vector2i.ZERO:
					var half_size := Vector2(frame_image.get_size()) * 0.5
					var visible_center_x := float(bounds.position.x) + float(bounds.size.x) * 0.5
					var visible_foot_y := float(bounds.position.y + bounds.size.y - 1)
					alignment = Vector2(visible_center_x - half_size.x, visible_foot_y - half_size.y)
		_alignment_cache[cache_key] = alignment
	var local_alignment: Vector2 = _alignment_cache[cache_key]
	return Vector2(
		-local_alignment.x * _visual_scale,
		FOOT_TASKBAR_OVERLAP - local_alignment.y * _visual_scale
	)


static func _get_atlas_frame_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image := atlas_texture.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region := Rect2i(
			Vector2i(roundi(atlas_texture.region.position.x), roundi(atlas_texture.region.position.y)),
			Vector2i(roundi(atlas_texture.region.size.x), roundi(atlas_texture.region.size.y))
		)
		return atlas_image.get_region(region)
	return texture.get_image()


static func _get_visible_bounds(image: Image) -> Rect2i:
	var key_color := image.get_pixel(0, 0)
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.02 or _color_distance(color, key_color) <= CHROMA_TOLERANCE:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt((dr * dr) + (dg * dg) + (db * db))


func _flash_red() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.22, 0.22, 1.0), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.14)


func _update_swallowed(delta: float) -> void:
	if _swallower == null or not is_instance_valid(_swallower):
		_being_swallowed = false
		_swallower = null
		_sprite.scale = Vector2.ONE * _visual_scale
		_sprite.position = _swallow_start_sprite_position
		_sprite.rotation = _swallow_start_sprite_rotation
		_sprite.z_index = 180
		return
	_swallow_progress = minf(1.0, _swallow_progress + delta / maxf(0.01, _swallow_duration))
	var mouth_position := _swallower.position
	if _swallower.has_method("get_swallow_mouth_position"):
		mouth_position = _swallower.call("get_swallow_mouth_position")
	var travel_progress := smoothstep(0.0, 1.0, _swallow_progress)
	var desired_visual_position := _swallow_start_visual_position.lerp(
		mouth_position,
		travel_progress
	)
	var path_direction := mouth_position - _swallow_start_visual_position
	if not path_direction.is_zero_approx():
		var path_normal := Vector2(-path_direction.y, path_direction.x).normalized()
		desired_visual_position += (
			path_normal * sin(travel_progress * PI) * _swallow_arc_height
		)
	# Rotation and shrink start on the first suction frame and continue steadily
	# until the visible center reaches the vortex.
	var shrink_progress := smoothstep(0.0, 1.0, _swallow_progress)
	# Enemy roots sit at their feet during combat, while the sprite has a negative
	# alignment offset. Cancelling that offset throughout the squeeze makes the
	# visible body—not merely its root—finish exactly at the vortex opening.
	_sprite.position = _swallow_start_sprite_position.lerp(Vector2.ZERO, shrink_progress)
	position = desired_visual_position - _sprite.position
	_sprite.scale = Vector2.ONE * _visual_scale * lerpf(1.0, 0.04, shrink_progress)
	var rotation_direction := -1.0 if path_direction.x >= 0.0 else 1.0
	_sprite.rotation = (
		_swallow_start_sprite_rotation
		+ rotation_direction * TAU * SWALLOW_ROTATIONS * _swallow_progress
	)
	if _swallow_progress >= 1.0:
		_being_swallowed = false
		_dead = true
		_sprite.visible = false
		swallowed.emit(self, _reward_count)


func _update_launched(delta: float) -> void:
	position += _launch_velocity * delta
	_launch_velocity.y += 720.0 * delta
	if _sprite != null:
		_sprite.rotation += _launch_spin * delta
	var battlefield_width := _get_battlefield_width()
	if position.x < -260.0 or position.x > battlefield_width + 260.0 or position.y > _ground_y + 260.0:
		queue_free()


func _get_battlefield_width() -> float:
	return maxf(1.0, get_viewport_rect().size.x) if is_inside_tree() else 1920.0
