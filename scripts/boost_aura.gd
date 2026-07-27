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

var _mode := AuraMode.PET_ROW
var _active := false
var _multiplier := 1.0
var _phase := 0.0
var _growth_flash := 0.0
var _rune_textures: Array[Texture2D] = []


func setup(mode: AuraMode) -> void:
	_mode = mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_load_runes()
	set_process(false)
	visible = false


func set_boost(active: bool, multiplier := 1.0) -> void:
	_active = active
	_multiplier = maxf(1.0, multiplier)
	visible = active
	set_process(active)
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
	# Phase stays unbounded. Every rune is fully transparent at its wrap point,
	# so recycling never produces a visible snap.
	_phase += maxf(0.0, delta)
	_growth_flash = move_toward(_growth_flash, 0.0, maxf(0.0, delta) * 5.2)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	if _mode == AuraMode.FAITH_COUNTER:
		_draw_faith_glow_and_runes()
	else:
		_draw_pet_glow_and_runes()


func _draw_pet_glow_and_runes() -> void:
	var portrait_center := Vector2(51.0, 62.0)
	var pulse := 0.5 + sin(_phase * 0.72) * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)

	_draw_soft_glow(
		portrait_center,
		42.0 + pulse * 3.5,
		Color(0.61, 1.0, 0.34, 0.13 + power * 0.045),
		6
	)
	# Layered transparent contours illuminate the full row perimeter without
	# placing any colored sheet over the item art.
	for glow_layer in 5:
		var row_glow := StyleBoxFlat.new()
		var layer_alpha := (0.54 + pulse * 0.12 + power * 0.08) / float(glow_layer + 1)
		row_glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		row_glow.border_color = Color(0.62, 1.0, 0.30, layer_alpha)
		row_glow.set_border_width_all(3 if glow_layer == 0 else 2)
		row_glow.set_corner_radius_all(14 + glow_layer * 2)
		var inset := 5.0 + float(glow_layer) * 2.0
		draw_style_box(
			row_glow,
			Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		)
	if _rune_textures.is_empty():
		return

	for rune_index in 17:
		var speed := 0.105 + float(rune_index % 4) * 0.017
		var progress := fposmod(
			_phase * speed + float(rune_index) / 17.0,
			1.0
		)
		var angle := -1.18 + 2.36 * float(rune_index % 7) / 6.0
		angle += sin(float(rune_index) * 2.17) * 0.18
		var direction := Vector2(1.0, sin(angle) * 0.72).normalized()
		var distance := 30.0 + progress * (206.0 + power * 48.0)
		var position := portrait_center + direction * distance
		var fade := pow(sin(progress * PI), 1.35)
		var rune_size := Vector2(21.0, 31.0).lerp(
			Vector2(34.0, 49.0),
			progress
		)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			rune_size,
			fade * (0.68 + power * 0.26)
		)


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

	for rune_index in 22:
		var speed := 0.083 + float(rune_index % 5) * 0.013 + _growth_flash * 0.035
		var progress := fposmod(
			_phase * speed + float(rune_index) / 22.0,
			1.0
		)
		var angle := TAU * float(rune_index) / 22.0
		angle += sin(float(rune_index) * 1.91) * 0.16
		var radius_x := 40.0 + progress * (148.0 + _growth_flash * 22.0)
		var radius_y := 16.0 + progress * (56.0 + _growth_flash * 8.0)
		var position := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		var fade := pow(sin(progress * PI), 1.4)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(21.0, 31.0).lerp(Vector2(34.0, 49.0), progress),
			fade * (0.60 + power * 0.26 + _growth_flash * 0.14)
		)


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
