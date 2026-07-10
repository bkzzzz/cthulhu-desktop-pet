extends RefCounted

const ACTIVE_DESKTOP_PETS := ["octupus1_1", "octupus2_1", "octupus3_1"]
const INVENTORY_STARTER_PETS := ["octupus1_1", "octupus2_1", "octupus3_1"]

const DEFINITIONS := {
	"octupus1_1": {
		"id": "octupus1_1",
		"name": "Octupus 1-1",
		"species": "Octupus",
		"description": "潮湿幼体，适合最早投入信徒供养。",
		"desktop_scale": 1.26,
		"upgrade_cost_base": 10,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.05,
		"power_growth": 1.035,
		"icon": "res://assets/characters/Octupus/octupus1_1.png",
		"idle": "res://assets/characters/OctupusAnimation/octupusIdle1_1.png",
		"walk": "res://assets/characters/OctupusAnimation/octupusWalk1_1.png"
	},
	"octupus2_1": {
		"id": "octupus2_1",
		"name": "Octupus 2-1",
		"species": "Octupus",
		"description": "更活跃的幼体，升级后能承载更多信仰。",
		"desktop_scale": 1.26,
		"upgrade_cost_base": 80,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.35,
		"power_growth": 1.035,
		"icon": "res://assets/characters/Octupus/octupus2_1.png",
		"idle": "res://assets/characters/OctupusAnimation/octupusIdle2_1.png",
		"walk": "res://assets/characters/OctupusAnimation/octupusWalk2_1.png"
	},
	"octupus3_1": {
		"id": "octupus3_1",
		"name": "Octupus 3-1",
		"species": "Octupus",
		"description": "眼状幼体，适合中期投入信徒升级。",
		"desktop_scale": 1.26,
		"upgrade_cost_base": 600,
		"upgrade_cost_growth": 1.17,
		"base_fps": 2.5,
		"power_growth": 1.04,
		"icon": "res://assets/characters/Octupus/octupus3_1.png",
		"idle": "res://assets/characters/OctupusAnimation/octupusIdle3_1.png",
		"walk": "res://assets/characters/OctupusAnimation/OctupusWalk3_1.png"
	}
}

const SHEET_COLUMNS := 4
const SHEET_ROWS := 3
const SHEET_FRAME_CENTER_Y := 64.0
const SHEET_FRAME_FOOT_Y := 102
const CHROMA_KEY_TOLERANCE := 0.075

static var _frame_cache := {}


static func get_definition(pet_id: String) -> Dictionary:
	if DEFINITIONS.has(pet_id):
		return DEFINITIONS[pet_id]

	return DEFINITIONS[ACTIVE_DESKTOP_PETS[0]]


static func make_inventory_entry(pet_id: String) -> Dictionary:
	var pet_data := get_definition(pet_id)
	return {
		"id": String(pet_data.get("id", pet_id)),
		"name": String(pet_data.get("name", pet_id)),
		"texture": String(pet_data.get("icon", ""))
	}


static func make_inventory_entries(pet_ids: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id in pet_ids:
		entries.append(make_inventory_entry(String(pet_id)))
	return entries


static func build_frames(pet_id: String) -> SpriteFrames:
	var cached_frames := _frame_cache.get(pet_id) as SpriteFrames
	if cached_frames != null:
		return cached_frames

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var pet_data := get_definition(pet_id)
	_add_sheet_animation(frames, "idle", String(pet_data.get("idle", "")), 4.8)
	_add_sheet_animation(frames, "walk", String(pet_data.get("walk", "")), 9.0)

	if not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		frames.add_animation("idle")
		var fallback := load(String(pet_data.get("icon", ""))) as Texture2D
		if fallback != null:
			frames.add_frame("idle", fallback)
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 1.0)

	if not frames.has_animation("walk") or frames.get_frame_count("walk") == 0:
		frames.add_animation("walk")
		for index in frames.get_frame_count("idle"):
			frames.add_frame("walk", frames.get_frame_texture("idle", index))
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 1.0)

	_frame_cache[pet_id] = frames
	return frames


static func make_icon_texture(texture_path: String, padding := 8) -> Texture2D:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO or bounds.size == image.get_size():
		return texture

	var crop_position := Vector2i(
		maxi(0, bounds.position.x - padding),
		maxi(0, bounds.position.y - padding)
	)
	var crop_end := Vector2i(
		mini(image.get_width(), bounds.position.x + bounds.size.x + padding),
		mini(image.get_height(), bounds.position.y + bounds.size.y + padding)
	)
	var crop_size := crop_end - crop_position
	var cropped := Image.create_empty(crop_size.x, crop_size.y, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0.0, 0.0, 0.0, 0.0))
	cropped.blit_rect(image, Rect2i(crop_position, crop_size), Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


static func _add_sheet_animation(frames: SpriteFrames, animation_name: String, sheet_path: String, speed: float) -> void:
	if sheet_path.is_empty():
		return

	var sheet_texture := load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_warning("Missing pet animation sheet: %s" % sheet_path)
		return

	var source_image := sheet_texture.get_image()
	if source_image == null or source_image.is_empty():
		push_warning("Could not read pet animation sheet: %s" % sheet_path)
		return

	source_image.convert(Image.FORMAT_RGBA8)
	var frame_size := Vector2i(
		int(source_image.get_width() / float(SHEET_COLUMNS)),
		int(source_image.get_height() / float(SHEET_ROWS))
	)
	var key_color := source_image.get_pixel(0, 0)

	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, speed)

	for row in SHEET_ROWS:
		for column in SHEET_COLUMNS:
			var frame_image := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			var source_rect := Rect2i(Vector2i(column * frame_size.x, row * frame_size.y), frame_size)
			frame_image.blit_rect(source_image, source_rect, Vector2i.ZERO)
			_apply_chroma_key(frame_image, key_color)
			frame_image = _align_frame_to_floor(frame_image)
			frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))


static func _apply_chroma_key(image: Image, key_color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if _color_distance(color, key_color) <= CHROMA_KEY_TOLERANCE:
				color.a = 0.0
				image.set_pixel(x, y, color)


static func _align_frame_to_floor(image: Image) -> Image:
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO:
		return image

	var visible_bottom := bounds.position.y + bounds.size.y - 1
	var offset_y := SHEET_FRAME_FOOT_Y - visible_bottom
	if offset_y == 0:
		return image

	var aligned := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	aligned.fill(Color(0.0, 0.0, 0.0, 0.0))
	aligned.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, offset_y))
	return aligned


static func _get_visible_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt((dr * dr) + (dg * dg) + (db * db))
