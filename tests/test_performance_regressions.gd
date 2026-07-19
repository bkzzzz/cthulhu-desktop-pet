extends RefCounted

const Main = preload("res://scripts/main.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_runtime_pacing_settings(failures)
	_test_pet_interaction_geometry_cache(failures)
	_test_shared_pet_asset_caches(failures)
	_test_battle_engagement_caches(failures)
	_test_storage_release_assets_are_prewarmed(failures)
	_test_hidden_drawer_defers_visual_work(failures)
	_test_saves_are_debounced(failures)
	return failures


static func _test_runtime_pacing_settings(failures: Array[String]) -> void:
	if bool(ProjectSettings.get_setting("application/run/low_processor_mode", false)) and int(ProjectSettings.get_setting("application/run/low_processor_mode_sleep_usec", 10000)) > 3000:
		failures.append("low-processor mode must use a short sleep that preserves smooth animated frame pacing")


static func _test_pet_interaction_geometry_cache(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false, false, 50)
	actor.call("_update_interaction_area")
	var first_revision := int(actor.get("_interaction_geometry_revision"))
	actor.call("_update_interaction_area")
	if int(actor.get("_interaction_geometry_revision")) != first_revision:
		failures.append("a stationary pet must not rebuild its native interaction geometry")
	actor.position.x += 8.0
	actor.call("_update_interaction_area")
	if int(actor.get("_interaction_geometry_revision")) != first_revision + 1:
		failures.append("pet interaction geometry must still update after visible movement")
	actor.free()


static func _test_shared_pet_asset_caches(failures: Array[String]) -> void:
	var first := DesktopPetActor.new()
	var second := DesktopPetActor.new()
	first.setup("pet7", Vector2i(1000, 720), 0.0, 1000.0, 420.0, 704.0, false, false, 50)
	second.setup("pet7", Vector2i(1000, 720), 0.0, 1000.0, 580.0, 704.0, false, false, 50)
	var first_image := first.get("_stable_hit_image") as Image
	var second_image := second.get("_stable_hit_image") as Image
	if first_image == null or second_image == null or first_image.get_instance_id() != second_image.get_instance_id():
		failures.append("same-form pets must share their precomputed hit-test image")
	var runtime_definition := PetCatalog.get_runtime_definition("pet7", false)
	if not runtime_definition.is_read_only():
		failures.append("cached runtime pet definitions must be immutable")
	first.free()
	second.free()


static func _test_battle_engagement_caches(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false, false, 50)
	var sprite := actor.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	var cache: Dictionary = DesktopPetActor._battle_frame_bottom_cache
	var cached_before_attack := cache.size()
	actor.set_battle_mode(true)
	actor.play_battle_attack_toward(1.0)
	if sprite != null:
		for frame_index in sprite.sprite_frames.get_frame_count("attack"):
			sprite.frame = frame_index
			actor.call("_get_current_frame_local_bottom")
	if cache.size() != cached_before_attack:
		failures.append("first engagement must use precomputed pet attack-frame metrics")
	actor.free()


static func _test_storage_release_assets_are_prewarmed(failures: Array[String]) -> void:
	DesktopPetActor.warm_up_assets("pet4", false, 50)
	var frame_cache_size := (PetCatalog._frame_cache as Dictionary).size()
	var hit_cache_size := (DesktopPetActor._stable_hit_image_cache as Dictionary).size()
	var bottom_cache_size := (DesktopPetActor._battle_frame_bottom_cache as Dictionary).size()
	var released_actor := DesktopPetActor.new()
	released_actor.setup("pet4", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false, false, 50)
	if (PetCatalog._frame_cache as Dictionary).size() != frame_cache_size:
		failures.append("releasing a warmed stored pet must not rebuild animation textures")
	if (DesktopPetActor._stable_hit_image_cache as Dictionary).size() != hit_cache_size:
		failures.append("releasing a warmed stored pet must reuse its hit geometry image")
	if (DesktopPetActor._battle_frame_bottom_cache as Dictionary).size() != bottom_cache_size:
		failures.append("releasing a warmed stored pet must reuse attack-frame metrics")
	released_actor.free()


static func _test_hidden_drawer_defers_visual_work(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	drawer.call("_create_drawer_window")
	var labels: Dictionary = drawer.get("_upgrade_name_labels")
	var pet_label := labels.get("pet1") as Label
	if pet_label == null:
		failures.append("performance test could not find the pet1 upgrade label")
		drawer.free()
		return
	pet_label.text = "unchanged while hidden"
	var entries := [{
		"id": "pet1",
		"name": "Cached name",
		"level": 12,
		"cost": 5,
		"affordable": true,
		"current_fps": 1.0,
		"next_fps": 1.2,
		"icon": String(PetCatalog.get_definition("pet1").get("icon", ""))
	}]
	drawer.call("refresh_pet_upgrades", entries)
	if pet_label.text != "unchanged while hidden":
		failures.append("a closed drawer must cache data without repainting invisible upgrade rows")
	drawer.set("_drawer_open", true)
	drawer.call("refresh_pet_upgrades", entries)
	if pet_label.text != "Cached name":
		failures.append("opening the drawer must paint the latest cached pet data")
	drawer.free()


static func _test_saves_are_debounced(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", true)
	main.call("_request_save")
	if not bool(main.get("_save_dirty")):
		failures.append("interactive changes must mark the save snapshot dirty")
	if float(main.get("_save_debounce_remaining")) <= 0.0:
		failures.append("interactive changes must debounce synchronous disk writes")
	main.set("_persistence_enabled", false)
	main.free()
