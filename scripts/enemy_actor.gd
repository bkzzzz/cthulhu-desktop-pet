extends Node2D

signal attack_landed(actor: Node2D, target: Node2D, damage: float)
signal defeated(actor: Node2D, reward_count: int)

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
		"hp": 2.6, "damage": 0.16, "speed": 76.0, "reward": 7, "ranged": false
	},
	"villager2": {
		"move": "res://assets/enemyCharacter/villagers/villager2Run.png",
		"attack": "res://assets/enemyCharacter/villagers/villager2Attack.png",
		"hp": 2.8, "damage": 0.17, "speed": 72.0, "reward": 8, "ranged": false
	},
	"soldier1": {
		"move": "res://assets/enemyCharacter/soldiers/soldier1Idle.png",
		"attack": "res://assets/enemyCharacter/soldiers/soldier1Attack.png",
		"hp": 3.8, "damage": 0.23, "speed": 66.0, "reward": 11, "ranged": false
	},
	"soldier2": {
		"move": "res://assets/enemyCharacter/soldiers/soldier2Idle.png",
		"attack": "res://assets/enemyCharacter/soldiers/soldier2Attack.png",
		"hp": 3.1, "damage": 0.19, "speed": 56.0, "reward": 12, "ranged": true
	}
}

static var _frames_cache := {}
static var _chroma_shader: Shader

var enemy_id := "villager1"
var is_ranged := false
var health := 1.0
var max_health := 1.0
var _damage := 0.2
var _move_speed := 60.0
var _reward_count := 5
var _target: Node2D
var _sprite: AnimatedSprite2D
var _attack_cooldown := 0.0
var _attack_windup := 0.0
var _attack_pending := false
var _dead := false
var _entered := false
var _ground_y := 0.0
var _rng := RandomNumberGenerator.new()


func setup(new_enemy_id: String, spawn_position: Vector2, ground_y: float, power_scale := 1.0) -> void:
	enemy_id = new_enemy_id if DEFINITIONS.has(new_enemy_id) else "villager1"
	var data: Dictionary = DEFINITIONS[enemy_id]
	var safe_power := clampf(power_scale, 0.8, 2.0)
	max_health = float(data.get("hp", 2.0)) * (0.92 + (safe_power - 0.8) * 0.34)
	health = max_health
	_damage = float(data.get("damage", 0.3)) * safe_power
	_move_speed = float(data.get("speed", 60.0))
	_reward_count = int(data.get("reward", 6))
	is_ranged = bool(data.get("ranged", false))
	_ground_y = ground_y
	position = spawn_position
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_create_sprite(data)


func _process(delta: float) -> void:
	if _dead or _sprite == null:
		return
	var safe_delta := maxf(0.0, delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - safe_delta)
	if _attack_pending:
		_attack_windup -= safe_delta
		if _attack_windup <= 0.0:
			_attack_pending = false
			if _target != null and is_instance_valid(_target):
				attack_landed.emit(self, _target, _damage)
		return
	if _target == null or not is_instance_valid(_target):
		_play_move()
		return

	var stop_distance := 190.0 if is_ranged else 68.0
	var distance_x := _target.position.x - position.x
	if distance_x > stop_distance:
		position.x += minf(distance_x - stop_distance, _move_speed * safe_delta)
		_play_move()
		_entered = true
	elif _attack_cooldown <= 0.0:
		_begin_attack()
	else:
		_play_move()
	position.y = _ground_y


func set_target(target: Node2D) -> void:
	_target = target


func take_damage(amount: float, knockback := 12.0) -> void:
	if _dead:
		return
	health -= maxf(0.0, amount)
	position.x -= maxf(0.0, knockback)
	_flash_red()
	if health <= 0.0:
		_dead = true
		if _sprite != null:
			_sprite.visible = false
		defeated.emit(self, _reward_count)


func is_defeated() -> bool:
	return _dead


func _create_sprite(data: Dictionary) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "EnemySprite"
	_sprite.sprite_frames = _get_or_build_frames(enemy_id, data)
	_sprite.centered = true
	_sprite.position.y = -64.0
	_sprite.scale = Vector2.ONE * (0.82 if enemy_id.begins_with("villager") else 0.86)
	_sprite.flip_h = false
	_sprite.z_index = 180
	var material := ShaderMaterial.new()
	material.shader = _get_chroma_shader()
	var move_texture := load(String(data.get("move", ""))) as Texture2D
	if move_texture != null:
		var image := move_texture.get_image()
		if image != null and not image.is_empty():
			material.set_shader_parameter("key_color", image.get_pixel(0, 0))
	_sprite.material = material
	add_child(_sprite)
	_play_move()


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
	_add_atlas_animation(frames, "move", String(data.get("move", "")), 4, 3, 9.0, true)
	_add_atlas_animation(frames, "attack", String(data.get("attack", "")), 4, 4, 12.0, false)
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


func _play_move() -> void:
	if _sprite.animation != "move" or not _sprite.is_playing():
		_sprite.play("move")


func _begin_attack() -> void:
	_attack_cooldown = _rng.randf_range(1.65, 2.25) if is_ranged else _rng.randf_range(1.35, 1.9)
	_attack_windup = 0.48 if is_ranged else 0.28
	_attack_pending = true
	_sprite.play("attack")


func _flash_red() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.22, 0.22, 1.0), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.14)
