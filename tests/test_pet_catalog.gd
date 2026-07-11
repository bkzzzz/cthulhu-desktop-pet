extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if PetCatalog.ACTIVE_DESKTOP_PETS != ["pet1", "pet2"]:
		failures.append("only the two new pets must be active")
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
	return failures
