extends Node2D

const CombatHealthBar = preload("res://scripts/combat_health_bar.gd")

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
		"move": "res://assets/enemyCharacter/soldiers/soldier1Run.png",
		"attack": "res://assets/enemyCharacter/soldiers/soldier1Attack.png",
		"hp": 3.8, "damage": 0.23, "speed": 136.0, "reward": 11, "ranged": false,
		"run_columns": 4, "run_rows": 3, "attack_columns": 4, "attack_rows": 4,
		"run_animation_speed": 10.5, "run_bob": 0.35, "run_tilt": 0.003
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
	},
	"modern2": {
		"move": "res://assets/enemyCharacter/modern/modern2Run.png",
		"attack": "res://assets/enemyCharacter/modern/modern2Attack.png",
		"hp": 14.5, "damage": 0.62, "speed": 166.0, "reward": 31, "ranged": true,
		"projectile": "modern_shell", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 0.92,
		"run_animation_speed": 9.0, "run_bob": 0.25, "run_tilt": 0.002,
		"attack_windup": 0.34, "attack_duration": 1.0, "attack_cooldown_min": 1.05,
		"attack_cooldown_max": 1.28, "projectile_height": 64.0
	},
	"modern3": {
		"move": "res://assets/enemyCharacter/modern/modern3Run.png",
		"attack": "res://assets/enemyCharacter/modern/modern3Attack.png",
		"hp": 12.8, "damage": 0.78, "speed": 178.0, "reward": 34, "ranged": true,
		"projectile": "modern_orb", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 0.94,
		"attack_windup": 0.24, "attack_duration": 0.82,
		"attack_cooldown_min": 0.88, "attack_cooldown_max": 1.12,
		"projectile_height": 94.0
	},
	"outerspace1": {
		"move": "res://assets/enemyCharacter/outerSpace/outerSpace1Idle.png",
		"attack": "res://assets/enemyCharacter/outerSpace/outerSpace1Idle.png",
		"hp": 24.0, "damage": 0.36, "speed": 205.0, "reward": 48, "ranged": true,
		"projectile": "outer_bolt", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 0.82,
		"flying": true, "flight_height": 118.0, "projectiles_per_attack": 5,
		"projectile_spread": 16.0, "attack_windup": 0.22, "attack_duration": 0.78,
		"attack_cooldown_min": 1.08, "attack_cooldown_max": 1.28
	},
	"outerspace2": {
		"move": "res://assets/enemyCharacter/outerSpace/outerSpace2Idle.png",
		"attack": "res://assets/enemyCharacter/outerSpace/outerSpace2Idle.png",
		"hp": 31.0, "damage": 0.34, "speed": 192.0, "reward": 58, "ranged": true,
		"projectile": "outer_bolt", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 0.88,
		"flying": true, "flight_height": 154.0, "projectiles_per_attack": 7,
		"projectile_spread": 18.0, "attack_windup": 0.28, "attack_duration": 0.86,
		"attack_cooldown_min": 1.18, "attack_cooldown_max": 1.38
	},
	"outerspace3": {
		"move": "res://assets/enemyCharacter/outerSpace/outerSpace3Idle.png",
		"attack": "res://assets/enemyCharacter/outerSpace/outerSpace3Idle.png",
		"hp": 42.0, "damage": 0.32, "speed": 184.0, "reward": 72, "ranged": true,
		"projectile": "outer_bolt", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 0.96,
		"flying": true, "flight_height": 182.0, "projectiles_per_attack": 9,
		"projectile_spread": 21.0, "attack_windup": 0.34, "attack_duration": 0.96,
		"attack_cooldown_min": 1.32, "attack_cooldown_max": 1.52
	},
	"final_boss": {
		"move": "res://assets/enemyCharacter/finalBoss1/finalBossAnimation.png",
		"attack": "res://assets/enemyCharacter/finalBoss1/finalBossAnimation.png",
		"hp": 260.0, "damage": 0.50, "speed": 95.0, "reward": 400, "ranged": true,
		"projectile": "modern_orb", "run_columns": 4, "run_rows": 3,
		"attack_columns": 4, "attack_rows": 3, "visual_scale": 1.12,
		"attack_visual_scale": 1.035, "run_animation_speed": 7.5,
		"attack_animation_speed": 8.5, "run_bob": 3.8, "run_tilt": 0.008,
		"flying": true, "flight_height": 178.0, "projectiles_per_attack": 3,
		"projectile_spread": 34.0, "projectile_height": 104.0,
		"attack_windup": 0.48, "attack_duration": 1.36,
		"attack_cooldown_min": 1.48, "attack_cooldown_max": 1.72,
		"swallow_resistant": true, "boss": true, "health_bar_width": 190.0,
		"health_bar_y": -154.0, "hit_height": 0.0
	}
}

const COMBAT_POWER := {
	"villager1": 10.0, "villager2": 12.0, "soldier1": 18.0, "soldier2": 22.0,
	"victorian1": 30.0, "victorian2": 34.0, "victorian_boss": 50.0,
	"modern2": 65.0, "modern3": 78.0,
	"outerspace1": 120.0, "outerspace2": 150.0, "outerspace3": 190.0,
	"final_boss": 520.0
}

const MELEE_STOP_DISTANCE := 68.0
const MELEE_HIT_RANGE := 92.0
const FOOT_TASKBAR_OVERLAP := 0.0
const CHROMA_TOLERANCE := 0.24
const SWALLOW_ROTATIONS := 0.85
const HIT_REACTION_SECONDS := 0.16
const LOOP_ENDPOINT_DURATION_SCALE := 0.5
# Standard battle waves need enough staying power for formation and targeting to
# matter. The finale remains separately tuned around its boss health window.
const STANDARD_ENEMY_HEALTH_MULTIPLIER := 1.50
const GROUND_ENEMY_DAMAGE_MULTIPLIER := 1.15

static var _frames_cache := {}
static var _alignment_cache := {}
static var _run_half_width_cache := {}
static var _battle_half_width_cache := {}
static var _visible_bounds_cache := {}
static var _move_sheet_key_color_cache := {}
static var _warmed_enemy_ids := {}
static var _chroma_shader: Shader


static func warm_up(enemy_ids: Array) -> void:
	for enemy_id_value in enemy_ids:
		var warm_enemy_id := String(enemy_id_value)
		warm_up_stage(warm_enemy_id, "frames")
		warm_up_stage(warm_enemy_id, "run_width")
		warm_up_stage(warm_enemy_id, "battle_width")


static func warm_up_stage(warm_enemy_id: String, stage: String) -> void:
	if _warmed_enemy_ids.has(warm_enemy_id) or not DEFINITIONS.has(warm_enemy_id):
		return
	var probe = _create_warmup_probe(warm_enemy_id)
	if probe == null:
		return
	if stage == "run_width":
		probe.call("_get_run_visual_half_width")
	elif stage == "battle_width":
		probe.call("_get_battle_visual_half_width")
		probe.call(
			"_get_animation_alignment",
			"attack",
			float(DEFINITIONS[warm_enemy_id].get("attack_visual_scale", 1.0))
		)
		_warmed_enemy_ids[warm_enemy_id] = true
	probe.free()


static func _create_warmup_probe(warm_enemy_id: String) -> Node2D:
	var script_resource := load("res://scripts/enemy_actor.gd") as GDScript
	if script_resource == null:
		return null
	var probe = script_resource.new()
	probe.setup(warm_enemy_id, Vector2.ZERO, 720.0, 1.0, 120.0)
	return probe

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
var _health_bar: Node2D
var _attack_cooldown := 0.0
var _attack_windup := 0.0
var _attack_pending := false
var _attack_animation_remaining := 0.0
var _dead := false
var _entered := false
var _entry_x := 120.0
var _entry_side := -1
var _ground_y := 0.0
var _battlefield_width := 0.0
var _visual_scale := 0.84
var _attack_visual_scale := 1.0
var _attack_windup_seconds := 0.58
var _attack_duration_seconds := 1.30
var _attack_cooldown_min := 1.36
var _attack_cooldown_max := 1.62
var _projectile_height := 0.0
var _flying := false
var _flight_height := 0.0
var _projectiles_per_attack := 1
var _projectile_spread := 0.0
var _barrage_shot_index := 0
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
var _hit_reaction_remaining := 0.0
var _hit_reaction_direction := -1.0
var _is_boss := false
var _boss_phase := 1
var _hit_height := 52.0


func setup(
	new_enemy_id: String,
	spawn_position: Vector2,
	ground_y: float,
	power_scale := 1.0,
	entry_x := 120.0,
	battlefield_width := -1.0
) -> void:
	enemy_id = new_enemy_id if DEFINITIONS.has(new_enemy_id) else "villager1"
	var data: Dictionary = DEFINITIONS[enemy_id]
	var safe_power := clampf(power_scale, 0.0, 1_000_000_000_000_000.0)
	_power_scale = safe_power
	var health_scale := clampf(pow(maxf(0.01, safe_power), 0.68), 0.05, 100_000.0)
	max_health = float(data.get("hp", 2.0)) * health_scale * get_health_multiplier(enemy_id)
	health = max_health
	_damage = float(data.get("damage", 0.3)) * safe_power * get_damage_multiplier(enemy_id)
	_move_speed = float(data.get("speed", 60.0))
	_reward_count = int(data.get("reward", 6))
	is_ranged = bool(data.get("ranged", false))
	_projectile_kind = String(data.get("projectile", ""))
	_swallow_resistant = bool(data.get("swallow_resistant", false))
	_is_boss = bool(data.get("boss", false))
	_hit_height = maxf(0.0, float(data.get("hit_height", 52.0)))
	_run_bob_amount = float(data.get("run_bob", 2.2))
	_run_tilt_amount = float(data.get("run_tilt", 0.018))
	_flying = bool(data.get("flying", false))
	_flight_height = maxf(0.0, float(data.get("flight_height", 0.0)))
	_projectiles_per_attack = maxi(1, int(data.get("projectiles_per_attack", 1)))
	_projectile_spread = maxf(0.0, float(data.get("projectile_spread", 0.0)))
	_ground_y = ground_y
	_battlefield_width = maxf(0.0, battlefield_width)
	_entry_x = entry_x
	_entry_side = 1 if spawn_position.x > entry_x else -1
	position = spawn_position
	position.y = _ground_y - _flight_height
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_create_sprite(data)
	_create_health_bar(data)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	var safe_delta := maxf(0.0, delta)
	if _being_swallowed:
		_update_swallowed(safe_delta)
		return
	if _dead:
		return
	position.y = _ground_y - _flight_height
	_run_motion_active = false
	_attack_cooldown = maxf(0.0, _attack_cooldown - safe_delta)
	if _attack_animation_remaining > 0.0:
		_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - safe_delta)
	_hit_reaction_remaining = maxf(0.0, _hit_reaction_remaining - safe_delta)
	if _attack_pending:
		_attack_windup -= safe_delta
		if _attack_windup <= 0.0:
			_attack_pending = false
			if _target != null and is_instance_valid(_target) and _is_target_in_attack_range():
				if is_ranged and not _projectile_kind.is_empty():
					for shot_index in _projectiles_per_attack:
						_barrage_shot_index = shot_index
						projectile_requested.emit(self, _target, _damage, _projectile_kind, _power_scale)
				else:
					attack_landed.emit(self, _target, _damage)
	if _attack_animation_remaining > 0.0:
		_update_sprite_pose(safe_delta)
		return

	if not _entered:
		var entry_destination := _get_entry_destination_x()
		var entry_distance := entry_destination - position.x
		if absf(entry_distance) > 1.0:
			_face_target(entry_distance)
			position.x = move_toward(position.x, entry_destination, _move_speed * safe_delta)
			_play_run(true)
			_update_sprite_pose(safe_delta)
			return
		position.x = entry_destination
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


func take_damage(
	amount: float,
	knockback := 12.0,
	_launch_velocity := Vector2.ZERO,
	knockback_direction := -1.0
) -> void:
	if _dead:
		return
	health -= maxf(0.0, amount)
	var battlefield_width := _get_battlefield_width()
	var visual_margin := minf(_get_battle_visual_half_width(), battlefield_width * 0.5)
	var safe_knockback_direction := -1.0 if knockback_direction < 0.0 else 1.0
	_hit_reaction_remaining = HIT_REACTION_SECONDS
	_hit_reaction_direction = safe_knockback_direction
	position.x = clampf(
		position.x + safe_knockback_direction * maxf(0.0, knockback),
		visual_margin,
		battlefield_width - visual_margin
	)
	_flash_red()
	if _health_bar != null and is_instance_valid(_health_bar):
		_health_bar.call("set_health", health, max_health)
	_update_boss_phase()
	if health <= 0.0:
		_dead = true
		if _sprite != null:
			_sprite.visible = false
		defeated.emit(self, _reward_count)


func get_health() -> float:
	return health


func can_be_swallowed() -> bool:
	return (
		has_entered_battlefield()
		and not _dead
		and not _being_swallowed
		and not _swallow_resistant
		and _sprite != null
		and _sprite.visible
	)


func start_swallowed_by(swallower: Node2D) -> bool:
	if swallower == null or not is_instance_valid(swallower) or not can_be_swallowed():
		return false
	_being_swallowed = true
	if _health_bar != null:
		_health_bar.visible = false
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


func is_defeated() -> bool:
	return _dead or _being_swallowed


func is_targetable() -> bool:
	return not _dead and not _being_swallowed


func has_entered_battlefield() -> bool:
	# Test-spawned and restored enemies may begin exactly at their entrance goal.
	return _entered or absf(position.x - _get_entry_destination_x()) <= 0.5


func _get_entry_destination_x() -> float:
	var visual_margin := _get_run_visual_half_width()
	if is_ranged:
		return visual_margin if _entry_side < 0 else _get_battlefield_width() - visual_margin
	if _entry_side < 0:
		return maxf(_entry_x, visual_margin)
	return minf(_entry_x, _get_battlefield_width() - visual_margin)


func _get_run_visual_half_width() -> float:
	if _run_half_width_cache.has(enemy_id):
		return float(_run_half_width_cache[enemy_id])
	if _sprite == null or _sprite.sprite_frames == null:
		return 48.0
	var animation_name := "run"
	if not _sprite.sprite_frames.has_animation(animation_name):
		return 48.0
	var alignment_x := _get_animation_alignment(animation_name).x
	var widest_extent := 0.0
	for frame_index in _sprite.sprite_frames.get_frame_count(animation_name):
		var frame_texture := _sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
		var bounds := _get_frame_visible_bounds(frame_texture)
		if bounds.size == Vector2i.ZERO:
			continue
		var half_frame_width := float(_get_frame_size(frame_texture).x) * 0.5
		var raw_left := (float(bounds.position.x) - half_frame_width) * _visual_scale
		var raw_right := (float(bounds.position.x + bounds.size.x) - half_frame_width) * _visual_scale
		# Enemies can enter from either edge, so include the mirrored extents too.
		widest_extent = maxf(widest_extent, absf(alignment_x + raw_left))
		widest_extent = maxf(widest_extent, absf(alignment_x + raw_right))
		widest_extent = maxf(widest_extent, absf(alignment_x - raw_left))
		widest_extent = maxf(widest_extent, absf(alignment_x - raw_right))
	# The hit squash can briefly widen the sprite during its entrance.
	var safe_half_width := maxf(12.0, ceilf(widest_extent * 1.08 + 4.0))
	_run_half_width_cache[enemy_id] = safe_half_width
	return safe_half_width


func _get_battle_visual_half_width() -> float:
	if _battle_half_width_cache.has(enemy_id):
		return float(_battle_half_width_cache[enemy_id])
	if _sprite == null or _sprite.sprite_frames == null:
		return 48.0
	var widest_extent := 0.0
	for animation_name in ["run", "attack"]:
		if not _sprite.sprite_frames.has_animation(animation_name):
			continue
		var animation_scale := _attack_visual_scale if animation_name == "attack" else 1.0
		var effective_scale := _visual_scale * animation_scale
		var alignment_x := _get_animation_alignment(animation_name, animation_scale).x
		for frame_index in _sprite.sprite_frames.get_frame_count(animation_name):
			var frame_texture := _sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
			var bounds := _get_frame_visible_bounds(frame_texture)
			if bounds.size == Vector2i.ZERO:
				continue
			var half_frame_width := float(_get_frame_size(frame_texture).x) * 0.5
			var raw_left := (float(bounds.position.x) - half_frame_width) * effective_scale
			var raw_right := (float(bounds.position.x + bounds.size.x) - half_frame_width) * effective_scale
			widest_extent = maxf(widest_extent, absf(alignment_x + raw_left))
			widest_extent = maxf(widest_extent, absf(alignment_x + raw_right))
			widest_extent = maxf(widest_extent, absf(alignment_x - raw_left))
			widest_extent = maxf(widest_extent, absf(alignment_x - raw_right))
	var safe_half_width := maxf(12.0, ceilf(widest_extent * 1.08 + 4.0))
	_battle_half_width_cache[enemy_id] = safe_half_width
	return safe_half_width


func get_entry_side() -> int:
	return _entry_side


func get_battle_state() -> String:
	return _battle_state


func get_battle_hit_position() -> Vector2:
	return position + Vector2(0.0, -_hit_height)


func get_boss_phase() -> int:
	return _boss_phase


func get_projectile_origin() -> Vector2:
	var height := _projectile_height
	if height <= 0.0:
		height = 0.0 if _flying else (66.0 if enemy_id == "soldier2" else 78.0)
	var direction := 1.0
	if _target != null and is_instance_valid(_target) and _target.position.x < position.x:
		direction = -1.0
	var centered_shot := float(_barrage_shot_index) - float(_projectiles_per_attack - 1) * 0.5
	return position + Vector2(direction * (52.0 if _flying else 38.0), -height + centered_shot * _projectile_spread)


static func get_combat_power(type_id: String) -> float:
	return float(COMBAT_POWER.get(type_id, 10.0))


static func get_health_multiplier(type_id: String) -> float:
	var data: Dictionary = DEFINITIONS.get(type_id, DEFINITIONS["villager1"])
	return 1.0 if bool(data.get("boss", false)) else STANDARD_ENEMY_HEALTH_MULTIPLIER


static func get_damage_multiplier(type_id: String) -> float:
	var data: Dictionary = DEFINITIONS.get(type_id, DEFINITIONS["villager1"])
	if bool(data.get("boss", false)) or bool(data.get("flying", false)):
		return 1.0
	return GROUND_ENEMY_DAMAGE_MULTIPLIER


static func get_reward_count(type_id: String) -> int:
	var data: Dictionary = DEFINITIONS.get(type_id, DEFINITIONS["villager1"])
	return maxi(0, int(data.get("reward", 0)))


func _create_sprite(data: Dictionary) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "EnemySprite"
	_sprite.sprite_frames = _get_or_build_frames(enemy_id, data)
	_sprite.centered = true
	_visual_scale = float(data.get("visual_scale", 0.82 if enemy_id.begins_with("villager") else 0.86))
	_attack_visual_scale = float(data.get("attack_visual_scale", 1.0))
	_attack_windup_seconds = float(data.get("attack_windup", 0.58 if is_ranged else 0.31))
	_attack_duration_seconds = float(data.get("attack_duration", 1.30))
	_attack_cooldown_min = float(data.get("attack_cooldown_min", 1.36 if is_ranged else 1.30))
	_attack_cooldown_max = float(data.get("attack_cooldown_max", 1.62 if is_ranged else 1.58))
	_projectile_height = float(data.get("projectile_height", 0.0))
	_sprite.scale = Vector2.ONE * _visual_scale
	_sprite.flip_h = false
	_sprite.z_index = 180
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = _get_chroma_shader()
	var move_sheet_key_color: Variant = _get_move_sheet_key_color(String(data.get("move", "")))
	if move_sheet_key_color is Color:
		material.set_shader_parameter("key_color", move_sheet_key_color)
	_sprite.material = material
	add_child(_sprite)
	_play_run(true)
	_update_sprite_pose(0.0)


func _create_health_bar(data: Dictionary) -> void:
	_health_bar = CombatHealthBar.new()
	_health_bar.name = "CombatHealthBar"
	var is_boss := bool(data.get("boss", false))
	var bar_width := float(data.get("health_bar_width", 190.0 if is_boss else 76.0))
	_health_bar.call("setup", true, is_boss, bar_width)
	_health_bar.call("set_health", health, max_health, true)
	_health_bar.position = Vector2(
		0.0,
		float(data.get("health_bar_y", -82.0 if _flying else -142.0))
	)
	add_child(_health_bar)


static func _get_chroma_shader() -> Shader:
	if _chroma_shader == null:
		_chroma_shader = Shader.new()
		_chroma_shader.code = CHROMA_SHADER
	return _chroma_shader


static func _get_move_sheet_key_color(texture_path: String) -> Variant:
	if _move_sheet_key_color_cache.has(texture_path):
		return _move_sheet_key_color_cache[texture_path]
	var key_color: Variant = null
	var texture := load(texture_path) as Texture2D
	if texture != null:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			key_color = image.get_pixel(0, 0)
	_move_sheet_key_color_cache[texture_path] = key_color
	return key_color


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
		int(data.get("attack_columns", 4)), int(data.get("attack_rows", 4)),
		float(data.get("attack_animation_speed", 12.0)), false
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
	var frame_count := columns * rows
	var frame_index := 0
	for row in rows:
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			var duration_scale := 1.0
			if looped and frame_count > 1 and frame_index in [0, frame_count - 1]:
				# Treat the two endpoint samples as one boundary beat so the run
				# cycle does not appear to pause when it wraps back to frame zero.
				duration_scale = LOOP_ENDPOINT_DURATION_SCALE
			frames.add_frame(animation_name, atlas, duration_scale)
			frame_index += 1


func _play_run(moving: bool, speed_scale := 1.0) -> void:
	_battle_state = "run"
	_run_motion_active = moving
	_sprite.speed_scale = maxf(0.05, speed_scale)
	if _sprite.animation != "run" or not _sprite.is_playing():
		_sprite.play("run")


func _begin_attack() -> void:
	_battle_state = "attack"
	_attack_cooldown = _rng.randf_range(_attack_cooldown_min, _attack_cooldown_max)
	_attack_windup = _attack_windup_seconds
	_attack_pending = true
	_attack_animation_remaining = _attack_duration_seconds
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
	_sprite.flip_h = distance_x < 0.0


func _update_sprite_pose(delta: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _run_motion_active and _sprite.animation == "run":
		_run_phase += maxf(0.0, delta) * 11.0
	var animation_scale := _attack_visual_scale if _sprite.animation == "attack" else 1.0
	var hit_strength := sin(
		clampf(_hit_reaction_remaining / HIT_REACTION_SECONDS, 0.0, 1.0) * PI
	)
	var pose_scale := Vector2(1.0 + hit_strength * 0.08, 1.0 - hit_strength * 0.06)
	_sprite.scale = Vector2.ONE * _visual_scale * animation_scale * pose_scale
	var base_position := _get_animation_alignment(String(_sprite.animation), animation_scale)
	if _sprite.animation == "attack" and _attack_duration_seconds > 0.0:
		var attack_progress := clampf(
			1.0 - _attack_animation_remaining / _attack_duration_seconds,
			0.0,
			1.0
		)
		var attack_direction := -1.0 if _sprite.flip_h else 1.0
		var attack_motion := sin(attack_progress * PI)
		base_position.x += attack_direction * attack_motion * (5.0 if is_ranged else 11.0)
	var run_bob := sin(_run_phase) * _run_bob_amount if _run_motion_active and _sprite.animation == "run" else 0.0
	_sprite.position = base_position + Vector2(_hit_reaction_direction * hit_strength * 4.0, run_bob)
	var run_rotation := sin(_run_phase * 0.5) * _run_tilt_amount if _run_motion_active and _sprite.animation == "run" else 0.0
	_sprite.rotation = run_rotation + _hit_reaction_direction * hit_strength * 0.025


func _get_animation_alignment(animation_name: String, animation_scale := 1.0) -> Vector2:
	var cache_key := "%s:%s" % [enemy_id, animation_name]
	if not _alignment_cache.has(cache_key):
		var alignment := Vector2(0.0, 60.0)
		if _sprite.sprite_frames.has_animation(animation_name) and _sprite.sprite_frames.get_frame_count(animation_name) > 0:
			var frame_texture := _sprite.sprite_frames.get_frame_texture(animation_name, 0)
			var bounds := _get_frame_visible_bounds(frame_texture)
			if bounds.size != Vector2i.ZERO:
				var half_size := Vector2(_get_frame_size(frame_texture)) * 0.5
				var visible_center_x := float(bounds.position.x) + float(bounds.size.x) * 0.5
				var visible_anchor_y := (
					float(bounds.position.y) + float(bounds.size.y) * 0.5
					if _flying
					else float(bounds.position.y + bounds.size.y - 1)
				)
				alignment = Vector2(visible_center_x - half_size.x, visible_anchor_y - half_size.y)
		_alignment_cache[cache_key] = alignment
	var local_alignment: Vector2 = _alignment_cache[cache_key]
	var effective_scale := _visual_scale * animation_scale
	return Vector2(
		-local_alignment.x * effective_scale,
		(0.0 if _flying else FOOT_TASKBAR_OVERLAP) - local_alignment.y * effective_scale
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


static func _get_frame_visible_bounds(texture: Texture2D) -> Rect2i:
	var cache_key := _get_frame_cache_key(texture)
	if _visible_bounds_cache.has(cache_key):
		var cached_bounds: Rect2i = _visible_bounds_cache[cache_key]
		return cached_bounds
	var bounds := Rect2i()
	var image := _get_atlas_frame_image(texture)
	if image != null and not image.is_empty():
		bounds = _get_visible_bounds(image)
	_visible_bounds_cache[cache_key] = bounds
	return bounds


static func _get_frame_cache_key(texture: Texture2D) -> String:
	if texture == null:
		return "<null>"
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		var atlas_key := "<null>"
		if atlas_texture.atlas != null:
			atlas_key = atlas_texture.atlas.resource_path
			if atlas_key.is_empty():
				atlas_key = "instance:%d" % atlas_texture.atlas.get_instance_id()
		var region := atlas_texture.region
		return "%s@%d,%d,%d,%d" % [
			atlas_key,
			roundi(region.position.x),
			roundi(region.position.y),
			roundi(region.size.x),
			roundi(region.size.y)
		]
	var texture_key := texture.resource_path
	if texture_key.is_empty():
		texture_key = "instance:%d" % texture.get_instance_id()
	return texture_key


static func _get_frame_size(texture: Texture2D) -> Vector2i:
	if texture == null:
		return Vector2i.ZERO
	if texture is AtlasTexture:
		var region := (texture as AtlasTexture).region
		return Vector2i(roundi(region.size.x), roundi(region.size.y))
	var texture_size := texture.get_size()
	return Vector2i(roundi(texture_size.x), roundi(texture_size.y))


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


func _update_boss_phase() -> void:
	if not _is_boss or _boss_phase >= 2 or health > max_health * 0.5:
		return
	_boss_phase = 2
	_move_speed *= 1.12
	_attack_cooldown_min *= 0.72
	_attack_cooldown_max *= 0.72
	_projectiles_per_attack += 2
	if _health_bar != null:
		var phase_tween := create_tween()
		phase_tween.tween_property(_health_bar, "modulate", Color(1.0, 0.42, 0.28), 0.08)
		phase_tween.tween_property(_health_bar, "modulate", Color.WHITE, 0.24)


func _update_swallowed(delta: float) -> void:
	if _swallower == null or not is_instance_valid(_swallower):
		_being_swallowed = false
		_swallower = null
		if _health_bar != null:
			_health_bar.visible = true
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


func _get_battlefield_width() -> float:
	if _battlefield_width > 0.0:
		return _battlefield_width
	return maxf(1.0, get_viewport_rect().size.x) if is_inside_tree() else 1920.0
