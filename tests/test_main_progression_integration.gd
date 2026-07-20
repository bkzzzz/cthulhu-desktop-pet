extends RefCounted

const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_state_migration(failures)
	_test_explicit_level_migration(failures)
	_test_starter_unlock_state(failures)
	_test_language_defaults_and_pet_names(failures)
	_test_pet_gacha_integration(failures)
	_test_gacha_batch_tier_ceiling(failures)
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


static func _test_starter_unlock_state(failures: Array[String]) -> void:
	var main := _make_main()
	if main.get("_unlocked_pet_ids") != ["pet1"]:
		failures.append("a fresh main state must unlock only pet1")
	if main.get("_deployed_pet_ids") != ["pet1"]:
		failures.append("a fresh main state must deploy only pet1")
	var entries: Array[Dictionary] = main.call("_get_pet_upgrade_entries")
	if entries.size() != 1 or String(entries[0].get("id", "")) != "pet1":
		failures.append("locked gacha pets must stay out of the upgrade list")
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

	var gacha := Main.GachaWindowScript.new()
	gacha.setup()
	if String(gacha.get("_language")) != "en" or not gacha.theme.default_font is SystemFont:
		failures.append("the standalone gacha window must start in English with readable body typography")
	gacha.set_language("zh")
	if not gacha.theme.default_font is SystemFont:
		failures.append("the Chinese gacha UI must switch to a CJK-capable system font")
	gacha.set_language("en")
	if not gacha.theme.default_font is SystemFont:
		failures.append("switching gacha back to English must restore its readable body font")
	gacha.free()


static func _test_pet_gacha_integration(failures: Array[String]) -> void:
	var main := _make_main()
	var window := Main.GachaWindowScript.new()
	window.setup()
	main.set("_gacha_window", window)
	main.set("_gold_coins", 1000000)
	main.set("_gacha_pity_count", Main.GachaProgression.NEW_PET_PITY_DRAWS - 1)
	var first_cost := Main.GachaProgression.draw_cost(0)
	main.call("_on_gacha_draw_requested")
	_drain_gacha_batch(main, failures, "first draw")
	var unlocked_after_first: Array = main.get("_unlocked_pet_ids")
	if unlocked_after_first.size() != 2 or not unlocked_after_first.has("pet1"):
		failures.append("the first successful pet draw must unlock exactly one new non-starter pet")
	var newly_unlocked_id := ""
	for unlocked_id_value in unlocked_after_first:
		var unlocked_id := String(unlocked_id_value)
		if unlocked_id != "pet1":
			newly_unlocked_id = unlocked_id
			break
	var deployed_after_first: Array = main.get("_deployed_pet_ids")
	var spawned_after_first: Array = main.get("_pets")
	if newly_unlocked_id.is_empty() or not deployed_after_first.has(newly_unlocked_id):
		failures.append("a newly unlocked pet must default to the deployed desktop roster")
	elif spawned_after_first.is_empty() or String(main.call("_get_actor_pet_id", spawned_after_first.back())) != newly_unlocked_id:
		failures.append("a newly unlocked pet must appear on the desktop immediately instead of entering storage")
	for inventory_entry in main.call("_get_inventory_pet_entries"):
		if String((inventory_entry as Dictionary).get("id", "")) == newly_unlocked_id:
			failures.append("an automatically deployed new pet must not also appear in storage")
	if int(main.get("_gacha_draw_count")) != 1:
		failures.append("a successful pet draw must advance the saved draw count")
	if int(main.get("_gold_coins")) != 1000000 - first_cost:
		failures.append("a successful pet draw must spend its displayed gold cost")
	var history: Array = main.get("_gacha_history")
	if history.is_empty() or not bool((history[0] as Dictionary).get("is_new", false)):
		failures.append("new pet draws must be recorded as unlocks in gacha history")

	var unlocked_all: Array = main.get("_unlocked_pet_ids")
	unlocked_all.clear()
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		unlocked_all.append(String(pet_id_value))
	var gold_before_duplicate := int(main.get("_gold_coins"))
	var faith_before_duplicate := float(main.get("_faith_points"))
	var duplicate_draw_cost := Main.GachaProgression.draw_cost(1)
	main.call("_on_gacha_draw_requested")
	_drain_gacha_batch(main, failures, "duplicate draw")
	history = main.get("_gacha_history")
	if history.is_empty() or bool((history[0] as Dictionary).get("is_new", true)):
		failures.append("draws from a complete collection must be recorded as duplicate exchanges")
	else:
		var duplicate_faith := int((history[0] as Dictionary).get("duplicate_faith", 0))
		if duplicate_faith <= 0:
			failures.append("a duplicate pet must exchange directly into faith")
		if int(main.get("_gold_coins")) != gold_before_duplicate - duplicate_draw_cost:
			failures.append("duplicate draws must still spend only gold")
		if not is_equal_approx(float(main.get("_faith_points")), faith_before_duplicate + float(duplicate_faith)):
			failures.append("duplicate faith must be credited without refunding the gold draw cost")

	var draw_count_before_batch := int(main.get("_gacha_draw_count"))
	main.set("_gold_coins", 9_000_000_000_000_000_000)
	main.call("_on_gacha_draw_requested", 10)
	_drain_gacha_batch(main, failures, "ten draw")
	if int(main.get("_gacha_draw_count")) != draw_count_before_batch + 10:
		failures.append("checking draw ten must resolve exactly ten sequential pet draws")
	var pending_results: Array = window.get("_pending_results")
	if pending_results.size() != 10:
		failures.append("a ten-draw batch must queue all ten popup results in draw order")
	var expected_duplicate_summary := 0
	for pending_result_value in pending_results:
		expected_duplicate_summary += int((pending_result_value as Dictionary).get("duplicate_faith", 0))
	var prepared_summary: Dictionary = window.get("_prepared_batch_summary")
	if int(prepared_summary.get("duplicate_faith_total", -1)) != expected_duplicate_summary:
		failures.append("batch processing must precompute the exact skip-all duplicate faith total")
	var draw_count_before_hundred := int(main.get("_gacha_draw_count"))
	main.call("_on_gacha_draw_requested", 100)
	_drain_gacha_batch(main, failures, "hundred draw")
	if int(main.get("_gacha_draw_count")) != draw_count_before_hundred + 100:
		failures.append("the 100-draw option must resolve one hundred sequential draws")
	pending_results = window.get("_pending_results")
	if pending_results.size() != 100:
		failures.append("large batches must remain available to skip-all result aggregation")

	var chunked_amount := Main.GACHA_BATCH_MAX_DRAWS_PER_FRAME + 17
	var draw_count_before_chunked := int(main.get("_gacha_draw_count"))
	main.call("_on_gacha_draw_requested", chunked_amount)
	var chunked_token := int(main.get("_gacha_batch_token"))
	var gold_after_reservation := int(main.get("_gold_coins"))
	if not bool(main.get("_gacha_batch_active")) or not window.is_draw_request_pending():
		failures.append("a large gacha request must enter a visible busy state before batch work starts")
	main.call("_on_gacha_draw_requested", 10)
	if int(main.get("_gacha_batch_token")) != chunked_token or int(main.get("_gold_coins")) != gold_after_reservation:
		failures.append("a repeated draw signal must not replace the active batch or reserve gold twice")
	var replacement_window := Main.GachaWindowScript.new()
	replacement_window.setup()
	main.set("_gacha_window", replacement_window)
	main.call("_on_gacha_draw_requested", 10)
	if replacement_window.is_draw_request_pending():
		failures.append("a stale batch must not transfer its busy state or result ownership to a replacement window")
	main.set("_gacha_window", window)
	replacement_window.free()
	main.call("_process_gacha_draw_batch", chunked_token)
	var first_chunk_draws := int(main.get("_gacha_draw_count")) - draw_count_before_chunked
	if first_chunk_draws <= 0 or first_chunk_draws > Main.GACHA_BATCH_MAX_DRAWS_PER_FRAME:
		failures.append("one gacha frame must obey the explicit maximum draw chunk")
	if not bool(main.get("_gacha_batch_active")) or not window.is_draw_request_pending():
		failures.append("a multi-frame gacha batch must remain busy between chunks")
	_drain_gacha_batch(main, failures, "multi-frame draw")
	if int(main.get("_gacha_draw_count")) != draw_count_before_chunked + chunked_amount:
		failures.append("chunking must preserve the exact requested number and result order")
	if window.is_draw_request_pending():
		failures.append("a completed gacha batch must always release its busy state")
	var count_after_chunked := int(main.get("_gacha_draw_count"))
	main.call("_process_gacha_draw_batch", chunked_token)
	if int(main.get("_gacha_draw_count")) != count_after_chunked:
		failures.append("a stale deferred chunk must not mutate a completed batch")

	var gold_before_empty := int(main.get("_gold_coins"))
	main.call("_on_gacha_draw_requested", 10)
	var empty_token := int(main.get("_gacha_batch_token"))
	var empty_state: Dictionary = main.get("_gacha_batch_state")
	empty_state["remaining"] = 0
	empty_state["results"] = []
	empty_state["spent_cost"] = 0
	main.set("_gacha_batch_state", empty_state)
	main.call("_process_gacha_draw_batch", empty_token)
	if bool(main.get("_gacha_batch_active")) or window.is_draw_request_pending():
		failures.append("an empty gacha result must release both model and UI busy state")
	if int(main.get("_gold_coins")) != gold_before_empty:
		failures.append("an empty gacha result must refund all reserved gold")

	main.set("_gold_coins", 0)
	window.set_draw_request_pending(true)
	main.call("_on_gacha_draw_requested", 100)
	if bool(main.get("_gacha_batch_active")) or window.is_draw_request_pending():
		failures.append("an unaffordable gacha request must not leave the window waiting")
	main.set("_gacha_window", null)
	window.free()
	main.free()


static func _drain_gacha_batch(main: Node, failures: Array[String], label: String) -> void:
	var chunk_count := 0
	while bool(main.get("_gacha_batch_active")) and chunk_count < 20_000:
		main.call("_process_gacha_draw_batch", int(main.get("_gacha_batch_token")))
		chunk_count += 1
	if bool(main.get("_gacha_batch_active")):
		failures.append("%s gacha batch must finish within a bounded number of chunks" % label)


static func _test_gacha_batch_tier_ceiling(failures: Array[String]) -> void:
	var main := _make_main()
	var window := Main.GachaWindowScript.new()
	window.setup()
	main.set("_gacha_window", window)
	var starter_state: Dictionary = main.call("_get_pet_state", "pet1")
	starter_state["upgrade_level"] = 100
	starter_state["evolved"] = true
	main.set("_gold_coins", 1_000_000_000)
	main.set("_gacha_pity_count", Main.GachaProgression.NEW_PET_PITY_DRAWS - 1)
	main.call("_on_gacha_draw_requested", 10)
	_drain_gacha_batch(main, failures, "faith-gated ten draw")
	var unlocked_after_batch: Array = main.get("_unlocked_pet_ids")
	if unlocked_after_batch != ["pet1", "pet2"]:
		failures.append("one high-faith batch must unlock only its starting next tier")
	main.call("_on_gacha_draw_requested", 1)
	_drain_gacha_batch(main, failures, "next gated request")
	var unlocked_after_next_request: Array = main.get("_unlocked_pet_ids")
	if not unlocked_after_next_request.has("pet3"):
		failures.append("a later request may unlock the following tier after the prior batch ends")
	main.set("_gacha_window", null)
	window.free()
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
