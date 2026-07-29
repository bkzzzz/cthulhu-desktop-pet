extends RefCounted

const Main = preload("res://scripts/main.gd")
const CompletionWindow = preload("res://scripts/completion_window.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_exact_campaign_goal(failures)
	_test_campaign_level_cap_and_endless_unlock(failures)
	_test_final_boss_definition_and_schedule(failures)
	_test_final_boss_balance_window(failures)
	_test_completion_window_copy_and_signals(failures)
	return failures


static func _make_main() -> Node:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	return main


static func _make_complete_roster() -> Dictionary:
	var states := {}
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		states[String(pet_id_value)] = {
			"upgrade_level": Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET
		}
	return states


static func _test_exact_campaign_goal(failures: Array[String]) -> void:
	var all_pet_ids: Array[String] = []
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		all_pet_ids.append(String(pet_id_value))
	var complete_states := _make_complete_roster()
	if not Main.EconomyBalance.is_campaign_complete(all_pet_ids, complete_states):
		failures.append("campaign completion must require and accept every active pet at Lv.100")

	var missing_unlocks := all_pet_ids.duplicate()
	missing_unlocks.pop_back()
	if Main.EconomyBalance.is_campaign_complete(missing_unlocks, complete_states):
		failures.append("campaign completion must reject a Lv.100 roster with one pet still locked")

	var underleveled_states := complete_states.duplicate(true)
	var final_pet_id := String(all_pet_ids.back())
	underleveled_states[final_pet_id]["upgrade_level"] = (
		Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET - 1
	)
	if Main.EconomyBalance.is_campaign_complete(all_pet_ids, underleveled_states):
		failures.append("campaign completion must reject even one pet below Lv.100")

	var main := _make_main()
	main.set("_unlocked_pet_ids", all_pet_ids)
	main.set("_pet_states", complete_states)
	if bool(main.call("_check_campaign_completion")) or bool(main.get("_campaign_completed")):
		failures.append("a Lv.100 roster must unlock the final boss instead of skipping directly to completion")
	if not bool(main.call("_should_offer_final_boss")):
		failures.append("the final boss encounter must become pending as soon as the exact roster goal is reached")
	main.call("_on_final_boss_defeated")
	if (
		not bool(main.call("_check_campaign_completion"))
		or not bool(main.get("_campaign_completed"))
		or bool(main.get("_campaign_completion_acknowledged"))
	):
		failures.append("defeating the final boss must persist completion without auto-acknowledging its choice")
	main.free()


static func _test_campaign_level_cap_and_endless_unlock(failures: Array[String]) -> void:
	var main := _make_main()
	var pet_state: Dictionary = main.call("_get_pet_state", "pet1")
	pet_state["upgrade_level"] = Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET
	main.set("_faith_points", 1.0e18)
	var faith_before_cap := float(main.get("_faith_points"))
	main.call("_on_pet_upgrade_requested", "pet1")
	if int(pet_state.get("upgrade_level", 0)) != Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET:
		failures.append("normal campaign progression must stop each pet at Lv.100")
	if not is_equal_approx(float(main.get("_faith_points")), faith_before_cap):
		failures.append("clicking a campaign-capped pet must not spend faith")
	if int(main.call("_get_campaign_level_cap")) != Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET:
		failures.append("the normal campaign must expose Lv.100 as its effective cap")

	main.call("_on_completion_continue_requested")
	if (
		bool(main.get("_campaign_completed"))
		or bool(main.get("_campaign_completion_acknowledged"))
	):
		failures.append("a stale finale signal must not acknowledge an unfinished campaign")
	main.call("_on_endless_mode_requested")
	if bool(main.get("_endless_mode")):
		failures.append("Endless Mode must remain locked before every pet reaches Lv.100")

	var all_pet_ids: Array[String] = []
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		all_pet_ids.append(String(pet_id_value))
	main.set("_unlocked_pet_ids", all_pet_ids)
	main.set("_pet_states", _make_complete_roster())
	main.call("_check_campaign_completion")
	main.call("_on_endless_mode_requested")
	if bool(main.get("_endless_mode")):
		failures.append("Endless Mode must remain locked until the final boss is defeated")
	main.call("_on_final_boss_defeated")
	main.call("_on_endless_mode_requested")
	if not bool(main.get("_endless_mode")):
		failures.append("choosing Endless Mode after completion must persistently unlock it")
	if int(main.call("_get_campaign_level_cap")) != Main.PetProgression.MAX_LEVEL:
		failures.append("Endless Mode must replace the campaign cap with the supported engine cap")

	var endless_pet_state: Dictionary = main.call("_get_pet_state", "pet1")
	endless_pet_state["upgrade_level"] = Main.EconomyBalance.CAMPAIGN_LEVEL_TARGET
	main.set("_faith_points", 1.0e18)
	main.call("_on_pet_upgrade_requested", "pet1")
	if int(endless_pet_state.get("upgrade_level", 0)) != 101:
		failures.append("a completed roster must be able to advance beyond Lv.100 in Endless Mode")
	main.free()


static func _test_final_boss_definition_and_schedule(failures: Array[String]) -> void:
	if not Main._get_loaded_final_boss_defeated(12, true, false, false):
		failures.append("pre-final-boss completed saves must migrate as boss-defeated")
	if Main._get_loaded_final_boss_defeated(Main.SAVE_VERSION, false, false, false):
		failures.append("new incomplete saves must not inherit a final-boss victory")
	var schedule := Main.BattleBalance.build_final_boss_schedule()
	if not Main.BattleBalance.is_final_boss_schedule(schedule):
		failures.append("the campaign finale must expose a dedicated marked encounter schedule")
	elif schedule.is_empty() or not (schedule.back() as Dictionary).get("types", []).has("final_boss"):
		failures.append("the dedicated finale schedule must culminate in the imported final boss")
	var definition: Dictionary = Main.EnemyActor.DEFINITIONS.get("final_boss", {})
	var animation_path := String(definition.get("move", ""))
	if definition.is_empty() or not ResourceLoader.exists(animation_path):
		failures.append("the final boss must use its imported animation sheet")
		return
	var boss := Main.EnemyActor.new()
	boss.setup("final_boss", Vector2(700.0, 704.0), 704.0, 1.0, 700.0)
	var sprite := boss.get_node_or_null("EnemySprite") as AnimatedSprite2D
	var health_bar := boss.get_node_or_null("CombatHealthBar") as Node2D
	if sprite == null or sprite.sprite_frames.get_frame_count("run") != 12:
		failures.append("the final boss must animate all twelve imported frames")
	if health_bar == null or float(health_bar.get("_bar_size").x) < 180.0:
		failures.append("the final boss must use a prominent segmented boss health bar")
	if boss.can_be_swallowed():
		failures.append("the final boss must resist instant swallow defeat mechanics")
	var opening_projectiles := int(boss.get("_projectiles_per_attack"))
	boss.take_damage(boss.max_health * 0.51, 0.0)
	if boss.get_boss_phase() != 2 or int(boss.get("_projectiles_per_attack")) <= opening_projectiles:
		failures.append("the final boss must enter a faster multi-projectile second phase below half health")
	boss.free()


static func _test_final_boss_balance_window(failures: Array[String]) -> void:
	var roster_power := 0.0
	var estimated_damage_per_second := 0.0
	for pet_id_value in Main.PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var pet_data := Main.PetCatalog.get_definition(pet_id)
		var rarity := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
		var pet_power := Main.PetCatalog.get_combat_power(pet_id, 100, true)
		roster_power += pet_power
		var damage_power_scale := clampf(pow(pet_power / 20.0, 0.35), 0.80, 2.5)
		var damage := (1.05 + float(rarity) * 0.24 + sqrt(100.0) * 0.055) * damage_power_scale
		estimated_damage_per_second += damage / 1.15
	var schedule := Main.BattleBalance.build_final_boss_schedule()
	var difficulty := Main.BattleBalance.recommended_difficulty_scale(
		roster_power,
		schedule,
		100.0,
		false,
		1.0,
		0.0,
		Main.PetCatalog.ACTIVE_DESKTOP_PETS.size()
	)
	var boss := Main.EnemyActor.new()
	boss.setup("final_boss", Vector2(700.0, 704.0), 704.0, difficulty * 1.075, 700.0)
	var estimated_clear_seconds := boss.max_health / maxf(0.001, estimated_damage_per_second)
	if estimated_clear_seconds < 18.0 or estimated_clear_seconds > 26.0:
		failures.append(
			"the final boss must occupy a meaningful but clearable 18-26 second window, estimated %.1fs"
			% estimated_clear_seconds
		)
	boss.free()

	var main := _make_main()
	main.set("_battle_wave_schedule", Main.BattleBalance.build_final_boss_schedule())
	var final_rewards: Dictionary = main.call("_get_battle_reward_budget", 1.0)
	main.set("_battle_wave_schedule", Main.EraProgression.get_wave_schedule(0.0))
	var regular_rewards: Dictionary = main.call("_get_battle_reward_budget", 1.0)
	if (
		int(final_rewards.get("gold", 0)) < int(regular_rewards.get("gold", 0)) * 5
		or int(final_rewards.get("faith", 0)) < int(regular_rewards.get("faith", 0)) * 3
	):
		failures.append("the one-time final boss must award a clearly premium gold and faith payout")
	main.free()


static func _test_completion_window_copy_and_signals(failures: Array[String]) -> void:
	var window := CompletionWindow.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(window)
	window.setup("zh")
	var initial_child_count := window.get_child_count()
	window.setup("zh")
	if window.get_child_count() != initial_child_count:
		failures.append("reconfiguring completion copy must not duplicate the window hierarchy")
	var continue_events: Array[bool] = []
	var endless_events: Array[bool] = []
	window.continue_requested.connect(func() -> void: continue_events.append(true))
	window.endless_requested.connect(func() -> void: endless_events.append(true))

	window.open_window(200.0 * 3600.0)
	var title_label := window.get("_title_label") as Label
	var body_label := window.get("_body_label") as Label
	var time_label := window.get("_time_label") as Label
	var continue_button := window.get("_continue_button") as Button
	var endless_button := window.get("_endless_button") as Button
	if (
		title_label == null
		or not title_label.text.contains("游戏通关")
		or body_label == null
		or not body_label.text.contains("Lv.100")
		or not body_label.text.contains("终焉星械")
		or time_label == null
		or not time_label.text.contains("200.0")
	):
		failures.append("the Chinese completion screen must explain Lv.100 and show total play time")
	if continue_button == null or endless_button == null:
		failures.append("the completion screen must expose finale and Endless Mode choices")
	else:
		continue_button.pressed.emit()
		if continue_events.size() != 1 or window.visible:
			failures.append("the finale choice must close the window and emit exactly once")
		window.open_window(200.0 * 3600.0)
		endless_button.pressed.emit()
		if endless_events.size() != 1 or window.visible:
			failures.append("the Endless Mode choice must close the window and emit exactly once")

	window.set_language("en")
	if (
		title_label == null
		or title_label.text != "ALL PETS ASCENDED"
		or body_label == null
		or not body_label.text.contains("Every pet reached Lv.100")
		or not body_label.text.contains("Final Orrery")
		or time_label == null
		or not time_label.text.contains("TOTAL PLAY TIME  200.0 HOURS")
		or endless_button == null
		or endless_button.text != "ENTER ENDLESS MODE"
	):
		failures.append("the completion screen must provide complete English finale copy")

	if tree != null:
		tree.root.remove_child(window)
	window.free()
