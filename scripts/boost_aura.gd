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
		_load_runes()
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
	# The effect is intentionally drawn at 30 fps. It remains fluid while
	# avoiding duplicate redraw work in the UI window.
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
		_draw_faith_glow()
	else:
		_draw_pet_glow()


func _draw_pet_glow() -> void:
	var pulse := 0.5 + sin(_phase * 1.45) * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)
	# A continuous rim glow identifies the boosted row without stacking visible
	# balls or putting a hard frame over its content.
	_draw_row_edge_glow(pulse, power)
	_draw_pet_rune_spray(power)


func _draw_faith_glow() -> void:
	var center := size * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)

	_draw_soft_glow(
		center,
		52.0,
		Color(0.68, 1.0, 0.34, 0.12 + power * 0.04),
		6
	)
	_draw_faith_symbol_spray(center, power)


func _draw_pet_rune_spray(power: float) -> void:
	if _rune_textures.is_empty():
		return
	# A few small runes peel away from the row's four edges. They remain sparse
	# so the glow reads as one boosted row instead of a pile of light orbs.
	for rune_index in 5:
		var progress := fposmod(
			_phase * (0.82 + float(rune_index % 3) * 0.13) + float(rune_index) / 5.0,
			1.0
		)
		var edge := rune_index % 4
		var edge_progress := fposmod(float(rune_index) * 0.37, 1.0)
		var origin := Vector2.ZERO
		var direction := Vector2.ZERO
		if edge == 0:
			origin = Vector2(28.0 + edge_progress * maxf(1.0, size.x - 56.0), 9.0)
			direction = Vector2(0.16, -1.0).normalized()
		elif edge == 1:
			origin = Vector2(size.x - 9.0, 20.0 + edge_progress * maxf(1.0, size.y - 40.0))
			direction = Vector2(1.0, -0.14).normalized()
		elif edge == 2:
			origin = Vector2(28.0 + edge_progress * maxf(1.0, size.x - 56.0), size.y - 9.0)
			direction = Vector2(-0.16, 1.0).normalized()
		else:
			origin = Vector2(9.0, 20.0 + edge_progress * maxf(1.0, size.y - 40.0))
			direction = Vector2(-1.0, 0.14).normalized()
		var position := origin + direction * (5.0 + progress * 42.0)
		var fade := smoothstep(0.0, 0.08, progress) * pow(1.0 - progress, 0.72)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(9.0, 12.0).lerp(Vector2(13.0, 18.0), progress),
			fade * (0.20 + power * 0.12)
		)


func _draw_faith_symbol_spray(center: Vector2, power: float) -> void:
	if _rune_textures.is_empty():
		return
	# Symbols leave the counter on fixed outward trajectories. Their short
	# lifetime creates a fast spray without making the number itself pulse.
	for rune_index in 10:
		var progress := fposmod(
			_phase * (1.12 + float(rune_index % 4) * 0.10) + float(rune_index) / 10.0,
			1.0
		)
		var seed := float(rune_index)
		var origin := center + Vector2(sin(seed * 2.41) * 82.0, sin(seed * 5.17) * 13.0)
		var angle := atan2(origin.y - center.y, origin.x - center.x) + sin(seed * 1.91) * 0.16
		var direction := Vector2(cos(angle), sin(angle) * 0.72).normalized()
		var position := origin + direction * (8.0 + progress * (118.0 + _growth_flash * 22.0))
		var fade := smoothstep(0.0, 0.05, progress) * pow(1.0 - progress, 0.82)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(13.0, 19.0).lerp(Vector2(19.0, 27.0), progress),
			fade * (0.32 + power * 0.12 + _growth_flash * 0.08)
		)


func _draw_row_edge_glow(pulse: float, power: float) -> void:
	var glow_strength := 0.70 + pulse * 0.08 + power * 0.14
	# A boosted pet is marked by an illuminated baseline and a little life around
	# its portrait.  This avoids the old full rounded-rectangle outline, which
	# fought against the hand-drawn row asset and made the card look like a stock
	# UI component.
	var baseline := size.y - 14.0
	for layer in 3:
		var offset := float(layer) * 2.0
		var alpha := (0.040 + float(layer) * 0.028) * glow_strength
		draw_line(
			Vector2(38.0, baseline + offset),
			Vector2(size.x - 34.0, baseline + offset),
			Color(0.62, 1.0, 0.34, alpha),
			4.0 - float(layer),
			true
		)
	var portrait_center := Vector2(51.0, size.y * 0.5)
	_draw_soft_glow(
		portrait_center,
		31.0,
		Color(0.62, 1.0, 0.34, 0.06 + power * 0.025),
		4
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


func _draw_rune(index: int, center: Vector2, rune_size: Vector2, alpha: float) -> void:
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
	for texture_path in RUNE_TEXTURE_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			_rune_textures.append(texture)
