extends RefCounted

const Main = preload("res://scripts/main.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_coin_definitions(failures)
	_test_coin_ground_first_pickup(failures)
	_test_coin_collection(failures)
	_test_pet_money_pile(failures)
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
	if drops.size() < Main.PET_AUTO_COIN_PILE_MIN:
		failures.append("an automatic pet money event must drop a visible pile of coins")
	if int(main.get("_gold_coins")) != 0:
		failures.append("automatic pet money must remain on the ground until the mouse collects it")
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
	if max_fps <= 0 or max_fps > 30:
		failures.append("the always-running desktop game must cap its rendering frame rate")


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
		failures.append("believers must expose a distinct scared-away event")
	if not believer.has_signal("prayed"):
		failures.append("believers must expose a completed-prayer reward event")
	believer.free()


static func _test_believer_prayer_animation_and_reward(failures: Array[String]) -> void:
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
		or reward_counts[0] < BelieverActor.NORMAL_PRAY_COIN_MIN
		or reward_counts[0] > BelieverActor.NORMAL_PRAY_COIN_MAX
	):
		failures.append("a completed ordinary prayer must emit one multi-D-coin reward")
	believer.free()

	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.call("_on_believer_scared_away", null, Vector2(300.0, 200.0))
	if not (main.get("_coin_drops") as Array).is_empty():
		failures.append("a fleeing believer must leave no coins")
	main.call("_on_believer_prayed", null, Vector2(300.0, 200.0), 6)
	var drops := main.get("_coin_drops") as Array
	if drops.size() != 6:
		failures.append("a prayer reward must create every promised expensive coin")
	else:
		for drop in drops:
			if String(drop.get("coin_type")) != "D":
				failures.append("prayer rewards must use the expensive D coin")
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
	main.call("_finish_pilgrimage", false)
	if bool(main.get("_pilgrimage_active")) or float(main.get("_next_pilgrimage_at")) <= 0.0:
		failures.append("finishing a pilgrimage must restore normal play and schedule a later event")
	main.free()
