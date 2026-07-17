extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected_pets := [
		"pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
		"pet8", "pet9", "pet10", "pet11"
	]
	var desktop_scales := {}
	var behavior_styles := {}
	var minimum_scale := INF
	var maximum_scale := 0.0
	if PetCatalog.ACTIVE_DESKTOP_PETS != expected_pets:
		failures.append("all eleven pets must be active")
	if PetCatalog.STARTER_UNLOCKED_PETS != ["pet1"]:
		failures.append("only pet1 may be unlocked at the start of a fresh game")
	if PetCatalog.INVENTORY_STARTER_PETS != ["pet1"]:
		failures.append("the starter roster must not expose gacha pets")
	if PetCatalog.GACHA_PETS != expected_pets.slice(1):
		failures.append("pet2 through pet11 must be acquired through pet gacha")
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var definition := PetCatalog.get_definition(pet_id)
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
		if frames.get_frame_count("idle") != 12:
			failures.append("%s idle must contain 12 frames" % pet_id)
		if frames.get_frame_count("walk") != 12:
			failures.append("%s walk fallback must contain 12 frames" % pet_id)
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
	for new_pet_id in ["pet8", "pet9", "pet10", "pet11"]:
		if float(PetCatalog.get_definition(new_pet_id).get("desktop_scale", 0.0)) < 0.90:
			failures.append("%s must visually match the established desktop pet size" % new_pet_id)
	if desktop_scales.size() == 1:
		failures.append("desktop pets must use varied sizes")
	if behavior_styles.size() < 6:
		failures.append("the expanded desktop roster must retain varied behavior styles")
	if minimum_scale > 0.7:
		failures.append("the smallest desktop pet must be visibly small")
	if maximum_scale - minimum_scale < 0.6:
		failures.append("desktop pet sizes must have a clear visual range")
	for climbing_pet_id in ["pet1", "pet4", "pet5"]:
		if float(PetCatalog.get_definition(climbing_pet_id).get("wall_chance", 0.0)) <= 0.0:
			failures.append("%s must occasionally climb a screen edge" % climbing_pet_id)
		if not bool(PetCatalog.get_definition(climbing_pet_id).get("can_wall_crawl", false)):
			failures.append("%s wall-crawl chance must be backed by explicit permission" % climbing_pet_id)
	for ground_pet_id in ["pet2", "pet3", "pet6", "pet7", "pet9"]:
		if float(PetCatalog.get_definition(ground_pet_id).get("wall_chance", 0.0)) > 0.0:
			failures.append("%s must remain a ground-only pet" % ground_pet_id)
		if bool(PetCatalog.get_definition(ground_pet_id).get("can_wall_crawl", false)):
			failures.append("%s must explicitly forbid wall crawling" % ground_pet_id)
	for ground_pet_id in ["pet1", "pet3", "pet4", "pet5", "pet6"]:
		var offset := float(PetCatalog.get_definition(ground_pet_id).get("ground_offset_y", -99.0))
		if not is_zero_approx(offset):
			failures.append("%s must use the shared pixel-exact taskbar foot line" % ground_pet_id)
	if float(PetCatalog.get_definition("pet2").get("air_roam_chance", 0.0)) <= 0.0:
		failures.append("pet2 must occasionally roam above the taskbar")
	if PetCatalog.choose_weighted_emotion("pet2", 0.1) != "sleepy":
		failures.append("pet2 personality must strongly prefer sleepy emotions")
	var pet2_frames := PetCatalog.build_frames("pet2")
	_check_frame_count(failures, pet2_frames, "close_eye", 16)
	_check_frame_count(failures, pet2_frames, "open_eye", 16)
	_check_frame_count(failures, pet2_frames, "sleep", 7)
	var pet3_frames := PetCatalog.build_frames("pet3")
	_check_frame_count(failures, pet3_frames, "burrow", 12)
	_check_frame_count(failures, pet3_frames, "emerge", 12)
	var pet6_definition := PetCatalog.get_definition("pet6")
	if bool(pet6_definition.get("align_frames_to_floor", true)):
		failures.append("pet6 must preserve its authored foot line instead of aligning its lower hands")
	if int(pet6_definition.get("frame_foot_y", 0)) != 232:
		failures.append("pet6 must use its authored y=232 body/foot contact line")
	var pet6_frames := PetCatalog.build_frames("pet6")
	var pet6_idle_frame := pet6_frames.get_frame_texture("idle", 0).get_image()
	if pet6_idle_frame.get_size() != Vector2i(256, 256):
		failures.append("pet6's 1024x768 sheets must slice into 256x256 frames")
	var pet7_definition := PetCatalog.get_definition("pet7")
	if not bool(pet7_definition.get("rolls_while_walking", false)):
		failures.append("pet7 must roll its idle art while walking")
	if float(pet7_definition.get("ground_offset_y", 0.0)) <= 0.0:
		failures.append("pet7 must sit slightly lower on the taskbar contact line")
	var pet7_frames := PetCatalog.build_frames("pet7")
	_check_frame_count(failures, pet7_frames, "idle", 12)
	_check_frame_count(failures, pet7_frames, "walk", 12)
	for pet_id in ["pet8", "pet9", "pet10", "pet11"]:
		var frames := PetCatalog.build_frames(pet_id)
		_check_frame_count(failures, frames, "idle", 12)
		_check_frame_count(failures, frames, "walk", 12)
	var pet9_definition := PetCatalog.get_definition("pet9")
	if String(pet9_definition.get("walk", "")).is_empty():
		failures.append("pet9 must use its dedicated walk animation sheet")
	for idle_mover_id in ["pet8", "pet10", "pet11"]:
		if not String(PetCatalog.get_definition(idle_mover_id).get("walk", "")).is_empty():
			failures.append("%s must move by reusing its idle animation" % idle_mover_id)
	return failures


static func _check_frame_count(failures: Array[String], frames: SpriteFrames, animation_name: String, expected: int) -> void:
	var actual := frames.get_frame_count(animation_name)
	if actual != expected:
		failures.append("%s must contain %d frames, got %d" % [animation_name, expected, actual])
