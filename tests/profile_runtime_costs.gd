extends SceneTree

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")

const HIT_TEST_ITERATIONS := 20_000


func _initialize() -> void:
	print("PROFILE runtime costs")
	_profile_pet_frame_builds()
	_profile_believer_frame_build()
	_profile_enemy_warmup_stages()
	_profile_pet_hit_tests()
	quit(0)


func _profile_pet_frame_builds() -> void:
	(PetCatalog._frame_cache as Dictionary).clear()
	var total_usec := 0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var started_usec := Time.get_ticks_usec()
		var frames := PetCatalog.build_frames(pet_id, false)
		var elapsed_usec := Time.get_ticks_usec() - started_usec
		total_usec += elapsed_usec
		print(
			"PROFILE pet_frames id=%s milliseconds=%.3f animations=%d"
			% [pet_id, float(elapsed_usec) / 1000.0, frames.get_animation_names().size()]
		)
	print("PROFILE pet_frames_total milliseconds=%.3f" % (float(total_usec) / 1000.0))


func _profile_believer_frame_build() -> void:
	BelieverActor._cached_frames = null
	var started_usec := Time.get_ticks_usec()
	var frames := BelieverActor._build_frames()
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	print(
		"PROFILE believer_frames milliseconds=%.3f animations=%d"
		% [float(elapsed_usec) / 1000.0, frames.get_animation_names().size()]
	)


func _profile_enemy_warmup_stages() -> void:
	(EnemyActor._frames_cache as Dictionary).clear()
	(EnemyActor._alignment_cache as Dictionary).clear()
	(EnemyActor._run_half_width_cache as Dictionary).clear()
	(EnemyActor._battle_half_width_cache as Dictionary).clear()
	(EnemyActor._visible_bounds_cache as Dictionary).clear()
	(EnemyActor._move_sheet_key_color_cache as Dictionary).clear()
	(EnemyActor._warmed_enemy_ids as Dictionary).clear()
	EnemyActor._prebuilt_cache_enabled = true
	EnemyActor._prebuilt_metrics_loaded = false
	var total_usec := 0
	for enemy_id_value in EnemyActor.DEFINITIONS.keys():
		var enemy_id := String(enemy_id_value)
		for stage in ["frames", "run_width", "battle_width"]:
			var started_usec := Time.get_ticks_usec()
			EnemyActor.warm_up_stage(enemy_id, stage)
			var elapsed_usec := Time.get_ticks_usec() - started_usec
			total_usec += elapsed_usec
			print(
				"PROFILE enemy_warmup id=%s stage=%s milliseconds=%.3f"
				% [enemy_id, stage, float(elapsed_usec) / 1000.0]
			)
	print("PROFILE enemy_warmup_total milliseconds=%.3f" % (float(total_usec) / 1000.0))


func _profile_pet_hit_tests() -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet10", Vector2i(1920, 1080), 0.0, 1920.0, 960.0, 1064.0, false, false, 100)
	var rect := actor.get_interaction_rect()
	var sample_point := rect.get_center()
	var started_usec := Time.get_ticks_usec()
	var hits := 0
	for _iteration in HIT_TEST_ITERATIONS:
		if actor.is_point_over_opaque_pixel(sample_point):
			hits += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	print(
		"PROFILE pet_hit_test iterations=%d milliseconds=%.3f hits=%d"
		% [HIT_TEST_ITERATIONS, float(elapsed_usec) / 1000.0, hits]
	)
	actor.free()
