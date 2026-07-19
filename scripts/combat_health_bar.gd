extends Node2D

const DEFAULT_SIZE := Vector2(76.0, 9.0)
const BOSS_SIZE := Vector2(190.0, 14.0)
const DISPLAY_SPEED := 5.5
const CHIP_SPEED := 1.8

var _bar_size := DEFAULT_SIZE
var _target_ratio := 1.0
var _display_ratio := 1.0
var _chip_ratio := 1.0
var _is_enemy := false
var _is_boss := false


func setup(is_enemy: bool, is_boss := false, width := 0.0) -> void:
	_is_enemy = is_enemy
	_is_boss = is_boss
	_bar_size = BOSS_SIZE if is_boss else DEFAULT_SIZE
	if width > 0.0:
		_bar_size.x = width
	z_index = 420 if not is_boss else 460
	queue_redraw()


func set_health(current_health: float, maximum_health: float, immediate := false) -> void:
	var safe_maximum := maxf(0.000001, maximum_health)
	_target_ratio = clampf(current_health / safe_maximum, 0.0, 1.0)
	if immediate:
		_display_ratio = _target_ratio
		_chip_ratio = _target_ratio
	set_process(
		not is_equal_approx(_display_ratio, _target_ratio)
		or not is_equal_approx(_chip_ratio, _target_ratio)
	)
	queue_redraw()


func get_health_ratio() -> float:
	return _target_ratio


func get_display_ratio() -> float:
	return _display_ratio


func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_display_ratio = move_toward(_display_ratio, _target_ratio, DISPLAY_SPEED * safe_delta)
	if _chip_ratio < _display_ratio:
		_chip_ratio = _display_ratio
	else:
		_chip_ratio = move_toward(_chip_ratio, _target_ratio, CHIP_SPEED * safe_delta)
	if (
		is_equal_approx(_display_ratio, _target_ratio)
		and is_equal_approx(_chip_ratio, _target_ratio)
	):
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(-_bar_size * 0.5, _bar_size)
	var inset := 2.0 if _is_boss else 1.5
	var inner := outer.grow(-inset)
	draw_rect(outer, Color(0.015, 0.018, 0.025, 0.94), true)
	draw_rect(outer, Color(0.82, 0.72, 0.46, 0.95) if _is_boss else Color(0.08, 0.08, 0.1, 0.98), false, 1.0)
	draw_rect(inner, Color(0.12, 0.025, 0.025, 0.92), true)
	if _chip_ratio > 0.0:
		var chip_rect := inner
		chip_rect.size.x *= _chip_ratio
		draw_rect(chip_rect, Color(1.0, 0.72, 0.18, 0.92), true)
	if _display_ratio > 0.0:
		var health_rect := inner
		health_rect.size.x *= _display_ratio
		var healthy_color := Color(0.38, 0.92, 0.48) if not _is_enemy else Color(0.92, 0.25, 0.24)
		var danger_color := Color(0.95, 0.22, 0.16)
		draw_rect(health_rect, danger_color.lerp(healthy_color, _display_ratio), true)
	if _is_boss:
		var marker_color := Color(0.94, 0.78, 0.38, 0.9)
		for marker_index in range(1, 4):
			var marker_x := inner.position.x + inner.size.x * float(marker_index) / 4.0
			draw_line(
				Vector2(marker_x, inner.position.y),
				Vector2(marker_x, inner.end.y),
				marker_color,
				1.0
			)
