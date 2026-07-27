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


func _process(delta: float) -> void:
	if not _active:
		return
	# Phase stays unbounded. Every rune is fully transparent at its wrap point,
	# so recycling never produces a visible snap.
	_phase += maxf(0.0, delta)
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
		38.0 + pulse * 2.5,
		Color(0.61, 1.0, 0.41, 0.075 + power * 0.025),
		6
	)
	if _rune_textures.is_empty():
		return

	for rune_index in 12:
		var speed := 0.105 + float(rune_index % 4) * 0.017
		var progress := fposmod(
			_phase * speed + float(rune_index) / 12.0,
			1.0
		)
		var angle := -1.18 + 2.36 * float(rune_index % 7) / 6.0
		angle += sin(float(rune_index) * 2.17) * 0.18
		var direction := Vector2(1.0, sin(angle) * 0.72).normalized()
		var distance := 34.0 + progress * (154.0 + power * 36.0)
		var position := portrait_center + direction * distance
		var fade := pow(sin(progress * PI), 1.35)
		var rune_size := Vector2(17.0, 25.0).lerp(
			Vector2(27.0, 39.0),
			progress
		)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			rune_size,
			fade * (0.50 + power * 0.28)
		)


func _draw_faith_glow_and_runes() -> void:
	var center := size * 0.5
	var pulse := 0.5 + sin(_phase * 0.58) * 0.5
	var power := clampf(log(_multiplier) / log(16.0), 0.18, 1.0)

	_draw_soft_glow(
		center,
		52.0 + pulse * 3.0,
		Color(0.66, 1.0, 0.40, 0.055 + power * 0.025),
		7
	)
	if _rune_textures.is_empty():
		return

	for rune_index in 16:
		var speed := 0.075 + float(rune_index % 5) * 0.011
		var progress := fposmod(
			_phase * speed + float(rune_index) / 16.0,
			1.0
		)
		var angle := TAU * float(rune_index) / 16.0
		angle += sin(float(rune_index) * 1.91) * 0.16
		var radius_x := 45.0 + progress * 132.0
		var radius_y := 18.0 + progress * 50.0
		var position := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		var fade := pow(sin(progress * PI), 1.4)
		_draw_rune(
			rune_index % _rune_textures.size(),
			position,
			Vector2(18.0, 27.0).lerp(Vector2(29.0, 42.0), progress),
			fade * (0.43 + power * 0.28)
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
		Color(0.88, 1.0, 0.58, clampf(alpha, 0.0, 1.0))
	)


func _load_runes() -> void:
	if not _rune_textures.is_empty():
		return
	for path in RUNE_TEXTURE_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			_rune_textures.append(texture)
