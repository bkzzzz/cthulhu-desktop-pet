extends Node2D

signal projectile_impacted(actor: Node2D, target: Node2D)

const PROJECTILE_ROOT := "res://assets/effects/GandalfHardcore Projectiles and effects/"
const SUPER_PIXEL_PROJECTILE_ROOT := "res://assets/effects/Super Pixel Projectiles Pack 2/Super Pixel Projectiles Pack 2/spritesheet/"
const PROJECTILE_CONFIG := {
	"pet2": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles1.png", "row": 1, "scale": 0.72},
	"pet7": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles2.png", "row": 4, "scale": 0.62},
	"pet8": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles4.png", "row": 2, "scale": 0.72},
	"pet9": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles3.png", "row": 3, "scale": 0.68},
	"pet10": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles5.png", "row": 5, "scale": 0.58},
	"pet2_evolved": {
		"sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_magic_missile_large_violet/spritesheet.png",
		"frame_size": Vector2(48.0, 32.0), "frames": 8, "fps": 15.0, "scale": 0.94, "speed": 850.0
	},
	"pet7_evolved": {
		"sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_shuriken_large_yellow/spritesheet.png",
		"frame_size": Vector2(32.0, 32.0), "frames": 8, "fps": 15.0, "scale": 0.98, "speed": 880.0
	},
	"pet8_evolved": {
		"sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_helix_beam_large_blue/spritesheet.png",
		"frame_size": Vector2(64.0, 32.0), "frames": 30, "fps": 15.0, "scale": 0.78, "speed": 860.0
	},
	"pet9_evolved": {
		"sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_lightning_orb_large_violet/spritesheet.png",
		"frame_size": Vector2(64.0, 48.0), "frames": 8, "fps": 15.0, "scale": 0.84, "speed": 830.0
	},
	"pet10_evolved": {
		"sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_meteor_large_violet/spritesheet.png",
		"frame_size": Vector2(96.0, 64.0),
		"frames": 8,
		"fps": 15.0,
		"scale": 0.66,
		"speed": 900.0,
		"launch_sheet": SUPER_PIXEL_PROJECTILE_ROOT + "pj2_ground_shockwave_large_violet/spritesheet.png",
		"launch_frame_size": Vector2(128.0, 64.0),
		"launch_frames": 5,
		"launch_fps": 15.0,
		"launch_scale": 0.64
	}
}
const EXPLOSION_CONFIG := [
	{"sheet": "res://assets/effects/explosion/Medium Blast/spritesheet.png", "frames": 10, "frame_size": Vector2(48.0, 48.0), "fps": 18.0, "scale": 1.0},
	{"sheet": "res://assets/effects/explosion/Bomb Explosion/Spritesheet.png", "frames": 10, "frame_size": Vector2(64.0, 64.0), "fps": 17.0, "scale": 1.05},
	{"sheet": "res://assets/effects/explosion/electric explosion/spritesheet.png", "frames": 12, "frame_size": Vector2(116.0, 85.0), "fps": 20.0, "scale": 0.82},
	{"sheet": "res://assets/effects/explosion/Big Explosion/big_explosion-sheet.png", "frames": 11, "frame_size": Vector2(208.0, 164.0), "fps": 16.0, "scale": 0.72}
]
const ORPHAN_COAST_SECONDS := 1.35
const ORPHAN_VIEWPORT_MARGIN := 180.0

static var _projectile_frame_cache := {}
static var _launch_frame_cache := {}
static var _explosion_frame_cache := {}


static func warm_up(pet_ids: Array) -> void:
	for pet_id_value in pet_ids:
		var pet_id := String(pet_id_value)
		if PROJECTILE_CONFIG.has(pet_id):
			_get_projectile_frames(pet_id, PROJECTILE_CONFIG[pet_id])
		var evolved_key := "%s_evolved" % pet_id
		if PROJECTILE_CONFIG.has(evolved_key):
			var evolved_config: Dictionary = PROJECTILE_CONFIG[evolved_key]
			_get_projectile_frames(evolved_key, evolved_config)
			if evolved_config.has("launch_sheet"):
				_get_launch_frames(evolved_key, evolved_config)
	for tier in EXPLOSION_CONFIG.size():
		_get_explosion_frames(tier, EXPLOSION_CONFIG[tier])

var _mode := ""
var _target: Node2D
var _projectile_speed := 760.0
var _sprite: AnimatedSprite2D
var _last_target_position := Vector2.ZERO
var _travel_direction := Vector2.RIGHT
var _coasting := false
var _coast_elapsed := 0.0


func setup_projectile(
	pet_id: String,
	start_position: Vector2,
	target: Node2D,
	visual_power: float,
	evolved := false
) -> void:
	_mode = "projectile"
	_target = target
	position = start_position
	_last_target_position = _get_target_hit_position()
	var initial_direction := _last_target_position - position
	if initial_direction.length_squared() > 0.001:
		_travel_direction = initial_direction.normalized()
	z_index = 235
	var effect_key := "%s_evolved" % pet_id if evolved else pet_id
	var config: Dictionary = PROJECTILE_CONFIG.get(effect_key, PROJECTILE_CONFIG.get(pet_id, PROJECTILE_CONFIG["pet2"]))
	if not PROJECTILE_CONFIG.has(effect_key):
		effect_key = pet_id if PROJECTILE_CONFIG.has(pet_id) else "pet2"
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ProjectileSprite"
	_sprite.sprite_frames = _get_projectile_frames(effect_key, config)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var power_scale := clampf(0.88 + visual_power * 0.035, 0.9, 1.28)
	_sprite.scale = Vector2.ONE * float(config.get("scale", 0.7)) * power_scale
	add_child(_sprite)
	_sprite.play("fly")
	var base_speed := float(config.get("speed", 680.0))
	_projectile_speed = clampf(base_speed + visual_power * 24.0, base_speed, 1_050.0)
	_face_travel_direction()
	if config.has("launch_sheet"):
		call_deferred("_spawn_launch_rift", effect_key, config, start_position, _travel_direction)


func setup_explosion(world_position: Vector2, visual_power: float) -> void:
	_mode = "explosion"
	position = world_position
	z_index = 250
	var tier := clampi(int(floor((visual_power - 1.5) / 1.45)), 0, EXPLOSION_CONFIG.size() - 1)
	var config: Dictionary = EXPLOSION_CONFIG[tier]
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ExplosionSprite"
	_sprite.sprite_frames = _get_explosion_frames(tier, config)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var level_scale := clampf(0.72 + pow(maxf(1.0, visual_power), 0.72) * 0.18, 0.90, 1.85)
	_sprite.scale = Vector2.ONE * float(config.get("scale", 1.0)) * level_scale
	_sprite.animation_finished.connect(queue_free)
	add_child(_sprite)
	_sprite.play("burst")


func _process(delta: float) -> void:
	if _mode != "projectile":
		return
	var safe_delta := maxf(0.0, delta)
	if not _is_target_available():
		_begin_coasting()
		_update_coasting(safe_delta)
		return
	var target_position := _get_target_hit_position()
	_last_target_position = target_position
	var distance := position.distance_to(target_position)
	var step := _projectile_speed * safe_delta
	if distance <= maxf(8.0, step):
		position = target_position
		projectile_impacted.emit(self, _target)
		queue_free()
		return
	var previous_position := position
	position = position.move_toward(target_position, step)
	var travel := position - previous_position
	if travel.length_squared() > 0.001:
		_travel_direction = travel.normalized()
	_face_travel_direction()


func _get_target_hit_position() -> Vector2:
	if _target != null and is_instance_valid(_target) and _target.has_method("get_battle_hit_position"):
		return _target.call("get_battle_hit_position")
	if _target != null and is_instance_valid(_target):
		return _target.position + Vector2(0.0, -54.0)
	return _last_target_position


func _face_travel_direction() -> void:
	if _sprite == null:
		return
	var direction := _travel_direction if _coasting else _get_target_hit_position() - position
	if direction.length_squared() > 0.001:
		rotation = direction.angle()


func get_travel_direction() -> Vector2:
	return _travel_direction


func _is_target_available() -> bool:
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return false
	if _target.has_method("is_defeated") and bool(_target.call("is_defeated")):
		return false
	return true


func _begin_coasting() -> void:
	if _coasting:
		return
	_coasting = true
	_coast_elapsed = 0.0
	var remaining_direction := _last_target_position - position
	if remaining_direction.length_squared() > 0.001:
		_travel_direction = remaining_direction.normalized()
	if _travel_direction.length_squared() <= 0.001:
		_travel_direction = Vector2.RIGHT
	_target = null
	_face_travel_direction()


func _update_coasting(delta: float) -> void:
	_coast_elapsed += delta
	position += _travel_direction * _projectile_speed * delta
	if _coast_elapsed >= ORPHAN_COAST_SECONDS or _is_outside_padded_viewport():
		queue_free()


func _is_outside_padded_viewport() -> bool:
	if not is_inside_tree():
		return false
	var bounds := get_viewport_rect().grow(ORPHAN_VIEWPORT_MARGIN)
	return not bounds.has_point(position)


static func _get_projectile_frames(effect_key: String, config: Dictionary) -> SpriteFrames:
	if _projectile_frame_cache.has(effect_key):
		return _projectile_frame_cache[effect_key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_loop("fly", true)
	frames.set_animation_speed("fly", float(config.get("fps", 14.0)))
	var texture := load(String(config.get("sheet", ""))) as Texture2D
	if texture != null:
		var frame_size: Vector2 = config.get("frame_size", Vector2(64.0, 64.0))
		var max_row := maxi(0, int(texture.get_height() / frame_size.y) - 1)
		var row := clampi(int(config.get("row", 0)), 0, max_row)
		for column in int(config.get("frames", 5)):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(float(column) * frame_size.x, float(row) * frame_size.y), frame_size)
			frames.add_frame("fly", atlas)
	_projectile_frame_cache[effect_key] = frames
	return frames


func _spawn_launch_rift(
	effect_key: String,
	config: Dictionary,
	launch_position: Vector2,
	launch_direction: Vector2
) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var rift := AnimatedSprite2D.new()
	rift.name = "MeteorLaunchRift"
	rift.set_meta("battle_runtime", true)
	rift.sprite_frames = _get_launch_frames(effect_key, config)
	rift.centered = true
	rift.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rift.position = launch_position
	rift.z_index = 232
	rift.scale = Vector2.ONE * float(config.get("launch_scale", 0.64))
	if launch_direction.x < 0.0:
		rift.flip_h = true
	rift.animation_finished.connect(Callable(rift, "queue_free"))
	parent.add_child(rift)
	rift.play("burst")


static func _get_launch_frames(effect_key: String, config: Dictionary) -> SpriteFrames:
	var cache_key := "%s_launch" % effect_key
	if _launch_frame_cache.has(cache_key):
		return _launch_frame_cache[cache_key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("burst")
	frames.set_animation_loop("burst", false)
	frames.set_animation_speed("burst", float(config.get("launch_fps", 15.0)))
	var texture := load(String(config.get("launch_sheet", ""))) as Texture2D
	var frame_size: Vector2 = config.get("launch_frame_size", Vector2(64.0, 64.0))
	if texture != null:
		for frame_index in int(config.get("launch_frames", 1)):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(frame_size.x * float(frame_index), 0.0), frame_size)
			frames.add_frame("burst", atlas)
	_launch_frame_cache[cache_key] = frames
	return frames


static func _get_explosion_frames(tier: int, config: Dictionary) -> SpriteFrames:
	if _explosion_frame_cache.has(tier):
		return _explosion_frame_cache[tier]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("burst")
	frames.set_animation_loop("burst", false)
	frames.set_animation_speed("burst", float(config.get("fps", 18.0)))
	var texture := load(String(config.get("sheet", ""))) as Texture2D
	var frame_size: Vector2 = config.get("frame_size", Vector2(48.0, 48.0))
	if texture != null:
		for frame_index in int(config.get("frames", 1)):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(frame_size.x * float(frame_index), 0.0), frame_size)
			frames.add_frame("burst", atlas)
	_explosion_frame_cache[tier] = frames
	return frames
