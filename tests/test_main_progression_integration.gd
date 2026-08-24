extends RefCounted

const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_state_migration(failures)
	_test_explicit_level_migration(failures)
	_test_persistence_snapshot_backup_and_recovery(failures)
	_test_persistence_rejects_non_finite_numbers(failures)
	_test_starter_unlock_state(failures)
	_test_language_defaults_and_pet_names(failures)
	_test_growth_unlock_and_achievement_integration(failures)
	_test_hidden_inventory_updates_are_lazy(failures)
	_test_single_level_upgrade(failures)
	_test_upgrade_entry_simplicity(failures)
	_test_scaled_manual_click(failures)
	_test_news_overlay_tuning(failures)
	_test_versioned_news_tier_migration(failures)
	return failures


static func _make_main() -> Node:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	return main


static func _test_persistence_snapshot_backup_and_recovery(failures: Array[String]) -> void:
	var primary_path := "user://cthulhu_test_snapshot_primary.cfg"
	var backup_path := "%s.bak" % primary_path
	var temporary_path := "%s.tmp" % primary_path
	var backup_temporary_path := "%s.tmp" % backup_path
	for path in [primary_path, backup_path, temporary_path, backup_temporary_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var first_snapshot := ConfigFile.new()
	first_snapshot.set_value("meta", "marker", "first")
	if first_snapshot.save(primary_path) != OK:
		failures.append("persistence backup test could not create its isolated primary snapshot")
		return
	var next_snapshot := ConfigFile.new()
	next_snapshot.set_value("meta", "marker", "second")
	if Main.PersistenceController.save_config_with_backup(
		next_snapshot,
		primary_path,
		backup_path,
		temporary_path
	) != OK:
		failures.append("saving a snapshot must atomically replace the primary file")
	else:
		var primary := ConfigFile.new()
		var backup := ConfigFile.new()
		if primary.load(primary_path) != OK or String(primary.get_value("meta", "marker", "")) != "second":
			failures.append("the new snapshot must become the primary save")
		if backup.load(backup_path) != OK or String(backup.get_value("meta", "marker", "")) != "first":
			failures.append("replacing a save must retain the previous snapshot as a backup")
		var damaged := FileAccess.open(primary_path, FileAccess.WRITE)
		if damaged == null:
			failures.append("persistence recovery test could not damage its isolated primary snapshot")
		else:
			var oversized_contents := PackedByteArray()
			oversized_contents.resize(Main.MAX_SAVE_FILE_BYTES + 1)
			damaged.store_buffer(oversized_contents)
			damaged.close()
			var recovered: Dictionary = Main.PersistenceController.load_config_with_backup(primary_path, backup_path)
			var recovered_save := recovered.get("config") as ConfigFile
			if recovered_save == null or String(recovered_save.get_value("meta", "marker", "")) != "first":
				failures.append("a damaged primary save must recover from its last valid backup")
			elif Main.PersistenceController.save_config_with_backup(recovered_save, primary_path, backup_path, temporary_path) != OK:
				failures.append("a recovered backup must be safely promoted into a new primary save")
			elif backup.load(backup_path) != OK or String(backup.get_value("meta", "marker", "")) != "first":
				failures.append("recovering from backup must not replace the valid backup with the damaged primary")
	for path in [primary_path, backup_path, temporary_path, backup_temporary_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _test_persistence_rejects_non_finite_numbers(failures: Array[String]) -> void:
	if not is_equal_approx(Main.PersistenceController.sanitize_finite_float(NAN, 0.0, 100.0, 7.0), 7.0):
		failures.append("persistence must replace NaN values with a safe fallback")
	if not is_equal_approx(Main.PersistenceController.sanitize_finite_float(INF, 0.0, 100.0, 7.0), 7.0):
		failures.append("persistence must replace infinite values with a safe fallback")
	if not is_equal_approx(Main.PersistenceController.sanitize_finite_float(125.0, 0.0, 100.0, 7.0), 100.0):
		failures.append("persistence must clamp finite values to their configured range")


static func _test_starter_unlock_state(failures: Array[String]) -> void:
	var main := _make_main()
	if main.get("_unlocked_pet_ids") != ["pet1"]:
		failures.append("a fresh main state must unlock only pet1")
	if main.get("_deployed_pet_ids") != ["pet1"]:
		failures.append("a fresh main state must deploy only pet1")
	var entries: Array[Dictionary] = main.call("_get_pet_upgrade_entries")
	if entries.size() != 1 or String(entries[0].get("id", "")) != "pet1":
		failures.append("growth-locked pets must stay out of the upgrade list")
	if not main.call("_get_inventory_pet_entries").is_empty():
		failures.append("the deployed starter pet must not also appear in storage")
	var expected_rate := Main.PetProgression.faith_per_second(
		Main.PetCatalog.get_definition("pet1"),
		1
	)
	if not is_equal_approx(float(main.call("_get_faith_growth_rate")), expected_rate):
		failures.append("locked pets must not produce faith before they are drawn")
	main.free()


static func _test_language_defaults_and_pet_names(failures: Array[String]) -> void:
	var main := _make_main()
	if String(main.get("_language")) != "en":
		failures.append("a fresh game state must default to English")

	var language_less_save := ConfigFile.new()
	if Main.PersistenceController.resolve_saved_language(language_less_save) != "en":
		failures.append("a legacy save without a language key must migrate to English")
	language_less_save.set_value("settings", "language", "zh")
	if Main.PersistenceController.resolve_saved_language(language_less_save) != "zh":
		failures.append("an existing explicit Chinese language selection must be preserved")
	var migrated_names: Dictionary = main.call("_sanitize_loaded_pet_states", {
		"pet1": {"upgrade_level": 7, "name": Main.PetCatalog.get_localized_name("pet1", "zh")},
		"pet2": {"upgrade_level": 8, "name": Main.PetCatalog.get_localized_name("pet2", "en")},
		"pet3": {"upgrade_level": 9, "name": "Nyx"}
	})
	for pet_id in ["pet1", "pet2", "pet3"]:
		if String((migrated_names[pet_id] as Dictionary).get("name", "")).is_empty():
			failures.append("save migration must preserve every explicit custom name, even when it matches an authored name")

	var english_name := Main.PetCatalog.get_localized_name("pet1", "en")
	var chinese_name := Main.PetCatalog.get_localized_name("pet1", "zh")
	if String(main.call("_get_pet_display_name", "pet1")) != english_name:
		failures.append("an unrenamed pet must use its English name by default")
	main.set("_language", "zh")
	if String(main.call("_get_pet_display_name", "pet1")) != chinese_name:
		failures.append("an unrenamed pet must switch to its Chinese authored name")
	var state: Dictionary = main.call("_get_pet_state", "pet1")
	state["name"] = "Nyx"
	for language_code in ["en", "zh"]:
		main.set("_language", language_code)
		if String(main.call("_get_pet_display_name", "pet1")) != "Nyx":
			failures.append("switching to %s must not overwrite a custom pet name" % language_code)
	main.set("_language", "en")
	for pet_id in ["pet7", "pet9", "pet10"]:
		var pet_data := Main.PetCatalog.get_definition(pet_id)
		var english_age := String(main.call("_get_pet_age_text", pet_data))
		if english_age != Main.PetCatalog.get_localized_field(pet_id, "age", "en"):
			failures.append("%s must not leak its Chinese unknown-age copy in English mode" % pet_id)
	main.free()

	var achievements := Main.AchievementWindowScript.new()
	achievements.setup()
	if String(achievements.get("_language")) != "en" or not achievements.theme.default_font is SystemFont:
		failures.append("the achievement window must start in English with readable body typography")
	achievements.set_language("zh")
	if not achievements.theme.default_font is SystemFont:
		failures.append("the Chinese achievement UI must use a CJK-capable system font")
	achievements.free()


static func _test_growth_unlock_and_achievement_integration(failures: Array[String]) -> void:
	var main := _make_main()
	var pet1_state: Dictionary = main.call("_get_pet_state", "pet1")
	pet1_state["upgrade_level"] = 10
	var unlocked: Array = main.call("_unlock_growth_eligible_pets")
	if unlocked != ["pet2"]:
		failures.append("crossing the first permanent growth threshold must unlock pet2 without randomness or payment")
	if not (main.get("_unlocked_pet_ids") as Array).has("pet2"):
		failures.append("a growth-unlocked pet must join the permanent roster")
	if not (main.get("_deployed_pet_ids") as Array).has("pet2"):
		failures.append("a growth-unlocked pet must deploy to the desktop immediately")
	var next_unlock: Dictionary = Main.PetUnlockProgression.get_next_unlock(main.get("_unlocked_pet_ids"))
	if String(next_unlock.get("pet_id", "")) != "pet3" or float(next_unlock.get("threshold", 0.0)) != 20.0:
		failures.append("the roster must expose pet3 as the next authored growth milestone")

	main.set("_battle_victories", 1)
	var gold_before := int(main.get("_gold_coins"))
	var faith_before := float(main.get("_faith_points"))
	main.call("_on_achievement_claim_requested", "battle_1")
	if not (main.get("_claimed_achievement_ids") as Array).has("battle_1"):
		failures.append("a completed achievement must persist its claimed state")
	if int(main.get("_gold_coins")) <= gold_before or float(main.get("_faith_points")) <= faith_before:
		failures.append("claiming an achievement must grant both gold and faith")
	var rewarded_gold := int(main.get("_gold_coins"))
	main.call("_on_achievement_claim_requested", "battle_1")
	if int(main.get("_gold_coins")) != rewarded_gold:
		failures.append("an achievement reward must never be claimable twice")
	main.free()


static func _test_hidden_inventory_updates_are_lazy(failures: Array[String]) -> void:
	var inventory := Main.InventoryWindowScript.new()
	inventory.setup([Main.PetCatalog.make_inventory_entry("pet1")])
	inventory.visible = false
	var icons: Array = inventory.get("_slot_icons")
	var first_texture_before := (icons[0] as TextureRect).texture
	if (icons[1] as TextureRect).visible:
		failures.append("inventory lazy-refresh test requires an initially empty second slot")

	inventory.add_pet("pet2")
	if not bool(inventory.get("_visuals_dirty")):
		failures.append("adding a pet to a hidden inventory must mark its visuals dirty")
	if (icons[1] as TextureRect).visible:
		failures.append("adding a hidden pet must not redraw all 48 inventory slots immediately")
	inventory.remove_pet("pet1")
	if not bool(inventory.get("_visuals_dirty")):
		failures.append("removing a pet from a hidden inventory must preserve the dirty marker")
	if (icons[0] as TextureRect).texture != first_texture_before:
		failures.append("hidden inventory removal must defer icon replacement until the book opens")

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(inventory)
		inventory.open_window()
		var expected_pet2_icon := Main.PetCatalog.make_icon_texture(
			String(Main.PetCatalog.get_definition("pet2").get("icon", ""))
		)
		if bool(inventory.get("_visuals_dirty")):
			failures.append("opening inventory must consume its one deferred visual refresh")
		if not (icons[0] as TextureRect).visible or (icons[0] as TextureRect).texture != expected_pet2_icon:
			failures.append("opening a dirty inventory must render the latest pet data exactly once")
		tree.root.remove_child(inventory)
		inventory.free()
	else:
		inventory.free()


static func _test_legacy_state_migration(failures: Array[String]) -> void:
	var main := _make_main()
	var sanitized: Dictionary = main.call("_sanitize_loaded_pet_states", {
		"pet1": {
			"count": 150,
			"trust": 3,
			"favor": 5,
			"next_trust_pet_at": 123.0,
			"hungry": true,
			"last_fed_at": 1.0
		}
	})
	var state: Dictionary = sanitized.get("pet1", {})
	if int(state.get("upgrade_level", 0)) != 150:
		failures.append("legacy population saves must migrate their count into the upgrade level")
	for removed_key in ["count", "evolution_stage", "hungry", "last_fed_at", "trust", "favor", "next_trust_pet_at"]:
		if state.has(removed_key):
			failures.append("pure upgrade migration must remove legacy field %s" % removed_key)
	main.free()


static func _test_explicit_level_migration(failures: Array[String]) -> void:
	var main := _make_main()
	var sanitized: Dictionary = main.call("_sanitize_loaded_pet_states", {
		"pet2": {"count": 20000, "upgrade_level": 290, "evolution_stage": 2}
	})
	var state: Dictionary = sanitized.get("pet2", {})
	if int(state.get("upgrade_level", 0)) != 290:
		failures.append("an explicit legacy upgrade level must take precedence over population")
	if state.size() != 2 or not bool(state.get("evolved", false)):
		failures.append("migrated level-100+ pets must retain their level and derived evolved form")
	main.free()


static func _test_single_level_upgrade(failures: Array[String]) -> void:
	var main := _make_main()
	main.set("_endless_mode", true)
	var unlocked: Array = main.get("_unlocked_pet_ids")
	unlocked.append("pet2")
	var state: Dictionary = main.call("_get_pet_state", "pet2")
	state["upgrade_level"] = 100
	main.set("_faith_points", 1.0e15)
	var cost: int = main.call("_get_upgrade_cost", "pet2")
	var faith_before := float(main.get("_faith_points"))
	var output_before: float = main.call("_get_faith_growth_rate")
	main.call("_on_pet_upgrade_requested", "pet2")
	if int(state.get("upgrade_level", 0)) != 101:
		failures.append("each pet-row click must advance exactly one level")
	if state.has("count") or state.has("evolution_stage"):
		failures.append("upgrading must not recreate population or evolution state")
	if not is_equal_approx(float(main.get("_faith_points")), faith_before - float(cost)):
		failures.append("a successful level upgrade must charge its displayed faith cost")
	if float(main.call("_get_faith_growth_rate")) <= output_before:
		failures.append("a pet level upgrade must increase total faith generation")
	state["upgrade_level"] = Main.PetProgression.MAX_LEVEL
	var max_faith_before := float(main.get("_faith_points"))
	main.call("_on_pet_upgrade_requested", "pet2")
	if int(state.get("upgrade_level", 0)) != Main.PetProgression.MAX_LEVEL:
		failures.append("a max-level pet must not advance beyond the supported level cap")
	if not is_equal_approx(float(main.get("_faith_points")), max_faith_before):
		failures.append("clicking a max-level pet must not spend faith")
	main.free()


static func _test_upgrade_entry_simplicity(failures: Array[String]) -> void:
	var main := _make_main()
	main.set("_language", "zh")
	var entries: Array[Dictionary] = main.call("_get_pet_upgrade_entries")
	var pet1_entry: Dictionary = entries[0]
	if int(pet1_entry.get("level", 0)) != 1:
		failures.append("upgrade entries must expose the current pet level")
	if float(pet1_entry.get("next_fps", 0.0)) <= float(pet1_entry.get("current_fps", 0.0)):
		failures.append("upgrade entries must preview a higher next-level generation rate")
	if float(pet1_entry.get("next_money_rate", 0.0)) <= float(pet1_entry.get("current_money_rate", 0.0)):
		failures.append("pet detail entries must preview higher collectible money drops")
	if int(pet1_entry.get("rarity_stars", 0)) < 1:
		failures.append("pet detail entries must expose a visible rarity star count")
	if String(pet1_entry.get("age_text", "")).is_empty() or String(pet1_entry.get("personality", "")).is_empty():
		failures.append("pet detail entries must expose age and personality copy")
	if String(pet1_entry.get("age_text", "")) != String(Main.PetCatalog.get_definition("pet1").get("age", "")):
		failures.append("pet detail entries must preserve the catalog age instead of showing an unknown fallback")
	for removed_key in ["count", "upgrade_level", "evolution_stage", "next_evolution_threshold", "can_evolve", "leader_age", "leader_name"]:
		if pet1_entry.has(removed_key):
			failures.append("pure upgrade entries must not expose removed UI field %s" % removed_key)
	main.free()


static func _test_scaled_manual_click(failures: Array[String]) -> void:
	var main := _make_main()
	var opening_gain: float = main.call("_get_manual_faith_click_gain", 1)
	if opening_gain < 1.0:
		failures.append("manual faith clicks must always grant at least one faith")
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		var state: Dictionary = main.call("_get_pet_state", String(pet_id_value))
		state["upgrade_level"] = 200
	var scaled_gain: float = main.call("_get_manual_faith_click_gain", 1)
	if scaled_gain <= opening_gain:
		failures.append("manual faith click gain must grow with passive production")
	var faith_before := float(main.get("_faith_points"))
	main.call("_on_faith_add_requested", 1)
	if not is_equal_approx(float(main.get("_faith_points")), faith_before + scaled_gain):
		failures.append("one adder click must grant exactly one scaled click reward")
	main.free()


static func _test_news_overlay_tuning(failures: Array[String]) -> void:
	var main := _make_main()
	main.set("_language", "zh")
	var style: StyleBoxFlat = main.call("_make_news_broadcast_style")
	if style.bg_color.a <= 0.0 or style.bg_color.a >= 0.5:
		failures.append("the desktop news broadcast must tint the desktop without hiding it")
	if style.border_color.a <= 0.0 or style.border_color.a >= 1.0:
		failures.append("the desktop news broadcast must keep a visible semi-transparent border")
	for border_width in [
		style.border_width_left,
		style.border_width_top,
		style.border_width_right,
		style.border_width_bottom
	]:
		if border_width <= 0:
			failures.append("the desktop news broadcast border must have visible width on every side")
			break
	if style.shadow_size != 0 or not is_zero_approx(style.shadow_color.a):
		failures.append("the desktop news broadcast must not cast an opaque shadow")
	if Main.NEWS_BROADCAST_FONT_SIZE < 24:
		failures.append("the desktop news broadcast text must remain large enough to read clearly")
	main.call("_create_news_broadcast")
	var broadcast_label: Label = main.get("_news_broadcast_label")
	if broadcast_label == null:
		failures.append("the desktop news broadcast must create its readable text label")
	else:
		if broadcast_label.get_theme_font_size("font_size") < 24:
			failures.append("the desktop news broadcast must apply its readable font size")
		if not broadcast_label.get_theme_font("font") is SystemFont:
			failures.append("the desktop news broadcast must use a clear system UI font")
	var short_hold: float = main.call("_get_news_broadcast_hold_seconds", "短讯")
	var long_hold: float = main.call("_get_news_broadcast_hold_seconds", "很长的新闻".repeat(100))
	if short_hold < 6.0 or long_hold > 9.0 or long_hold <= short_hold:
		failures.append("news broadcasts must remain readable for a bounded 6-9 seconds")
	if not is_equal_approx(float(Main.NEWS_INITIAL_AMBIENT_DELAY), 45.0):
		failures.append("the first ambient news must arrive after a short 45-second wait")
	main.call("_try_queue_news_event", "petting", {"pet_name": "测试宠物"}, "test:petting", 0.0)
	var feed: RefCounted = main.get("_news_feed")
	var backlog: Array = main.get("_news_story_backlog")
	if not feed.call("get_history").is_empty() or backlog.size() != 1:
		failures.append("ordinary pet events must wait in the idle-news backlog instead of broadcasting immediately")
	elif String(backlog[0].get("headline", "")).contains("测试宠物"):
		failures.append("pet-triggered news must never expose a pet display name")
	main.free()


static func _test_versioned_news_tier_migration(failures: Array[String]) -> void:
	var migrated_tier: int = Main._get_loaded_news_faith_tier(4, 9, 5.0)
	if migrated_tier != 2:
		failures.append("pre-level-model news tiers must be rebased to the migrated faith rate")
	var preserved_tier: int = Main._get_loaded_news_faith_tier(Main.SAVE_VERSION, 7, 5.0)
	if preserved_tier != 7:
		failures.append("current-version news tiers must retain their saved milestone progress")
