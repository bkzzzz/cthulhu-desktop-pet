extends SceneTree

const TEST_SUITES := [
	preload("res://tests/test_pet_progression.gd"),
	preload("res://tests/test_pet_catalog.gd"),
	preload("res://tests/test_desktop_pet_behavior.gd"),
	preload("res://tests/test_desktop_input_safety.gd"),
	preload("res://tests/test_follower_progression.gd"),
	preload("res://tests/test_gacha_progression.gd"),
	preload("res://tests/test_economy_balance.gd"),
	preload("res://tests/test_currency_display.gd"),
	preload("res://tests/test_offering_inventory.gd"),
	preload("res://tests/test_turret_system.gd"),
	preload("res://tests/test_main_progression_integration.gd"),
	preload("res://tests/test_save_slots.gd"),
	preload("res://tests/test_ui_number_format.gd"),
	preload("res://tests/test_locked_pet_ui.gd"),
	preload("res://tests/test_news_feed.gd"),
	preload("res://tests/test_coin_and_settings.gd"),
	preload("res://tests/test_desktop_events.gd"),
	preload("res://tests/test_pet_evolution.gd"),
	preload("res://tests/test_campaign_endgame.gd"),
	preload("res://tests/test_melee_combat.gd"),
	preload("res://tests/test_pet_level_size.gd"),
	preload("res://tests/test_performance_regressions.gd"),
	preload("res://tests/test_display_layout.gd")
]


func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	for suite in TEST_SUITES:
		var suite_failures: Array[String] = suite.run()
		checks += 1
		failures.append_array(suite_failures)

	if failures.is_empty():
		print("PASS: %d test suite(s)" % checks)
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("FAIL: %d failure(s)" % failures.size())
	quit(1)
