class_name DrawerSymbolFlow
extends Control

## Batched decorative symbol flow for the side drawer. The owner supplies a
## fixed-rate tick through advance(); this node never enables its own process
## callback and replaces one CanvasItem/Control per symbol with one draw pass.

const BASE_SYMBOL_SIZE := Vector2(28.0, 40.0)
const HORIZONTAL_MARGIN := 28.0
const SCALE_MIN := 0.9
const SCALE_MAX := 1.65
const SPEED_MIN := 18.0
const SPEED_MAX := 42.0
const DRIFT_MIN := 4.0
const DRIFT_MAX := 18.0
const WAVE_SPEED_MIN := 0.35
const WAVE_SPEED_MAX := 0.9
const ALPHA_MIN := 0.14
const ALPHA_MAX := 0.28
const ROTATION_MIN := -0.12
const ROTATION_MAX := 0.12
const RESPAWN_GAP_MIN := 4.0
const RESPAWN_GAP_MAX := 90.0
const SYMBOL_TINT := Color(0.78, 1.0, 0.72, 1.0)

var _rng := RandomNumberGenerator.new()
var _textures: Array[Texture2D] = []
var _symbol_count := 0
var _layout_size := Vector2.ZERO
var _layout_ready := false

var _texture_indices := PackedInt32Array()
var _base_x := PackedFloat32Array()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _scales := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _drifts := PackedFloat32Array()
var _wave_speeds := PackedFloat32Array()
var _phases := PackedFloat32Array()
var _alphas := PackedFloat32Array()
var _rotations := PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)


## Loads valid Texture2D resources from texture_paths and creates symbol state.
## A non-zero rng_seed makes the layout deterministic; zero randomizes it.
func setup(texture_paths: Array, symbol_count: int, rng_seed: int = 0) -> void:
	set_process(false)
	_textures.clear()
	for texture_path_value in texture_paths:
		var texture: Texture2D
		if texture_path_value is Texture2D:
			texture = texture_path_value as Texture2D
		else:
			var texture_path := String(texture_path_value).strip_edges()
			if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
				continue
			texture = load(texture_path) as Texture2D
		if texture != null:
			_textures.append(texture)

	_symbol_count = maxi(0, symbol_count)
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_resize_state_arrays()
	_reset_layout_internal(true)


## Advances every symbol once. Call this from the owner at its desired visual
## cadence (the side drawer currently uses 30 Hz).
func advance(delta: float) -> void:
	var current_size := _get_safe_layout_size()
	if not current_size.is_equal_approx(_layout_size):
		_reset_layout_internal(false)
	if not _layout_ready or _textures.is_empty() or _symbol_count <= 0:
		queue_redraw()
		return

	var safe_delta := maxf(0.0, delta)
	for index in _symbol_count:
		_phases[index] += safe_delta * _wave_speeds[index]
		_y[index] += safe_delta * _speeds[index]
		_x[index] = _base_x[index] + sin(_phases[index]) * _drifts[index]
		var symbol_height := BASE_SYMBOL_SIZE.y * _scales[index]
		if _y[index] > _layout_size.y + symbol_height:
			_reset_symbol(index, false)
	queue_redraw()


## Re-scatters all symbols for the Control's current size. This is useful when
## the owner changes layout explicitly; advance() also detects size changes.
func reset_layout() -> void:
	_reset_layout_internal(true)


func _draw() -> void:
	if not _layout_ready or _textures.is_empty() or _symbol_count <= 0:
		return
	for index in _symbol_count:
		var texture_index := _texture_indices[index]
		if texture_index < 0 or texture_index >= _textures.size():
			continue
		var texture := _textures[texture_index]
		if texture == null:
			continue
		var symbol_size := BASE_SYMBOL_SIZE * _scales[index]
		var texture_size := texture.get_size()
		var fitted_size := symbol_size
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var fit_scale := minf(
				symbol_size.x / texture_size.x,
				symbol_size.y / texture_size.y
			)
			fitted_size = texture_size * fit_scale
		var fitted_offset := (symbol_size - fitted_size) * 0.5
		draw_set_transform(Vector2(_x[index], _y[index]), _rotations[index], Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(fitted_offset, fitted_size),
			false,
			Color(SYMBOL_TINT.r, SYMBOL_TINT.g, SYMBOL_TINT.b, _alphas[index])
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _reset_layout_internal(request_redraw: bool) -> void:
	_layout_size = _get_safe_layout_size()
	_layout_ready = _layout_size.x > 0.0 and _layout_size.y > 0.0
	if _texture_indices.size() != _symbol_count:
		_resize_state_arrays()
	if _layout_ready and not _textures.is_empty():
		for index in _symbol_count:
			_texture_indices[index] = index % _textures.size()
			_reset_symbol(index, true)
	if request_redraw:
		queue_redraw()


func _reset_symbol(index: int, scatter_y: bool) -> void:
	if index < 0 or index >= _symbol_count or not _layout_ready:
		return
	var scale_factor := _rng.randf_range(SCALE_MIN, SCALE_MAX)
	var symbol_size := BASE_SYMBOL_SIZE * scale_factor
	var maximum_x := maxf(
		HORIZONTAL_MARGIN,
		_layout_size.x - symbol_size.x - HORIZONTAL_MARGIN
	)
	var base_position_x := _rng.randf_range(HORIZONTAL_MARGIN, maximum_x)
	var next_y := (
		_rng.randf_range(-_layout_size.y, _layout_size.y)
		if scatter_y
		else -symbol_size.y - _rng.randf_range(RESPAWN_GAP_MIN, RESPAWN_GAP_MAX)
	)
	_scales[index] = scale_factor
	_base_x[index] = base_position_x
	_x[index] = base_position_x
	_y[index] = next_y
	_speeds[index] = _rng.randf_range(SPEED_MIN, SPEED_MAX)
	_drifts[index] = _rng.randf_range(DRIFT_MIN, DRIFT_MAX)
	_wave_speeds[index] = _rng.randf_range(WAVE_SPEED_MIN, WAVE_SPEED_MAX)
	_phases[index] = _rng.randf_range(0.0, TAU)
	_alphas[index] = _rng.randf_range(ALPHA_MIN, ALPHA_MAX)
	_rotations[index] = _rng.randf_range(ROTATION_MIN, ROTATION_MAX)


func _resize_state_arrays() -> void:
	_texture_indices.resize(_symbol_count)
	_base_x.resize(_symbol_count)
	_x.resize(_symbol_count)
	_y.resize(_symbol_count)
	_scales.resize(_symbol_count)
	_speeds.resize(_symbol_count)
	_drifts.resize(_symbol_count)
	_wave_speeds.resize(_symbol_count)
	_phases.resize(_symbol_count)
	_alphas.resize(_symbol_count)
	_rotations.resize(_symbol_count)


func _get_safe_layout_size() -> Vector2:
	return Vector2(maxf(0.0, size.x), maxf(0.0, size.y))
