extends SceneTree

## Visual QA harness for the runtime pet catalogue.  It deliberately builds the
## same DesktopPetActor used by the game instead of drawing source PNGs directly,
## so scale, floor offsets, animation slicing, and authored-direction flags are
## all represented in the screenshots.

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")

const PET_IDS := [
	"pet1", "pet2", "pet3", "pet4", "pet5",
	"pet6", "pet7", "pet8", "pet9", "pet10"
]
const OUTPUT_DIR := "res://tests/_artifacts"
const MATRIX_SIZE := Vector2i(1600, 850)
const CELL_SIZE := Vector2(320.0, 390.0)
const GRID_TOP := 58.0
const FLOOR_INSET := 34.0

const BACKGROUND := Color(0.025, 0.032, 0.052, 1.0)
const CELL_A := Color(0.055, 0.068, 0.098, 1.0)
const CELL_B := Color(0.043, 0.054, 0.082, 1.0)
const FLOOR_COLOR := Color(0.38, 0.52, 0.63, 0.58)
const LABEL_COLOR := Color(0.91, 0.94, 1.0, 1.0)
const MUTED_COLOR := Color(0.59, 0.68, 0.79, 1.0)


func _initialize() -> void:
	call_deferred("_render_all")


func _render_all() -> void:
	var absolute_output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create pet QA artifact directory: %s" % mkdir_error)
		quit(1)
		return

	_print_layering_audit()
	var output_paths: Array[String] = []
	for evolved in [false, true]:
		for animation_name in ["idle", "attack"]:
			var output_path := await _render_matrix(bool(evolved), animation_name)
			output_paths.append(output_path)

	for output_path in output_paths:
		print("PET_ASSET_MATRIX=%s" % output_path)
	quit(0)


func _render_matrix(evolved: bool, animation_name: String) -> String:
	var window := Window.new()
	window.title = "Pet asset QA"
	window.size = MATRIX_SIZE
	window.min_size = MATRIX_SIZE
	window.unresizable = true
	window.transparent = false
	window.transparent_bg = false
	root.add_child(window)

	var backdrop := ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(MATRIX_SIZE)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	window.add_child(backdrop)

	var overlay := CanvasLayer.new()
	overlay.layer = 50
	window.add_child(overlay)
	var form_label := "EVOLVED (level >= 100)" if evolved else "BASE (level < 100)"
	_add_label(
		overlay,
		"PET 1-10 RUNTIME ASSET QA  |  %s  |  %s  |  TARGET LEFT  <-" % [
			form_label,
			animation_name.to_upper()
		],
		Vector2(18.0, 10.0),
		Vector2(1564.0, 38.0),
		22,
		LABEL_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT
	)

	for pet_index in PET_IDS.size():
		var pet_id: String = PET_IDS[pet_index]
		var column := pet_index % 5
		var row := int(pet_index / 5)
		var cell_origin := Vector2(float(column) * CELL_SIZE.x, GRID_TOP + float(row) * CELL_SIZE.y)
		var ground_y := cell_origin.y + CELL_SIZE.y - FLOOR_INSET
		_add_cell_chrome(window, overlay, pet_id, evolved, animation_name, pet_index, cell_origin, ground_y)

		var start_x := cell_origin.x + CELL_SIZE.x * 0.5
		var actor := DesktopPetActor.new()
		actor.name = "%s_%s_%s" % [pet_id, "evolved" if evolved else "base", animation_name]
		actor.setup(
			pet_id,
			MATRIX_SIZE,
			cell_origin.x + 8.0,
			cell_origin.x + CELL_SIZE.x - 8.0,
			start_x,
			ground_y,
			true,
			evolved,
			100 if evolved else 99
		)
		window.add_child(actor)
		actor.set_battle_mode(true)
		actor.face_battle_target(-1.0)
		actor.call("_set_interaction_enabled", false)
		# Sleepy floaters normally start at a randomized roaming height.  Pin the
		# QA pose to its configured rest/contact height so base/evolved scale and
		# ground offsets remain directly comparable from run to run.
		if String(actor.pet_data.get("behavior", "")) == "sleepy_floater":
			var stable_rest_y := float(actor.call("_get_rest_y"))
			actor.set("_float_anchor_y", stable_rest_y)
			actor.position.y = stable_rest_y

		var sprite := actor.get("_sprite") as AnimatedSprite2D
		var frame_index := _pose_actor(actor, sprite, pet_id, evolved, animation_name, start_x)
		_add_pose_metadata(overlay, actor, sprite, pet_id, evolved, animation_name, frame_index, cell_origin, ground_y)

	window.visible = true
	for _frame in 4:
		await process_frame

	var file_name := "pet_%s_%s_left_matrix.png" % [
		"evolved" if evolved else "base",
		animation_name
	]
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var image := window.get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save pet QA matrix %s: %s" % [output_path, save_error])
	else:
		print("QA_SAVED form=%s anim=%s size=%s path=%s" % [
			"evolved" if evolved else "base",
			animation_name,
			image.get_size(),
			output_path
		])
	window.queue_free()
	await process_frame
	return output_path


func _pose_actor(
	actor: Node2D,
	sprite: AnimatedSprite2D,
	pet_id: String,
	evolved: bool,
	animation_name: String,
	start_x: float
) -> int:
	if sprite == null or sprite.sprite_frames == null:
		return -1
	if animation_name == "attack":
		if pet_id == "pet5" and not evolved:
			# Base pet5's real battle attack is its rolling walk sequence rather than
			# the ordinary lunge helper used by the other melee pets.
			actor.begin_battle_roll_attack(start_x - 92.0)
			actor.call("_update_battle_roll_attack", 0.045)
		else:
			actor.play_battle_attack_toward(-1.0)
	else:
		sprite.play("idle")
		actor.face_battle_target(-1.0)

	var posed_animation := String(sprite.animation)
	var frame_count := sprite.sprite_frames.get_frame_count(posed_animation)
	var frame_index := 0
	if frame_count > 1:
		frame_index = clampi(int(round(float(frame_count - 1) * 0.58)), 0, frame_count - 1)
	sprite.pause()
	sprite.frame = frame_index
	return frame_index


func _add_cell_chrome(
	window: Window,
	overlay: CanvasLayer,
	pet_id: String,
	evolved: bool,
	animation_name: String,
	pet_index: int,
	cell_origin: Vector2,
	ground_y: float
) -> void:
	var panel := ColorRect.new()
	panel.color = CELL_A if pet_index % 2 == 0 else CELL_B
	panel.position = cell_origin + Vector2(2.0, 2.0)
	panel.size = CELL_SIZE - Vector2(4.0, 4.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = -90
	window.add_child(panel)

	var floor_line := ColorRect.new()
	floor_line.color = FLOOR_COLOR
	floor_line.position = Vector2(cell_origin.x + 10.0, ground_y)
	floor_line.size = Vector2(CELL_SIZE.x - 20.0, 2.0)
	floor_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_line.z_index = -20
	window.add_child(floor_line)

	var definition := PetCatalog.get_runtime_definition(pet_id, evolved)
	var configured_path := String(definition.get(animation_name, ""))
	var sheet_name := configured_path.get_file()
	_add_label(
		overlay,
		"%s  |  %s" % [pet_id.to_upper(), "EVO" if evolved else "BASE"],
		cell_origin + Vector2(12.0, 8.0),
		Vector2(CELL_SIZE.x - 24.0, 26.0),
		17,
		LABEL_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_add_label(
		overlay,
		sheet_name,
		cell_origin + Vector2(12.0, 33.0),
		Vector2(CELL_SIZE.x - 24.0, 22.0),
		11,
		MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT
	)


func _add_pose_metadata(
	overlay: CanvasLayer,
	actor: Node2D,
	sprite: AnimatedSprite2D,
	pet_id: String,
	evolved: bool,
	requested_animation: String,
	frame_index: int,
	cell_origin: Vector2,
	stage_ground_y: float
) -> void:
	if sprite == null or sprite.sprite_frames == null:
		_add_label(
			overlay, "MISSING SPRITE", cell_origin + Vector2(12.0, 62.0),
			Vector2(CELL_SIZE.x - 24.0, 22.0), 13, Color(1.0, 0.3, 0.3),
			HORIZONTAL_ALIGNMENT_LEFT
		)
		return
	var actual_animation := String(sprite.animation)
	var frame_count := sprite.sprite_frames.get_frame_count(actual_animation)
	var frame_texture := sprite.sprite_frames.get_frame_texture(actual_animation, maxi(0, frame_index))
	var visual_bottom := _runtime_visual_bottom(actor, sprite, frame_texture)
	var stage_gap := stage_ground_y - visual_bottom
	var runtime_definition := PetCatalog.get_runtime_definition(pet_id, evolved)
	var configured_contact_y := stage_ground_y + float(runtime_definition.get("ground_offset_y", 0.0))
	var contact_gap := configured_contact_y - visual_bottom
	var pose_text := "%s f%d/%d | flip=%s | floor gap %.1f | contact %.1f" % [
		actual_animation if requested_animation == actual_animation else "%s->%s" % [requested_animation, actual_animation],
		frame_index + 1,
		frame_count,
		"Y" if sprite.flip_h else "N",
		stage_gap,
		contact_gap
	]
	_add_label(
		overlay,
		pose_text,
		cell_origin + Vector2(12.0, CELL_SIZE.y - 27.0),
		Vector2(CELL_SIZE.x - 24.0, 20.0),
		10,
		MUTED_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	print("QA_POSE pet=%s form=%s requested=%s actual=%s frame=%d/%d flip_h=%s stage_gap=%.2f contact_gap=%.2f scale=%.3f" % [
		pet_id,
		"evolved" if evolved else "base",
		requested_animation,
		actual_animation,
		frame_index + 1,
		frame_count,
		sprite.flip_h,
		stage_gap,
		contact_gap,
		absf(sprite.scale.x)
	])


func _runtime_visual_bottom(actor: Node2D, sprite: AnimatedSprite2D, texture: Texture2D) -> float:
	if texture == null:
		return actor.position.y
	var image := texture.get_image()
	if image == null or image.is_empty():
		return actor.position.y
	var visible_bounds := image.get_used_rect()
	if visible_bounds.size == Vector2i.ZERO:
		return actor.position.y
	var local_bottom := float(visible_bounds.end.y) - float(image.get_height()) * 0.5
	return actor.position.y + local_bottom * absf(sprite.scale.y)


func _add_label(
	parent: Node,
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	font_color: Color,
	alignment: HorizontalAlignment
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _print_layering_audit() -> void:
	for pet_id in PET_IDS:
		var base_definition := PetCatalog.get_runtime_definition(pet_id, false)
		var evolved_definition := PetCatalog.get_runtime_definition(pet_id, true)
		var expected_evolved_folder := "/%sEvolved/" % pet_id
		for animation_name in ["idle", "walk", "attack", "closing_eye", "sleep", "burrow"]:
			var base_path := String(base_definition.get(animation_name, ""))
			var evolved_path := String(evolved_definition.get(animation_name, ""))
			var base_uses_evolved := expected_evolved_folder in base_path
			var evolved_uses_base := not evolved_path.is_empty() and expected_evolved_folder not in evolved_path
			var reused_between_forms := not base_path.is_empty() and base_path == evolved_path
			print("QA_LAYER pet=%s anim=%s base=%s evolved=%s base_uses_evo=%s evo_uses_base=%s reused=%s" % [
				pet_id,
				animation_name,
				base_path if not base_path.is_empty() else "<empty>",
				evolved_path if not evolved_path.is_empty() else "<empty>",
				base_uses_evolved,
				evolved_uses_base,
				reused_between_forms
			])
