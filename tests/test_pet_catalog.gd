extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected_pets := ["pet1", "pet2", "pet3", "pet4", "pet5"]
	if PetCatalog.ACTIVE_DESKTOP_PETS != expected_pets:
		failures.append("all five pets must be active")
	if PetCatalog.INVENTORY_STARTER_PETS != expected_pets:
		failures.append("all five pets must be available to inventory")
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var definition := PetCatalog.get_definition(pet_id)
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
