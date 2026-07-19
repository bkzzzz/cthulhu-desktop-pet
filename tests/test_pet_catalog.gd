extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected_pets := [
		"pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
		"pet8", "pet9", "pet10"
	]
	var desktop_scales := {}
	var behavior_styles := {}
	var minimum_scale := INF
	var maximum_scale := 0.0
	if PetCatalog.ACTIVE_DESKTOP_PETS != expected_pets:
		failures.append("the ten current pets must be active in authored order")
	if PetCatalog.STARTER_UNLOCKED_PETS != ["pet1"]:
		failures.append("only pet1 may be unlocked at the start of a fresh game")
	if PetCatalog.INVENTORY_STARTER_PETS != ["pet1"]:
		failures.append("the starter roster must not expose gacha pets")
	if PetCatalog.GACHA_PETS != expected_pets.slice(1):
		failures.append("pet2 through pet10 must be acquired through pet gacha")
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var definition := PetCatalog.get_definition(pet_id)
		var english_name := PetCatalog.get_localized_name(pet_id, "en")
		if english_name.is_empty() or english_name == String(definition.get("name", "")):
			failures.append("%s must expose a distinct English default name" % pet_id)
		if PetCatalog.get_localized_field(pet_id, "personality", "en").is_empty():
			failures.append("%s must expose English profile copy" % pet_id)
		if PetCatalog.can_evolve(pet_id) and PetCatalog.get_localized_evolution_name(pet_id, "en").is_empty():
			failures.append("%s must expose an English evolution name" % pet_id)
		var behavior_style := String(definition.get("behavior", ""))
		behavior_styles[behavior_style] = true
		if behavior_style.is_empty():
			failures.append("%s must define a behavior style" % pet_id)
		var desktop_scale := float(definition.get("desktop_scale", 0.0))
		desktop_scales[desktop_scale] = true
		minimum_scale = minf(minimum_scale, desktop_scale)
		maximum_scale = maxf(maximum_scale, desktop_scale)
		if desktop_scale <= 0.0 or desktop_scale > 1.25:
			failures.append("%s desktop scale must be within (0, 1.25]" % pet_id)
		var total_special_chance := (
			float(definition.get("special_chance", 0.0))
			+ float(definition.get("air_roam_chance", 0.0))
			+ float(definition.get("doze_chance", 0.0))
			+ float(definition.get("hide_chance", 0.0))
			+ float(definition.get("wall_chance", 0.0))
		)
		if total_special_chance > 1.0:
			failures.append("%s special action chances must not exceed 1" % pet_id)
		var activity_chance := float(definition.get("activity_chance", 1.0))
		if activity_chance <= 0.0 or activity_chance > 0.25:
			failures.append("%s must use a low activity gate so idle remains its primary state" % pet_id)
		if float(definition.get("idle_time_min", 0.0)) < 8.0:
			failures.append("%s minimum idle interval must prevent constant movement" % pet_id)
		var can_hide := bool(definition.get("can_hide", false))
		if can_hide != (pet_id == "pet2"):
			failures.append("only pet2 may use the folder hide-and-pop behavior")
		if pet_id != "pet2" and float(definition.get("hide_chance", 0.0)) > 0.0:
			failures.append("non-pet2 creatures must keep hide chance disabled")
		if float(definition.get("ambient_emotion_interval_min", 0.0)) < 120.0:
			failures.append("%s ambient emotions must be infrequent" % pet_id)
		for key in ["icon", "idle"]:
			var path := String(definition.get(key, ""))
			if path.is_empty() or not FileAccess.file_exists(path):
				failures.append("%s must provide %s" % [pet_id, key])
		var frames := PetCatalog.build_frames(pet_id)
		var expected_idle_count := 1 if pet_id == "pet5" else (10 if pet_id == "pet10" else 12)
		var expected_walk_count := 10 if pet_id == "pet10" else 12
		if frames.get_frame_count("idle") != expected_idle_count:
			failures.append("%s idle must contain %d authored frames" % [pet_id, expected_idle_count])
		if frames.get_frame_count("walk") != expected_walk_count:
			failures.append("%s walk must contain %d authored frames" % [pet_id, expected_walk_count])
		if float(definition.get("base_fps", 0.0)) <= 0.0:
			failures.append("%s must produce faith" % pet_id)
		if float(definition.get("base_money_rate", 4.0 + float(definition.get("rarity_stars", 1)) * 3.0)) <= 0.0:
			failures.append("%s must produce collectible dropped money" % pet_id)
		var rarity_stars := int(definition.get("rarity_stars", 0))
		if rarity_stars < 1 or rarity_stars > 5:
			failures.append("%s rarity must be represented by one to five stars" % pet_id)
		if String(definition.get("age", "")).strip_edges().is_empty():
			failures.append("%s must provide an age description" % pet_id)
		if String(definition.get("personality", "")).strip_edges().is_empty():
			failures.append("%s must provide a personality description" % pet_id)
		for removed_key in ["evolution_thresholds", "evolution_names", "evolution_multipliers"]:
			if definition.has(removed_key):
				failures.append("%s must not retain removed progression field %s" % [pet_id, removed_key])
		var walk_distance_min := float(definition.get("walk_distance_min", 0.0))
		var walk_distance_max := float(definition.get("walk_distance_max", 0.0))
		if walk_distance_min <= 0.0 or walk_distance_max <= walk_distance_min:
			failures.append("%s must define its own valid walking distance range" % pet_id)
		var emotion_weights: Dictionary = definition.get("emotion_weights", {})
		if emotion_weights.size() < 3:
			failures.append("%s must define a varied personality emotion profile" % pet_id)
		if emotion_weights.has("hungry"):
			failures.append("%s personality must not use the removed hunger emotion" % pet_id)
	for new_pet_id in ["pet8", "pet9"]:
		if float(PetCatalog.get_definition(new_pet_id).get("desktop_scale", 0.0)) < 0.90:
			failures.append("%s must visually match the established desktop pet size" % new_pet_id)
	var base_pet10_scale := float(PetCatalog.get_definition("pet10").get("desktop_scale", 0.0))
	var evolved_pet10_scale := float(PetCatalog.get_evolution_definition("pet10").get("desktop_scale", 0.0))
	if base_pet10_scale > 0.72:
		failures.append("base pet10 must retain its deliberately small juvenile silhouette")
	if evolved_pet10_scale <= base_pet10_scale:
		failures.append("pet10 evolution must unlock a visibly larger authored scale")
	_test_new_pet_animation_preserves_pixels(failures)
	if desktop_scales.size() == 1:
		failures.append("desktop pets must use varied sizes")
	if behavior_styles.size() < 6:
		failures.append("the expanded desktop roster must retain varied behavior styles")
	if minimum_scale > 0.7:
		failures.append("the smallest desktop pet must be visibly small")
	if maximum_scale - minimum_scale < 0.45:
		failures.append("desktop pet sizes must have a clear visual range")
	for climbing_pet_id in ["pet1", "pet4"]:
		if float(PetCatalog.get_definition(climbing_pet_id).get("wall_chance", 0.0)) <= 0.0:
			failures.append("%s must occasionally climb a screen edge" % climbing_pet_id)
		if not bool(PetCatalog.get_definition(climbing_pet_id).get("can_wall_crawl", false)):
			failures.append("%s wall-crawl chance must be backed by explicit permission" % climbing_pet_id)
	for ground_pet_id in ["pet2", "pet3", "pet5", "pet6", "pet7", "pet9"]:
		if float(PetCatalog.get_definition(ground_pet_id).get("wall_chance", 0.0)) > 0.0:
			failures.append("%s must remain a ground-only pet" % ground_pet_id)
		if bool(PetCatalog.get_definition(ground_pet_id).get("can_wall_crawl", false)):
			failures.append("%s must explicitly forbid wall crawling" % ground_pet_id)
	for ground_pet_id in ["pet1", "pet3", "pet4", "pet5", "pet6", "pet7"]:
		var offset := float(PetCatalog.get_definition(ground_pet_id).get("ground_offset_y", -99.0))
		if not is_zero_approx(offset):
			failures.append("%s must use the shared pixel-exact taskbar foot line" % ground_pet_id)
	if float(PetCatalog.get_definition("pet2").get("air_roam_chance", 0.0)) <= 0.0:
		failures.append("pet2 must occasionally roam above the taskbar")
	if PetCatalog.choose_weighted_emotion("pet2", 0.1) != "sleepy":
		failures.append("pet2 personality must strongly prefer sleepy emotions")
	var pet2_frames := PetCatalog.build_frames("pet2")
	var pet2_definition := PetCatalog.get_definition("pet2")
	if (
		String(pet2_definition.get("walk", "")) != String(pet2_definition.get("idle", ""))
		or String(pet2_definition.get("attack", "")) != String(pet2_definition.get("idle", ""))
	):
		failures.append("base pet2 must deliberately reuse its floating cycle for idle, walk, and ranged attack")
	_check_frame_count(failures, pet2_frames, "close_eye", 16)
	_check_frame_count(failures, pet2_frames, "open_eye", 16)
	_check_frame_count(failures, pet2_frames, "sleep", 7)
	var pet3_frames := PetCatalog.build_frames("pet3")
	_check_frame_count(failures, pet3_frames, "attack", 12)
	_check_frame_count(failures, pet3_frames, "burrow", 12)
	_check_frame_count(failures, pet3_frames, "emerge", 12)
	var pet5_frames := PetCatalog.build_frames("pet5")
	_check_frame_count(failures, pet5_frames, "idle", 1)
	_check_frame_count(failures, pet5_frames, "walk", 12)
	_check_frame_count(failures, pet5_frames, "attack", 12)
	if float(PetCatalog.get_definition("pet5").get("desktop_scale", 99.0)) > 0.95:
		failures.append("base pet5's full-frame ball must stay compact")
	var pet6_definition := PetCatalog.get_definition("pet6")
	if bool(pet6_definition.get("align_frames_to_floor", true)):
		failures.append("pet6 must preserve its authored frame rather than vertically rewriting it")
	if bool(pet6_definition.get("faces_right", true)) or bool(pet6_definition.get("attack_faces_right", true)):
		failures.append("base pet6 art is authored facing left for both movement and attack")
	var pet6_frames := PetCatalog.build_frames("pet6")
	var pet6_idle_frame := pet6_frames.get_frame_texture("idle", 0).get_image()
	if pet6_idle_frame.get_size() != Vector2i(128, 128):
		failures.append("base pet6 sheets must slice into 128x128 frames")
	var pet7_definition := PetCatalog.get_definition("pet7")
	if float(pet7_definition.get("desktop_scale", 0.0)) < 0.65:
		failures.append("base pet7's coin must remain clearly visible at low levels")
	if float(PetCatalog.get_evolution_definition("pet7").get("desktop_scale", 0.0)) < 0.50:
		failures.append("evolved pet7's coin must not retain its old undersized scale")
	if not bool(pet7_definition.get("rolls_while_walking", false)):
		failures.append("pet7 must roll its idle art while walking")
	if not is_zero_approx(float(pet7_definition.get("ground_offset_y", -99.0))):
		failures.append("pet7 must use the shared taskbar contact line without clipping below it")
	var pet7_frames := PetCatalog.build_frames("pet7")
	_check_frame_count(failures, pet7_frames, "idle", 12)
	_check_frame_count(failures, pet7_frames, "walk", 12)
	for pet_id in ["pet7", "pet8", "pet9"]:
		var frames := PetCatalog.build_frames(pet_id)
		_check_frame_count(failures, frames, "idle", 12)
		_check_frame_count(failures, frames, "walk", 12)
		_check_frame_count(failures, frames, "attack", 12)
		var unified_path := String(PetCatalog.get_definition(pet_id).get("idle", ""))
		if (
			String(PetCatalog.get_definition(pet_id).get("walk", "")) != unified_path
			or String(PetCatalog.get_definition(pet_id).get("attack", "")) != unified_path
		):
			failures.append("%s must keep idle, movement, and attack on its unified authored sheet" % pet_id)
	var pet10_frames := PetCatalog.build_frames("pet10")
	for animation_name in ["idle", "walk", "attack"]:
		_check_frame_count(failures, pet10_frames, animation_name, 10)
	var icon_path := String(PetCatalog.get_definition("pet10").get("icon", ""))
	var first_icon := PetCatalog.make_icon_texture(icon_path, 12)
	var cached_icon := PetCatalog.make_icon_texture(icon_path, 6)
	if first_icon == null or cached_icon == null or first_icon.get_instance_id() != cached_icon.get_instance_id():
		failures.append("inventory icon cropping must be cached instead of rescanning pixels throughout recovery")
	return failures


static func _test_new_pet_animation_preserves_pixels(failures: Array[String]) -> void:
	for pet_id in ["pet8", "pet9", "pet10"]:
		var definition := PetCatalog.get_definition(pet_id)
		var built_frames := PetCatalog.build_frames(pet_id)
		var animations := ["idle", "walk", "attack"]
		for animation_name in animations:
			var sheet_path := String(definition.get(animation_name, ""))
			var sheet_texture := load(sheet_path) as Texture2D
			if sheet_texture == null:
				continue
			var sheet_image := sheet_texture.get_image()
			sheet_image.convert(Image.FORMAT_RGBA8)
			var frame_size := Vector2i(sheet_image.get_width() / 4, sheet_image.get_height() / 3)
			var key_color := sheet_image.get_pixel(0, 0)
			for frame_index in built_frames.get_frame_count(animation_name):
				var source_frame := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
				source_frame.blit_rect(
					sheet_image,
					Rect2i(Vector2i((frame_index % 4) * frame_size.x, (frame_index / 4) * frame_size.y), frame_size),
					Vector2i.ZERO
				)
				PetCatalog._apply_chroma_key(source_frame, key_color)
				var built_image := built_frames.get_frame_texture(animation_name, frame_index).get_image()
				if _count_visible_pixels(built_image) < _count_visible_pixels(source_frame):
					failures.append("%s %s frame %d must not crop the creature's head or silhouette" % [pet_id, animation_name, frame_index])
					break


static func _count_visible_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.02:
				count += 1
	return count


static func _check_frame_count(failures: Array[String], frames: SpriteFrames, animation_name: String, expected: int) -> void:
	var actual := frames.get_frame_count(animation_name)
	if actual != expected:
		failures.append("%s must contain %d frames, got %d" % [animation_name, expected, actual])
