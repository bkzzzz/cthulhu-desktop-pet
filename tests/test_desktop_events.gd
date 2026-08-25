extends RefCounted

const Main = preload("res://scripts/main.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const BattleBalance = preload("res://scripts/domain/battle_balance.gd")
const BattleEffectActor = preload("res://scripts/battle_effect_actor.gd")
const EnemyProjectileActor = preload("res://scripts/enemy_projectile_actor.gd")
const EventInvitation = preload("res://scripts/event_invitation.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_event_assets(failures)
	_test_era_progression(failures)
	_test_enemy_roles_and_frames(failures)
	_test_enemy_projectiles_and_special_defeats(failures)
	_test_projectiles_coast_after_target_loss(failures)
	_test_pet_combat_assets(failures)
	_test_pet6_dragged_combat(failures)
	_test_era_age_and_difficulty(failures)
	_test_adaptive_encounter_and_rewards(failures)
	_test_campaign_combat_checkpoints(failures)
	_test_victory_loot_burst(failures)
	_test_invitation_retention_and_singleton(failures)
	_test_battle_invitation_cooldowns(failures)
	_test_recovery_pauses_production(failures)
	_test_battle_activity_override(failures)
	_test_inventory_deploy_during_events(failures)
	_test_battle_starts_first_wave(failures)
	_test_debug_battle_replacement_is_silent(failures)
	_test_battle_timeout_is_defeat(failures)
	return failures


static func _test_victory_loot_burst(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.call("_spawn_victory_loot_burst", 2_500_000)
	var presentation: Node = main.get("_presentation_controller")
	var drops: Array = presentation.get("_victory_loot_drops")
	if drops.size() < Main.PresentationController.VICTORY_LOOT_MIN_DROPS or drops.size() > Main.PresentationController.VICTORY_LOOT_MAX_DROPS:
		failures.append("victory loot must create a denomination-compressed, bounded celebration burst")
	if not (main.get("_coin_drops") as Array).is_empty():
		failures.append("victory celebration drops must not evict or join collectible desktop currency")
	var found_high_denomination := false
	for drop_value in drops:
		var drop := drop_value as Node2D
		if int(drop.get("value")) != 0 or not bool(drop.get_meta("victory_loot_visual", false)):
			failures.append("victory loot visuals must never duplicate the settled gold reward")
			break
		if String(drop.get("coin_type")) in ["C", "S", "G"]:
			found_high_denomination = true
	if not found_high_denomination:
		failures.append("high-value victory loot must use the imported high-denomination animations")
	if Main.PresentationController.VICTORY_LOOT_DELAY_SECONDS <= 0.0:
		failures.append("victory loot must wait until after the notification panel entrance")
	for _frame in 150:
		for drop_value in drops:
			if is_instance_valid(drop_value):
				(drop_value as Node2D).call("_process", 1.0 / 60.0)
	if drops.any(func(drop: Node2D) -> bool: return not is_instance_valid(drop) or drop.is_queued_for_deletion()):
		failures.append("victory loot must remain visible after finishing its spill")
	presentation.call("_collect_victory_loot_drops")
	for drop_value in drops:
		var drop := drop_value as Node2D
		if is_instance_valid(drop):
			if not bool(drop.get("_celebration_collecting")):
				failures.append("all victory coins must begin collecting toward the pointer together")
				break
			drop.call("_update_celebration_collection", Vector2(600.0, 240.0), 2.0)
			drop.call("_update_celebration_collection", Vector2(600.0, 240.0), 0.01)
			if not drop.is_queued_for_deletion():
				failures.append("victory coins must disappear only after reaching their collection point")
				break
	main.free()


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
	if not is_equal_approx(soldier_time / 3600.0, 1.0):
		failures.append("the soldier era must begin at the one-hour time fallback checkpoint")
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
	if not is_equal_approx(victorian_time / 3600.0, 2.5):
		failures.append("the Victorian era must begin at the two-and-a-half-hour time fallback checkpoint")
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
	var modern_time := EraProgression.SECONDS_PER_YEAR * float(EraProgression.MODERN_ERA_START_YEAR - 1)
	if not is_equal_approx(modern_time / 3600.0, 4.5):
		failures.append("the modern era must begin at the four-and-a-half-hour time fallback checkpoint")
	if EraProgression.get_era_index(modern_time) != 3:
		failures.append("elapsed desktop time must advance into the modern era")
	var modern_types: Array[String] = []
	for wave in EraProgression.get_wave_schedule(modern_time):
		for enemy_type in (wave as Dictionary).get("types", []):
			modern_types.append(String(enemy_type))
	for expected_type in ["modern2", "modern3"]:
		if not modern_types.has(expected_type):
			failures.append("the modern era must schedule %s" % expected_type)
	var outer_time := EraProgression.SECONDS_PER_YEAR * float(EraProgression.OUTER_SPACE_ERA_START_YEAR - 1)
	if not is_equal_approx(outer_time / 3600.0, 6.5):
		failures.append("the outer-space era must begin at the six-and-a-half-hour time fallback checkpoint")
	if EraProgression.get_era_index(outer_time) != 4:
		failures.append("elapsed desktop time must advance into the outer-space era")
	var outer_types: Array[String] = []
	for wave in EraProgression.get_wave_schedule(outer_time):
		for enemy_type in (wave as Dictionary).get("types", []):
			outer_types.append(String(enemy_type))
	for expected_type in ["outerspace1", "outerspace2", "outerspace3"]:
		if not outer_types.has(expected_type):
			failures.append("the outer-space era must schedule %s" % expected_type)
	var legacy_outer_runtime := (
		EraProgression.LEGACY_SECONDS_PER_YEAR
		* float(EraProgression.OUTER_SPACE_ERA_START_YEAR - 1)
	)
	if EraProgression.get_legacy_era_index(legacy_outer_runtime) != 4:
		failures.append("pre-rebalance saves must preserve their already-reached combat era")
	var roster_requirements := EraProgression.ERA_UNLOCKED_PET_REQUIREMENTS
	for era_index in EraProgression.get_era_count():
		var required_pets := int(roster_requirements[era_index])
		if EraProgression.get_roster_era_index(required_pets) != era_index:
			failures.append("each roster milestone must advance exactly one era")
			break
		if required_pets > 1 and EraProgression.get_roster_era_index(required_pets - 1) >= era_index:
			failures.append("roster milestones must not skip an era early")
			break
	if EraProgression.get_progression_era_index(0.0, 5) != 2:
		failures.append("five unlocked pets must move a fresh save into the Victorian era")
	if EraProgression.get_progression_era_index(0.0, 1, 3) != 3:
		failures.append("a persisted legacy era floor must remain stronger than a small roster")
	var roster_main := Main.new()
	roster_main.set("_persistence_enabled", false)
	roster_main.set("_total_runtime_seconds", 0.0)
	var seven_pet_roster: Array[String] = ["pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7"]
	roster_main.set("_unlocked_pet_ids", seven_pet_roster)
	var roster_runtime := float(roster_main.call("_get_era_runtime_seconds"))
	if EraProgression.get_era_index(roster_runtime) != 3:
		failures.append("the runtime era must immediately reflect a seven-pet roster without rewriting play time")
	if not is_equal_approx(float(roster_main.get("_total_runtime_seconds")), 0.0):
		failures.append("roster-driven era changes must not inflate saved total play time")
	roster_main.call("_on_debug_era_requested", 1)
	if EraProgression.get_era_index(float(roster_main.call("_get_era_runtime_seconds"))) != 1:
		failures.append("debug era selection must remain able to preview earlier chapters")
	roster_main.free()
	var migrated_main := Main.new()
	migrated_main.set("_persistence_enabled", false)
	migrated_main.set("_total_runtime_seconds", legacy_outer_runtime)
	migrated_main.set("_era_floor_index", 4)
	if (
		EraProgression.get_era_index(float(migrated_main.call("_get_era_runtime_seconds"))) != 4
		or not is_equal_approx(float(migrated_main.get("_total_runtime_seconds")), legacy_outer_runtime)
	):
		failures.append("era migration must preserve the chapter without inflating saved play time")
	migrated_main.free()


static func _test_enemy_roles_and_frames(failures: Array[String]) -> void:
	if String(EnemyActor.DEFINITIONS["soldier1"].get("move", "")) != "res://assets/enemyCharacter/soldiers/soldier1Run.png":
		failures.append("soldier1 must use the newly imported run sheet instead of its idle sheet")
	if (
		not is_equal_approx(EnemyActor.get_health_multiplier("villager1"), 1.50)
		or not is_equal_approx(EnemyActor.get_damage_multiplier("modern2"), 1.15)
		or not is_equal_approx(EnemyActor.get_damage_multiplier("outerspace1"), 1.0)
		or not is_equal_approx(EnemyActor.get_health_multiplier("final_boss"), 1.0)
	):
		failures.append("standard waves must be tougher while barrage enemies and the final boss retain their tuned damage windows")
	var ranged_ids := ["soldier2", "victorian1", "modern2", "modern3", "outerspace1", "outerspace2", "outerspace3"]
	for enemy_id in ["villager1", "villager2", "soldier1", "soldier2", "victorian1", "victorian2", "victorian_boss", "modern2", "modern3", "outerspace1", "outerspace2", "outerspace3"]:
		var enemy := EnemyActor.new()
		enemy.setup(enemy_id, Vector2.ZERO, 400.0, 1.0, 80.0)
		var emitted_projectiles := [0]
		enemy.projectile_requested.connect(
			func(_actor: Node2D, _target: Node2D, _damage: float, _kind: String, _power: float) -> void:
				emitted_projectiles[0] += 1
		)
		var sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
		if sprite == null:
			failures.append("%s must build a battle sprite" % enemy_id)
		else:
			if sprite.sprite_frames.get_frame_count("run") != 12:
				failures.append("%s must use all 12 authored movement frames" % enemy_id)
			elif (
				not is_equal_approx(sprite.sprite_frames.get_frame_duration("run", 0), 0.5)
				or not is_equal_approx(sprite.sprite_frames.get_frame_duration("run", 11), 0.5)
			):
				failures.append("%s movement loop must not dwell on its wraparound pose" % enemy_id)
			var expected_attack_frames := 12 if enemy_id in ["victorian2", "victorian_boss", "modern2", "modern3", "outerspace1", "outerspace2", "outerspace3"] else 16
			if sprite.sprite_frames.get_frame_count("attack") != expected_attack_frames:
				failures.append("%s must use all %d authored attack frames" % [enemy_id, expected_attack_frames])
			if sprite.animation != "run" or not sprite.is_playing():
				failures.append("%s must visibly run while entering the battlefield" % enemy_id)
			if sprite.position.y <= -64.0:
				failures.append("%s feet must overlap the taskbar edge instead of hovering" % enemy_id)
		if bool(enemy.get("is_ranged")) != (enemy_id in ranged_ids):
			failures.append("all declared gunner and modern enemies must hold ranged attack distance")
		if enemy_id.begins_with("modern") and float(enemy.get("max_health")) <= 10.5:
			failures.append("%s must be tougher than every earlier enemy" % enemy_id)
		if enemy_id.begins_with("outerspace"):
			if not bool(enemy.get("_flying")) or enemy.position.y >= 400.0:
				failures.append("%s must fight above the taskbar as a flying object" % enemy_id)
			if EnemyActor.get_combat_power(enemy_id) <= EnemyActor.get_combat_power("modern3"):
				failures.append("%s must carry more hidden combat power than modern enemies" % enemy_id)
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
		target.position = Vector2(900.0 if enemy_id in ranged_ids else enemy.position.x + 60.0, 400.0)
		enemy.set_target(target)
		enemy.call("_process", 0.01)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s must switch from run to its authored attack animation in range" % enemy_id)
		enemy.call("_process", 0.5)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s attack animation must remain visible through its hit frame" % enemy_id)
		if enemy_id in ranged_ids and not is_equal_approx(enemy.position.x, firing_post_x):
			failures.append("%s must shoot from its entry post instead of chasing a pet" % enemy_id)
		if enemy_id.begins_with("outerspace") and emitted_projectiles[0] != int(enemy.get("_projectiles_per_attack")):
			failures.append("%s must emit its entire authored projectile barrage" % enemy_id)
		target.free()
		enemy.free()


static func _test_enemy_projectiles_and_special_defeats(failures: Array[String]) -> void:
	var target := Node2D.new()
	target.position = Vector2(600.0, 360.0)
	var arrow := EnemyProjectileActor.new()
	arrow.setup("arrow", Vector2(80.0, 280.0), target, 1.0, 1.0)
	var arrow_sprite := arrow.get_node_or_null("EnemyProjectileSprite") as Sprite2D
	if arrow_sprite == null or arrow_sprite.texture == null:
		failures.append("soldier2 arrows must use the imported arrow asset")
	arrow.free()

	var bullet := EnemyProjectileActor.new()
	bullet.setup("victorian_bullet", Vector2(80.0, 280.0), target, 1.0, 2.0)
	var victorian_splash := float(bullet.get("_splash_radius"))
	if victorian_splash <= 0.0:
		failures.append("victorian1 bullets must carry area damage")
	bullet.free()
	var modern_shell := EnemyProjectileActor.new()
	modern_shell.setup("modern_shell", Vector2(80.0, 280.0), target, 1.0, 1.0)
	if bool(modern_shell.call("can_be_swallowed")):
		failures.append("modern heavy shells must not be swallowable")
	if float(modern_shell.get("_splash_radius")) <= victorian_splash:
		failures.append("modern heavy shells must outclass Victorian splash damage")
	modern_shell.free()
	var outer_bolt := EnemyProjectileActor.new()
	outer_bolt.setup("outer_bolt", Vector2(80.0, 180.0), target, 1.0, 1.0)
	if float(outer_bolt.get("_splash_radius")) <= 0.0:
		failures.append("outer-space barrage bolts must trigger impact effects")
	outer_bolt.free()

	var dodge_target := Node2D.new()
	dodge_target.position = Vector2(600.0, 360.0)
	var ballistic_shot := EnemyProjectileActor.new()
	var ballistic_impacts := [0]
	ballistic_shot.impacted.connect(
		func(_actor: Node2D, _hit_target: Node2D, _damage: float, _splash: float, _knockback: float) -> void:
			ballistic_impacts[0] += 1
	)
	ballistic_shot.setup("arrow", Vector2(80.0, 280.0), dodge_target, 1.0, 1.0)
	var fixed_aim_position := ballistic_shot.get("_last_target_position") as Vector2
	ballistic_shot.call("_process", float(ballistic_shot.get("_flight_duration")) * 0.35)
	dodge_target.position += Vector2(0.0, 180.0)
	ballistic_shot.call("_process", float(ballistic_shot.get("_flight_duration")))
	if ballistic_shot.position.x <= fixed_aim_position.x:
		failures.append("a missed enemy projectile must continue past its original aim position")
	if ballistic_impacts[0] != 0:
		failures.append("moving a pet after launch must allow it to dodge an enemy projectile")
	ballistic_shot.free()
	dodge_target.free()

	var stationary_target := Node2D.new()
	stationary_target.position = Vector2(600.0, 360.0)
	var stationary_shot := EnemyProjectileActor.new()
	var stationary_impacts := [0]
	stationary_shot.impacted.connect(
		func(_actor: Node2D, hit_target: Node2D, _damage: float, _splash: float, _knockback: float) -> void:
			if hit_target == stationary_target:
				stationary_impacts[0] += 1
	)
	stationary_shot.setup("arrow", Vector2(80.0, 280.0), stationary_target, 1.0, 1.0)
	stationary_shot.call("_process", float(stationary_shot.get("_flight_duration")))
	if stationary_impacts[0] != 1:
		failures.append("continuous projectile collision must hit a stationary pet")
	stationary_shot.call("_process", 0.5)
	if stationary_impacts[0] != 1:
		failures.append("a projectile collision must resolve damage exactly once")
	stationary_shot.free()
	stationary_target.free()

	var original_target := Node2D.new()
	original_target.position = Vector2(800.0, 360.0)
	var intercepting_pet := Node2D.new()
	intercepting_pet.position = Vector2(440.0, 244.0)
	var collision_candidates: Array[Node2D] = [original_target, intercepting_pet]
	var fast_shot := EnemyProjectileActor.new()
	var intercepted_target: Array[Node2D] = []
	fast_shot.impacted.connect(
		func(_actor: Node2D, hit_target: Node2D, _damage: float, _splash: float, _knockback: float) -> void:
			intercepted_target.append(hit_target)
	)
	fast_shot.setup(
		"outer_bolt",
		Vector2(80.0, 280.0),
		original_target,
		1.0,
		1.0,
		collision_candidates
	)
	original_target.position.y += 220.0
	fast_shot.call("_process", float(fast_shot.get("_flight_duration")) * 0.25)
	intercepting_pet.position.y += 200.0
	fast_shot.call("_process", float(fast_shot.get("_flight_duration")) * 0.50)
	if intercepted_target.size() != 1 or intercepted_target[0] != intercepting_pet:
		failures.append("swept collision must hit another pet crossing a high-speed projectile path")
	fast_shot.free()
	original_target.free()
	intercepting_pet.free()

	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(180.0, 400.0), 400.0, 1.0, 180.0, 1000.0)
	var visual_margin := float(enemy.call("_get_battle_visual_half_width"))
	enemy.take_damage(0.0, 900.0, Vector2(-800.0, -220.0), -1.0)
	if enemy.position.x < visual_margin - 0.01:
		failures.append("strong finishing knockback must stop at the visible desktop boundary")
	if enemy.has_method("launch_offscreen") or enemy.has_method("is_launched"):
		failures.append("combat must no longer expose an offscreen enemy-launch state")
	enemy.free()
	target.free()


static func _test_projectiles_coast_after_target_loss(failures: Array[String]) -> void:
	var pet_target := Node2D.new()
	pet_target.position = Vector2(520.0, 300.0)
	var pet_projectile := BattleEffectActor.new()
	pet_projectile.setup_projectile("pet10", Vector2(80.0, 260.0), pet_target, 5.0)
	pet_projectile.call("_process", 0.08)
	var pet_position_before_loss := pet_projectile.position
	pet_target.free()
	pet_projectile.call("_process", 0.08)
	if not bool(pet_projectile.get("_coasting")) or pet_projectile.position == pet_position_before_loss:
		failures.append("pet projectiles must continue on their last trajectory after a target dies")
	pet_projectile.free()

	var pet_target_for_enemy := Node2D.new()
	pet_target_for_enemy.position = Vector2(520.0, 300.0)
	var enemy_projectile := EnemyProjectileActor.new()
	enemy_projectile.setup("victorian_bullet", Vector2(80.0, 260.0), pet_target_for_enemy, 1.0, 1.0)
	enemy_projectile.call("_process", 0.08)
	var enemy_position_before_loss := enemy_projectile.position
	pet_target_for_enemy.free()
	enemy_projectile.call("_process", 0.08)
	if not bool(enemy_projectile.get("_coasting")) or enemy_projectile.position == enemy_position_before_loss:
		failures.append("enemy projectiles must continue on their last trajectory after a pet dies")
	enemy_projectile.free()


static func _test_era_age_and_difficulty(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_language", "zh")
	main.set("_total_runtime_seconds", EraProgression.SECONDS_PER_YEAR * 3.0)
	var age_text := String(main.call("_get_pet_age_text", Main.PetCatalog.get_definition("pet1")))
	var expected_age := 3 + EraProgression.get_elapsed_calendar_years(EraProgression.SECONDS_PER_YEAR * 3.0)
	if age_text != "%d岁" % expected_age:
		failures.append("pet detail ages must advance by the real calendar years shown in the menu")
	main.set("_total_runtime_seconds", EraProgression.SECONDS_PER_YEAR * float(EraProgression.VICTORIAN_ERA_START_YEAR - 1))
	main.set("_debug_enemy_power_scale", 2.0)
	var base_difficulty := float(main.call("_get_base_battle_difficulty_scale"))
	var difficulty_text := String(main.call("_get_battle_difficulty_text"))
	if not difficulty_text.contains("敌军编成") or not difficulty_text.contains("奖励预算") or difficulty_text.contains("战斗力") or difficulty_text.contains("敌军 ×"):
		failures.append("battle invitations must show enemy composition and reward budget without exposing combat power")
	var rolled_values: Array[float] = []
	(main.get("_rng") as RandomNumberGenerator).seed = 71218
	for _roll_index in 4:
		rolled_values.append(float(main.call("_roll_battle_difficulty_scale")))
	for rolled_value in rolled_values:
		if rolled_value < base_difficulty * Main.BATTLE_DIFFICULTY_VARIANCE_MIN - 0.001 or rolled_value > base_difficulty * Main.BATTLE_DIFFICULTY_VARIANCE_MAX + 0.001:
			failures.append("random battle difficulty must stay inside the advertised variance range")
			break
	if is_equal_approx(rolled_values[0], rolled_values[1]):
		failures.append("successive battle invitations must have real difficulty variance")
	main.set("_active_battle_difficulty_scale", 2.73)
	var stronger_budget: Dictionary = main.call("_get_battle_reward_budget", 2.73)
	var weaker_budget: Dictionary = main.call("_get_battle_reward_budget", 0.5)
	if int(stronger_budget.get("gold", 0)) <= int(weaker_budget.get("gold", 0)) or int(stronger_budget.get("faith", 0)) <= int(weaker_budget.get("faith", 0)):
		failures.append("stronger enemy encounters must advertise richer gold and faith budgets")
	main.free()


static func _test_adaptive_encounter_and_rewards(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 700.0, 704.0, false)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)

	var state: Dictionary = main.call("_get_pet_state", "pet1")
	state["upgrade_level"] = 1
	(main.get("_pet_states") as Dictionary)["pet1"] = state
	var battle_controller: Node = main.get("_battle_controller")
	var low_schedule: Array[Dictionary] = battle_controller.call("_build_battle_wave_schedule")
	var low_enemy_count := 0
	var low_wave_max := 0
	for wave in low_schedule:
		var wave_count: int = (wave as Dictionary).get("types", []).size()
		low_enemy_count += wave_count
		low_wave_max = maxi(low_wave_max, wave_count)
	main.set("_battle_wave_schedule", low_schedule.duplicate(true))
	var weak_difficulty := float(main.call("_get_base_battle_difficulty_scale"))
	var low_budget: Dictionary = main.call("_get_battle_reward_budget", weak_difficulty)
	var low_manual_click_gain := float(main.call("_get_manual_faith_click_gain", 1))
	var low_baseline_faith_rate := float(main.call("_get_baseline_faith_growth_rate"))

	state["upgrade_level"] = 50
	(main.get("_pet_states") as Dictionary)["pet1"] = state
	main.set("_battle_wave_schedule", [])
	var mid_schedule: Array[Dictionary] = battle_controller.call("_build_battle_wave_schedule")
	var mid_enemy_count := 0
	var mid_wave_max := 0
	for wave in mid_schedule:
		var wave_count: int = (wave as Dictionary).get("types", []).size()
		mid_enemy_count += wave_count
		mid_wave_max = maxi(mid_wave_max, wave_count)

	state["upgrade_level"] = 100
	(main.get("_pet_states") as Dictionary)["pet1"] = state
	main.set("_battle_wave_schedule", [])
	var high_schedule: Array[Dictionary] = battle_controller.call("_build_battle_wave_schedule")
	var high_enemy_count := 0
	var high_wave_max := 0
	for wave in high_schedule:
		var wave_count: int = (wave as Dictionary).get("types", []).size()
		high_enemy_count += wave_count
		high_wave_max = maxi(high_wave_max, wave_count)
	main.set("_battle_wave_schedule", low_schedule.duplicate(true))
	var strong_difficulty := float(main.call("_get_base_battle_difficulty_scale"))
	main.set("_battle_wave_schedule", high_schedule.duplicate(true))
	var high_budget: Dictionary = main.call("_get_battle_reward_budget", strong_difficulty)

	if low_schedule.size() != 4 or low_wave_max > 3 or int((low_schedule[0] as Dictionary).get("types", []).size()) != 2:
		failures.append("opening battles must keep the authored four waves of only two to three enemies")
	if not (low_enemy_count < mid_enemy_count and mid_enemy_count < high_enemy_count):
		failures.append("enemy count must rise gradually across low, mid, and high pet levels")
	if mid_wave_max > 4 or high_wave_max > 6:
		failures.append("campaign pressure must cap mid-level waves at four and high-level waves at six enemies")
	var veteran_schedule := BattleBalance.build_wave_schedule(
		EraProgression.get_wave_schedule(0.0),
		80.0,
		false
	)
	if veteran_schedule.is_empty() or int((veteran_schedule[0] as Dictionary).get("types", []).size()) != 5:
		failures.append("veteran campaign rosters must add a third reinforcement before the level-100 cap")
	if strong_difficulty <= weak_difficulty:
		failures.append("stronger pets must produce stronger enemy stats for the same wave composition")
	var carry_schedule: Array[Dictionary] = [{"types": ["villager1", "villager2"]}]
	var spread_roster_difficulty := BattleBalance.recommended_difficulty_scale(
		70.0,
		carry_schedule,
		1.0,
		false,
		1.0,
		32.0
	)
	var advanced_carry_difficulty := BattleBalance.recommended_difficulty_scale(
		70.0,
		carry_schedule,
		1.0,
		false,
		1.0,
		70.0
	)
	if advanced_carry_difficulty <= spread_roster_difficulty:
		failures.append("one advanced carry pet must create extra enemy pressure beyond equal spread-out roster power")
	var village_schedule := BattleBalance.build_wave_schedule(EraProgression.get_wave_schedule(0.0), 1.0, false)
	var outer_schedule := BattleBalance.build_wave_schedule(
		EraProgression.get_wave_schedule(EraProgression.get_era_start_runtime_seconds(4)),
		1.0,
		false
	)
	var village_scale := BattleBalance.recommended_difficulty_scale(12.0, village_schedule, 1.0, false, 1.0, 12.0, 1)
	var outer_scale := BattleBalance.recommended_difficulty_scale(12.0, outer_schedule, 1.0, false, 1.0, 12.0, 1)
	var village_wave_health := BattleBalance.strongest_wave_base_health(village_schedule) * pow(village_scale, 0.68)
	var outer_wave_health := BattleBalance.strongest_wave_base_health(outer_schedule) * pow(outer_scale, 0.68)
	if absf(village_wave_health - outer_wave_health) > maxf(village_wave_health, outer_wave_health) * 0.12:
		failures.append("era visuals must not make an equally strong roster face a stronger health budget")
	var village_volley := BattleBalance.strongest_wave_base_volley_damage(village_schedule) * BattleBalance.recommended_enemy_damage_multiplier(12.0, 1.0, 1, village_schedule, 1.0)
	var outer_volley := BattleBalance.strongest_wave_base_volley_damage(outer_schedule) * BattleBalance.recommended_enemy_damage_multiplier(12.0, 1.0, 1, outer_schedule, 1.0)
	if absf(village_volley - outer_volley) > maxf(village_volley, outer_volley) * 0.12:
		failures.append("era visuals must not make an equally strong roster face a stronger damage budget")
	if int(high_budget.get("gold", 0)) <= int(low_budget.get("gold", 0)):
		failures.append("battle gold rewards must rise with potential coin income")
	if int(low_budget.get("enemy_gold", 0)) <= 0:
		failures.append("battle settlement must include the defeated enemies' authored money value")
	if int(low_budget.get("gold", 0)) < int(Main.BattleController.BATTLE_GOLD_REWARD_OPENING_FLOOR * 0.80):
		failures.append("even an opening battle must pay a substantial money reward")
	if Main.BattleController.BATTLE_GOLD_REWARD_MIN_MINUTES < 12.0:
		failures.append("low-frequency battles must be valued at at least twelve minutes of gold production")
	if int(high_budget.get("faith", 0)) <= int(low_budget.get("faith", 0)):
		failures.append("battle faith rewards must rise with baseline faith growth")
	if int(low_budget.get("faith", 0)) < int(floor(
		low_manual_click_gain * Main.BattleController.BATTLE_FAITH_REWARD_MANUAL_CLICKS
	)):
		failures.append("even an opening battle reward must cover the designed manual-faith value")
	if int(low_budget.get("faith", 0)) < int(floor(
		low_baseline_faith_rate * Main.BattleController.BATTLE_FAITH_REWARD_MIN_SECONDS
	)):
		failures.append("battle faith rewards must cover at least one minute of baseline production")

	for drop_index in 12:
		main.call("_spawn_battle_reward", Vector2(300.0 + float(drop_index), 420.0), 50)
	var visual_drops: Array = main.get("_coin_drops")
	if visual_drops.size() > 8:
		failures.append("enemy defeats must cap battlefield reward visuals independently of encounter size")
	for visual_drop in visual_drops:
		if int((visual_drop as Node2D).get("value")) != 0:
			failures.append("battlefield reward coins must be visual-only so pickup cannot duplicate settlement")
			break
	main.set("_gold_coins", 0)
	main.set("_faith_points", 0.0)
	main.set("_battle_active", true)
	main.set("_active_battle_difficulty_scale", strong_difficulty)
	main.set("_persistence_enabled", true)
	main.call("_finish_battle", true)
	if int(main.get("_gold_coins")) != int(high_budget.get("gold", 0)):
		failures.append("victory must credit the complete advertised gold budget directly")
	if int(round(float(main.get("_faith_points")))) != int(high_budget.get("faith", 0)):
		failures.append("victory must credit the complete advertised faith budget directly")
	if not bool(main.get("_save_dirty")):
		failures.append("victory rewards must immediately mark persistent progress for saving")
	var settled_gold := int(main.get("_gold_coins"))
	main.call("_finish_battle", true)
	if int(main.get("_gold_coins")) != settled_gold:
		failures.append("victory settlement must grant its authoritative reward exactly once")
	state["upgrade_level"] = 99
	(main.get("_pet_states") as Dictionary)["pet1"] = state
	var late_difficulty := float(main.call("_get_base_battle_difficulty_scale"))
	var late_budget: Dictionary = main.call("_get_battle_reward_budget", late_difficulty)
	var late_baseline_rate := float(main.call("_get_baseline_faith_growth_rate"))
	var late_manual_click_gain := float(main.call("_get_manual_faith_click_gain", 1))
	var late_next_upgrade_cost := Main.EconomyBalance.next_upgrade_cost(
		main.get("_unlocked_pet_ids") as Array,
		main.get("_pet_states") as Dictionary,
		Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET
	)
	var late_difficulty_factor := clampf(
		pow(maxf(0.20, late_difficulty), 0.12),
		0.80,
		1.20
	)
	var late_base_reward := maxi(
		int(round(5.0 * late_difficulty_factor)),
		maxi(
			int(round(
				late_manual_click_gain
				* Main.BattleController.BATTLE_FAITH_REWARD_MANUAL_CLICKS
				* maxf(1.0, late_difficulty_factor)
			)),
			int(round(
				late_baseline_rate
				* clampf(
					Main.BattleController.BATTLE_FAITH_REWARD_BASE_SECONDS * late_difficulty_factor,
					Main.BattleController.BATTLE_FAITH_REWARD_MIN_SECONDS,
					Main.BattleController.BATTLE_FAITH_REWARD_MAX_SECONDS
				)
			))
		)
	)
	var expected_late_upgrade_floor := mini(
		int(round(
			float(late_next_upgrade_cost)
			* Main.BattleController.BATTLE_FAITH_REWARD_UPGRADE_FRACTION
			* late_difficulty_factor
		)),
		int(round(
			float(late_base_reward)
			* Main.BattleController.BATTLE_FAITH_REWARD_MAX_BASE_MULTIPLIER
		))
	)
	if int(late_budget.get("faith", 0)) < maxi(late_base_reward, expected_late_upgrade_floor):
		failures.append("late battles must award a visible, capped fraction of the next faith upgrade")
	main.set("_persistence_enabled", false)
	main.free()


static func _test_campaign_combat_checkpoints(failures: Array[String]) -> void:
	var checkpoints := [
		{"hours": 0.0, "levels": {"pet1": 1}},
		{"hours": 10.0, "levels": {"pet1": 63, "pet2": 74, "pet3": 69, "pet4": 63, "pet5": 61}},
		{"hours": 25.0, "levels": {"pet1": 80, "pet2": 95, "pet3": 88, "pet4": 80, "pet5": 77, "pet6": 74}},
		{"hours": 45.0, "levels": {"pet1": 93, "pet2": 100, "pet3": 100, "pet4": 93, "pet5": 90, "pet6": 86, "pet7": 83, "pet8": 81}},
		{"hours": 65.0, "levels": {"pet1": 100, "pet2": 100, "pet3": 100, "pet4": 100, "pet5": 100, "pet6": 97, "pet7": 94, "pet8": 91, "pet9": 88}},
		{"hours": 89.0, "levels": {"pet1": 100, "pet2": 100, "pet3": 100, "pet4": 100, "pet5": 100, "pet6": 100, "pet7": 100, "pet8": 100, "pet9": 100, "pet10": 99}}
	]
	for checkpoint_value in checkpoints:
		var checkpoint := checkpoint_value as Dictionary
		var levels := checkpoint.get("levels", {}) as Dictionary
		var pet_ids: Array = levels.keys()
		var average_level := 0.0
		var roster_power := 0.0
		var peak_power := 0.0
		var estimated_dps := 0.0
		for pet_id_value in pet_ids:
			var pet_id := String(pet_id_value)
			var level := int(levels.get(pet_id, 1))
			var evolved := level >= Main.PetProgression.CAMPAIGN_PET_LEVEL_TARGET
			var pet_power := Main.PetCatalog.get_combat_power(pet_id, level, evolved)
			var rarity := clampi(int(Main.PetCatalog.get_definition(pet_id).get("rarity_stars", 1)), 1, 5)
			var damage_scale := clampf(pow(pet_power / 20.0, 0.35), 0.80, 2.5)
			average_level += float(level)
			roster_power += pet_power
			peak_power = maxf(peak_power, pet_power)
			estimated_dps += (
				(1.05 + float(rarity) * 0.24 + sqrt(float(level)) * 0.055)
				* damage_scale
				/ 1.15
			)
		average_level /= float(maxi(1, pet_ids.size()))
		var runtime_seconds := float(checkpoint.get("hours", 0.0)) * 3600.0
		var schedule := BattleBalance.build_wave_schedule(
			EraProgression.get_wave_schedule(runtime_seconds),
			average_level,
			false
		)
		var difficulty := BattleBalance.recommended_difficulty_scale(
			roster_power,
			schedule,
			average_level,
			false,
			1.0,
			peak_power,
			pet_ids.size()
		)
		var health_scale := pow(maxf(0.01, difficulty), 0.68)
		var strongest_wave_health := 0.0
		for wave_value in schedule:
			var wave_health := 0.0
			for enemy_id_value in (wave_value as Dictionary).get("types", []):
				var enemy_id := String(enemy_id_value)
				wave_health += (
					float(EnemyActor.DEFINITIONS[enemy_id].get("hp", 1.0))
					* EnemyActor.get_health_multiplier(enemy_id)
					* health_scale
				)
			strongest_wave_health = maxf(strongest_wave_health, wave_health)
		var estimated_clear_seconds := strongest_wave_health / maxf(0.001, estimated_dps)
		if difficulty < BattleBalance.MIN_DIFFICULTY_SCALE or difficulty > 100.0:
			failures.append(
				"the %.0fh combat checkpoint must stay inside the adaptive difficulty envelope, got %.2f"
				% [float(checkpoint.get("hours", 0.0)), difficulty]
			)
		if estimated_clear_seconds < 7.0 or estimated_clear_seconds > 16.0:
			failures.append(
				"the %.0fh strongest wave must remain a clearable 7-16 seconds, estimated %.2f"
				% [float(checkpoint.get("hours", 0.0)), estimated_clear_seconds]
			)


static func _test_invitation_retention_and_singleton(failures: Array[String]) -> void:
	var standalone := EventInvitation.new()
	standalone.setup(
		"battle",
		Main.BATTLE_INVITE_TEXTURE,
		Vector2i(1200, 720),
		704.0,
		420.0,
		"en",
		"ENEMIES: TEST",
		"ENEMIES: TEST",
		"敌军编成：测试"
	)
	var expired_events: Array[String] = []
	standalone.expired.connect(func(event_type: String) -> void: expired_events.append(event_type))
	standalone.set_language("zh")
	if String(standalone.get("_language")) != "zh" or not String(standalone.get("_difficulty_text")).contains("敌军编成"):
		failures.append("a retained invitation must translate its locked encounter when language changes")
	standalone.set_language("en")
	if not String(standalone.get("_difficulty_text")).contains("ENEMIES"):
		failures.append("a retained invitation must restore its English encounter copy")
	standalone.call("_process", 10_000.0)
	if bool(standalone.get("_resolved")) or not expired_events.is_empty():
		failures.append("an untouched event invitation must remain on the desktop indefinitely")
	standalone.free()

	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.call("_spawn_event_invitation", "battle")
	var first_invitation: Node2D = main.get("_event_invitation")
	main.call("_spawn_event_invitation", "battle")
	var events_controller: Node = main.get("_events_controller")
	var invitation_count := 0
	for child in events_controller.get_children():
		if child is EventInvitation:
			invitation_count += 1
	if first_invitation == null or main.get("_event_invitation") != first_invitation or invitation_count != 1:
		failures.append("event scheduling must retain exactly one desktop invitation at a time")
	main.free()


static func _test_battle_invitation_cooldowns(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_simulation_now_seconds", 1000.0)
	main.call("_spawn_event_invitation", "battle")
	var discarded_invitation := main.get("_event_invitation") as Node2D
	main.call("_on_event_invitation_discarded", "battle")
	if discarded_invitation != null:
		discarded_invitation.free()
	var invitation_history: Array = (main.get("_news_feed") as RefCounted).call("get_history")
	if invitation_history.is_empty():
		failures.append("discarded invitations must leave a localized archive entry")
	else:
		var invitation_article := invitation_history.back() as Dictionary
		if (
			String(invitation_article.get("headline", "")) != "事件邀请已被丢弃。"
			or String(invitation_article.get("headline_en", "")) != "The invitation was discarded."
		):
			failures.append("system-event news must preserve both languages for later switching")
	var declined_delay := float(main.get("_next_battle_at")) - 1000.0
	if (
		declined_delay < Main.BATTLE_DECLINED_DELAY_MIN_SECONDS
		or declined_delay > Main.BATTLE_DECLINED_DELAY_MAX_SECONDS
	):
		failures.append("discarding a battle invitation must use the longer declined cooldown")

	main.set("_simulation_now_seconds", 2000.0)
	main.set("_battle_active", true)
	main.set("_active_battle_difficulty_scale", 1.0)
	main.call("_finish_battle", false)
	var post_battle_delay := float(main.get("_next_battle_at")) - 2000.0
	if (
		post_battle_delay < Main.BATTLE_INTERVAL_MIN_SECONDS
		or post_battle_delay > Main.BATTLE_INTERVAL_MAX_SECONDS
	):
		failures.append("a completed battle must use the configured short invitation cooldown")

	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 700.0, 704.0, false)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	main.set("_total_runtime_seconds", 1000.0)
	main.set("_next_pilgrimage_at", 1999.0)
	main.call("_update_pilgrimage")
	var pilgrimage_invitation := main.get("_event_invitation") as Node2D
	if pilgrimage_invitation == null or String(pilgrimage_invitation.get("event_type")) != "pilgrimage":
		failures.append("the longer battle cadence must leave room for a due pilgrimage invitation")
	elif is_instance_valid(pilgrimage_invitation):
		pilgrimage_invitation.free()
	main.set("_event_invitation", null)
	main.set("_simulation_now_seconds", float(main.get("_next_battle_at")) + 0.1)
	main.call("_update_event_invitations")
	var followup_invitation := main.get("_event_invitation") as Node2D
	if followup_invitation == null or String(followup_invitation.get("event_type")) != "battle":
		failures.append("the reserved post-battle invitation slot must produce the next battle letter")
	main.free()


static func _test_pet_combat_assets(failures: Array[String]) -> void:
	for loop_pet_id in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		var loop_frames := Main.PetCatalog.build_frames(loop_pet_id)
		for loop_name in ["idle", "walk"]:
			var loop_count := loop_frames.get_frame_count(loop_name)
			if loop_count > 1 and (
				not is_equal_approx(loop_frames.get_frame_duration(loop_name, 0), 0.5)
				or not is_equal_approx(loop_frames.get_frame_duration(loop_name, loop_count - 1), 0.5)
			):
				failures.append("%s %s loop must not dwell on its wraparound pose" % [loop_pet_id, loop_name])
	for pet_id in ["pet3", "pet4", "pet5", "pet6"]:
		var pet_data := Main.PetCatalog.get_definition(pet_id)
		var frames := Main.PetCatalog.build_frames(pet_id)
		if not frames.has_animation("attack") or frames.get_frame_count("attack") != 12:
			failures.append("%s must use its authored melee attack sheet" % pet_id)
		if not FileAccess.file_exists(String(pet_data.get("attack", ""))):
			failures.append("%s must reference the corrected attack asset filename" % pet_id)
		if not pet_data.has("attack_faces_right"):
			failures.append("%s must declare the authored attack-sheet direction explicitly" % pet_id)
	var melee_pet := Main.DesktopPetActor.new()
	melee_pet.setup("pet3", Vector2i(900, 600), 0.0, 900.0, 640.0, 584.0, false)
	melee_pet.set_battle_mode(true)
	melee_pet.play_battle_attack_toward(-1.0)
	var melee_sprite := melee_pet.get_node_or_null("pet3Sprite") as AnimatedSprite2D
	if melee_sprite == null or melee_sprite.animation != "attack":
		failures.append("melee pets must switch to their attack animation when striking")
	elif melee_sprite.flip_h != bool(Main.PetCatalog.get_definition("pet3").get("attack_faces_right", false)):
		failures.append("pet3 must flip exactly once when its authored attack faces away from a left-side target")
	elif melee_sprite.frame != 0:
		failures.append("horizontal facing changes must not reverse or skip the authored attack frame order")
	if float(melee_pet.get_battle_attack_duration()) < 12.0 / 12.0:
		failures.append("combat cooldowns must leave enough time for all authored attack frames to play")
	melee_pet.free()
	var pet4 := Main.DesktopPetActor.new()
	pet4.setup("pet4", Vector2i(900, 600), 0.0, 900.0, 640.0, 584.0, false)
	pet4.set_battle_mode(true)
	var pet4_root_y := pet4.position.y
	var pet4_ground_y := float(pet4.call("_get_ground_contact_y"))
	pet4.play_battle_attack_toward(-1.0)
	var pet4_sprite := pet4.get_node_or_null("pet4Sprite") as AnimatedSprite2D
	if pet4_sprite == null:
		failures.append("pet4 must build its authored attack sprite")
	else:
		for frame_index in pet4_sprite.sprite_frames.get_frame_count("attack"):
			pet4_sprite.frame = frame_index
			var frame_image := pet4_sprite.sprite_frames.get_frame_texture("attack", frame_index).get_image()
			var frame_bounds := frame_image.get_used_rect()
			if frame_bounds.position.y < 40 or frame_bounds.size.x >= frame_image.get_width() - 20:
				failures.append("pet4 attack frames must discard per-cell chroma residue before grounding")
				break
			pet4.call("_anchor_attack_frame_to_visual_bottom")
			var visible_bottom := float(pet4.call("_get_current_frame_visual_bottom_y"))
			if absf(visible_bottom - pet4_ground_y) > 1.0:
				failures.append("every pet4 attack frame must remain locked to the ground")
				break
	if not is_equal_approx(pet4.position.y, pet4_root_y):
		failures.append("starting pet4's attack must not move its actor root upward")
	pet4.free()
	var pet6 := Main.DesktopPetActor.new()
	pet6.setup("pet6", Vector2i(900, 600), 0.0, 900.0, 640.0, 584.0, false)
	pet6.set_battle_mode(true)
	pet6.play_battle_attack_toward(-1.0)
	var pet6_sprite := pet6.get_node_or_null("pet6Sprite") as AnimatedSprite2D
	if pet6_sprite == null or pet6_sprite.animation != "attack" or pet6_sprite.sprite_frames.get_frame_count("attack") != 12:
		failures.append("pet6 must play all twelve frames of its corrected attack animation in battle")
	if bool(Main.PetCatalog.get_definition("pet6").get("attack_align_to_floor", true)):
		failures.append("pet6 attack frames must preserve their authored center instead of following tentacle bottoms")
	pet6.free()


static func _test_pet6_dragged_combat(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_simulation_now_seconds", 1000.0)
	main.set("_battle_started_at", 1000.0)
	main.set("_battle_ends_at", 1100.0)
	main.set("_battle_wave_schedule", [])
	main.set("_battle_next_wave_index", 0)
	var pet6 := Main.DesktopPetActor.new()
	pet6.setup("pet6", Vector2i(1000, 720), 0.0, 1000.0, 720.0, 704.0, false)
	pet6.position.x = 820.0
	pet6.set_battle_mode(true)
	main.add_child(pet6)
	pet6.grabbed_changed.connect(Callable(main, "_on_pet_grabbed_changed"))
	(main.get("_pets") as Array).append(pet6)
	var actor_key := str(pet6.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[actor_key] = 10.0
	(main.get("_battle_pet_max_health") as Dictionary)[actor_key] = 10.0
	pet6.set("_pointer_held", true)
	pet6.set("_pointer_hold_time", 0.4)
	pet6.call("_begin_grab")
	pet6.position = Vector2(820.0, 520.0)
	pet6.call("_finish_pointer_hold", true)
	if int(pet6.get("_behavior")) != Main.DesktopPetActor.Behavior.FALLING:
		failures.append("releasing a dragged pet6 above the taskbar must enter its landing state")
	for _step in 180:
		pet6.call("_update_falling", 1.0 / 60.0)
		if int(pet6.get("_behavior")) != Main.DesktopPetActor.Behavior.FALLING:
			break
	if not pet6.is_battle_ready():
		failures.append(
			"pet6 must leave FALLING and become battle-ready after a real drag landing (behavior=%s y=%.1f rest=%.1f held=%s)"
			% [pet6.get("_behavior"), pet6.position.y, float(pet6.call("_get_rest_y")), pet6.get("_pointer_held")]
		)
	main.set("_simulation_now_seconds", 1000.07)
	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(530.0, 704.0), 704.0, 1.0, 530.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	var health_before := enemy.get_health()
	main.call("_update_battle", 0.016)
	var sprite := pet6.get_node_or_null("pet6Sprite") as AnimatedSprite2D
	if sprite == null or sprite.animation != "attack":
		failures.append(
			"a dragged pet6 beside an enemy must visibly attack instead of sleeping (animation=%s ready=%s formed=%s distance=%.1f)"
			% [String(sprite.animation) if sprite != null else "missing", pet6.is_battle_ready(), (main.get("_battle_pet_formed") as Dictionary).get(actor_key, false), absf(pet6.position.x - enemy.position.x)]
		)
	elif sprite.flip_h:
		failures.append("pet6's authored left-facing attack must not flip away from an enemy standing on its left")
	if enemy.get_health() >= health_before:
		failures.append("a dragged pet6 attack must apply real enemy damage")
	main.free()
	for pet_id in Main.RANGED_BATTLE_PET_IDS:
		var config: Dictionary = BattleEffectActor.PROJECTILE_CONFIG.get(pet_id, {})
		if config.is_empty() or not FileAccess.file_exists(String(config.get("sheet", ""))):
			failures.append("%s must have a dedicated projectile type" % pet_id)
		var evolved_config: Dictionary = BattleEffectActor.PROJECTILE_CONFIG.get("%s_evolved" % pet_id, {})
		if evolved_config.is_empty() or not FileAccess.file_exists(String(evolved_config.get("sheet", ""))):
			failures.append("evolved %s must unlock a Super Pixel projectile" % pet_id)
	var target := Node2D.new()
	target.position = Vector2(320.0, 300.0)
	var projectile := BattleEffectActor.new()
	projectile.setup_projectile("pet10", Vector2(40.0, 240.0), target, 6.0)
	var projectile_sprite := projectile.get_node_or_null("ProjectileSprite") as AnimatedSprite2D
	if projectile_sprite == null or projectile_sprite.sprite_frames.get_frame_count("fly") != 5:
		failures.append("ranged pet projectiles must animate through five authored frames")
	var evolved_projectile := BattleEffectActor.new()
	evolved_projectile.setup_projectile("pet10", Vector2(40.0, 240.0), target, 6.0, true)
	var evolved_sprite := evolved_projectile.get_node_or_null("ProjectileSprite") as AnimatedSprite2D
	if evolved_sprite == null or evolved_sprite.sprite_frames.get_frame_count("fly") != 8:
		failures.append("evolved pet10 must launch the eight-frame violet meteor projectile")
	if not Main.BATTLE_DRAG_HINT_ZH.contains("拖动宠物"):
		failures.append("battle announcements must teach the player to drag pets beside enemies")
	var explosion := BattleEffectActor.new()
	explosion.setup_explosion(Vector2.ZERO, 7.5)
	var explosion_sprite := explosion.get_node_or_null("ExplosionSprite") as AnimatedSprite2D
	if explosion_sprite == null or explosion_sprite.sprite_frames.get_frame_count("burst") != 11:
		failures.append("high-power pets must select the large eleven-frame explosion")
	projectile.free()
	evolved_projectile.free()
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
	var permanent_roster_rate := (
		pet2_only_rate
		+ Main.PetProgression.faith_per_second(Main.PetCatalog.get_definition("pet1"), 1)
	)
	if not is_equal_approx(float(main.call("_get_baseline_faith_growth_rate")), permanent_roster_rate):
		failures.append("temporary recovery must not close a permanent pet growth gate")
	main.set("_pilgrimage_active", true)
	main.set("_pilgrimage_total_member_count", 4)
	main.set("_pilgrimage_resolved_count", 4)
	if float(main.call("_get_faith_growth_rate")) <= pet2_only_rate:
		failures.append("an active pilgrimage must still boost live faith production")
	if not is_equal_approx(float(main.call("_get_baseline_faith_growth_rate")), permanent_roster_rate):
		failures.append("a temporary pilgrimage must not open a permanent pet growth gate")
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


static func _test_inventory_deploy_during_events(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	var unlocked: Array = main.get("_unlocked_pet_ids")
	unlocked.clear()
	unlocked.append_array(["pet2", "pet3"])
	var deployed: Array = main.get("_deployed_pet_ids")
	deployed.clear()

	main.set("_battle_active", true)
	main.call("_on_inventory_pet_deploy_requested", "pet2")
	var pets: Array = main.get("_pets")
	if pets.size() != 1 or not deployed.has("pet2"):
		failures.append("storage must deploy an owned pet while a battle is active")
	elif not bool((pets[0] as Node2D).get("_battle_mode")):
		failures.append("a pet deployed from storage during battle must join battle mode immediately")

	main.set("_battle_active", false)
	main.set("_pilgrimage_active", true)
	main.call("_on_inventory_pet_deploy_requested", "pet3")
	if pets.size() != 2 or not deployed.has("pet3"):
		failures.append("storage must deploy an owned pet while a pilgrimage is active")
	elif not bool((pets[1] as Node2D).get("_autonomy_paused")):
		failures.append("a pet deployed from storage during pilgrimage must join the paused procession state")
	main.free()


static func _test_battle_starts_first_wave(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_language", "zh")
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
	var invitation_text := String(invitation.get("_difficulty_text")) if invitation != null else ""
	var pending_budget: Dictionary = main.call("_get_battle_reward_budget", pending_difficulty)
	var advertised_schedule: Array = (main.get("_battle_wave_schedule") as Array).duplicate(true)
	var pending_gold_text := Main.CurrencyDisplay.format_compact(int(pending_budget.get("gold", 0)))
	if pending_difficulty < 0.0 or invitation == null or not invitation_text.contains("%s + %d 信仰" % [pending_gold_text, int(pending_budget.get("faith", 0))]):
		failures.append("battle invitations must display the reward budget for the exact randomly rolled encounter")
	main.set("_total_runtime_seconds", EraProgression.SECONDS_PER_YEAR * 20.0)
	var pre_battle_pet_x := pet.position.x
	main.call("_on_event_invitation_accepted", "battle")
	if not bool(main.get("_battle_active")):
		failures.append("accepting the debug invitation must enter battle state")
	if not is_equal_approx(float(main.get("_active_battle_difficulty_scale")), pending_difficulty):
		failures.append("accepting an invitation must lock its advertised difficulty for every enemy wave")
	if (main.get("_battle_wave_schedule") as Array) != advertised_schedule:
		failures.append("an invitation must lock its advertised wave composition across later era changes")
	var opening_enemy_count := (main.get("_battle_enemies") as Array).size()
	if opening_enemy_count < 2 or opening_enemy_count > 4:
		failures.append("battle start must send a readable opening formation of two to four enemies")
	var entry_slots: Array[float] = []
	for enemy_value in main.get("_battle_enemies") as Array:
		entry_slots.append(float((enemy_value as Node2D).get("_entry_x")))
	entry_slots.sort()
	if (
		entry_slots.size() >= 2
		and (
			entry_slots[1] <= entry_slots[0]
			or (
				entry_slots.size() >= 3
				and entry_slots.back() <= entry_slots[entry_slots.size() - 2]
			)
		)
	):
		failures.append("enemy waves must spread across distinct left-side formation slots")
	if not is_equal_approx(
		float(main.get("_battle_ends_at")) - float(main.get("_battle_started_at")),
		55.0
	):
		failures.append("battle encounters must use the full 55-second clear deadline")
	if not bool(pet.get("_battle_mode")):
		failures.append("battle start must enable combat behavior for deployed pets")
	if not is_equal_approx(pet.position.x, pre_battle_pet_x):
		failures.append("battle start must keep every pet at its existing desktop position")
	if not bool((main.get("_battle_pet_formed") as Dictionary).get(str(pet.get_instance_id()), false)):
		failures.append("pets must begin battle already settled at their current positions")
	if not bool(pet.get("_interaction_enabled")):
		failures.append("battle pets must remain draggable so placement can alter the fight")
	var projectile_source := (main.get("_battle_enemies") as Array)[0] as Node2D
	for _projectile_index in Main.BATTLE_EFFECT_LIMIT + 8:
		main.call(
			"_on_enemy_projectile_requested",
			projectile_source,
			pet,
			1.0,
			"arrow",
			1.0
		)
	if (main.get("_battle_effects") as Array).size() > Main.BATTLE_EFFECT_LIMIT:
		failures.append("expanded enemy barrages must respect the shared battle-effect soft limit")
	var formation_start_x := pet.position.x
	main.call("_update_battle_pet_formation", 1.0 / 60.0)
	var early_formation_step := absf(pet.position.x - formation_start_x)
	if not is_zero_approx(early_formation_step):
		failures.append("melee pets must hold position while enemies are still inside spawn zones")
	projectile_source.call("_process", 4.0)
	formation_start_x = pet.position.x
	main.call("_update_battle_pet_formation", 1.0 / 60.0)
	var formation_step := absf(pet.position.x - formation_start_x)
	if formation_step <= 0.0 or formation_step > 5.0:
		failures.append("melee combat movement must remain smooth after an enemy finishes entering")
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


static func _test_debug_battle_replacement_is_silent(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.set("_gold_coins", 321)
	main.set("_faith_points", 654.0)
	main.set("_battle_active", true)
	main.set("_active_battle_difficulty_scale", 1.0)
	main.set("_battle_wave_schedule", [{"time": 0.0, "types": ["villager1"]}])
	var battlefield := main.get("_battle_controller") as Node
	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(180.0, 704.0), 704.0, 1.0, 180.0, 1200.0)
	enemy.set_meta("battle_runtime", true)
	if battlefield != null:
		battlefield.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)

	main.call("_on_debug_event_requested", "battle")
	if int(main.get("_gold_coins")) != 321 or not is_equal_approx(float(main.get("_faith_points")), 654.0):
		failures.append("replacing a debug battle must never settle the old fight as a victory")
	if bool(main.get("_battle_active")) or main.get("_event_invitation") == null:
		failures.append("replacing a debug battle must quietly clear the old field before dropping one new invitation")
	if battlefield != null:
		for child in battlefield.get_children():
			if child is AnimatedSprite2D and not child.is_queued_for_deletion():
				failures.append("debug battle replacement must not spawn a synchronous smoke burst")
				break
	main.free()


static func _test_battle_timeout_is_defeat(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.set("_simulation_now_seconds", 56.0)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 700.0, 704.0, false)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	var actor_key := str(pet.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[actor_key] = 20.0
	(main.get("_battle_pet_max_health") as Dictionary)[actor_key] = 20.0
	(main.get("_battle_pet_formed") as Dictionary)[actor_key] = false

	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(180.0, 704.0), 704.0, 1.0, 180.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	main.set("_battle_active", true)
	main.set("_battle_started_at", 0.0)
	main.set("_battle_ends_at", 55.0)
	main.set("_battle_wave_schedule", [{"time": 0.0, "types": []}])
	main.set("_battle_next_wave_index", 1)
	main.set("_active_battle_difficulty_scale", 1.0)
	main.call("_update_battle", 0.016)
	if bool(main.get("_battle_active")):
		failures.append("a battle must end when its 55-second deadline is reached")
	if int(main.get("_gold_coins")) != 0 or float(main.get("_faith_points")) != 0.0:
		failures.append("timing out with enemies alive must be a defeat without the victory reward")
	main.free()
