extends RefCounted

const Main = preload("res://scripts/main.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_event_assets(failures)
	_test_era_progression(failures)
	_test_enemy_roles_and_frames(failures)
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
	var soldier_time := EraProgression.SECONDS_PER_YEAR * float(EraProgression.SOLDIER_ERA_START_YEAR - 1)
	if EraProgression.get_era_index(soldier_time - 0.01) != 0:
		failures.append("soldiers must stay out of the village era")
	if EraProgression.get_era_index(soldier_time) != 1:
		failures.append("elapsed desktop time must advance into the soldier era")
	var later_schedule := EraProgression.get_wave_schedule(soldier_time)
	var later_types: Array[String] = []
	for wave in later_schedule:
		for enemy_type in (wave as Dictionary).get("types", []):
			later_types.append(String(enemy_type))
	if not later_types.has("soldier1") or not later_types.has("soldier2"):
		failures.append("the later era must schedule both melee and ranged soldiers")


static func _test_enemy_roles_and_frames(failures: Array[String]) -> void:
	for enemy_id in ["villager1", "villager2", "soldier1", "soldier2"]:
		var enemy := EnemyActor.new()
		enemy.setup(enemy_id, Vector2.ZERO, 400.0)
		var sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
		if sprite == null:
			failures.append("%s must build a battle sprite" % enemy_id)
		else:
			if sprite.sprite_frames.get_frame_count("run") != 12:
				failures.append("%s must use all 12 authored movement frames" % enemy_id)
			if sprite.sprite_frames.get_frame_count("attack") != 16:
				failures.append("%s must use all 16 authored attack frames" % enemy_id)
			if sprite.animation != "run" or not sprite.is_playing():
				failures.append("%s must visibly run while entering the battlefield" % enemy_id)
			if sprite.position.y <= -64.0:
				failures.append("%s feet must overlap the taskbar edge instead of hovering" % enemy_id)
		if bool(enemy.get("is_ranged")) != (enemy_id == "soldier2"):
			failures.append("only soldier2 must hold ranged attack distance")
		var target := Node2D.new()
		target.position = Vector2(500.0, 400.0)
		enemy.set_target(target)
		enemy.call("_process", 0.1)
		if enemy.position.x <= 0.0:
			failures.append("%s must advance toward pets during its run animation" % enemy_id)
		enemy.position.x = 0.0
		target.position = Vector2(120.0 if enemy_id == "soldier2" else 60.0, 400.0)
		enemy.set_target(target)
		enemy.call("_process", 0.01)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s must switch from run to its authored attack animation in range" % enemy_id)
		enemy.call("_process", 0.5)
		if sprite != null and sprite.animation != "attack":
			failures.append("%s attack animation must remain visible through its hit frame" % enemy_id)
		target.free()
		enemy.free()


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
	if not bool(main.get("_battle_active")):
		failures.append("accepting or debug-triggering a battle must enter battle state")
	if (main.get("_battle_enemies") as Array).size() < 2:
		failures.append("battle start must immediately send the first timed enemy wave from the left")
	if not bool(pet.get("_battle_mode")):
		failures.append("battle start must move deployed pets into the right-side formation mode")
	if not bool(pet.get("_interaction_enabled")):
		failures.append("battle pets must remain draggable so placement can alter the fight")
	main.call("_on_pet_grabbed_changed", pet, true)
	if not bool((main.get("_battle_pet_formed") as Dictionary).get(str(pet.get_instance_id()), false)):
		failures.append("manually grabbing a battle pet must release it from formation correction")
	main.call("_finish_battle", true)
	if bool(main.get("_battle_active")) or bool(pet.get("_battle_mode")):
		failures.append("battle cleanup must restore surviving pets to normal autonomy")
	main.free()
