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
	if _mode == AuraMode.FAITH_COUNTER:
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


func _draw_faith_glow() -> void:
	var center := size * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)

	_draw_soft_glow(
		center,
		64.0 + _growth_flash * 16.0,
		Color(0.66, 1.0, 0.31, 0.17 + power * 0.055 + _growth_flash * 0.15),
		8
	)
	_draw_faith_symbol_spray(center, power)


func _draw_faith_symbol_spray(center: Vector2, power: float) -> void:
	if _rune_textures.is_empty():
		return
	# Symbols leave the counter on fixed outward trajectories. Their short
	# lifetime creates a fast spray without making the number itself pulse.
	for rune_index in 20:
		var progress := fposmod(
			_phase * (1.12 + float(rune_index % 4) * 0.10) + float(rune_index) / 20.0,
			1.0
		)
		var seed := float(rune_index)
		var origin := center + Vector2(sin(seed * 2.41) * 106.0, sin(seed * 5.17) * 17.0)
		var angle := atan2(origin.y - center.y, origin.x - center.x) + sin(seed * 1.91) * 0.16
		var direction := Vector2(cos(angle), sin(angle) * 0.72).normalized()
		var position := origin + direction * (10.0 + progress * (174.0 + _growth_flash * 30.0))
		var fade := smoothstep(0.0, 0.05, progress) * pow(1.0 - progress, 0.82)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(16.0, 24.0).lerp(Vector2(25.0, 36.0), progress),
			fade * (0.74 + power * 0.20 + _growth_flash * 0.12)
		)


func _draw_row_edge_glow(pulse: float, power: float) -> void:
	var glow_strength := 0.92 + pulse * 0.34 + power * 0.26
	var edge_rect := Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0))
	for layer in 3:
		var expansion := float(3 - layer) * 2.5
		var layer_rect := edge_rect.grow(expansion)
		var layer_alpha := (0.055 + float(layer) * 0.055) * glow_strength
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
