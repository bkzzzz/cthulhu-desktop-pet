extends RefCounted

const DisplayLayout = preload("res://scripts/domain/display_layout.gd")

const COMMON_USABLE_SIZES := [
	Vector2i(1024, 600),
	Vector2i(1280, 720),
	Vector2i(1366, 728),
	Vector2i(1920, 1040),
	Vector2i(2560, 1400),
	Vector2i(3840, 2080),
]
const LARGE_WINDOW_DESIGNS := [
	Vector2i(1160, 850),
	Vector2i(1117, 1034),
	Vector2i(720, 720),
	Vector2i(570, 798),
]


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_desktop_matches_work_area(failures)
	_test_native_windows_fit_common_resolutions(failures)
	_test_positions_stay_inside_offset_monitors(failures)
	_test_window_keeps_design_coordinate_space(failures)
	_test_hidden_window_skips_native_screen_query(failures)
	return failures


static func _test_desktop_matches_work_area(failures: Array[String]) -> void:
	for usable_size in COMMON_USABLE_SIZES:
		var usable := Rect2i(Vector2i(120, 45), usable_size)
		var desktop := DisplayLayout.desktop_window_rect(usable)
		_expect(desktop == usable, "desktop should exactly match usable rect %s" % usable, failures)


static func _test_native_windows_fit_common_resolutions(failures: Array[String]) -> void:
	for usable_size in COMMON_USABLE_SIZES:
		for design_size in LARGE_WINDOW_DESIGNS:
			var fitted := DisplayLayout.fit_design_size(design_size, usable_size)
			_expect(fitted.x <= usable_size.x - 32, "window should fit width at %s" % usable_size, failures)
			_expect(fitted.y <= usable_size.y - 32, "window should fit height at %s" % usable_size, failures)
			_expect(
				absf(float(fitted.x) / float(fitted.y) - float(design_size.x) / float(design_size.y)) < 0.01,
				"window should preserve design aspect at %s" % usable_size,
				failures
			)


static func _test_positions_stay_inside_offset_monitors(failures: Array[String]) -> void:
	var usable := Rect2i(Vector2i(-1366, 40), Vector2i(1366, 728))
	var fitted := DisplayLayout.fit_design_size(Vector2i(1117, 1034), usable.size)
	var centered := DisplayLayout.centered_position(usable, fitted)
	var dragged := DisplayLayout.clamp_position(Vector2i(-9000, 9000), fitted, usable)
	_expect(centered.x >= usable.position.x, "centered window should respect negative monitor origin", failures)
	_expect(centered.y >= usable.position.y, "centered window should respect taskbar offset", failures)
	_expect(dragged.x == usable.position.x, "dragged window should clamp to monitor left edge", failures)
	_expect(dragged.y + fitted.y <= usable.end.y, "dragged window should clamp to monitor bottom edge", failures)


static func _test_window_keeps_design_coordinate_space(failures: Array[String]) -> void:
	var design_size := Vector2i(1117, 1034)
	var usable := Rect2i(Vector2i.ZERO, Vector2i(1024, 600))
	var window := Window.new()
	var fitted := DisplayLayout.apply_scaled_window(window, design_size, usable)
	_expect(window.content_scale_size == design_size, "scaled window should keep its design-space size", failures)
	_expect(window.size == fitted, "native window should use the fitted physical size", failures)
	_expect(window.size.y <= usable.size.y - 32, "scaled native window should leave its screen margin", failures)
	window.free()


static func _test_hidden_window_skips_native_screen_query(failures: Array[String]) -> void:
	var window := Window.new()
	window.visible = false
	_expect(
		not DisplayLayout.can_query_window_screen(window),
		"a hidden or unattached window must not query an unavailable native screen",
		failures
	)
	window.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("Display layout: %s" % message)
