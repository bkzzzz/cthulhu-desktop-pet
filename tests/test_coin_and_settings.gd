extends RefCounted

const Main = preload("res://scripts/main.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_coin_definitions(failures)
	_test_coin_ground_first_pickup(failures)
	_test_coin_collection(failures)
	_test_activity_ranges(failures)
	_test_settings_runtime(failures)
	_test_believer_drop_signal(failures)
	return failures


static func _test_coin_definitions(failures: Array[String]) -> void:
	var r_value := CoinDrop.get_coin_value("R")
	var p_value := CoinDrop.get_coin_value("P")
	var d_value := CoinDrop.get_coin_value("D")
	if not (r_value > 0 and p_value > r_value and d_value >= p_value * 10):
		failures.append("coin values must satisfy R < P << D")
	for coin_type in ["R", "P", "D"]:
		var texture_path := CoinDrop.get_coin_texture(coin_type)
		if texture_path.is_empty() or not FileAccess.file_exists(texture_path):
			failures.append("coin %s must use its provided sprite sheet" % coin_type)

	var coin := CoinDrop.new()
	coin.setup("P", Vector2(200.0, 100.0), Vector2i(820, 420), 400.0)
	var sprite := coin.get_node_or_null("CoinPSprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames.get_frame_count("spin") != CoinDrop.SHEET_FRAMES:
		failures.append("coin drops must animate every frame in the provided five-frame sheet")
	coin.free()


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
	main.free()


static func _test_settings_runtime(failures: Array[String]) -> void:
	if SettingsWindow._format_duration(3661.9) != "01:01:01":
		failures.append("settings must format current and total runtime as HH:MM:SS")
	var settings := SettingsWindow.new()
	settings.setup("right", "en")
	if settings.get_activity_range() != "right" or settings.get_language() != "en":
		failures.append("settings must restore the saved activity range and language")
	settings.refresh_runtime(61.0, 3723.0)
	var session_label := settings.get("_session_value_label") as Label
	var total_label := settings.get("_total_value_label") as Label
	if session_label == null or session_label.text != "00:01:01":
		failures.append("settings must display the current session runtime")
	if total_label == null or total_label.text != "01:02:03":
		failures.append("settings must display the persisted total runtime")
	settings.free()


static func _test_believer_drop_signal(failures: Array[String]) -> void:
	var believer := BelieverActor.new()
	if not believer.has_signal("scared_away"):
		failures.append("believers must expose a distinct scared-away event for D coin drops")
	believer.free()
