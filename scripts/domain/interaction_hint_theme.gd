extends RefCounted

## Shared visual language for the small hover plaques used by desktop actors
## and the taskbar menu handle.

const FONT_COLOR := Color(0.95, 0.84, 0.62, 1.0)
const FONT_OUTLINE_COLOR := Color(0.025, 0.018, 0.01, 1.0)


static func make_plaque_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.052, 0.032, 0.96)
	style.border_color = Color(0.72, 0.61, 0.38, 0.94)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func apply_to_label(label: Label, font_size: int) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", FONT_COLOR)
	label.add_theme_color_override("font_outline_color", FONT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_stylebox_override("normal", make_plaque_style())
