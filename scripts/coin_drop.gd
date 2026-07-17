extends Node2D

signal collected(actor: Node2D, coin_type: String, value: int)

const COIN_TEXTURES := {
	"R": "res://assets/ui/coins/MonedaR.png",
	"P": "res://assets/ui/coins/MonedaP.png",
	"D": "res://assets/ui/coins/MonedaD.png"
}
const COIN_VALUES := {
	"R": 1,
	"P": 5,
	"D": 50
}
const SHEET_FRAMES := 5
const COIN_SCALE := 2.65
const GRAVITY := 980.0
const MAGNET_RADIUS := 150.0
const MAGNET_START_SPEED := 260.0
const MAGNET_ACCELERATION := 1150.0
const PICKUP_ARM_DELAY_SECONDS := 0.20
const COLLECT_DISTANCE := 15.0
const MAX_LIFETIME_SECONDS := 180.0

var coin_type := "R"
var value := 1
var _window_size := Vector2i(820, 420)
var _ground_y := 420.0
var _velocity := Vector2.ZERO
var _magnet_speed := MAGNET_START_SPEED
var _magnetized := false
var _settled := false
var _settled_age := 0.0
var _age := 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D


static func get_coin_value(type_id: String) -> int:
	return int(COIN_VALUES.get(type_id.to_upper(), 0))


static func get_coin_texture(type_id: String) -> String:
	return String(COIN_TEXTURES.get(type_id.to_upper(), ""))


func setup(type_id: String, start_position: Vector2, window_size: Vector2i, ground_y: float) -> void:
	coin_type = type_id.to_upper()
	if not COIN_TEXTURES.has(coin_type):
		coin_type = "R"
	value = get_coin_value(coin_type)
	_window_size = window_size
	_ground_y = clampf(ground_y, 0.0, float(window_size.y))
	position = start_position
	z_index = 210
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id()) ^ coin_type.hash()
	_velocity = Vector2(_rng.randf_range(-92.0, 92.0), _rng.randf_range(-245.0, -155.0))
	_create_sprite()


func set_window_bounds(window_size: Vector2i, ground_y: float) -> void:
	_window_size = window_size
	_ground_y = clampf(ground_y, 0.0, float(window_size.y))
	position.x = clampf(position.x, 18.0, maxf(18.0, float(window_size.x) - 18.0))
	if _settled:
		position.y = _get_rest_y()


func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_age += safe_delta
	if _age >= MAX_LIFETIME_SECONDS:
		queue_free()
		return

	if _settled:
		_settled_age += safe_delta
	var pointer := _get_pointer_position()
	if not _magnetized and _can_start_magnet(pointer):
		_magnetized = true
		_settled = false

	if _magnetized:
		_update_magnet(pointer, safe_delta)
		return

	_update_fall(safe_delta)


func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Coin%sSprite" % coin_type
	_sprite.sprite_frames = _build_frames(get_coin_texture(coin_type))
	_sprite.animation = "spin"
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * COIN_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play("spin")


func _build_frames(texture_path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("spin")
	frames.set_animation_loop("spin", true)
	frames.set_animation_speed("spin", 10.0)
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return frames
	var frame_width := float(texture.get_width()) / float(SHEET_FRAMES)
	for frame_index in SHEET_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(texture.get_height()))
		frames.add_frame("spin", atlas)
	return frames


func _update_fall(delta: float) -> void:
	if _settled:
		position.y = _get_rest_y()
		return
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	position.x = clampf(position.x, 18.0, maxf(18.0, float(_window_size.x) - 18.0))
	var rest_y := _get_rest_y()
	if position.y < rest_y:
		return
	position.y = rest_y
	if absf(_velocity.y) > 105.0:
		_velocity.y *= -0.28
		_velocity.x *= 0.68
		return
	_velocity = Vector2.ZERO
	_settled = true
	_settled_age = 0.0


func _can_start_magnet(pointer: Vector2) -> bool:
	return (
		_settled
		and _settled_age >= PICKUP_ARM_DELAY_SECONDS
		and position.distance_to(pointer) <= MAGNET_RADIUS
	)


func _update_magnet(pointer: Vector2, delta: float) -> void:
	var distance := position.distance_to(pointer)
	if distance <= COLLECT_DISTANCE:
		collected.emit(self, coin_type, value)
		queue_free()
		return
	_magnet_speed += MAGNET_ACCELERATION * delta
	position = position.move_toward(pointer, _magnet_speed * delta)
	var target_scale := maxf(0.55, distance / MAGNET_RADIUS) * COIN_SCALE
	if _sprite != null:
		_sprite.scale = _sprite.scale.lerp(Vector2.ONE * target_scale, minf(1.0, delta * 12.0))


func _get_rest_y() -> float:
	return _ground_y - (8.0 * COIN_SCALE) - 2.0


func _get_pointer_position() -> Vector2:
	var window := get_window()
	if window == null:
		return get_viewport().get_mouse_position()
	return Vector2(DisplayServer.mouse_get_position() - window.position)
