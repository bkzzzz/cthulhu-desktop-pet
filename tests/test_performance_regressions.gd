extends RefCounted

const Main = preload("res://scripts/main.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const DesktopItemActor = preload("res://scripts/desktop_item_actor.gd")
const CoinCollectorShovel = preload("res://scripts/coin_collector_shovel.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const CoinController = preload("res://scripts/runtime/coin_controller.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const EventInvitation = preload("res://scripts/event_invitation.gd")
const AchievementWindow = preload("res://scripts/achievement_window.gd")
const AchievementProgression = preload("res://scripts/domain/achievement_progression.gd")
const RuntimeCadence = preload("res://scripts/runtime/runtime_cadence.gd")
const SaveSlotRepository = preload("res://scripts/runtime/save_slot_repository.gd")


class HoverPetProbe:
	extends Node2D
	var foreground_requests := 0
	var foreground_releases := 0
	var hovered := false

	func raise_input_proxy() -> void:
		foreground_requests += 1

	func release_input_proxy_foreground_priority() -> void:
		foreground_releases += 1

	func set_pointer_hovered(value: bool) -> void:
		hovered = value


class RestingCoinProbe:
	extends Node2D
	var advanced_delta := 0.0

	func advance_resting(delta: float) -> void:
		advanced_delta += delta


class CountingSaveSlotRepository:
	extends SaveSlotRepository
	var write_count := 0
	var next_error := OK

	func save_active_slot(_save: ConfigFile) -> Dictionary:
		write_count += 1
		return {"ok": next_error == OK, "error": next_error}


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_runtime_pacing_settings(failures)
	_test_background_work_is_staggered(failures)
	_test_prebuilt_runtime_caches(failures)
	_test_pet_interaction_geometry_cache(failures)
	_test_shared_pet_asset_caches(failures)
	_test_battle_engagement_caches(failures)
	_test_storage_release_assets_are_prewarmed(failures)
	_test_lazy_secondary_windows_inherit_language(failures)
	_test_hidden_drawer_defers_visual_work(failures)
	_test_drawer_layout_geometry_is_cached(failures)
	_test_invitation_input_geometry_is_cached(failures)
	_test_achievement_state_skips_unchanged_refreshes(failures)
	_test_hover_foreground_changes_only_on_transition(failures)
	_test_static_desktop_helpers_sleep(failures)
	_test_settled_coins_use_central_tick(failures)
	_test_freed_coins_are_safely_untracked(failures)
	_test_freed_runtime_effects_are_safely_cleared(failures)
	_test_coin_pointer_sample_is_shared_per_process_frame(failures)
	_test_saves_are_debounced(failures)
	return failures


static func _test_background_work_is_staggered(failures: Array[String]) -> void:
	var cadence := RuntimeCadence.new(0.1)
	var dispatches: Array[int] = []
	for frame in range(18):
		var group := cadence.advance(1.0 / 60.0)
		if group < 0:
			continue
		dispatches.append(group)
		if not is_equal_approx(cadence.get_last_delta(), 0.1):
			failures.append("staggered runtime groups must retain their complete simulation delta")
			break
	var expected := [
		RuntimeCadence.GROUP_PROGRESSION,
		RuntimeCadence.GROUP_WORLD,
		RuntimeCadence.GROUP_MAINTENANCE,
		RuntimeCadence.GROUP_PROGRESSION,
		RuntimeCadence.GROUP_WORLD,
		RuntimeCadence.GROUP_MAINTENANCE,
	]
	if dispatches.slice(0, expected.size()) != expected:
		failures.append("10 Hz background systems must be released in stable, frame-staggered groups")

	var stalled := RuntimeCadence.new(0.1)
	var recovered := [stalled.advance(1.0), stalled.advance(0.0), stalled.advance(0.0)]
	if recovered != [
		RuntimeCadence.GROUP_PROGRESSION,
		RuntimeCadence.GROUP_WORLD,
		RuntimeCadence.GROUP_MAINTENANCE,
	]:
		failures.append("a long frame must queue background groups across subsequent frames")
	if stalled.advance(0.0) != -1:
		failures.append("the cadence must never replay the same overdue group more than once")


static func _test_runtime_pacing_settings(failures: Array[String]) -> void:
	if bool(ProjectSettings.get_setting("application/run/low_processor_mode", false)) and int(ProjectSettings.get_setting("application/run/low_processor_mode_sleep_usec", 10000)) > 3000:
		failures.append("low-processor mode must use a short sleep that preserves smooth animated frame pacing")


static func _test_prebuilt_runtime_caches(failures: Array[String]) -> void:
	var pet_icon_paths: Dictionary = {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var base_icon_path := String(PetCatalog.get_definition(pet_id).get("icon", ""))
		if not base_icon_path.is_empty():
			pet_icon_paths[base_icon_path] = true
		for evolved in [false, true]:
			if evolved and not PetCatalog.can_evolve(pet_id):
				continue
			var cache_path := PetCatalog.get_prebuilt_frame_path(pet_id, evolved)
			if not ResourceLoader.exists(cache_path):
				failures.append("missing prebuilt pet frame cache: %s" % cache_path)
		if PetCatalog.can_evolve(pet_id):
			var evolved_icon_path := String(PetCatalog.get_evolution_definition(pet_id).get("icon", ""))
			if not evolved_icon_path.is_empty():
				pet_icon_paths[evolved_icon_path] = true
	for icon_path_value in pet_icon_paths:
		var icon_path := String(icon_path_value)
		var icon_cache_path := PetCatalog.get_prebuilt_icon_path(icon_path)
		if not ResourceLoader.exists(icon_cache_path):
			failures.append("missing prebuilt pet icon cache: %s" % icon_cache_path)
	if not pet_icon_paths.is_empty():
		var probe_icon_path := String(pet_icon_paths.keys().front())
		var icon_memory_cache: Dictionary = PetCatalog._icon_texture_cache
		var previous_icon := icon_memory_cache.get(probe_icon_path) as Texture2D
		icon_memory_cache.erase(probe_icon_path)
		var loaded_icon := PetCatalog.make_icon_texture(probe_icon_path)
		if loaded_icon == null or loaded_icon.resource_path != PetCatalog.get_prebuilt_icon_path(probe_icon_path):
			failures.append("pet icons must prefer their offline cache over runtime pixel scanning")
		icon_memory_cache.erase(probe_icon_path)
		if previous_icon != null:
			icon_memory_cache[probe_icon_path] = previous_icon
	if not ResourceLoader.exists(BelieverActor.PREBUILT_FRAME_PATH):
		failures.append("missing prebuilt believer frame cache: %s" % BelieverActor.PREBUILT_FRAME_PATH)
	for enemy_id_value in EnemyActor.DEFINITIONS.keys():
		var enemy_frame_path := EnemyActor.get_prebuilt_frame_path(String(enemy_id_value))
		if not ResourceLoader.exists(enemy_frame_path):
			failures.append("missing prebuilt enemy frame cache: %s" % enemy_frame_path)
	if not FileAccess.file_exists(EnemyActor.PREBUILT_METRICS_PATH):
		failures.append("missing prebuilt enemy geometry cache: %s" % EnemyActor.PREBUILT_METRICS_PATH)


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


static func _test_lazy_secondary_windows_inherit_language(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_language", "zh")
	main.call("_create_inventory_window")
	main.call("_create_shop_window")
	main.call("_create_achievement_window")
	main.call("_create_news_window")
	var expected_titles := {
		"_inventory_window": "仓库",
		"_shop_window": "商店",
		"_achievement_window": "成就",
		"_news_window": "教团新闻档案",
	}
	for property_name in expected_titles:
		var window := main.get(property_name) as Window
		if window == null or window.title != String(expected_titles[property_name]):
			failures.append("a lazily created %s must inherit the current language" % property_name)
	main.free()


static func _test_hidden_drawer_defers_visual_work(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	drawer.call("setup")
	if drawer.get("_drawer_window") != null:
		failures.append("the heavy side drawer tree must be created only on first open")
	if not (drawer.get("_symbol_effect_textures") as Array).is_empty():
		failures.append("drawer-only effect textures must remain unloaded before first open")
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
	drawer.call("refresh_era", "Era of Tests")
	if drawer.get("_drawer_window") != null:
		failures.append("background state refreshes must not instantiate the hidden drawer")
	drawer.call("_toggle_drawer")
	if drawer.get("_drawer_window") == null:
		failures.append("opening the menu must instantiate its drawer on demand")
		drawer.free()
		return
	if not bool(drawer.call("_has_pending_drawer_build_work")):
		failures.append("the first drawer open must queue heavy controls across later frames")
	if drawer.get("_upgrade_detail_window") != null:
		failures.append("the pet detail native window must remain lazy until an actual hover")

	drawer.call("_toggle_drawer")
	var pending_before_pause := [
		bool(drawer.get("_drawer_background_pending")),
		bool(drawer.get("_drawer_bookmarks_pending")),
		bool(drawer.get("_drawer_faith_pending")),
	]
	drawer.call("_process", 0.016)
	var pending_after_pause := [
		bool(drawer.get("_drawer_background_pending")),
		bool(drawer.get("_drawer_bookmarks_pending")),
		bool(drawer.get("_drawer_faith_pending")),
	]
	if pending_after_pause != pending_before_pause:
		failures.append("closing a partially built drawer must pause its hidden construction queue")
	drawer.call("_toggle_drawer")
	drawer.call("_build_pending_drawer_work", 64)
	if bool(drawer.call("_has_pending_drawer_build_work")):
		failures.append("the staged drawer queue must finish without duplicate or orphaned work")
	var labels: Dictionary = drawer.get("_upgrade_name_labels")
	var pet_label := labels.get("pet1") as Label
	if pet_label == null:
		failures.append("performance test could not find the pet1 upgrade label")
		drawer.free()
		return
	if pet_label.text != "Cached name":
		failures.append("the first drawer open must paint pet data cached before creation")
	var era_label := drawer.get("_era_label") as Label
	if era_label == null or era_label.text != "Era of Tests":
		failures.append("the first drawer open must restore the cached era display")
	var upgrade_buttons: Dictionary = drawer.get("_upgrade_buttons")
	if upgrade_buttons.size() != PetCatalog.ACTIVE_DESKTOP_PETS.size():
		failures.append("the staged drawer must create exactly one row per real pet definition")
	var symbol_layer := drawer.get("_drawer_symbol_layer") as Control
	if symbol_layer == null or symbol_layer.get_child_count() != 0:
		failures.append("drawer symbols must use one batched draw node instead of one node per particle")
	drawer.call("set_language", "en")
	var pet1_button := upgrade_buttons.get("pet1") as Control
	drawer.call("_show_upgrade_detail_panel", "pet1", pet1_button)
	var lazy_detail_window := drawer.get("_upgrade_detail_window") as Window
	var lazy_detail_name := drawer.get("_upgrade_detail_name_edit") as LineEdit
	if (
		lazy_detail_window == null
		or lazy_detail_window.title != "Pet Details"
		or lazy_detail_name == null
		or lazy_detail_name.placeholder_text != "Pet name"
	):
		failures.append("a lazily created pet detail window must inherit the current language")
	var bookmark_container := drawer.get("_bookmark_container") as VBoxContainer
	var shared_click_mask_id := 0
	if bookmark_container != null:
		for child in bookmark_container.get_children():
			if not child is TextureButton:
				continue
			var mask := (child as TextureButton).texture_click_mask
			if mask == null:
				failures.append("drawer bookmark art must retain its alpha-aware click mask")
				break
			if shared_click_mask_id == 0:
				shared_click_mask_id = mask.get_instance_id()
			elif mask.get_instance_id() != shared_click_mask_id:
				failures.append("bookmarks sharing one texture must reuse one computed click mask")
				break

	var drawer_window := drawer.get("_drawer_window") as Window
	drawer_window.visible = false
	drawer.set("_drawer_open", false)
	pet_label.text = "unchanged while hidden"
	entries[0]["name"] = "Updated cached name"
	drawer.call("refresh_pet_upgrades", entries)
	if pet_label.text != "unchanged while hidden":
		failures.append("a closed drawer must cache data without repainting invisible upgrade rows")
	drawer.set("_drawer_open", true)
	drawer.call("refresh_pet_upgrades", entries)
	if pet_label.text != "Updated cached name":
		failures.append("opening the drawer must paint the latest cached pet data")
	drawer.free()


static func _test_drawer_layout_geometry_is_cached(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	var menu_window := Window.new()
	var drawer_window := Window.new()
	menu_window.visible = false
	drawer_window.visible = false
	drawer.add_child(menu_window)
	drawer.add_child(drawer_window)
	drawer.set("_menu_window", menu_window)
	drawer.set("_drawer_window", drawer_window)

	# Drive the pure geometry application path with synthetic monitor rectangles.
	# This covers cache behavior and display changes without requiring a native
	# Windows compositor in the headless test process.
	var first_usable_rect := Rect2i(0, 0, 1920, 1040)
	var first_screen_rect := Rect2i(0, 0, 1920, 1080)
	drawer.call("_apply_drawer_window_geometry", first_usable_rect, first_screen_rect, false)
	var first_drawer_revision := int(drawer.get("_drawer_geometry_revision"))
	var first_menu_revision := int(drawer.get("_menu_geometry_revision"))
	var first_drawer_size := drawer_window.size
	var first_passthrough_polygon := drawer_window.mouse_passthrough_polygon
	drawer.call("_apply_drawer_window_geometry", first_usable_rect, first_screen_rect, true)
	if int(drawer.get("_drawer_geometry_revision")) != first_drawer_revision:
		failures.append("an unchanged monitor layout must not rewrite drawer window geometry")
	if int(drawer.get("_menu_geometry_revision")) != first_menu_revision:
		failures.append("an unchanged monitor layout must not rewrite menu window geometry")
	if drawer_window.size != first_drawer_size or drawer_window.mouse_passthrough_polygon != first_passthrough_polygon:
		failures.append("a cached drawer layout must preserve its native size and passthrough shape")

	var next_usable_rect := Rect2i(120, 40, 1600, 860)
	var next_screen_rect := Rect2i(120, 0, 1600, 900)
	drawer.call("_apply_drawer_window_geometry", next_usable_rect, next_screen_rect, true)
	if int(drawer.get("_drawer_geometry_revision")) <= first_drawer_revision:
		failures.append("a changed usable work area must refresh drawer window geometry")
	if int(drawer.get("_menu_geometry_revision")) <= first_menu_revision:
		failures.append("a changed monitor layout must refresh menu window geometry")
	if drawer_window.size != Vector2i(SideDrawer.DRAWER_WIDTH, next_usable_rect.size.y):
		failures.append("drawer geometry refresh must adopt the changed work-area height")

	drawer_window.visible = false
	drawer.set("_drawer_open", false)
	drawer.set("_position_retry_frames", 0)
	drawer.set("_display_layout_poll_time", 0.0)
	var idle_skips_before := int(drawer.get("_idle_process_skip_count"))
	var drawer_revision_before_idle := int(drawer.get("_drawer_geometry_revision"))
	drawer.call("_process", 0.016)
	if int(drawer.get("_idle_process_skip_count")) != idle_skips_before + 1:
		failures.append("a fully closed drawer must take the minimal idle process path")
	if int(drawer.get("_drawer_geometry_revision")) != drawer_revision_before_idle:
		failures.append("the closed drawer idle path must not mutate native window geometry")
	drawer.free()


static func _test_invitation_input_geometry_is_cached(failures: Array[String]) -> void:
	var invitation := EventInvitation.new()
	var visual_window := Window.new()
	var input_window := Window.new()
	invitation.add_child(visual_window)
	invitation.add_child(input_window)
	invitation.set("_visual_window", visual_window)
	invitation.set("_input_window", input_window)
	invitation.set("_window_size", Vector2i(1280, 720))
	invitation.set("_ground_y", 704.0)
	invitation.position = Vector2(640.0, 620.0)
	invitation.call("_update_input_window")
	var first_revision := int(invitation.get("_input_geometry_revision"))
	invitation.call("_update_input_window")
	if int(invitation.get("_input_geometry_revision")) != first_revision:
		failures.append("an unchanged event invitation must not rewrite its native input window geometry")
	invitation.position.x += 12.0
	invitation.call("_update_input_window")
	if int(invitation.get("_input_geometry_revision")) != first_revision + 1:
		failures.append("a moved event invitation must still refresh its native input proxy once")
	invitation.free()


static func _test_coin_pointer_sample_is_shared_per_process_frame(failures: Array[String]) -> void:
	var previous_frame := CoinDrop._pointer_sample_frame
	var previous_pointer := CoinDrop._pointer_sample_global
	var expected_pointer := Vector2i(321, 654)
	CoinDrop._pointer_sample_frame = Engine.get_process_frames()
	CoinDrop._pointer_sample_global = expected_pointer
	var cached_pointer := CoinDrop._get_shared_global_pointer()
	CoinDrop._pointer_sample_frame = previous_frame
	CoinDrop._pointer_sample_global = previous_pointer
	if cached_pointer != expected_pointer:
		failures.append("coins in one process frame must share one cached native pointer sample")


static func _test_hover_foreground_changes_only_on_transition(failures: Array[String]) -> void:
	var main := Main.new()
	var probe := HoverPetProbe.new()
	main.add_child(probe)
	main.call("_set_hovered_pet", probe)
	main.call("_set_hovered_pet", probe)
	if probe.foreground_requests != 1:
		failures.append("a stationary hover target must raise its native input proxy only once")
	main.call("_set_hovered_pet", null)
	main.call("_set_hovered_pet", probe)
	if probe.foreground_releases != 1 or probe.foreground_requests != 2 or not probe.hovered:
		failures.append("a new hover session must restore one foreground transition")
	main.free()


static func _test_static_desktop_helpers_sleep(failures: Array[String]) -> void:
	var item := DesktopItemActor.new()
	item.setup("sofa", Vector2(500.0, 720.0), Vector2i(1000, 720))
	if item.is_processing():
		failures.append("a stationary desktop item must not keep a per-frame script callback active")
	item.free()
	var shovel := CoinCollectorShovel.new()
	shovel.setup()
	if shovel.is_processing():
		failures.append("an idle coin-collector shovel must sleep until a collection starts")
	shovel.free()


static func _test_settled_coins_use_central_tick(failures: Array[String]) -> void:
	var coin := CoinDrop.new()
	coin.setup("R", Vector2(900.0, 500.0), Vector2i(1000, 720), 720.0)
	for _step in 20:
		coin.call("_process", 0.1)
		if bool(coin.get("_settled")):
			break
	if not bool(coin.get("_settled")) or coin.is_processing():
		failures.append("a settled coin must sleep instead of keeping one process callback per rendered frame")
	coin.call("advance_resting", CoinDrop.PICKUP_ARM_DELAY_SECONDS)
	if bool(coin.call("begin_collector_collection", Vector2(800.0, 620.0))) and not coin.is_processing():
		failures.append("a resting coin must resume full-rate processing when collection movement starts")
	coin.free()

	var celebration := CoinDrop.new()
	celebration.setup("R", Vector2(900.0, 500.0), Vector2i(1000, 720), 720.0)
	celebration.configure_celebration(Vector2.ZERO, 1.0)
	for _step in 20:
		celebration.call("_process", 0.05)
		if bool(celebration.get("_settled")):
			break
	celebration.call("advance_resting", 1.0)
	if not bool(celebration.get("_celebration_collecting")) or not celebration.is_processing():
		failures.append("a settled celebration coin must wake when its delayed pointer collection begins")
	celebration.free()


static func _test_freed_coins_are_safely_untracked(failures: Array[String]) -> void:
	# Shovel batching, expiry, capacity eviction, and scene teardown can release
	# a coin without sending the normal reward signal first.
	var controller := CoinController.new()
	var live_a := RestingCoinProbe.new()
	var stale_coin := Node2D.new()
	var live_b := RestingCoinProbe.new()
	controller._coin_drops.append(live_a)
	controller._coin_drops.append(stale_coin)
	controller._coin_drops.append(live_b)
	var gold_before := int(controller._gold_coins)
	stale_coin.free()
	controller.call("_update_coin_drops", 0.1)
	if (
		controller._coin_drops.size() != 2
		or controller._coin_drops[0] != live_a
		or controller._coin_drops[1] != live_b
	):
		failures.append("freed desktop coins must be removed without a stale-object cast")
	if not is_equal_approx(live_a.advanced_delta, 0.1) or not is_equal_approx(live_b.advanced_delta, 0.1):
		failures.append("removing a stale coin must not skip either neighboring live coin")
	if int(controller._gold_coins) != gold_before:
		failures.append("discarding a stale coin must never award currency")
	for _iteration in 256:
		var transient_coin := Node2D.new()
		controller._coin_drops.append(transient_coin)
		transient_coin.free()
		controller.call("_update_coin_drops", 0.0)
	if controller._coin_drops.size() != 2:
		failures.append("repeated stale-coin cleanup must keep the tracked list bounded")

	# The suite runs before the root enters the SceneTree, so emit the lifecycle
	# signal explicitly to verify the production connection and its idempotence.
	var tracked_coin := controller.call("_spawn_coin", "R", Vector2(200.0, 200.0)) as Node2D
	tracked_coin.tree_exiting.emit()
	tracked_coin.free()
	if controller._coin_drops.size() != 2:
		failures.append("a production coin must unregister during tree exit before becoming stale")
	controller.call("_update_coin_drops", 0.1)
	if int(controller._gold_coins) != gold_before:
		failures.append("tree-exit cleanup must not reuse the coin reward path")
	live_a.free()
	live_b.free()
	controller.free()


static func _test_freed_runtime_effects_are_safely_cleared(failures: Array[String]) -> void:
	var main := Main.new()
	var stale_emotion := Sprite2D.new()
	var emotions: Dictionary = main.get("_active_emotions")
	emotions["pet1"] = stale_emotion
	stale_emotion.free()
	main.call("_clear_pet_runtime_effects", "pet1")
	if emotions.has("pet1"):
		failures.append("freed runtime-effect nodes must be cleared without a stale-object cast")
	main.free()


static func _test_achievement_state_skips_unchanged_refreshes(failures: Array[String]) -> void:
	var achievements := AchievementWindow.new()
	achievements.setup()
	var metrics := {"battle_victories": 3, "faith_rate": 14.0, "followers": 120, "pets_unlocked": 2}
	achievements.refresh_state(metrics, ["battle_1"])
	var cards: Dictionary = achievements.get("_cards")
	var first_card := (cards.get("battle_1", {}) as Dictionary).get("panel") as PanelContainer
	var first_card_id := first_card.get_instance_id() if first_card != null else 0
	var card_count := cards.size()
	var first_revision_value: Variant = achievements.get("_state_revision")
	var first_revision := int(first_revision_value) if first_revision_value != null else 0
	achievements.refresh_state(metrics, ["battle_1"])
	var repeated_revision_value: Variant = achievements.get("_state_revision")
	var repeated_revision := int(repeated_revision_value) if repeated_revision_value != null else 0
	if first_revision <= 0:
		failures.append("a changed achievement state must record one UI refresh revision")
	elif repeated_revision != first_revision:
		failures.append("identical achievement state must not rebuild controls or duplicate arrays")
	metrics["battle_victories"] = 4
	achievements.refresh_state(metrics, ["battle_1"])
	var changed_revision_value: Variant = achievements.get("_state_revision")
	var changed_revision := int(changed_revision_value) if changed_revision_value != null else 0
	if changed_revision != first_revision + 1:
		failures.append("a changed achievement state must still refresh visible controls")
	var refreshed_cards: Dictionary = achievements.get("_cards")
	var refreshed_first_card := (refreshed_cards.get("battle_1", {}) as Dictionary).get("panel") as PanelContainer
	if card_count != AchievementProgression.DEFINITIONS.size():
		failures.append("achievement UI must create exactly one stable card per definition")
	elif refreshed_cards.size() != card_count or refreshed_first_card == null or refreshed_first_card.get_instance_id() != first_card_id:
		failures.append("changing achievement progress must update existing cards instead of rebuilding the control tree")
	achievements.free()


static func _test_saves_are_debounced(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", true)
	var persistence := main.get("_persistence_controller") as Node
	var repository := CountingSaveSlotRepository.new()
	if persistence == null:
		failures.append("main must retain its persistence controller")
		main.free()
		return
	persistence.set("_save_slots", repository)
	main.call("_request_save")
	if not bool(main.get("_save_dirty")):
		failures.append("interactive changes must mark the save snapshot dirty")
	if float(main.get("_save_debounce_remaining")) <= 0.0:
		failures.append("interactive changes must debounce synchronous disk writes")

	main.set("_autosave_timer", Main.AUTOSAVE_INTERVAL_SECONDS - 0.2)
	main.set("_save_debounce_remaining", 0.05)
	main.call("_update_autosave", 0.1)
	main.call("_update_autosave", 0.1)
	if repository.write_count != 1:
		failures.append("a debounced save near the periodic boundary must perform exactly one disk transaction")
	if float(main.get("_autosave_timer")) >= 1.0:
		failures.append("a successful dirty checkpoint must restart the periodic autosave cycle")

	repository.next_error = ERR_CANT_CREATE
	main.set("_save_dirty", true)
	main.set("_save_debounce_remaining", 0.0)
	main.set("_autosave_timer", Main.AUTOSAVE_INTERVAL_SECONDS)
	var writes_before_failure := repository.write_count
	main.call("_update_autosave", 0.1)
	main.call("_update_autosave", 0.1)
	if repository.write_count != writes_before_failure + 1:
		failures.append("a failed save must not be attempted twice in one autosave boundary")
	if not bool(main.get("_save_dirty")) or float(main.get("_save_debounce_remaining")) < 4.0:
		failures.append("a failed save must remain dirty and retain its retry backoff")

	repository.next_error = OK
	main.set("_save_dirty", false)
	main.set("_autosave_timer", Main.AUTOSAVE_INTERVAL_SECONDS - 0.1)
	var writes_before_periodic := repository.write_count
	main.call("_update_autosave", 0.1)
	if repository.write_count != writes_before_periodic + 1:
		failures.append("an unchanged game must still receive its periodic passive-progress checkpoint")
	main.set("_persistence_enabled", false)
	main.free()
