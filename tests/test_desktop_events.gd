extends RefCounted

const Main = preload("res://scripts/main.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const BattleEffectActor = preload("res://scripts/battle_effect_actor.gd")
const EnemyProjectileActor = preload("res://scripts/enemy_projectile_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_event_assets(failures)
	_test_era_progression(failures)
	_test_enemy_roles_and_frames(failures)
	_test_enemy_projectiles_and_special_defeats(failures)
	_test_pet11_cross_screen_battle_swallow(failures)
	_test_pet_combat_assets(failures)
	_test_era_age_and_difficulty(failures)
	_test_recovery_pauses_production(failures)
	_test_battle_activity_override(failures)
	_test_battle_starts_first_wave(failures)
	return failures


static func _test_event_assets(failures: Array[String]) -> void:
	for asset_path in [
		Main.PILGRIMAGE_INVITE_TEXTURE,
		Main.BATTLE_INVITE_TEXTURE,
		Main.SMOKE_SHEET_TEXTURE
	]:
		if not FileAccess.file_exists(asset_path):
			failures.append("desktop event asset must exist: %s" % asset_path)
	var smoke := load(Main.SMOKE_SHEET_TEXTURE) as Texture2D
	if smoke == null or smoke.get_width() != 96 * Main.SMOKE_FRAME_COUNT:
		failures.append("the authored smoke GIF must be converted into all ten animation frames")


static func _test_era_progression(failures: Array[String]) -> void:
	if EraProgression.get_year(0.0) != 1:
		failures.append("the menu era clock must begin at year one")
	if EraProgression.get_calendar_year(0.0) != EraProgression.MEDIEVAL_START_CALENDAR_YEAR:
		failures.append("the menu era clock must begin on a real medieval calendar year")
	var soldier_time := EraProgression.SECONDS_PER_YEAR * float(EraProgression.SOLDIER_ERA_START_YEAR - 1)
	if EraProgression.get_era_index(soldier_time - 0.01) != 0:
		failures.append("soldiers must stay out of the village era")
	if EraProgression.get_era_index(soldier_time) != 1:
		failures.append("elapsed desktop time must advance into the soldier era")
	if EraProgression.get_calendar_year(soldier_time) != EraProgression.SOLDIER_ERA_START_CALENDAR_YEAR:
		failures.append("the armed medieval chapter must display its corresponding real year")
	var later_schedule := EraProgression.get_wave_schedule(soldier_time)
	var later_types: Array[String] = []
	for wave in later_schedule:
		for enemy_type in (wave as Dictionary).get("types", []):
			later_types.append(String(enemy_type))
	if not later_types.has("soldier1") or not later_types.has("soldier2"):
		failures.append("the later era must schedule both melee and ranged soldiers")
	var victorian_time := EraProgression.SECONDS_PER_YEAR * float(EraProgression.VICTORIAN_ERA_START_YEAR - 1)
	if EraProgression.get_era_index(victorian_time) != 2:
		failures.append("elapsed desktop time must advance into the Victorian era")
	if EraProgression.get_calendar_year(victorian_time) != 1837:
		failures.append("the Victorian era must begin in the real year 1837")
	if not EraProgression.get_display_text(victorian_time, "zh").contains("公元 1837 年"):
		failures.append("the menu must print the real calendar year instead of a fictional year count")
	var victorian_types: Array[String] = []
	for wave in EraProgression.get_wave_schedule(victorian_time):
		for enemy_type in (wave as Dictionary).get("types", []):
			victorian_types.append(String(enemy_type))
	for expected_type in ["victorian1", "victorian2", "victorian_boss"]:
		if not victorian_types.has(expected_type):
			failures.append("the Victorian era must schedule %s" % expected_type)


static func _test_enemy_roles_and_frames(failures: Array[String]) -> void:
	for enemy_id in ["villager1", "villager2", "soldier1", "soldier2", "victorian1", "victorian2", "victorian_boss"]:
		var enemy := EnemyActor.new()
		enemy.setup(enemy_id, Vector2.ZERO, 400.0, 1.0, 80.0)
		var sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
		if sprite == null:
			failures.append("%s must build a battle sprite" % enemy_id)
		else:
			if sprite.sprite_frames.get_frame_count("run") != 12:
				failures.append("%s must use all 12 authored movement frames" % enemy_id)
			var expected_attack_frames := 12 if enemy_id in ["victorian2", "victorian_boss"] else 16
			if sprite.sprite_frames.get_frame_count("attack") != expected_attack_frames:
				failures.append("%s must use all %d authored attack frames" % [enemy_id, expected_attack_frames])
			if sprite.animation != "run" or not sprite.is_playing():
				failures.append("%s must visibly run while entering the battlefield" % enemy_id)
			if sprite.position.y <= -64.0:
				failures.append("%s feet must overlap the taskbar edge instead of hovering" % enemy_id)
		if bool(enemy.get("is_ranged")) != (enemy_id in ["soldier2", "victorian1"]):
			failures.append("only soldier2 and victorian1 must hold ranged attack distance")
		var target := Node2D.new()
		target.position = Vector2(500.0, 400.0)
		enemy.set_target(target)
		enemy.call("_process", 0.1)
		if enemy.position.x <= 0.0:
			failures.append("%s must advance toward pets during its run animation" % enemy_id)
		enemy.call("_process", 1.0)
		enemy.call("_process", 0.01)
		if not bool(enemy.call("has_entered_battlefield")):
			failures.append("%s must finish its run-in before fighting" % enemy_id)
		enemy.set("_attack_animation_remaining", 0.0)
		enemy.set("_attack_pending", false)
		enemy.set("_attack_cooldown", 0.0)
		var firing_post_x := enemy.position.x
		target.position = Vector2(900.0 if enemy_id in ["soldier2", "victorian1"] else enemy.position.x + 60.0, 400.0)
		enemy.set_target(target)
		enemy.call("_process", 0.01)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s must switch from run to its authored attack animation in range" % enemy_id)
		enemy.call("_process", 0.5)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s attack animation must remain visible through its hit frame" % enemy_id)
		if enemy_id in ["soldier2", "victorian1"] and not is_equal_approx(enemy.position.x, firing_post_x):
			failures.append("%s must shoot from its entry post instead of chasing a pet" % enemy_id)
		target.free()
		enemy.free()


static func _test_enemy_projectiles_and_special_defeats(failures: Array[String]) -> void:
	var target := Node2D.new()
	target.position = Vector2(600.0, 360.0)
	var arrow := EnemyProjectileActor.new()
	arrow.setup("arrow", Vector2(80.0, 280.0), target, 1.0, 1.0)
	if not bool(arrow.call("can_be_swallowed")):
		failures.append("soldier2 arrows must be real projectiles that pet11 can swallow")
	var arrow_sprite := arrow.get_node_or_null("EnemyProjectileSprite") as Sprite2D
	if arrow_sprite == null or arrow_sprite.texture == null:
		failures.append("soldier2 arrows must use the imported arrow asset")
	var pet11 := Main.DesktopPetActor.new()
	pet11.setup("pet11", Vector2i(900, 500), 0.0, 900.0, 640.0, 484.0, false)
	if not bool(arrow.call("start_swallowed_by", pet11)):
		failures.append("pet11 must be able to intercept swallowable enemy projectiles")
	arrow.free()

	var bullet := EnemyProjectileActor.new()
	bullet.setup("victorian_bullet", Vector2(80.0, 280.0), target, 1.0, 2.0)
	if float(bullet.get("_splash_radius")) <= 0.0:
		failures.append("victorian1 bullets must carry area damage")
	bullet.free()

	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(180.0, 400.0), 400.0, 1.0, 180.0)
	enemy.launch_offscreen(Vector2(-800.0, -220.0))
	if not bool(enemy.call("is_launched")):
		failures.append("melee finishing blows must be able to launch enemies offscreen")
	var launch_start := enemy.position
	enemy.call("_process", 0.1)
	if enemy.position == launch_start:
		failures.append("launched enemies must visibly fly instead of disappearing immediately")
	enemy.free()
	var swallowed_enemy := EnemyActor.new()
	swallowed_enemy.setup("villager2", Vector2(420.0, 484.0), 484.0, 1.0, 420.0)
	var swallow_completed := [false]
	swallowed_enemy.swallowed.connect(func(_actor: Node2D, _reward: int) -> void: swallow_completed[0] = true)
	if not swallowed_enemy.start_swallowed_by(pet11):
		failures.append("pet11 must be able to swallow ordinary enemies")
	swallowed_enemy.call("_process", float(swallowed_enemy.get("_swallow_duration")) + 0.01)
	if not swallow_completed[0]:
		failures.append("swallowed enemies must finish by disappearing into pet11")
	swallowed_enemy.free()
	pet11.set_battle_mode(true)
	pet11.position.x = 890.0
	pet11.receive_battle_hit(1000.0)
	var pet_rect: Rect2 = pet11.call("_get_sprite_visual_rect")
	if pet_rect.end.x > 900.5:
		failures.append("battle knockback must never push a pet outside the desktop")
	pet11.free()
	target.free()


static func _test_era_age_and_difficulty(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_total_runtime_seconds", EraProgression.SECONDS_PER_YEAR * 3.0)
	var age_text := String(main.call("_get_pet_age_text", Main.PetCatalog.get_definition("pet1")))
	var expected_age := 3 + EraProgression.get_elapsed_calendar_years(EraProgression.SECONDS_PER_YEAR * 3.0)
	if age_text != "%d岁" % expected_age:
		failures.append("pet detail ages must advance by the real calendar years shown in the menu")
	main.set("_total_runtime_seconds", EraProgression.SECONDS_PER_YEAR * float(EraProgression.VICTORIAN_ERA_START_YEAR - 1))
	main.set("_debug_enemy_power_scale", 2.0)
	var difficulty_text := String(main.call("_get_battle_difficulty_text"))
	if not difficulty_text.contains("难度") or not difficulty_text.contains("×3.28"):
		failures.append("battle invitations must expose difficulty from era and debug enemy power")
	var rolled_values: Array[float] = []
	(main.get("_rng") as RandomNumberGenerator).seed = 71218
	for _roll_index in 4:
		rolled_values.append(float(main.call("_roll_battle_difficulty_scale")))
	for rolled_value in rolled_values:
		if rolled_value < 3.28 * Main.BATTLE_DIFFICULTY_VARIANCE_MIN - 0.001 or rolled_value > 3.28 * Main.BATTLE_DIFFICULTY_VARIANCE_MAX + 0.001:
			failures.append("random battle difficulty must stay inside the advertised variance range")
			break
	if is_equal_approx(rolled_values[0], rolled_values[1]):
		failures.append("successive battle invitations must have real difficulty variance")
	main.set("_active_battle_difficulty_scale", 2.73)
	if not String(main.call("_get_battle_difficulty_text")).contains("×2.73"):
		failures.append("battle difficulty text must use the value locked for the active encounter")
	main.free()


static func _test_pet11_cross_screen_battle_swallow(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_next_pet11_absorb_at", 0.0)
	var pet11 := Main.DesktopPetActor.new()
	pet11.setup("pet11", Vector2i(1400, 720), 0.0, 1400.0, 1240.0, 704.0, false)
	pet11.set_battle_mode(true)
	main.add_child(pet11)
	(main.get("_pets") as Array).append(pet11)
	(main.get("_battle_pet_health") as Dictionary)[str(pet11.get_instance_id())] = 10.0
	var enemy := EnemyActor.new()
	enemy.setup("victorian_boss", Vector2(80.0, 704.0), 704.0, 1.0, 80.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	main.call("_update_pet11_battle_absorb", pet11)
	if not bool(enemy.call("is_being_swallowed")):
		failures.append("pet11 must pull any enemy, including a boss, into its body from across the desktop")
	var swallow_duration := float(enemy.get("_swallow_duration"))
	if swallow_duration < 2.8:
		failures.append("pet11 suction must visibly pull and shrink an enemy instead of deleting it too quickly")
	var enemy_sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
	var initial_scale := enemy_sprite.scale if enemy_sprite != null else Vector2.ZERO
	var mouth_position := pet11.get_swallow_mouth_position()
	if mouth_position.distance_to(pet11.position) > 4.0:
		failures.append("pet11's suction target must be the visible center of its vortex")
	enemy.call("_process", swallow_duration * 0.70)
	if not bool(enemy.call("is_being_swallowed")):
		failures.append("a cross-screen enemy must remain visible during the slower suction animation")
	if enemy_sprite != null and not enemy_sprite.scale.is_equal_approx(initial_scale):
		failures.append("pet11 must not shrink an enemy until it has reached the mouth entrance")
	var approach_visual_position := enemy.position + enemy_sprite.position
	if approach_visual_position.distance_to(mouth_position) >= Vector2(80.0, 704.0).distance_to(mouth_position):
		failures.append("pet11 suction must visibly carry the enemy toward the vortex")
	enemy.call("_process", swallow_duration * 0.10)
	if enemy_sprite != null and enemy_sprite.scale.x >= initial_scale.x:
		failures.append("the enemy must begin shrinking only during the final movement into the mouth")
	if Main._get_enemy_launch_direction() >= 0.0:
		failures.append("melee launch defeats must always throw invaders toward the left side of the desktop")
	main.free()


static func _test_pet_combat_assets(failures: Array[String]) -> void:
	for pet_id in ["pet3", "pet4", "pet5", "pet6"]:
		var pet_data := Main.PetCatalog.get_definition(pet_id)
		var frames := Main.PetCatalog.build_frames(pet_id)
		var expected_count := 16 if pet_id == "pet3" else 12
		if not frames.has_animation("attack") or frames.get_frame_count("attack") != expected_count:
			failures.append("%s must use its authored melee attack sheet" % pet_id)
		if not FileAccess.file_exists(String(pet_data.get("attack", ""))):
			failures.append("%s must reference the corrected attack asset filename" % pet_id)
		if not bool(pet_data.get("attack_faces_right", false)):
			failures.append("%s must declare the authored attack-sheet direction explicitly" % pet_id)
	var melee_pet := Main.DesktopPetActor.new()
	melee_pet.setup("pet3", Vector2i(900, 600), 0.0, 900.0, 640.0, 584.0, false)
	melee_pet.set_battle_mode(true)
	melee_pet.play_battle_attack_toward(-1.0)
	var melee_sprite := melee_pet.get_node_or_null("pet3Sprite") as AnimatedSprite2D
	if melee_sprite == null or melee_sprite.animation != "attack":
		failures.append("melee pets must switch to their attack animation when striking")
	elif not melee_sprite.flip_h:
		failures.append("a right-facing attack sheet must flip visually when striking left")
	elif melee_sprite.frame != 0:
		failures.append("horizontal facing changes must not reverse or skip the authored attack frame order")
	if float(melee_pet.get_battle_attack_duration()) < 16.0 / 12.0:
		failures.append("combat cooldowns must leave enough time for all authored attack frames to play")
	melee_pet.free()
	for pet_id in Main.RANGED_BATTLE_PET_IDS:
		var config: Dictionary = BattleEffectActor.PROJECTILE_CONFIG.get(pet_id, {})
		if config.is_empty() or not FileAccess.file_exists(String(config.get("sheet", ""))):
			failures.append("%s must have a dedicated projectile type" % pet_id)
	var target := Node2D.new()
	target.position = Vector2(320.0, 300.0)
	var projectile := BattleEffectActor.new()
	projectile.setup_projectile("pet11", Vector2(40.0, 240.0), target, 6.0)
	var projectile_sprite := projectile.get_node_or_null("ProjectileSprite") as AnimatedSprite2D
	if projectile_sprite == null or projectile_sprite.sprite_frames.get_frame_count("fly") != 5:
		failures.append("ranged pet projectiles must animate through five authored frames")
	var explosion := BattleEffectActor.new()
	explosion.setup_explosion(Vector2.ZERO, 7.5)
	var explosion_sprite := explosion.get_node_or_null("ExplosionSprite") as AnimatedSprite2D
	if explosion_sprite == null or explosion_sprite.sprite_frames.get_frame_count("burst") != 11:
		failures.append("high-power pets must select the large eleven-frame explosion")
	projectile.free()
	explosion.free()
	target.free()


static func _test_recovery_pauses_production(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	var unlocked: Array = main.get("_unlocked_pet_ids")
	unlocked.append("pet2")
	var deployed: Array = main.get("_deployed_pet_ids")
	deployed.clear()
	main.call("_set_pet_recovery", "pet1")
	var pet2_only_rate := Main.PetProgression.faith_per_second(Main.PetCatalog.get_definition("pet2"), 1)
	if not is_equal_approx(float(main.call("_get_faith_growth_rate")), pet2_only_rate):
		failures.append("a defeated pet must pause all passive production while recovering")
	var entries: Array[Dictionary] = main.call("_get_inventory_pet_entries")
	var recovery_entry: Dictionary = {}
	for entry in entries:
		if String(entry.get("id", "")) == "pet1":
			recovery_entry = entry
			break
	if not bool(recovery_entry.get("recovering", false)):
		failures.append("storage entries must expose defeated-pet recovery state")
	if float(recovery_entry.get("recovery_progress", -1.0)) < 0.0:
		failures.append("storage recovery state must expose circular progress")
	main.free()


static func _test_battle_activity_override(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_pet_activity_range", "left")
	main.set("_battle_active", true)
	if String(main.call("_get_effective_pet_activity_range")) != "full":
		failures.append("battle events must temporarily open the entire desktop activity range")
	main.free()


static func _test_battle_starts_first_wave(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 700.0, 704.0, false)
	main.add_child(pet)
	var pets: Array = main.get("_pets")
	pets.append(pet)
	main.call("_on_debug_event_requested", "battle")
	if bool(main.get("_battle_active")) or main.get("_event_invitation") == null:
		failures.append("debug-triggered battles must still drop a clickable invitation item")
	var pending_difficulty := float(main.get("_pending_battle_difficulty_scale"))
	var invitation := main.get("_event_invitation") as Node2D
	if pending_difficulty < 0.0 or invitation == null or not String(invitation.get("_difficulty_text")).contains("×%.2f" % pending_difficulty):
		failures.append("battle invitations must display the exact randomly rolled encounter difficulty")
	main.call("_on_event_invitation_accepted", "battle")
	if not bool(main.get("_battle_active")):
		failures.append("accepting the debug invitation must enter battle state")
	if not is_equal_approx(float(main.get("_active_battle_difficulty_scale")), pending_difficulty):
		failures.append("accepting an invitation must lock its advertised difficulty for every enemy wave")
	if (main.get("_battle_enemies") as Array).size() < 2:
		failures.append("battle start must immediately send the first timed enemy wave from the left")
	if not bool(pet.get("_battle_mode")):
		failures.append("battle start must move deployed pets into the right-side formation mode")
	if not bool(pet.get("_interaction_enabled")):
		failures.append("battle pets must remain draggable so placement can alter the fight")
	var formation_start_x := pet.position.x
	main.call("_update_battle_pet_formation", 1.0 / 60.0)
	var formation_step := absf(pet.position.x - formation_start_x)
	if formation_step <= 0.0 or formation_step > 5.0:
		failures.append("battle formation must move smoothly at render cadence instead of jumping at 10 Hz")
	main.call("_on_pet_grabbed_changed", pet, true)
	if not bool((main.get("_battle_pet_formed") as Dictionary).get(str(pet.get_instance_id()), false)):
		failures.append("manually grabbing a battle pet must release it from formation correction")
	main.call("_finish_battle", true)
	if bool(main.get("_battle_active")) or bool(pet.get("_battle_mode")):
		failures.append("battle cleanup must restore surviving pets to normal autonomy")
	for child in main.get_children():
		if bool(child.get_meta("battle_runtime", false)) and not child.is_queued_for_deletion():
			failures.append("battle cleanup must remove every enemy/effect node, including actors already erased from combat arrays")
			break
	main.free()
