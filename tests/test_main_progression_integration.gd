extends RefCounted

const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_state_migration(failures)
	_test_explicit_level_migration(failures)
	_test_single_level_upgrade(failures)
	_test_upgrade_entry_simplicity(failures)
	_test_news_overlay_tuning(failures)
	_test_versioned_news_tier_migration(failures)
	return failures


static func _make_main() -> Node:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	return main


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
	if state.size() != 1:
		failures.append("migrated unnamed pets must retain only their upgrade level")
	main.free()


static func _test_single_level_upgrade(failures: Array[String]) -> void:
	var main := _make_main()
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
	var entries: Array[Dictionary] = main.call("_get_pet_upgrade_entries")
	var pet1_entry: Dictionary = entries[0]
	if int(pet1_entry.get("level", 0)) != 1:
		failures.append("upgrade entries must expose the current pet level")
	if float(pet1_entry.get("next_fps", 0.0)) <= float(pet1_entry.get("current_fps", 0.0)):
		failures.append("upgrade entries must preview a higher next-level generation rate")
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


static func _test_news_overlay_tuning(failures: Array[String]) -> void:
	var main := _make_main()
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
