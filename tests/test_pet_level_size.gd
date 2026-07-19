extends RefCounted

const Main = preload("res://scripts/main.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_growth_curve(failures)
	_test_actor_setup_and_live_level_change(failures)
	_test_main_spawn_and_debug_sync(failures)
	return failures


static func _test_growth_curve(failures: Array[String]) -> void:
	var levels := [1, 10, 25, 50, 75, 99, 100, 101, 300, 1000, 100_000]
	var previous := 0.0
	for level in levels:
		var multiplier := DesktopPetActor.get_level_size_multiplier(level, false)
		if multiplier + 0.00001 < previous:
			failures.append("base-form pet visual size must increase monotonically with level")
			break
		previous = multiplier
	if not is_equal_approx(
		DesktopPetActor.get_level_size_multiplier(1, false),
		DesktopPetActor.LEVEL_SIZE_MIN_MULTIPLIER
	):
		failures.append("a level-1 pet must use the designed young-pet size")
	if not is_equal_approx(
		DesktopPetActor.get_level_size_multiplier(99, false),
		DesktopPetActor.LEVEL_SIZE_BASE_FORM_MAX_MULTIPLIER
	):
		failures.append("a base form must stop below the evolved form's size band")
	if DesktopPetActor.get_level_size_multiplier(100_000, false) >= 1.0:
		failures.append("unevolved debug/save levels must never unlock evolved-form growth")
	if not is_equal_approx(DesktopPetActor.get_level_size_multiplier(100, true), 1.0):
		failures.append("an evolved level-100 pet must preserve its authored evolved size")
	if DesktopPetActor.get_level_size_multiplier(300, true) <= 1.0:
		failures.append("levels above 100 must continue growing slowly")
	if DesktopPetActor.get_level_size_multiplier(100_000, true) > DesktopPetActor.LEVEL_SIZE_MAX_MULTIPLIER + 0.00001:
		failures.append("very high pet levels must respect the visual-size cap")
	var base_pet10_scale := float(Main.PetCatalog.get_definition("pet10").get("desktop_scale", 0.0))
	var evolved_pet10_scale := float(Main.PetCatalog.get_evolution_definition("pet10").get("desktop_scale", 0.0))
	if base_pet10_scale * DesktopPetActor.LEVEL_SIZE_BASE_FORM_MAX_MULTIPLIER >= evolved_pet10_scale:
		failures.append("pet10's largest base form must remain visibly smaller than its evolved form")


static func _test_actor_setup_and_live_level_change(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, false, 1)
	var catalog_scale := float(actor.get("_catalog_pet_scale"))
	var young_scale := float(actor.get("_pet_scale"))
	if int(actor.get("pet_level")) != 1:
		failures.append("desktop actor setup must retain the supplied pet level")
	if not is_equal_approx(
		young_scale,
		catalog_scale * DesktopPetActor.get_level_size_multiplier(1, false)
	):
		failures.append("desktop actor setup must apply level-derived size")
	var old_ground_y := actor.position.y
	actor.set_pet_level(99)
	var adult_scale := float(actor.get("_pet_scale"))
	var sprite := actor.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	if adult_scale <= young_scale or not is_equal_approx(
		adult_scale,
		catalog_scale * DesktopPetActor.LEVEL_SIZE_BASE_FORM_MAX_MULTIPLIER
	):
		failures.append("raising an existing base pet to level 99 must reach its base-form ceiling")
	if sprite == null or not is_equal_approx(sprite.scale.x, adult_scale):
		failures.append("live pet-level changes must immediately update the rendered sprite")
	if actor.position.y >= old_ground_y:
		failures.append("a growing ground pet must move its center upward to keep its feet planted")
	actor.set_pet_level(100_000)
	if float(actor.get("_pet_scale")) > catalog_scale * DesktopPetActor.LEVEL_SIZE_BASE_FORM_MAX_MULTIPLIER + 0.00001:
		failures.append("an unevolved live actor must never exceed its base-form cap")
	actor.free()

	var evolved_actor := DesktopPetActor.new()
	evolved_actor.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, true, 100)
	var evolved_catalog_scale := float(evolved_actor.get("_catalog_pet_scale"))
	if not is_equal_approx(float(evolved_actor.get("_pet_scale")), evolved_catalog_scale):
		failures.append("evolution must enter the evolved form's larger size band at level 100")
	evolved_actor.set_pet_level(100_000)
	if float(evolved_actor.get("_pet_scale")) > evolved_catalog_scale * DesktopPetActor.LEVEL_SIZE_MAX_MULTIPLIER + 0.00001:
		failures.append("evolved live growth must respect the configured cap")
	evolved_actor.free()


static func _test_main_spawn_and_debug_sync(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1000, 720))
	main.set("_unlocked_pet_ids", ["pet1"])
	main.set("_deployed_pet_ids", ["pet1"])
	main.set("_pet_states", {"pet1": {"upgrade_level": 20}})
	var actor := main.call("_spawn_desktop_pet", "pet1", 600.0) as Node2D
	if actor == null:
		failures.append("main must be able to spawn a level-scaled desktop pet")
		main.free()
		return
	if int(actor.get("pet_level")) != 20:
		failures.append("save/warehouse spawning must pass the stored pet level into the actor")
	var original_id := actor.get_instance_id()
	var original_scale := float(actor.get("_pet_scale"))
	main.call("_on_debug_pet_levels_requested", {"pet1": 80})
	var synced_actor := (main.get("_pets") as Array).front() as Node2D
	if synced_actor == null or synced_actor.get_instance_id() != original_id:
		failures.append("same-form level changes should resize the deployed actor without replacing it")
	elif int(synced_actor.get("pet_level")) != 80 or float(synced_actor.get("_pet_scale")) <= original_scale:
		failures.append("debug level edits must immediately resize deployed pets")
	main.free()
