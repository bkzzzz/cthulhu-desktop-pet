extends Node2D

signal exited(actor: Node2D)

const IDLE_TEXTURE := "res://assets/characters/believersAnimation/believerIdle1.png"
const WALK_TEXTURE := "res://assets/characters/believersAnimation/believerWalk1.png"
const RUN_TEXTURE := "res://assets/characters/believersAnimation/believerRun1.png"
const NOTICE_TEXTURE := "res://assets/characters/believers/感叹号.png"

const SHEET_COLUMNS := 4
const SHEET_ROWS := 3
const SHEET_FRAME_CENTER_Y := 64.0
const SHEET_FRAME_FOOT_Y := 102
const CHROMA_KEY_TOLERANCE := 0.075

const BELIEVER_SCALE := 1.54
const NOTICE_SCALE := 0.17
const WALK_SPEED := 62.0
const RUN_SPEED := 188.0
const OFFSCREEN_PADDING := 78.0
const CENTER_ZONE_HALF_WIDTH := 86.0
const CENTER_WANDER_STEP := 56.0
const ARRIVE_DISTANCE := 4.0
const SCARE_DISTANCE := 116.0
const SCARE_GRACE_SECONDS := 3.0
const IDLE_ANIMATION_SPEED := 3.0
const NATURAL_LEAVE_MIN_SECONDS := 26.0
const NATURAL_LEAVE_MAX_SECONDS := 52.0

enum BelieverState {
	WALK_IN,
	IDLE,
	CENTER_WALK,
	WALK_OUT,
	RUN_AWAY
}

var _window_size := Vector2i(820, 420)
var _state := BelieverState.WALK_IN
var _target_x := 0.0
var _idle_time := 0.0
var _natural_leave_time := 0.0
var _scare_grace_time := 0.0
var _run_target_x := 0.0
var _threat_positions: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _notice: Sprite2D
var _notice_tween: Tween
static var _cached_frames: SpriteFrames


func setup(window_size: Vector2i, spawn_from_left: bool) -> void:
	_rng.randomize()
	_window_size = window_size
	z_index = 70
	_create_sprite()
	_create_notice()
	_schedule_natural_leave()

	var start_x := -OFFSCREEN_PADDING if spawn_from_left else float(_window_size.x) + OFFSCREEN_PADDING
	position = Vector2(start_x, _get_rest_y())
	_target_x = _get_center_target_x()
	_state = BelieverState.WALK_IN
	_face_target(_target_x)
	_sprite.play("walk")


func setup_visible(window_size: Vector2i) -> void:
	_rng.randomize()
	_window_size = window_size
	z_index = 70
	_create_sprite()
	_create_notice()
	_schedule_natural_leave()

	position = Vector2(lerpf(_get_center_min_x(), _get_center_max_x(), 0.18), _get_rest_y())
	_state = BelieverState.IDLE
	_sprite.flip_h = _rng.randf() < 0.5
	_start_idle(0.0)


func _process(delta: float) -> void:
	position.y = _get_rest_y()

	match _state:
		BelieverState.WALK_IN:
			_update_walk_in(delta)
		BelieverState.IDLE:
			_update_idle(delta)
		BelieverState.CENTER_WALK:
			_update_center_walk(delta)
		BelieverState.WALK_OUT:
			_update_walk_out(delta)
		BelieverState.RUN_AWAY:
			_update_run_away(delta)


func set_threat_positions(threat_positions: Array) -> void:
	_threat_positions.clear()
	for threat_position_value in threat_positions:
		if threat_position_value is Vector2:
			_threat_positions.append(threat_position_value)
	if _state != BelieverState.WALK_IN:
		_try_start_run_away(false)


func set_window_size(window_size: Vector2i) -> void:
	_window_size = window_size
	if _state == BelieverState.IDLE or _state == BelieverState.CENTER_WALK:
		position.x = clampf(position.x, _get_center_min_x(), _get_center_max_x())


func get_draw_rect() -> Rect2:
	var visual_size := Vector2(92.0, 132.0) * BELIEVER_SCALE
	return Rect2(position - Vector2(visual_size.x * 0.5, visual_size.y - 16.0), visual_size)


func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "BelieverSprite"
	_sprite.sprite_frames = _build_frames()
	_sprite.animation = "idle"
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * BELIEVER_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _create_notice() -> void:
	_notice = Sprite2D.new()
	_notice.name = "BelieverNotice"
	_notice.texture = load(NOTICE_TEXTURE) as Texture2D
	_notice.centered = true
	_notice.scale = Vector2.ONE * NOTICE_SCALE
	_notice.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_notice.position = Vector2(2.0, -112.0)
	_notice.visible = false
	_notice.z_index = 90
	add_child(_notice)


func _update_walk_in(delta: float) -> void:
	_move_toward_x(_target_x, WALK_SPEED, delta)
	if absf(position.x - _target_x) <= ARRIVE_DISTANCE:
		position.x = _target_x
		_start_idle()


func _update_idle(delta: float) -> void:
	_idle_time -= delta
	_scare_grace_time = maxf(0.0, _scare_grace_time - delta)

	if _try_start_run_away(false):
		return

	if _try_start_natural_leave(delta):
		return

	if _idle_time <= 0.0:
		_choose_center_walk_target()


func _update_center_walk(delta: float) -> void:
	if _try_start_run_away(false):
		return

	if _try_start_natural_leave(delta):
		return

	_move_toward_x(_target_x, WALK_SPEED, delta)
	if absf(position.x - _target_x) <= ARRIVE_DISTANCE:
		position.x = _target_x
		_start_idle()


func _update_walk_out(delta: float) -> void:
	_move_toward_x(_run_target_x, WALK_SPEED, delta)
	if position.x < -OFFSCREEN_PADDING or position.x > float(_window_size.x) + OFFSCREEN_PADDING:
		exited.emit(self)
		queue_free()


func _update_run_away(delta: float) -> void:
	_move_toward_x(_run_target_x, RUN_SPEED, delta)
	if position.x < -OFFSCREEN_PADDING or position.x > float(_window_size.x) + OFFSCREEN_PADDING:
		exited.emit(self)
		queue_free()


func _start_idle(grace_time := SCARE_GRACE_SECONDS) -> void:
	_state = BelieverState.IDLE
	_idle_time = _rng.randf_range(1.2, 3.2)
	_scare_grace_time = grace_time
	_sprite.play("idle")


func _schedule_natural_leave() -> void:
	_natural_leave_time = _rng.randf_range(NATURAL_LEAVE_MIN_SECONDS, NATURAL_LEAVE_MAX_SECONDS)


func _try_start_natural_leave(delta: float) -> bool:
	_natural_leave_time -= delta
	if _natural_leave_time > 0.0:
		return false

	_start_walk_out()
	return true


func _start_walk_out() -> void:
	_state = BelieverState.WALK_OUT
	var go_left := position.x <= float(_window_size.x) * 0.5
	_run_target_x = -OFFSCREEN_PADDING if go_left else float(_window_size.x) + OFFSCREEN_PADDING
	_face_target(_run_target_x)
	_sprite.play("walk")


func _choose_center_walk_target() -> void:
	var next_x := position.x + _rng.randf_range(-CENTER_WANDER_STEP, CENTER_WANDER_STEP)
	_target_x = clampf(next_x, _get_center_min_x(), _get_center_max_x())
	if absf(_target_x - position.x) <= 8.0:
		_start_idle()
		return

	_state = BelieverState.CENTER_WALK
	_face_target(_target_x)
	_sprite.play("walk")


func _start_run_away(threat_position: Vector2) -> void:
	_state = BelieverState.RUN_AWAY
	var run_left := threat_position.x <= position.x
	_run_target_x = float(_window_size.x) + OFFSCREEN_PADDING if run_left else -OFFSCREEN_PADDING
	_face_target(_run_target_x)
	_sprite.play("run")
	_show_notice()


func _try_start_run_away(ignore_grace: bool) -> bool:
	if _state == BelieverState.RUN_AWAY:
		return false
	if not ignore_grace and _scare_grace_time > 0.0:
		return false

	var threat_position := _get_close_threat_position()
	if not _is_valid_threat_position(threat_position):
		return false

	_start_run_away(threat_position)
	return true


func _move_toward_x(target_x: float, speed: float, delta: float) -> void:
	_face_target(target_x)
	position.x = move_toward(position.x, target_x, speed * delta)


func _face_target(target_x: float) -> void:
	if _sprite != null:
		var direction_x := target_x - position.x
		if absf(direction_x) > 0.1:
			_sprite.flip_h = direction_x > 0.0


func _get_center_target_x() -> float:
	return _rng.randf_range(_get_center_min_x(), _get_center_max_x())


func _get_center_min_x() -> float:
	return CENTER_ZONE_HALF_WIDTH


func _get_center_max_x() -> float:
	return maxf(_get_center_min_x() + 1.0, float(_window_size.x) - CENTER_ZONE_HALF_WIDTH)


func _get_close_threat_position() -> Vector2:
	var closest_distance := 999999.0
	var closest_position := Vector2(999999.0, 999999.0)
	for threat_position in _threat_positions:
		var distance := position.distance_to(threat_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_position = threat_position

	if closest_distance <= SCARE_DISTANCE:
		return closest_position

	return Vector2(999999.0, 999999.0)


func _is_valid_threat_position(threat_position: Vector2) -> bool:
	return threat_position.x < 999998.0


func _show_notice() -> void:
	if _notice == null or _notice.texture == null:
		return

	if _notice_tween != null and is_instance_valid(_notice_tween):
		_notice_tween.kill()

	_notice.visible = true
	_notice.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_notice.scale = Vector2.ONE * NOTICE_SCALE * 0.45

	_notice_tween = create_tween()
	_notice_tween.set_trans(Tween.TRANS_BACK)
	_notice_tween.set_ease(Tween.EASE_OUT)
	_notice_tween.tween_property(_notice, "scale", Vector2.ONE * NOTICE_SCALE, 0.12)
	_notice_tween.tween_interval(0.44)
	_notice_tween.tween_property(_notice, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.22)
	_notice_tween.tween_callback(Callable(self, "_hide_notice"))


func _hide_notice() -> void:
	if _notice != null:
		_notice.visible = false


func _get_rest_y() -> float:
	return float(_window_size.y - 1) - ((float(SHEET_FRAME_FOOT_Y) - SHEET_FRAME_CENTER_Y) * BELIEVER_SCALE)


static func _build_frames() -> SpriteFrames:
	if _cached_frames != null:
		return _cached_frames

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	_add_sheet_animation(frames, "idle", IDLE_TEXTURE, IDLE_ANIMATION_SPEED)
	_add_sheet_animation(frames, "walk", WALK_TEXTURE, 8.0)
	_add_sheet_animation(frames, "run", RUN_TEXTURE, 11.0)
	_cached_frames = frames
	return _cached_frames


static func _add_sheet_animation(frames: SpriteFrames, animation_name: String, sheet_path: String, speed: float) -> void:
	var sheet_texture := load(sheet_path) as Texture2D
	if sheet_texture == null:
		return

	var source_image := sheet_texture.get_image()
	if source_image == null or source_image.is_empty():
		return

	source_image.convert(Image.FORMAT_RGBA8)
	var frame_size := Vector2i(
		int(source_image.get_width() / float(SHEET_COLUMNS)),
		int(source_image.get_height() / float(SHEET_ROWS))
	)
	var key_color := source_image.get_pixel(0, 0)

	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, speed)

	for row in SHEET_ROWS:
		for column in SHEET_COLUMNS:
			var frame_image := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			var source_rect := Rect2i(Vector2i(column * frame_size.x, row * frame_size.y), frame_size)
			frame_image.blit_rect(source_image, source_rect, Vector2i.ZERO)
			_apply_chroma_key(frame_image, key_color)
			frame_image = _align_frame_to_floor(frame_image)
			frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))


static func _apply_chroma_key(image: Image, key_color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if _color_distance(color, key_color) <= CHROMA_KEY_TOLERANCE:
				color.a = 0.0
				image.set_pixel(x, y, color)


static func _align_frame_to_floor(image: Image) -> Image:
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO:
		return image

	var visible_bottom := bounds.position.y + bounds.size.y - 1
	var offset_y := SHEET_FRAME_FOOT_Y - visible_bottom
	if offset_y == 0:
		return image

	var aligned := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	aligned.fill(Color(0.0, 0.0, 0.0, 0.0))
	aligned.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, offset_y))
	return aligned


static func _get_visible_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
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
