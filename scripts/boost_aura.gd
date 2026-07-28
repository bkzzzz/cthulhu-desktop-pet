extends Control

enum AuraMode {
	PET_ROW,
	FAITH_COUNTER
}

const RUNE_TEXTURE_PATHS := [
	"res://assets/ui/newElements/符号特效1.png",
	"res://assets/ui/newElements/符号特效2.png",
	"res://assets/ui/newElements/符号特效3.png",
	"res://assets/ui/newElements/符号特效4.png",
	"res://assets/ui/newElements/符号特效5.png"
]
const REDRAW_INTERVAL_SECONDS := 1.0 / 30.0

var _mode := AuraMode.PET_ROW
var _active := false
var _multiplier := 1.0
var _phase := 0.0
var _growth_flash := 0.0
var _redraw_elapsed := 0.0
var _rune_textures: Array[Texture2D] = []


func setup(mode: AuraMode) -> void:
	_mode = mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_load_runes()
	set_process(false)
	visible = false


func set_boost(active: bool, multiplier := 1.0) -> void:
	var next_multiplier := maxf(1.0, multiplier)
	var state_changed := _active != active
	var power_changed := not is_equal_approx(_multiplier, next_multiplier)
	if not state_changed and not power_changed:
		return
	_active = active
	_multiplier = next_multiplier
	if state_changed:
		visible = active
		set_process(active)
		_redraw_elapsed = REDRAW_INTERVAL_SECONDS
	if active:
		queue_redraw()


func is_boost_active() -> bool:
	return _active


func notify_growth() -> void:
	if not _active or _mode != AuraMode.FAITH_COUNTER:
		return
	_growth_flash = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	var safe_delta := maxf(0.0, delta)
	# The effect is intentionally drawn at 30 fps. It remains fluid for slow
	# moving glyphs while avoiding duplicate redraw work in the UI window.
	_phase += safe_delta
	_growth_flash = move_toward(_growth_flash, 0.0, safe_delta * 4.2)
	_redraw_elapsed += safe_delta
	if _redraw_elapsed >= REDRAW_INTERVAL_SECONDS:
		_redraw_elapsed = fmod(_redraw_elapsed, REDRAW_INTERVAL_SECONDS)
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	if _mode == AuraMode.FAITH_COUNTER:
		_draw_faith_glow_and_runes()
	else:
		_draw_pet_glow_and_runes()


func _draw_pet_glow_and_runes() -> void:
	var pulse := 0.5 + sin(_phase * 0.72) * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)
	# A continuous rim glow identifies the boosted row without stacking visible
	# balls or putting a hard frame over its content.
	_draw_row_edge_glow(pulse, power)


func _draw_faith_glow_and_runes() -> void:
	var center := size * 0.5
	var pulse := 0.5 + sin(_phase * 0.58) * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)

	_draw_soft_glow(
		center,
		58.0 + pulse * 4.0 + _growth_flash * 9.0,
		Color(0.66, 1.0, 0.31, 0.11 + power * 0.035 + _growth_flash * 0.10),
		8
	)
	if _rune_textures.is_empty():
		return

	# Glyphs start within the number's footprint and flow out through its edges.
	# Their travel direction never changes, so the result feels like a steady
	# magical overflow instead of a twitching ring.
	for rune_index in 28:
		var speed := 0.102 + float(rune_index % 5) * 0.009
		var progress := fposmod(
			_phase * speed + float(rune_index) / 28.0,
			1.0
		)
		var seed := float(rune_index)
		var origin := center + Vector2(sin(seed * 2.41) * 108.0, sin(seed * 5.17) * 18.0)
		var angle := atan2(origin.y - center.y, origin.x - center.x)
		angle += sin(seed * 1.91) * 0.18
		var direction := Vector2(cos(angle), sin(angle) * 0.72).normalized()
		var eased_progress := 1.0 - pow(1.0 - progress, 1.45)
		var distance := 10.0 + eased_progress * (118.0 + _growth_flash * 24.0)
		var position := origin + direction * distance
		var fade := smoothstep(0.0, 0.10, progress) * pow(1.0 - progress, 0.78)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(18.0, 27.0).lerp(Vector2(27.0, 39.0), eased_progress),
			fade * (0.66 + power * 0.22 + _growth_flash * 0.12)
		)


func _draw_row_edge_glow(pulse: float, power: float) -> void:
	var glow_strength := 0.75 + pulse * 0.25 + power * 0.18
	var edge_rect := Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0))
	for layer in 3:
		var expansion := float(3 - layer) * 2.5
		var layer_rect := edge_rect.grow(expansion)
		var layer_alpha := (0.025 + float(layer) * 0.035) * glow_strength
		_draw_rounded_rect_glow(
			layer_rect,
			15.0 + expansion,
			Color(0.58, 1.0, 0.29, layer_alpha),
			8.0 - float(layer) * 2.25
		)


func _draw_rounded_rect_glow(rect: Rect2, corner_radius: float, color: Color, line_width: float) -> void:
	var radius := minf(corner_radius, minf(rect.size.x, rect.size.y) * 0.5)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	draw_line(Vector2(left + radius, top), Vector2(right - radius, top), color, line_width, true)
	draw_line(Vector2(right, top + radius), Vector2(right, bottom - radius), color, line_width, true)
	draw_line(Vector2(right - radius, bottom), Vector2(left + radius, bottom), color, line_width, true)
	draw_line(Vector2(left, bottom - radius), Vector2(left, top + radius), color, line_width, true)
	draw_arc(Vector2(right - radius, top + radius), radius, -PI * 0.5, 0.0, 8, color, line_width, true)
	draw_arc(Vector2(right - radius, bottom - radius), radius, 0.0, PI * 0.5, 8, color, line_width, true)
	draw_arc(Vector2(left + radius, bottom - radius), radius, PI * 0.5, PI, 8, color, line_width, true)
	draw_arc(Vector2(left + radius, top + radius), radius, PI, PI * 1.5, 8, color, line_width, true)


func _draw_soft_glow(
	center: Vector2,
	base_radius: float,
	color: Color,
	layer_count: int
) -> void:
	for layer_index in layer_count:
		var layer_progress := float(layer_index) / float(maxi(1, layer_count - 1))
		var layer_color := color
		layer_color.a *= (1.0 - layer_progress) * 0.72
		draw_circle(
			center,
			base_radius + layer_progress * 42.0,
			layer_color
		)


func _draw_rune(
	index: int,
	center: Vector2,
	rune_size: Vector2,
	alpha: float
) -> void:
	if index < 0 or index >= _rune_textures.size():
		return
	var texture := _rune_textures[index]
	if texture == null or alpha <= 0.001:
		return
	draw_texture_rect(
		texture,
		Rect2(center - rune_size * 0.5, rune_size),
		false,
		Color(0.86, 1.0, 0.42, clampf(alpha, 0.0, 1.0))
	)


func _load_runes() -> void:
	if not _rune_textures.is_empty():
		return
	for path in RUNE_TEXTURE_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			_rune_textures.append(texture)
