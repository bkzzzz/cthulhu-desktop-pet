extends Node2D

signal collected(actor: Node2D, coin_type: String, value: int)

const COIN_TEXTURES := {
	"R": "res://assets/ui/coins/MonedaR.png",
	"P": "res://assets/ui/coins/MonedaP.png",
	"D": "res://assets/ui/coins/MonedaD.png",
	"C": "res://assets/ui/coins/spr_coin_roj.png",
	"S": "res://assets/ui/coins/spr_coin_gri.png",
	"G": "res://assets/ui/coins/spr_coin_ama.png"
}
const COIN_VALUES := {
	"R": 1,
	"P": 5,
	"D": 50,
	"C": 100,
	"S": 250,
	"G": 500
}
const CRYSTAL_NAMES_ZH := {"C": "铜晶", "S": "银晶", "G": "金晶"}
const CRYSTAL_NAMES_EN := {"C": "COPPER CRYSTAL", "S": "SILVER CRYSTAL", "G": "GOLD CRYSTAL"}
const SHEET_FRAMES := 5
const CRYSTAL_SHEET_FRAMES := 4
const COIN_SCALE := 2.65
const GRAVITY := 980.0
const MAGNET_RADIUS := 150.0
const MAGNET_START_SPEED := 260.0
const MAGNET_ACCELERATION := 1150.0
const PICKUP_ARM_DELAY_SECONDS := 0.20
const COLLECT_DISTANCE := 15.0
const MAGNET_CHECK_INTERVAL_SECONDS := 0.14
const MAX_LIFETIME_SECONDS := 120.0
const EXPIRE_FADE_SECONDS := 0.24

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
var _magnet_check_time := 0.0
var _expiring := false
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
static var _frames_cache := {}


static func get_coin_value(type_id: String) -> int:
	return int(COIN_VALUES.get(type_id.to_upper(), 0))


static func get_coin_texture(type_id: String) -> String:
	return String(COIN_TEXTURES.get(type_id.to_upper(), ""))


static func get_sheet_frame_count(type_id: String) -> int:
	return CRYSTAL_SHEET_FRAMES if type_id.to_upper() in ["C", "S", "G"] else SHEET_FRAMES


static func get_drop_label(type_id: String, language_code := "zh") -> String:
	var safe_type := type_id.to_upper()
	if language_code == "en":
		return String(CRYSTAL_NAMES_EN.get(safe_type, safe_type))
	return String(CRYSTAL_NAMES_ZH.get(safe_type, safe_type))


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
	_magnet_check_time = _rng.randf_range(0.0, MAGNET_CHECK_INTERVAL_SECONDS)
	_velocity = Vector2(_rng.randf_range(-92.0, 92.0), _rng.randf_range(-245.0, -155.0))
	_create_sprite()


func set_window_bounds(window_size: Vector2i, ground_y: float) -> void:
	_window_size = window_size
	_ground_y = clampf(ground_y, 0.0, float(window_size.y))
	position.x = clampf(position.x, 18.0, maxf(18.0, float(window_size.x) - 18.0))
	if _settled:
		position.y = _get_rest_y()


func _process(delta: float) -> void:
	if _expiring:
		return
	var safe_delta := maxf(0.0, delta)
	_age += safe_delta
	if _age >= MAX_LIFETIME_SECONDS:
		expire()
		return

	if _settled:
		_settled_age += safe_delta

	if _magnetized:
		_update_magnet(_get_pointer_position(), safe_delta)
		return
	if _settled:
		_magnet_check_time -= safe_delta
		if _magnet_check_time <= 0.0:
			_magnet_check_time = MAGNET_CHECK_INTERVAL_SECONDS
			if _can_start_magnet(_get_pointer_position()):
				_magnetized = true
				_settled = false
				return

	_update_fall(safe_delta)


func expire() -> void:
	if _expiring or is_queued_for_deletion():
		return
	_expiring = true
	_magnetized = false
	set_process(false)
	if _sprite == null or not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), EXPIRE_FADE_SECONDS)
	tween.parallel().tween_property(_sprite, "scale", _sprite.scale * 0.72, EXPIRE_FADE_SECONDS)
	tween.tween_callback(queue_free)


func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Coin%sSprite" % coin_type
	_sprite.sprite_frames = _get_shared_frames(coin_type)
	_sprite.animation = "spin"
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * COIN_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play("spin")


static func _get_shared_frames(type_id: String) -> SpriteFrames:
	var safe_type := type_id.to_upper()
	var cached := _frames_cache.get(safe_type) as SpriteFrames
	if cached != null:
		return cached
	var frames := _build_frames(
		get_coin_texture(safe_type),
		get_sheet_frame_count(safe_type)
	)
	_frames_cache[safe_type] = frames
	return frames


static func _build_frames(texture_path: String, frame_count: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("spin")
	frames.set_animation_loop("spin", true)
	frames.set_animation_speed("spin", 10.0)
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return frames
	var safe_frame_count := maxi(1, frame_count)
	var frame_width := float(texture.get_width()) / float(safe_frame_count)
	for frame_index in safe_frame_count:
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
