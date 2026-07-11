extends RefCounted

const ACTIVE_DESKTOP_PETS := ["pet1", "pet2"]
const INVENTORY_STARTER_PETS := ["pet1", "pet2"]

const DEFINITIONS := {
	"pet1": {
		"id": "pet1",
		"name": "腐生眷族",
		"species": "异形眷族",
		"description": "伏地蠕行的腐生眷族，擅长稳定积累信仰。",
		"desktop_scale": 1.25,
		"frame_center_y": 64.0,
		"frame_foot_y": 105,
		"upgrade_cost_base": 10,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.05,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet1/pet1.png",
		"idle": "res://assets/NewCharacters/pet1/pet1Idle.png",
		"walk": "res://assets/NewCharacters/pet1/pet1Walk.png"
	},
	"pet2": {
		"id": "pet2",
		"name": "深渊凝视",
		"species": "深渊眷族",
		"description": "睁开巨眼的深渊眷族，以凝视汇聚更强的信仰。",
		"desktop_scale": 1.25,
		"frame_center_y": 64.0,
		"frame_foot_y": 112,
		"upgrade_cost_base": 80,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.35,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet2/pet2.png",
		"idle": "res://assets/NewCharacters/pet2/pet2Idle.png",
		"walk": ""
	}
}

const SHEET_COLUMNS := 4
const SHEET_ROWS := 3
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
	var frame_foot_y := int(pet_data.get("frame_foot_y", 102))
	_add_sheet_animation(frames, "idle", String(pet_data.get("idle", "")), 4.8, frame_foot_y)
	_add_sheet_animation(frames, "walk", String(pet_data.get("walk", "")), 9.0, frame_foot_y)

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


static func _add_sheet_animation(frames: SpriteFrames, animation_name: String, sheet_path: String, speed: float, frame_foot_y: int) -> void:
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
			frame_image = _align_frame_to_floor(frame_image, frame_foot_y)
			frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))


static func _apply_chroma_key(image: Image, key_color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if _color_distance(color, key_color) <= CHROMA_KEY_TOLERANCE:
				color.a = 0.0
				image.set_pixel(x, y, color)


static func _align_frame_to_floor(image: Image, frame_foot_y: int) -> Image:
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO:
		return image

	var visible_bottom := bounds.position.y + bounds.size.y - 1
	var offset_y := frame_foot_y - visible_bottom
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
