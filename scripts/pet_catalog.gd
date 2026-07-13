extends RefCounted

const ACTIVE_DESKTOP_PETS := ["pet1", "pet2", "pet3", "pet4", "pet5"]
const INVENTORY_STARTER_PETS := ["pet1", "pet2", "pet3", "pet4", "pet5"]

const DEFINITIONS := {
	"pet1": {
		"id": "pet1",
		"name": "腐生眷族",
		"species": "异形眷族",
		"description": "伏地蠕行的腐生眷族，擅长稳定积累信仰。",
		"desktop_scale": 0.92,
		"behavior": "skitterer",
		"walk_speed": 72.0,
		"walk_speed_variance": 10.0,
		"walk_distance_min": 90.0,
		"walk_distance_max": 280.0,
		"idle_time_min": 0.35,
		"idle_time_max": 1.6,
		"special_chance": 0.0,
		"wall_chance": 0.25,
		"frame_center_y": 64.0,
		"frame_foot_y": 105,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 18.0,
		"ambient_emotion_interval_max": 34.0,
		"emotion_weights": {"happy": 0.34, "suprised": 0.40, "confused": 0.18, "sleepy": 0.08},
		"petting_emotion_weights": {"happy": 0.38, "suprised": 0.42, "confused": 0.16, "sleepy": 0.04},
		"evolution_thresholds": [100, 1000],
		"evolution_names": ["腐芽蜕变", "腐生领主"],
		"evolution_multipliers": [1.0, 1.55, 2.45],
		"upgrade_cost_base": 1,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.0025,
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
		"desktop_scale": 0.62,
		"behavior": "sleepy_floater",
		"walk_speed": 24.0,
		"walk_speed_variance": 5.0,
		"walk_distance_min": 120.0,
		"walk_distance_max": 360.0,
		"idle_time_min": 0.7,
		"idle_time_max": 2.2,
		"special_chance": 0.64,
		"air_roam_chance": 0.30,
		"air_roam_legs_min": 2,
		"air_roam_legs_max": 5,
		"float_bob_amplitude": 30.0,
		"special_time_min": 10.0,
		"special_time_max": 24.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 112,
		"ground_offset_y": -86.0,
		"faces_right": true,
		"ambient_emotion_interval_min": 10.0,
		"ambient_emotion_interval_max": 22.0,
		"emotion_weights": {"sleepy": 0.70, "confused": 0.13, "happy": 0.10, "suprised": 0.07},
		"petting_emotion_weights": {"sleepy": 0.68, "happy": 0.16, "confused": 0.12, "suprised": 0.04},
		"evolution_thresholds": [200, 2000],
		"evolution_names": ["深渊梦眼", "永眠凝视者"],
		"evolution_multipliers": [1.0, 1.60, 2.55],
		"upgrade_cost_base": 2,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.00875,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet2/pet2.png",
		"idle": "res://assets/NewCharacters/pet2/pet2Idle.png",
		"walk": "",
		"closing_eye": "res://assets/NewCharacters/pet2/pet2ClosingEye.png",
		"sleep": "res://assets/NewCharacters/pet2/pet2Sleep.png"
	},
	"pet3": {
		"id": "pet3",
		"name": "掘地幼兽",
		"species": "穴居眷族",
		"description": "喜欢钻入阴影的穴居幼兽，会从地底收集散落的信仰。",
		"desktop_scale": 1.08,
		"behavior": "burrower",
		"walk_speed": 46.0,
		"walk_speed_variance": 8.0,
		"walk_distance_min": 36.0,
		"walk_distance_max": 132.0,
		"idle_time_min": 0.4,
		"idle_time_max": 1.45,
		"special_chance": 0.72,
		"special_time_min": 1.3,
		"special_time_max": 3.6,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 16.0,
		"ambient_emotion_interval_max": 32.0,
		"emotion_weights": {"confused": 0.44, "suprised": 0.28, "happy": 0.20, "sleepy": 0.08},
		"petting_emotion_weights": {"confused": 0.48, "suprised": 0.27, "happy": 0.20, "sleepy": 0.05},
		"evolution_thresholds": [500, 5000],
		"evolution_names": ["掘影兽", "地渊吞噬者"],
		"evolution_multipliers": [1.0, 1.65, 2.65],
		"upgrade_cost_base": 11,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.0375,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet3/pet3.png",
		"idle": "res://assets/NewCharacters/pet3/pet3Idle.png",
		"walk": "res://assets/NewCharacters/pet3/pet3Walk.png",
		"burrow": "res://assets/NewCharacters/pet3/pet3BurrowUnder.png"
	},
	"pet4": {
		"id": "pet4",
		"name": "星海蠕兽",
		"species": "星海眷族",
		"description": "从群星间漂来的柔软眷族，步伐迟缓却能放大低语。",
		"desktop_scale": 0.78,
		"behavior": "watcher",
		"walk_speed": 16.0,
		"walk_speed_variance": 2.5,
		"walk_distance_min": 180.0,
		"walk_distance_max": 620.0,
		"idle_time_min": 5.0,
		"idle_time_max": 11.0,
		"special_chance": 0.0,
		"wall_chance": 0.35,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 22.0,
		"ambient_emotion_interval_max": 46.0,
		"emotion_weights": {"happy": 0.42, "sleepy": 0.30, "confused": 0.18, "suprised": 0.10},
		"petting_emotion_weights": {"happy": 0.46, "sleepy": 0.28, "confused": 0.18, "suprised": 0.08},
		"evolution_thresholds": [1000, 10000],
		"evolution_names": ["星潮蠕兽", "群星牧者"],
		"evolution_multipliers": [1.0, 1.70, 2.75],
		"upgrade_cost_base": 55,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.15,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet4/pet4.png",
		"idle": "res://assets/NewCharacters/pet4/pet4Idle.png",
		"walk": "res://assets/NewCharacters/pet4/pet4Walk.png"
	},
	"pet5": {
		"id": "pet5",
		"name": "月影巨口",
		"species": "噬梦眷族",
		"description": "吞食噩梦与月光的古怪生灵，饱餐后会散播浓烈的信仰。",
		"desktop_scale": 1.25,
		"behavior": "wall_climber",
		"walk_speed": 27.0,
		"walk_speed_variance": 5.0,
		"walk_distance_min": 72.0,
		"walk_distance_max": 220.0,
		"idle_time_min": 1.2,
		"idle_time_max": 3.8,
		"special_chance": 0.0,
		"wall_chance": 0.55,
		"special_time_min": 1.0,
		"special_time_max": 4.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 14.0,
		"ambient_emotion_interval_max": 28.0,
		"emotion_weights": {"suprised": 0.42, "happy": 0.28, "confused": 0.20, "sleepy": 0.10},
		"petting_emotion_weights": {"suprised": 0.48, "happy": 0.27, "confused": 0.19, "sleepy": 0.06},
		"evolution_thresholds": [2000, 20000],
		"evolution_names": ["噬梦巨口", "月蚀吞星者"],
		"evolution_multipliers": [1.0, 1.75, 2.90],
		"upgrade_cost_base": 300,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.625,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet5/pet5.png",
		"idle": "res://assets/NewCharacters/pet5/pet5Idle.png",
		"walk": "res://assets/NewCharacters/pet5/pet5Walk.png"
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


static func choose_weighted_emotion(pet_id: String, unit_roll: float, weights_key := "emotion_weights") -> String:
	var weights_value: Variant = get_definition(pet_id).get(weights_key, {})
	if not weights_value is Dictionary:
		return "happy"
	var weights: Dictionary = weights_value
	var total := 0.0
	for emotion_value in weights:
		total += maxf(0.0, float(weights[emotion_value]))
	if total <= 0.0:
		return "happy"

	var target := clampf(unit_roll, 0.0, 0.999999) * total
	var accumulated := 0.0
	for emotion_value in weights:
		accumulated += maxf(0.0, float(weights[emotion_value]))
		if target < accumulated:
			return String(emotion_value)
	return String(weights.keys().back())


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
	_add_sheet_animation(frames, "close_eye", String(pet_data.get("closing_eye", "")), 10.0, frame_foot_y, 4, 4, false)
	_add_sheet_animation(frames, "sleep", String(pet_data.get("sleep", "")), 3.5, frame_foot_y, 4, 2, true, true)
	_add_sheet_animation(frames, "burrow", String(pet_data.get("burrow", "")), 9.0, frame_foot_y, 4, 3, false)
	_add_reversed_animation(frames, "close_eye", "open_eye")
	_add_reversed_animation(frames, "burrow", "emerge")

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


static func _add_sheet_animation(
	frames: SpriteFrames,
	animation_name: String,
	sheet_path: String,
	speed: float,
	frame_foot_y: int,
	columns := SHEET_COLUMNS,
	rows := SHEET_ROWS,
	loop := true,
	skip_empty_frames := false
) -> void:
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
		int(source_image.get_width() / float(columns)),
		int(source_image.get_height() / float(rows))
	)
	var key_color := source_image.get_pixel(0, 0)

	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)

	for row in rows:
		for column in columns:
			var frame_image := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			var source_rect := Rect2i(Vector2i(column * frame_size.x, row * frame_size.y), frame_size)
			frame_image.blit_rect(source_image, source_rect, Vector2i.ZERO)
			_apply_chroma_key(frame_image, key_color)
			if skip_empty_frames and _get_visible_bounds(frame_image).size == Vector2i.ZERO:
				continue
			frame_image = _align_frame_to_floor(frame_image, frame_foot_y)
			frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))


static func _add_reversed_animation(frames: SpriteFrames, source_name: String, target_name: String) -> void:
	if not frames.has_animation(source_name):
		return
	var frame_count := frames.get_frame_count(source_name)
	if frame_count == 0:
		return

	frames.add_animation(target_name)
	frames.set_animation_loop(target_name, false)
	frames.set_animation_speed(target_name, frames.get_animation_speed(source_name))
	for index in range(frame_count - 1, -1, -1):
		frames.add_frame(target_name, frames.get_frame_texture(source_name, index))


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
