extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected_pets := ["pet1", "pet2", "pet3", "pet4", "pet5"]
	var desktop_scales := {}
	var behavior_styles := {}
	var minimum_scale := INF
	var maximum_scale := 0.0
	var previous_first_evolution := 0
	var previous_second_evolution := 0
	if PetCatalog.ACTIVE_DESKTOP_PETS != expected_pets:
		failures.append("all five pets must be active")
	if PetCatalog.INVENTORY_STARTER_PETS != expected_pets:
		failures.append("all five pets must be available to inventory")
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
			+ float(definition.get("wall_chance", 0.0))
		)
		if total_special_chance > 1.0:
			failures.append("%s special action chances must not exceed 1" % pet_id)
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
		var walk_distance_min := float(definition.get("walk_distance_min", 0.0))
		var walk_distance_max := float(definition.get("walk_distance_max", 0.0))
		if walk_distance_min <= 0.0 or walk_distance_max <= walk_distance_min:
			failures.append("%s must define its own valid walking distance range" % pet_id)
		var emotion_weights: Dictionary = definition.get("emotion_weights", {})
		if emotion_weights.size() < 3:
			failures.append("%s must define a varied personality emotion profile" % pet_id)
		if emotion_weights.has("hungry"):
			failures.append("%s personality must not use the removed hunger emotion" % pet_id)
		var thresholds: Array = definition.get("evolution_thresholds", [])
		if thresholds.size() != 2 or int(thresholds[0]) <= 0 or int(thresholds[1]) <= int(thresholds[0]):
			failures.append("%s must define exactly two increasing evolution thresholds" % pet_id)
		elif int(thresholds[0]) < previous_first_evolution or int(thresholds[1]) < previous_second_evolution:
			failures.append("later pets must not evolve sooner or more cheaply than earlier pets")
		else:
			previous_first_evolution = int(thresholds[0])
			previous_second_evolution = int(thresholds[1])
		var evolution_multipliers: Array = definition.get("evolution_multipliers", [])
		if evolution_multipliers.size() != 3:
			failures.append("%s must define base, first, and second evolution output multipliers" % pet_id)
	if desktop_scales.size() == 1:
		failures.append("desktop pets must use varied sizes")
	if behavior_styles.size() != expected_pets.size():
		failures.append("each desktop pet must use a distinct behavior style")
	if minimum_scale > 0.7:
		failures.append("the smallest desktop pet must be visibly small")
	if maximum_scale - minimum_scale < 0.6:
		failures.append("desktop pet sizes must have a clear visual range")
	for climbing_pet_id in ["pet1", "pet4", "pet5"]:
		if float(PetCatalog.get_definition(climbing_pet_id).get("wall_chance", 0.0)) <= 0.0:
			failures.append("%s must occasionally climb a screen edge" % climbing_pet_id)
	for ground_pet_id in ["pet3"]:
		if float(PetCatalog.get_definition(ground_pet_id).get("wall_chance", 0.0)) > 0.0:
			failures.append("%s must remain a ground-only pet" % ground_pet_id)
	for ground_pet_id in ["pet1", "pet3", "pet4", "pet5"]:
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
	return failures


static func _check_frame_count(failures: Array[String], frames: SpriteFrames, animation_name: String, expected: int) -> void:
	var actual := frames.get_frame_count(animation_name)
	if actual != expected:
		failures.append("%s must contain %d frames, got %d" % [animation_name, expected, actual])
