extends Node2D

signal projectile_impacted(actor: Node2D, target: Node2D)

const PROJECTILE_ROOT := "res://assets/effects/GandalfHardcore Projectiles and effects/"
const PROJECTILE_CONFIG := {
	"pet2": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles1.png", "row": 1, "scale": 0.72},
	"pet7": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles2.png", "row": 4, "scale": 0.62},
	"pet8": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles4.png", "row": 2, "scale": 0.72},
	"pet9": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles3.png", "row": 3, "scale": 0.68},
	"pet10": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles5.png", "row": 5, "scale": 0.58},
	"pet11": {"sheet": PROJECTILE_ROOT + "GandalfHardcore 64x64 Projectiles5c.png", "row": 6, "scale": 0.62}
}
const EXPLOSION_CONFIG := [
	{"sheet": "res://assets/effects/explosion/Medium Blast/spritesheet.png", "frames": 10, "frame_size": Vector2(48.0, 48.0), "fps": 18.0, "scale": 1.0},
	{"sheet": "res://assets/effects/explosion/Bomb Explosion/Spritesheet.png", "frames": 10, "frame_size": Vector2(64.0, 64.0), "fps": 17.0, "scale": 1.05},
	{"sheet": "res://assets/effects/explosion/electric explosion/spritesheet.png", "frames": 12, "frame_size": Vector2(116.0, 85.0), "fps": 20.0, "scale": 0.82},
	{"sheet": "res://assets/effects/explosion/Big Explosion/big_explosion-sheet.png", "frames": 11, "frame_size": Vector2(208.0, 164.0), "fps": 16.0, "scale": 0.72}
]

static var _projectile_frame_cache := {}
static var _explosion_frame_cache := {}

var _mode := ""
var _target: Node2D
var _projectile_speed := 760.0
var _sprite: AnimatedSprite2D


func setup_projectile(pet_id: String, start_position: Vector2, target: Node2D, visual_power: float) -> void:
	_mode = "projectile"
	_target = target
	position = start_position
	z_index = 235
	var config: Dictionary = PROJECTILE_CONFIG.get(pet_id, PROJECTILE_CONFIG["pet2"])
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ProjectileSprite"
	_sprite.sprite_frames = _get_projectile_frames(pet_id, config)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var power_scale := clampf(0.88 + visual_power * 0.035, 0.9, 1.28)
	_sprite.scale = Vector2.ONE * float(config.get("scale", 0.7)) * power_scale
	add_child(_sprite)
	_sprite.play("fly")
	_projectile_speed = clampf(680.0 + visual_power * 24.0, 680.0, 980.0)
	_face_travel_direction()


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
	var level_scale := clampf(0.9 + visual_power * 0.035, 0.95, 1.3)
	_sprite.scale = Vector2.ONE * float(config.get("scale", 1.0)) * level_scale
	_sprite.animation_finished.connect(queue_free)
	add_child(_sprite)
	_sprite.play("burst")


func _process(delta: float) -> void:
	if _mode != "projectile":
		return
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var target_position := _get_target_hit_position()
	var distance := position.distance_to(target_position)
	var step := _projectile_speed * maxf(0.0, delta)
	if distance <= maxf(8.0, step):
		position = target_position
		projectile_impacted.emit(self, _target)
		queue_free()
		return
	position = position.move_toward(target_position, step)
	_face_travel_direction()


func _get_target_hit_position() -> Vector2:
	if _target != null and is_instance_valid(_target) and _target.has_method("get_battle_hit_position"):
		return _target.call("get_battle_hit_position")
	return _target.position + Vector2(0.0, -54.0)


func _face_travel_direction() -> void:
	if _sprite == null or _target == null or not is_instance_valid(_target):
		return
	var direction := _get_target_hit_position() - position
	if direction.length_squared() > 0.001:
		rotation = direction.angle()


static func _get_projectile_frames(pet_id: String, config: Dictionary) -> SpriteFrames:
	if _projectile_frame_cache.has(pet_id):
		return _projectile_frame_cache[pet_id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_loop("fly", true)
	frames.set_animation_speed("fly", 14.0)
	var texture := load(String(config.get("sheet", ""))) as Texture2D
	if texture != null:
		var frame_size := Vector2(64.0, 64.0)
		var max_row := maxi(0, int(texture.get_height() / 64.0) - 1)
		var row := clampi(int(config.get("row", 0)), 0, max_row)
		for column in 5:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(float(column) * 64.0, float(row) * 64.0), frame_size)
			frames.add_frame("fly", atlas)
	_projectile_frame_cache[pet_id] = frames
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
