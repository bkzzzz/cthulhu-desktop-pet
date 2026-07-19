class_name DisplayLayout
extends RefCounted

const DEFAULT_SCREEN_MARGIN := 16
const FALLBACK_USABLE_SIZE := Vector2i(1280, 720)


static func sanitize_usable_rect(usable_rect: Rect2i) -> Rect2i:
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		return usable_rect
	return Rect2i(usable_rect.position, FALLBACK_USABLE_SIZE)


static func desktop_window_rect(usable_rect: Rect2i) -> Rect2i:
	# The transparent desktop layer must cover the Windows work area exactly:
	# extending it overlaps the taskbar, while a fixed minimum leaves gaps on
	# larger displays and can overflow small/high-DPI displays.
	return sanitize_usable_rect(usable_rect)


static func fit_design_size(
	design_size: Vector2i,
	usable_size: Vector2i,
	margin := DEFAULT_SCREEN_MARGIN,
	allow_upscale := false
) -> Vector2i:
	var safe_design := Vector2i(maxi(1, design_size.x), maxi(1, design_size.y))
	var safe_usable := usable_size
	if safe_usable.x <= 0 or safe_usable.y <= 0:
		safe_usable = FALLBACK_USABLE_SIZE
	var safe_margin := maxi(0, margin)
	var available := Vector2i(
		maxi(1, safe_usable.x - safe_margin * 2),
		maxi(1, safe_usable.y - safe_margin * 2)
	)
	var scale_factor := minf(
		float(available.x) / float(safe_design.x),
		float(available.y) / float(safe_design.y)
	)
	if not allow_upscale:
		scale_factor = minf(1.0, scale_factor)
	return Vector2i(
		maxi(1, int(floor(float(safe_design.x) * scale_factor))),
		maxi(1, int(floor(float(safe_design.y) * scale_factor)))
	)


static func centered_position(usable_rect: Rect2i, window_size: Vector2i) -> Vector2i:
	var safe_rect := sanitize_usable_rect(usable_rect)
	var safe_size := Vector2i(maxi(1, window_size.x), maxi(1, window_size.y))
	return Vector2i(
		safe_rect.position.x + maxi(0, (safe_rect.size.x - safe_size.x) / 2),
		safe_rect.position.y + maxi(0, (safe_rect.size.y - safe_size.y) / 2)
	)


static func clamp_position(
	desired_position: Vector2i,
	window_size: Vector2i,
	usable_rect: Rect2i
) -> Vector2i:
	var safe_rect := sanitize_usable_rect(usable_rect)
	var safe_size := Vector2i(maxi(1, window_size.x), maxi(1, window_size.y))
	var maximum := Vector2i(
		safe_rect.position.x + maxi(0, safe_rect.size.x - safe_size.x),
		safe_rect.position.y + maxi(0, safe_rect.size.y - safe_size.y)
	)
	return Vector2i(
		clampi(desired_position.x, safe_rect.position.x, maximum.x),
		clampi(desired_position.y, safe_rect.position.y, maximum.y)
	)


static func get_current_screen(window: Window = null, prefer_mouse := true) -> int:
	var screen := -1
	if prefer_mouse:
		screen = DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0 and window != null and is_instance_valid(window):
		screen = DisplayServer.window_get_current_screen(window.get_window_id())
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = 0
	return screen


static func get_current_usable_rect(window: Window = null, prefer_mouse := true) -> Rect2i:
	return sanitize_usable_rect(
		DisplayServer.screen_get_usable_rect(get_current_screen(window, prefer_mouse))
	)


static func apply_scaled_window(
	window: Window,
	design_size: Vector2i,
	usable_rect: Rect2i,
	margin := DEFAULT_SCREEN_MARGIN
) -> Vector2i:
	if window == null:
		return Vector2i.ZERO
	var fitted_size := fit_design_size(design_size, usable_rect.size, margin)
	window.min_size = Vector2i.ZERO
	window.max_size = Vector2i.ZERO
	window.content_scale_size = design_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.size = fitted_size
	window.position = centered_position(usable_rect, fitted_size)
	return fitted_size
