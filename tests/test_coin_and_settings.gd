extends RefCounted

const Main = preload("res://scripts/main.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_coin_definitions(failures)
	_test_coin_ground_first_pickup(failures)
	_test_coin_collection(failures)
	_test_pet_money_pile(failures)
	_test_denomination_drop_plans(failures)
	_test_pet_interaction_value(failures)
	_test_coin_retention_limits(failures)
	_test_activity_ranges(failures)
	_test_settings_runtime(failures)
	_test_background_resource_settings(failures)
	_test_believer_drop_signal(failures)
	_test_believer_prayer_animation_and_reward(failures)
	_test_believer_exit_refresh_and_pilgrimage_entry(failures)
	_test_pilgrimage_activity_override(failures)
	_test_pilgrimage_event_lifecycle(failures)
	_test_pet_autonomy_pause(failures)
	return failures


static func _test_coin_definitions(failures: Array[String]) -> void:
	var r_value := CoinDrop.get_coin_value("R")
	var p_value := CoinDrop.get_coin_value("P")
	var d_value := CoinDrop.get_coin_value("D")
	var copper_value := CoinDrop.get_coin_value("C")
	var silver_value := CoinDrop.get_coin_value("S")
	var gold_value := CoinDrop.get_coin_value("G")
	if not (
		r_value > 0
		and p_value > r_value
		and d_value >= p_value * 10
		and copper_value > d_value
		and silver_value > copper_value
		and gold_value > silver_value
	):
		failures.append("drop values must satisfy R < P << D < copper crystal < silver crystal < gold crystal")
	for coin_type in ["R", "P", "D", "C", "S", "G"]:
		var texture_path := CoinDrop.get_coin_texture(coin_type)
		if texture_path.is_empty() or not FileAccess.file_exists(texture_path):
			failures.append("drop %s must use its provided sprite sheet" % coin_type)

	for drop_type in ["P", "C", "S", "G"]:
		var drop := CoinDrop.new()
		drop.setup(drop_type, Vector2(200.0, 100.0), Vector2i(820, 420), 400.0)
		var sprite := drop.get_node_or_null("Coin%sSprite" % drop_type) as AnimatedSprite2D
		if (
			sprite == null
			or sprite.sprite_frames.get_frame_count("spin") != CoinDrop.get_sheet_frame_count(drop_type)
		):
			failures.append("drop %s must animate every authored sprite-sheet frame" % drop_type)
		drop.free()


static func _test_coin_ground_first_pickup(failures: Array[String]) -> void:
	var coin := CoinDrop.new()
	coin.setup("R", Vector2(200.0, 100.0), Vector2i(820, 420), 400.0)
	if bool(coin.call("_can_start_magnet", coin.position)):
		failures.append("a freshly dropped coin must not magnetize while it is airborne")
	coin.set("_settled", true)
	coin.set("_settled_age", CoinDrop.PICKUP_ARM_DELAY_SECONDS * 0.5)
	if bool(coin.call("_can_start_magnet", coin.position)):
		failures.append("a coin must visibly settle before pickup is armed")
	coin.set("_settled_age", CoinDrop.PICKUP_ARM_DELAY_SECONDS)
	if not bool(coin.call("_can_start_magnet", coin.position)):
		failures.append("a settled coin must magnetize when the cursor enters its pickup range")
	if bool(coin.call("_can_start_magnet", coin.position + Vector2(CoinDrop.MAGNET_RADIUS + 1.0, 0.0))):
		failures.append("a settled coin must remain on the ground while the cursor is outside pickup range")
	coin.free()


static func _test_coin_collection(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.call("_on_coin_collected", null, "P", CoinDrop.get_coin_value("P"))
	if int(main.get("_gold_coins")) != CoinDrop.get_coin_value("P"):
		failures.append("magnet collection must credit the shared gold balance")
	main.free()


static func _test_pet_money_pile(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 500.0, 704.0, false)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	main.call("_spawn_pet_coin_pile", pet, 45.0)
	var drops := main.get("_coin_drops") as Array
	var expected_value := maxi(1, int(round(
		float(main.call("_get_pet_money_value_per_minute", "pet1", 1)) * 45.0 / 60.0
	)))
	var dropped_value := 0
	for drop in drops:
		dropped_value += int(drop.get("value"))
	if drops.is_empty() or drops.size() > Main.PET_AUTO_COIN_PILE_MAX:
		failures.append("an automatic pet money event must use a bounded visible denomination pile")
	if dropped_value != expected_value:
		failures.append("visual denomination replacement must preserve the exact automatic reward value")
	if int(main.get("_gold_coins")) != 0:
		failures.append("automatic pet money must remain on the ground until the mouse collects it")
	main.free()


static func _test_denomination_drop_plans(failures: Array[String]) -> void:
	var plan := CoinDrop.make_drop_plan(937, 10)
	var planned_value := 0
	var planned_types: Array[String] = []
	for entry in plan:
		planned_value += int(entry.get("value", 0))
		planned_types.append(String(entry.get("type", "")))
	if planned_value != 937 or plan.size() > 10:
		failures.append("denomination planning must preserve value while capping world-drop nodes")
	for expected_type in ["G", "S", "C", "D"]:
		if not planned_types.has(expected_type):
			failures.append("a large reward must replace low-value animations with %s" % expected_type)
	var huge_plan := CoinDrop.make_drop_plan(50_000, 4)
	var huge_value := 0
	for entry in huge_plan:
		huge_value += int(entry.get("value", 0))
	if huge_plan.size() > 4 or huge_value != 50_000 or String(huge_plan[0].get("type", "")) != "G":
		failures.append("very large rewards must bundle into a few highest-value animations without losing money")


static func _test_pet_interaction_value(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 500.0, 704.0, false)
	main.add_child(pet)
	var drop := main.call("_spawn_pet_coin", pet) as Node2D
	if drop == null or String(drop.get("coin_type")) != "R" or int(drop.get("value")) != 1:
		failures.append("every pet interaction must give exactly one lowest-value coin")
	main.free()


static func _test_coin_retention_limits(failures: Array[String]) -> void:
	if CoinDrop.MAX_LIFETIME_SECONDS > 120.0:
		failures.append("uncollected desktop coins must expire before they can accumulate indefinitely")
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	for coin_index in Main.DESKTOP_COIN_LIMIT + 12:
		main.call("_spawn_coin", "R", Vector2(200.0 + float(coin_index % 20), 300.0))
	if (main.get("_coin_drops") as Array).size() > Main.DESKTOP_COIN_LIMIT:
		failures.append("the desktop must enforce a hard retained-coin node limit")
	main.free()


static func _test_background_resource_settings(failures: Array[String]) -> void:
	if int(ProjectSettings.get_setting("application/boot_splash/minimum_display_time", 700)) > 0:
		failures.append("startup must not hold a temporary splash window on screen")
	if bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)):
		failures.append("startup must not flash a splash image before the desktop windows are positioned")
	if not bool(ProjectSettings.get_setting("application/run/low_processor_mode", false)):
		failures.append("the desktop game must opt into low-processor mode")
	var max_fps := int(ProjectSettings.get_setting("application/run/max_fps", 0))
	if max_fps < 45 or max_fps > 60:
		failures.append("desktop motion must use a smooth but still bounded rendering frame rate")
	var processor_sleep := int(ProjectSettings.get_setting("application/run/low_processor_mode_sleep_usec", 10000))
	if processor_sleep > 3000:
		failures.append("low-processor sleep must not be long enough to cause visible frame pacing stalls")


static func _test_activity_ranges(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_pet_window_size", Vector2i(1920, 1080))
	main.set("_pet_activity_range", "full")
	var full_min := float(main.call("_get_pet_stage_min_x"))
	var full_max := float(main.call("_get_pet_stage_max_x"))
	main.set("_pet_activity_range", "left")
	var left_min := float(main.call("_get_pet_stage_min_x"))
	var left_max := float(main.call("_get_pet_stage_max_x"))
	main.set("_pet_activity_range", "right")
	var right_min := float(main.call("_get_pet_stage_min_x"))
	var right_max := float(main.call("_get_pet_stage_max_x"))
	if not (is_equal_approx(left_min, full_min) and left_max < full_max):
		failures.append("left activity mode must constrain pets to the desktop's left side")
	if not (right_min > full_min and is_equal_approx(right_max, full_max)):
		failures.append("right activity mode must constrain pets to the desktop's right side")
	var left_actor := DesktopPetActor.new()
	left_actor.setup("pet1", Vector2i(1920, 1080), left_min, left_max, 400.0, 1064.0, true)
	left_actor.position.x = float(left_actor.get("_min_x"))
	var left_visual_rect: Rect2 = left_actor.call("_get_sprite_visual_rect")
	if left_visual_rect.position.x > 7.0:
		failures.append("left activity mode must let a pet visibly reach the physical left screen edge")
	left_actor.free()
	main.free()


static func _test_settings_runtime(failures: Array[String]) -> void:
	var settings := SettingsWindow.new()
	settings.setup("right", "not-a-language")
	if settings.has_method("refresh_runtime"):
		failures.append("settings must not retain the moved runtime-display API")
	if settings.get_activity_range() != "right" or settings.get_language() != "en":
		failures.append("settings must restore the range and default malformed or missing language values to English")
	if settings.theme == null or not settings.theme.default_font is SystemFont:
		failures.append("English settings body copy must use a readable system UI font")
	var settings_root := settings.get("_root") as Control
	var settings_panel := settings_root.get_node_or_null("SettingsPanel") as PanelContainer
	var close_button := settings.get("_close_button") as Button
	if settings_root.find_child("SettingsBackground", true, false) != null:
		failures.append("settings must not recreate the removed decorative background texture")
	if settings_panel == null or close_button == null:
		failures.append("settings must create its content panel and close control")
	else:
		var panel_rect := Rect2(settings_panel.position, settings_panel.size)
		var close_rect := Rect2(close_button.position, close_button.size)
		if not panel_rect.encloses(close_rect):
			failures.append("the settings close control must sit visibly inside the content panel")
		if not close_button.get_theme_stylebox("normal") is StyleBoxFlat:
			failures.append("the settings close control must have a visible normal-state background")

	var credits_button := settings.get("_credits_button") as Button
	var credits_panel := settings.get("_credits_panel") as PanelContainer
	var credits_copy := settings.get("_credits_copy_label") as Label
	if credits_button == null or credits_panel == null or credits_copy == null:
		failures.append("settings must expose an in-game credits and license entry")
	else:
		settings.call("_open_credits_panel")
		if not credits_panel.visible:
			failures.append("the credits entry must open its license panel")
		if (
			not credits_copy.text.contains("Super Pixel Projectiles Pack 2")
			or not credits_copy.text.contains("Will Tice")
			or not credits_copy.text.contains("https://untiedgames.com/files/license.txt")
		):
			failures.append("the credits panel must retain the projectile pack author and license URI")
		settings.close_window()
		if credits_panel.visible:
			failures.append("closing settings must also close its credits panel")

	var reset_button := settings.get("_debug_reset_button") as Button
	var reset_confirmation := settings.get("_reset_confirmation") as ConfirmationDialog
	var debug_back_button := settings.get("_debug_back_button") as Button
	if not settings.has_signal("reset_game_requested") or reset_button == null or reset_confirmation == null:
		failures.append("debug settings must expose a confirmed reset-all-progress action")
	else:
		if reset_button.get_parent() != debug_back_button.get_parent():
			failures.append("reset and back actions must share one compact footer row")
		if reset_button.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
			failures.append("the reset action must share footer width without overflowing the debug panel")
		if reset_button.text != "RESET CURRENT SAVE" or reset_confirmation.ok_button_text != "RESET CURRENT SAVE":
			failures.append("the reset confirmation workflow must identify the active save as the only destructive target")
		var reset_style := reset_button.get_theme_stylebox("normal") as StyleBoxFlat
		if reset_style == null or reset_style.bg_color.r <= reset_style.bg_color.g * 2.0:
			failures.append("the destructive reset action must use a clearly red normal style")
		var reset_requests: Array[bool] = []
		settings.reset_game_requested.connect(func() -> void: reset_requests.append(true))
		reset_confirmation.confirmed.emit()
		if reset_requests.size() != 1:
			failures.append("reset progress must emit only after the confirmation accepts")
		settings.set_language("zh")
		if settings.theme == null or not settings.theme.default_font is SystemFont:
			failures.append("Chinese settings must switch to a CJK-capable system font")
		if reset_button.text != "重置当前存档" or reset_confirmation.cancel_button_text != "取消":
			failures.append("the reset confirmation workflow must localize its Chinese destructive-action copy")
		if credits_button.text != "资源鸣谢与许可" or not credits_copy.text.contains("作者：Will Tice"):
			failures.append("the credits entry must localize without dropping legal attribution")
		settings.set_language("en")
		if settings.theme == null or not settings.theme.default_font is SystemFont:
			failures.append("switching settings back to English must restore the readable body font")
	settings.refresh_debug_values(12345.0, 6789, 2.5, 3.0, {"pet1": 100, "pet6": 246})
	var faith_spin := settings.get("_debug_faith_spin") as SpinBox
	var coin_spin := settings.get("_debug_coin_spin") as SpinBox
	var enemy_power_spin := settings.get("_debug_enemy_power_spin") as SpinBox
	var game_speed_spin := settings.get("_debug_game_speed_spin") as SpinBox
	var era_options := settings.get("_debug_era_options") as OptionButton
	if faith_spin == null or not is_equal_approx(faith_spin.value, 12345.0):
		failures.append("settings debug options must load the current faith value")
	if coin_spin == null or int(coin_spin.value) != 6789:
		failures.append("settings debug options must load the current gold value")
	if enemy_power_spin == null or not is_equal_approx(enemy_power_spin.value, 2.5):
		failures.append("settings debug options must expose freely adjustable enemy power")
	if game_speed_spin == null or not is_equal_approx(game_speed_spin.value, 3.0):
		failures.append("settings debug options must expose an adjustable game speed")
	settings.refresh_debug_era(3)
	if era_options == null or era_options.item_count != EraProgression.get_era_count() or era_options.selected != 3:
		failures.append("settings debug options must expose and synchronize every progression era")
	var pet_level_spins: Dictionary = settings.get("_debug_pet_level_spins")
	if pet_level_spins.size() != PetCatalog.ACTIVE_DESKTOP_PETS.size():
		failures.append("settings debug options must expose an individual level control for every pet")
	elif int((pet_level_spins["pet1"] as SpinBox).value) != 100 or int((pet_level_spins["pet6"] as SpinBox).value) != 246:
		failures.append("settings must load every pet's current level into its own control")
	var debug_events: Array[String] = []
	var debug_simulations: Array[Vector2] = []
	var debug_level_snapshots: Array[Dictionary] = []
	var debug_era_requests: Array[int] = []
	settings.debug_event_requested.connect(func(event_type: String) -> void: debug_events.append(event_type))
	settings.debug_simulation_requested.connect(
		func(enemy_scale: float, game_speed: float) -> void:
			debug_simulations.append(Vector2(enemy_scale, game_speed))
	)
	settings.debug_pet_levels_requested.connect(func(levels: Dictionary) -> void: debug_level_snapshots.append(levels))
	settings.debug_era_requested.connect(func(era_index: int) -> void: debug_era_requests.append(era_index))
	settings.call("_on_debug_era_selected", 4)
	if debug_era_requests != [4]:
		failures.append("changing the debug era selector must immediately request that era")
	settings.call("_on_debug_event_pressed", "pilgrimage")
	settings.call("_on_debug_event_pressed", "battle")
	if debug_events != ["pilgrimage", "battle"]:
		failures.append("settings debug options must expose direct pilgrimage and battle triggers")
	if debug_simulations.size() != 2 or not debug_simulations.back().is_equal_approx(Vector2(2.5, 3.0)):
		failures.append("debug event buttons must apply the typed multipliers before dropping an invitation")
	if debug_level_snapshots.size() != 2 or int(debug_level_snapshots.back().get("pet6", 0)) != 246:
		failures.append("debug apply/event actions must include the individually typed pet levels")
	_test_save_slot_manager_controls(settings, failures)
	var snapshot_main := Main.new()
	snapshot_main.set("_persistence_enabled", false)
	snapshot_main.set("_settings_window", settings)
	settings.debug_economy_requested.connect(Callable(snapshot_main, "_on_debug_economy_requested"))
	settings.debug_simulation_requested.connect(Callable(snapshot_main, "_on_debug_simulation_requested"))
	enemy_power_spin.value = 4.25
	game_speed_spin.value = 1.7
	settings.call("_on_debug_event_pressed", "battle")
	if (
		not is_equal_approx(float(snapshot_main.get("_debug_enemy_power_scale")), 4.25)
		or not is_equal_approx(float(snapshot_main.get("_debug_game_speed")), 1.7)
	):
		failures.append("economy refreshes must not overwrite debug multipliers before an event applies them")
	Engine.time_scale = 1.0
	snapshot_main.free()
	settings.free()

	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.call("_on_debug_economy_requested", 98765.0, 43210)
	if not is_equal_approx(float(main.get("_faith_points")), 98765.0) or int(main.get("_gold_coins")) != 43210:
		failures.append("debug economy changes must immediately replace faith and gold")
	main.call("_on_debug_simulation_requested", 0.25, 2.0)
	if not is_equal_approx(float(main.get("_debug_enemy_power_scale")), 0.25):
		failures.append("debug enemy power must support reductions below normal")
	if not is_equal_approx(float(main.get("_debug_game_speed")), 2.0) or not is_equal_approx(Engine.time_scale, 2.0):
		failures.append("debug game speed must immediately control simulation speed")
	main.set("_session_runtime_seconds", 9999.0)
	main.call("_on_debug_era_requested", 2)
	var victorian_start := EraProgression.get_era_start_runtime_seconds(2)
	if (
		not is_equal_approx(float(main.get("_total_runtime_seconds")), victorian_start)
		or EraProgression.get_era_index(float(main.get("_total_runtime_seconds"))) != 2
	):
		failures.append("debug era changes must update the authoritative progression runtime")
	if float(main.get("_session_runtime_seconds")) > victorian_start:
		failures.append("moving progression backward must keep session and total runtime state consistent")
	Engine.time_scale = 1.0
	main.free()


static func _test_save_slot_manager_controls(settings: Window, failures: Array[String]) -> void:
	var save_slots_button := settings.get("_save_slots_button") as Button
	var save_slots_panel := settings.get("_save_slots_panel") as PanelContainer
	if (
		not settings.has_signal("save_slot_create_requested")
		or not settings.has_signal("save_slot_switch_requested")
		or not settings.has_signal("save_slot_rename_requested")
		or not settings.has_signal("save_slot_delete_requested")
		or save_slots_button == null
		or save_slots_panel == null
	):
		failures.append("settings must expose a dedicated save-slot manager with explicit action signals")
		return
	settings.call("set_save_slots", [
		{"id": "slot_000001", "display_name": "Current", "has_data": true, "is_active": true, "playtime_seconds": 120.0},
		{"id": "slot_000002", "display_name": "Archive", "has_data": true, "is_active": false, "playtime_seconds": 60.0},
		{"id": "slot_000003", "display_name": "Fresh", "has_data": false, "is_active": false}
	], "slot_000001")
	if save_slots_button.disabled:
		failures.append("settings must enable save-slot management when slot metadata is available")
		return
	save_slots_button.pressed.emit()
	if not save_slots_panel.visible:
		failures.append("the save-slot manager entry must open an in-window overlay")
		return
	var create_button := save_slots_panel.find_child("CreateSaveSlot_slot_000003", true, false) as Button
	var switch_button := save_slots_panel.find_child("SwitchSaveSlot_slot_000002", true, false) as Button
	var rename_button := save_slots_panel.find_child("RenameSaveSlot_slot_000001", true, false) as Button
	var delete_button := save_slots_panel.find_child("DeleteSaveSlot_slot_000002", true, false) as Button
	if create_button == null or switch_button == null or rename_button == null or delete_button == null:
		failures.append("each save-slot card must expose the appropriate full-control actions")
		return
	for button in [create_button, switch_button, rename_button, delete_button]:
		if button.mouse_filter != Control.MOUSE_FILTER_STOP or button.custom_minimum_size.x <= 0.0 or button.custom_minimum_size.y <= 0.0:
			failures.append("save-slot actions must use full rectangular interactive controls")
			break
	var created: Array[String] = []
	var switched: Array[String] = []
	var renamed: Array[Dictionary] = []
	var deleted: Array[String] = []
	settings.save_slot_create_requested.connect(func(slot_id: String) -> void: created.append(slot_id))
	settings.save_slot_switch_requested.connect(func(slot_id: String) -> void: switched.append(slot_id))
	settings.save_slot_rename_requested.connect(func(slot_id: String, name: String) -> void: renamed.append({"id": slot_id, "name": name}))
	settings.save_slot_delete_requested.connect(func(slot_id: String) -> void: deleted.append(slot_id))
	create_button.pressed.emit()
	if created != ["slot_000003"]:
		failures.append("creating an empty save slot must emit only that controlled slot id")
	switch_button.pressed.emit()
	var action_confirmation := settings.get("_save_slot_action_confirmation") as ConfirmationDialog
	if action_confirmation == null or not action_confirmation.visible:
		failures.append("switching save slots must require an explicit confirmation")
	else:
		action_confirmation.confirmed.emit()
		if switched != ["slot_000002"]:
			failures.append("confirmed save-slot switching must emit the intended slot id")
	rename_button.pressed.emit()
	var rename_confirmation := settings.get("_save_slot_rename_confirmation") as ConfirmationDialog
	var rename_input := settings.get("_save_slot_rename_input") as LineEdit
	if rename_confirmation == null or rename_input == null or not rename_confirmation.visible:
		failures.append("renaming a save slot must open a bounded text confirmation")
	else:
		rename_input.text = "Renamed slot"
		rename_confirmation.confirmed.emit()
		if renamed.size() != 1 or String(renamed[0].get("id", "")) != "slot_000001" or String(renamed[0].get("name", "")) != "Renamed slot":
			failures.append("confirmed save-slot renaming must emit the slot id and typed display name")
	delete_button.pressed.emit()
	if action_confirmation != null and action_confirmation.visible:
		action_confirmation.confirmed.emit()
	if deleted != ["slot_000002"]:
		failures.append("deleting a non-active slot must require confirmation before emitting its id")


static func _test_believer_drop_signal(failures: Array[String]) -> void:
	var believer := BelieverActor.new()
	if not believer.has_signal("scared_away"):
		failures.append("believers must expose a distinct scared-away event")
	if not believer.has_signal("prayed"):
		failures.append("believers must expose a completed-prayer reward event")
	believer.free()


static func _test_believer_prayer_animation_and_reward(failures: Array[String]) -> void:
	if (
		BelieverActor.PILGRIMAGE_PRAY_REWARD_MAX >= CoinDrop.get_coin_value("D")
		or BelieverActor.PILGRIMAGE_PRAY_REWARD_MIN <= BelieverActor.NORMAL_PRAY_REWARD_MIN
	):
		failures.append("pilgrimage prayer rewards must be modest but still exceed ordinary prayer rewards")
	var believer := BelieverActor.new()
	believer.setup_visible(Vector2i(820, 420), 400.0)
	var sprite := believer.get_node_or_null("BelieverSprite") as AnimatedSprite2D
	if (
		sprite == null
		or not sprite.sprite_frames.has_animation("pray")
		or sprite.sprite_frames.get_frame_count("pray") != 16
		or sprite.sprite_frames.get_animation_loop("pray")
	):
		failures.append("the new believer pray sheet must play all 16 frames exactly once")

	var reward_counts: Array[int] = []
	believer.prayed.connect(func(_actor: Node2D, _position: Vector2, count: int) -> void:
		reward_counts.append(count)
	)
	believer.set("_prayer_chance", 1.0)
	believer.set("_scare_grace_time", 0.0)
	believer.set_threat_positions([believer.position])
	if sprite == null or sprite.animation != "pray":
		failures.append("a nearby pet must be able to put a believer into the pray state")
	believer.call("_finish_prayer")
	if (
		reward_counts.size() != 1
		or reward_counts[0] < BelieverActor.NORMAL_PRAY_REWARD_MIN
		or reward_counts[0] > BelieverActor.NORMAL_PRAY_REWARD_MAX
	):
		failures.append("a completed ordinary prayer must emit one small total money reward")
	believer.free()

	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.call("_on_believer_scared_away", null, Vector2(300.0, 200.0))
	if not (main.get("_coin_drops") as Array).is_empty():
		failures.append("a fleeing believer must leave no coins")
	main.call("_on_believer_prayed", null, Vector2(300.0, 200.0), 6)
	var drops := main.get("_coin_drops") as Array
	var prayer_value := 0
	for drop in drops:
		prayer_value += int(drop.get("value"))
	if drops.is_empty() or drops.size() > 3 or prayer_value != 6:
		failures.append("a prayer must preserve its small total reward using at most three denomination animations")
	for drop in drops:
		if String(drop.get("coin_type")) in ["D", "C", "S", "G"]:
			failures.append("a small prayer reward must not masquerade as an expensive coin")
			break
	main.free()


static func _test_believer_exit_refresh_and_pilgrimage_entry(failures: Array[String]) -> void:
	var believer := BelieverActor.new()
	believer.setup_visible(Vector2i(820, 420), 400.0)
	var exits: Array[bool] = []
	believer.exited.connect(func(_actor: Node2D) -> void: exits.append(true))
	believer.call("leave_quietly")
	believer.position.x = -BelieverActor.OFFSCREEN_PADDING
	believer.call("_update_walk_out", 0.0)
	if exits.size() != 1 or not believer.is_queued_for_deletion():
		failures.append("a believer reaching the exact screen boundary must be removed so spawning can continue")
	believer.free()

	var pilgrim := BelieverActor.new()
	pilgrim.setup_pilgrim(Vector2i(1200, 720), 420.0, 704.0, true, 0.2)
	if int(pilgrim.get("_state")) != BelieverActor.BelieverState.WALK_IN:
		failures.append("pilgrimage believers must enter through the walk-in state")
	if pilgrim.position.x >= 0.0:
		failures.append("pilgrimage believers must begin outside the screen instead of popping into place")
	var start_x := pilgrim.position.x
	pilgrim.call("_update_walk_in", 0.1)
	if not is_equal_approx(pilgrim.position.x, start_x):
		failures.append("staggered pilgrimage entrances must honor their short group delay")
	pilgrim.call("_update_walk_in", 0.2)
	pilgrim.call("_update_walk_in", 0.2)
	if pilgrim.position.x <= start_x:
		failures.append("pilgrimage believers must visibly walk in from the screen edge")
	pilgrim.free()


static func _test_pilgrimage_activity_override(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_pet_window_size", Vector2i(1920, 1080))
	main.set("_pet_activity_range", "left")
	var restricted_max := float(main.call("_get_pet_stage_max_x"))
	main.set("_pilgrimage_active", true)
	var pilgrimage_min := float(main.call("_get_pet_stage_min_x"))
	var pilgrimage_max := float(main.call("_get_pet_stage_max_x"))
	if not (
		is_equal_approx(pilgrimage_min, Main.PET_STAGE_MARGIN_X)
		and is_equal_approx(pilgrimage_max, 1920.0 - Main.PET_STAGE_RIGHT_MARGIN)
		and pilgrimage_max > restricted_max
	):
		failures.append("pilgrimage events must temporarily expand left/right pet ranges to the full desktop")
	if (
		Main.BELIEVER_MIN_ACTIVE != 0
		or Main.BELIEVER_MAX_ACTIVE != 2
		or Main.PILGRIMAGE_GROUP_MEMBER_MIN != 3
		or Main.PILGRIMAGE_GROUP_MEMBER_MAX != 5
	):
		failures.append("ordinary believers must stay occasional while pilgrimage believers spawn in groups of three to five")
	if Main.PILGRIMAGE_BROADCAST_FONT_SIZE <= Main.NEWS_BROADCAST_FONT_SIZE:
		failures.append("pilgrimage news must use a visibly larger breaking-news broadcast")
	main.free()


static func _test_pet_autonomy_pause(failures: Array[String]) -> void:
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(820, 420), 72.0, 724.0, 400.0, 400.0, false)
	pet.call("_choose_walk_target")
	pet.set_autonomy_paused(true)
	if not pet.is_autonomy_paused():
		failures.append("pets must pause autonomous behavior during pilgrimage events")
	var sprite := pet.get_node("pet1Sprite") as AnimatedSprite2D
	if int(pet.get("_behavior")) != DesktopPetActor.Behavior.IDLE or sprite.speed_scale <= 0.0:
		failures.append("pilgrimage pets must stay calmly idle without visually freezing their animations")
	pet.set_autonomy_paused(false)
	if pet.is_autonomy_paused():
		failures.append("pets must resume autonomous behavior after pilgrimage events")
	pet.free()


static func _test_pilgrimage_event_lifecycle(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1920, 1080))
	var pet := Node2D.new()
	pet.position = Vector2(280.0, 900.0)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	main.call("_start_pilgrimage")
	var believers := main.get("_believers") as Array
	if not bool(main.get("_pilgrimage_active")):
		failures.append("starting a pilgrimage must activate its timed minigame state")
	if (
		believers.size() < Main.PILGRIMAGE_GROUP_MIN * Main.PILGRIMAGE_GROUP_MEMBER_MIN
		or believers.size() > Main.PILGRIMAGE_GROUP_MAX * Main.PILGRIMAGE_GROUP_MEMBER_MAX
	):
		failures.append("a pilgrimage must spawn several three-to-five-member groups")
	for believer in believers:
		if not bool(believer.call("is_pilgrimage_member")):
			failures.append("every believer spawned by the pilgrimage batch must be event-scoped")
			break
	var opening_multiplier := float(main.call("_get_active_pilgrimage_faith_multiplier"))
	if not is_equal_approx(opening_multiplier, Main.PILGRIMAGE_FAITH_BASE_MULTIPLIER):
		failures.append("pilgrimages must begin with their advertised passive faith surge multiplier")
	var faith_before := float(main.get("_faith_points"))
	main.call("_on_believer_prayed", believers[0], believers[0].position, 10)
	if float(main.get("_faith_points")) <= faith_before:
		failures.append("resolving a pilgrim must immediately grant a production-scaled faith burst")
	if float(main.call("_get_active_pilgrimage_faith_multiplier")) <= opening_multiplier:
		failures.append("pilgrimage faith multipliers must chain upward as more pilgrims are resolved")
	main.call("_on_believer_scared_away", believers[1], believers[1].position)
	var dropped_gold := 0
	for drop in main.get("_coin_drops") as Array:
		dropped_gold += int(drop.get("value"))
	var expected_gold := int(round(
		10.0 * Main.PILGRIMAGE_GOLD_MULTIPLIER
		+ float(Main.PILGRIMAGE_SCARE_GOLD_BASE) * Main.PILGRIMAGE_GOLD_MULTIPLIER
	))
	if dropped_gold != expected_gold:
		failures.append("pilgrimage prayers and scares must use the higher event gold multiplier without losing denomination value")
	var faith_before_completion := float(main.get("_faith_points"))
	main.call("_finish_pilgrimage", true)
	if float(main.get("_faith_points")) <= faith_before_completion:
		failures.append("finishing a pilgrimage early must pay an additional multiplied faith burst")
	if bool(main.get("_pilgrimage_active")) or float(main.get("_next_pilgrimage_at")) <= 0.0:
		failures.append("finishing a pilgrimage must restore normal play and schedule a later event")
	main.free()
