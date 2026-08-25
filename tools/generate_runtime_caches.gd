extends SceneTree

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")


func _initialize() -> void:
	var output_root := ProjectSettings.globalize_path(PetCatalog.PREBUILT_FRAME_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_root)
	if directory_error != OK:
		push_error("Could not create pet frame cache directory: %s" % error_string(directory_error))
		quit(1)
		return

	PetCatalog._prebuilt_frames_enabled = false
	var failures := 0
	var generated := 0
	var generated_icons := 0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		for evolved in [false, true]:
			if evolved and not PetCatalog.can_evolve(pet_id):
				continue
			var cache_key := "%s:%s" % [pet_id, "evolved" if evolved else "base"]
			(PetCatalog._frame_cache as Dictionary).erase(cache_key)
			var frames := PetCatalog.build_frames(pet_id, evolved)
			var output_path := PetCatalog.get_prebuilt_frame_path(pet_id, evolved)
			var save_error := ResourceSaver.save(frames, output_path, ResourceSaver.FLAG_COMPRESS)
			if save_error != OK:
				failures += 1
				push_error("Could not save %s: %s" % [output_path, error_string(save_error)])
				continue
			generated += 1
			print("GENERATED %s" % output_path)
	PetCatalog._prebuilt_frames_enabled = true

	var icon_output_root := ProjectSettings.globalize_path(PetCatalog.PREBUILT_ICON_ROOT)
	var icon_directory_error := DirAccess.make_dir_recursive_absolute(icon_output_root)
	if icon_directory_error != OK:
		failures += 1
		push_error("Could not create pet icon cache directory: %s" % error_string(icon_directory_error))
	else:
		var unique_icon_paths: Dictionary = {}
		for definition_value in PetCatalog.DEFINITIONS.values():
			var icon_path := String((definition_value as Dictionary).get("icon", ""))
			if not icon_path.is_empty():
				unique_icon_paths[icon_path] = true
		for definition_value in PetCatalog.EVOLUTION_DEFINITIONS.values():
			var icon_path := String((definition_value as Dictionary).get("icon", ""))
			if not icon_path.is_empty():
				unique_icon_paths[icon_path] = true
		var sorted_icon_paths: Array = unique_icon_paths.keys()
		sorted_icon_paths.sort()
		PetCatalog._prebuilt_icons_enabled = false
		(PetCatalog._icon_texture_cache as Dictionary).clear()
		for icon_path_value in sorted_icon_paths:
			var icon_path := String(icon_path_value)
			var icon_texture := PetCatalog.make_icon_texture(icon_path)
			var icon_output_path := PetCatalog.get_prebuilt_icon_path(icon_path)
			var icon_save_error := (
				ResourceSaver.save(icon_texture, icon_output_path, ResourceSaver.FLAG_COMPRESS)
				if icon_texture != null
				else ERR_INVALID_DATA
			)
			if icon_save_error != OK:
				failures += 1
				push_error("Could not save %s from %s: %s" % [
					icon_output_path,
					icon_path,
					error_string(icon_save_error)
				])
				continue
			var saved_icon := ResourceLoader.load(
				icon_output_path,
				"Texture2D",
				ResourceLoader.CACHE_MODE_IGNORE
			) as Texture2D
			if saved_icon == null or saved_icon.get_size() != icon_texture.get_size():
				failures += 1
				push_error("Could not verify generated pet icon: %s" % icon_output_path)
				continue
			generated += 1
			generated_icons += 1
			print("GENERATED %s <- %s" % [icon_output_path, icon_path])
		(PetCatalog._icon_texture_cache as Dictionary).clear()
		PetCatalog._prebuilt_icons_enabled = true
		for icon_path_value in sorted_icon_paths:
			var icon_path := String(icon_path_value)
			var expected_path := PetCatalog.get_prebuilt_icon_path(icon_path)
			var loaded_icon := PetCatalog.make_icon_texture(icon_path)
			if loaded_icon == null or loaded_icon.resource_path != expected_path:
				failures += 1
				push_error("Pet icon did not reload from its generated cache: %s" % expected_path)
		(PetCatalog._icon_texture_cache as Dictionary).clear()

	var believer_output_path := BelieverActor.PREBUILT_FRAME_PATH
	var believer_output_root := ProjectSettings.globalize_path(believer_output_path.get_base_dir())
	var believer_directory_error := DirAccess.make_dir_recursive_absolute(believer_output_root)
	if believer_directory_error != OK:
		failures += 1
		push_error("Could not create believer frame cache directory: %s" % error_string(believer_directory_error))
	else:
		BelieverActor._prebuilt_frames_enabled = false
		BelieverActor._cached_frames = null
		var believer_frames := BelieverActor._build_frames()
		var believer_save_error := ResourceSaver.save(
			believer_frames,
			believer_output_path,
			ResourceSaver.FLAG_COMPRESS
		)
		if believer_save_error != OK:
			failures += 1
			push_error("Could not save %s: %s" % [believer_output_path, error_string(believer_save_error)])
		else:
			generated += 1
			print("GENERATED %s" % believer_output_path)
		BelieverActor._cached_frames = null
		BelieverActor._prebuilt_frames_enabled = true

	var enemy_frame_output_root := ProjectSettings.globalize_path(EnemyActor.PREBUILT_FRAME_ROOT)
	var enemy_metrics_output_root := ProjectSettings.globalize_path(EnemyActor.PREBUILT_METRICS_PATH.get_base_dir())
	for directory_path in [enemy_frame_output_root, enemy_metrics_output_root]:
		var enemy_directory_error := DirAccess.make_dir_recursive_absolute(directory_path)
		if enemy_directory_error != OK:
			failures += 1
			push_error("Could not create enemy cache directory: %s" % error_string(enemy_directory_error))
	EnemyActor._prebuilt_cache_enabled = false
	EnemyActor._prebuilt_metrics_loaded = true
	(EnemyActor._frames_cache as Dictionary).clear()
	(EnemyActor._alignment_cache as Dictionary).clear()
	(EnemyActor._run_half_width_cache as Dictionary).clear()
	(EnemyActor._battle_half_width_cache as Dictionary).clear()
	(EnemyActor._visible_bounds_cache as Dictionary).clear()
	(EnemyActor._move_sheet_key_color_cache as Dictionary).clear()
	(EnemyActor._warmed_enemy_ids as Dictionary).clear()
	for enemy_id_value in EnemyActor.DEFINITIONS.keys():
		var enemy_id := String(enemy_id_value)
		EnemyActor.warm_up([enemy_id])
		var enemy_frames := (EnemyActor._frames_cache as Dictionary).get(enemy_id) as SpriteFrames
		var enemy_frame_path := EnemyActor.get_prebuilt_frame_path(enemy_id)
		var enemy_frame_error := (
			ResourceSaver.save(enemy_frames, enemy_frame_path, ResourceSaver.FLAG_COMPRESS)
			if enemy_frames != null
			else ERR_INVALID_DATA
		)
		if enemy_frame_error != OK:
			failures += 1
			push_error("Could not save %s: %s" % [enemy_frame_path, error_string(enemy_frame_error)])
		else:
			generated += 1
			print("GENERATED %s" % enemy_frame_path)
	var enemy_metrics := ConfigFile.new()
	enemy_metrics.set_value("meta", "version", EnemyActor.PREBUILT_CACHE_VERSION)
	for enemy_id_value in EnemyActor.DEFINITIONS.keys():
		var enemy_id := String(enemy_id_value)
		enemy_metrics.set_value("enemies", enemy_id, {
			"run_alignment": (EnemyActor._alignment_cache as Dictionary).get("%s:run" % enemy_id, Vector2.ZERO),
			"attack_alignment": (EnemyActor._alignment_cache as Dictionary).get("%s:attack" % enemy_id, Vector2.ZERO),
			"run_half_width": float((EnemyActor._run_half_width_cache as Dictionary).get(enemy_id, 0.0)),
			"battle_half_width": float((EnemyActor._battle_half_width_cache as Dictionary).get(enemy_id, 0.0)),
		})
	var enemy_metrics_error := enemy_metrics.save(EnemyActor.PREBUILT_METRICS_PATH)
	if enemy_metrics_error != OK:
		failures += 1
		push_error("Could not save %s: %s" % [EnemyActor.PREBUILT_METRICS_PATH, error_string(enemy_metrics_error)])
	else:
		generated += 1
		print("GENERATED %s" % EnemyActor.PREBUILT_METRICS_PATH)
	EnemyActor._prebuilt_cache_enabled = true
	EnemyActor._prebuilt_metrics_loaded = false
	print("GENERATED pet icon caches=%d" % generated_icons)
	print("GENERATED runtime caches=%d failures=%d" % [generated, failures])
	quit(0 if failures == 0 else 1)
