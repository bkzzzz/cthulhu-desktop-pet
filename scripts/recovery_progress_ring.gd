extends Control

var _progress := 0.0
var _shade_alpha := 0.68


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_progress(value: float) -> void:
	var next_progress := clampf(value, 0.0, 1.0)
	if is_equal_approx(_progress, next_progress):
		return
	_progress = next_progress
	queue_redraw()


func set_shade_alpha(value: float) -> void:
	_shade_alpha = clampf(value, 0.0, 0.9)
	queue_redraw()


func _draw() -> void:
	var radius := maxf(4.0, minf(size.x, size.y) * 0.5 - 2.0)
	var center := size * 0.5
	draw_circle(center, radius, Color(0.10, 0.11, 0.12, _shade_alpha))
	draw_arc(center, radius - 2.0, -PI * 0.5, TAU - PI * 0.5, 64, Color(0.28, 0.30, 0.32, 0.94), 5.0, true)
	if _progress > 0.001:
		draw_arc(
			center,
			radius - 2.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * _progress,
			maxi(4, int(64.0 * _progress)),
			Color(0.82, 0.88, 0.78, 0.98),
			5.0,
			true
		)
