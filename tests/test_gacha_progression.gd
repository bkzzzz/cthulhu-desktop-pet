extends RefCounted

const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const GachaWindow = preload("res://scripts/gacha_window.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_draw_costs(failures)
	_check_pet_pool(failures)
	_check_growth_gates(failures)
	_check_new_and_duplicate_results(failures)
	_check_new_pet_pity(failures)
	_check_static_machine_and_eggs(failures)
	return failures


static func _check_draw_costs(failures: Array[String]) -> void:
	for draw_count in 10:
		_check_equal(
			failures,
			"opening draw %d stays cheap" % (draw_count + 1),
			GachaProgression.draw_cost(draw_count),
			2
		)
	_check_equal(failures, "draw 11 adds only one coin", GachaProgression.draw_cost(10), 3)

	_check_equal(
		failures,
		"negative draw count uses the first cost",
		GachaProgression.draw_cost(-4),
		GachaProgression.draw_cost(0)
	)
	_check_equal(
		failures,
		"ten opening draws remain affordable with manual coins",
		GachaProgression.draw_cost_total(0, 10),
		20.0
	)
	_check_equal(
		failures,
		"one thousand draws use the full batch instead of clamping to ten",
		GachaProgression.draw_cost_total(0, 1000),
		18_290.0
	)

	var previous_cost := GachaProgression.draw_cost(0)
	for draw_count in range(1, 241):
		var next_cost := GachaProgression.draw_cost(draw_count)
		if next_cost < previous_cost or next_cost - previous_cost > 1:
			failures.append(
				"draw costs must rise slowly at draw %d: %d after %d"
				% [draw_count + 1, next_cost, previous_cost]
			)
		previous_cost = next_cost
	_check_equal(
		failures,
		"draw price has a small permanent cap",
		GachaProgression.draw_cost(1000000),
		GachaProgression.MAX_DRAW_COST
	)


static func _check_pet_pool(failures: Array[String]) -> void:
	var expected_ids := [
		"pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
		"pet8", "pet9", "pet10"
	]
	var actual_ids: Array[String] = []
	var total_weight := 0.0
	for entry_value in GachaProgression.PET_POOL:
		var entry: Dictionary = entry_value
		actual_ids.append(String(entry.get("pet_id", "")))
		total_weight += float(entry.get("weight", 0.0))
	_check_equal(failures, "gacha pool contains every non-starter pet", actual_ids, expected_ids)
	_check_equal(failures, "catalog gacha list matches the roll pool", PetCatalog.GACHA_PETS, expected_ids)
	_check_close(failures, "pet draw weights total 100", total_weight, 100.0, 0.0001)
	for entry_value in GachaProgression.PET_POOL:
		var entry := entry_value as Dictionary
		if entry.has("rarity") or entry.has("color") or entry.has("duplicate_refund_ratio"):
			failures.append("the gacha pool must use catalog stars instead of a duplicate rarity model")
			break
	var previous_weight := INF
	for entry_value in GachaProgression.PET_POOL:
		var entry := entry_value as Dictionary
		var weight := float(entry.get("weight", 0.0))
		if weight > previous_weight:
			failures.append("higher-stage pets must never become more likely than the preceding pet")
			break
		previous_weight = weight

	_check_roll_pet(failures, "first two-star boundary", 0.0, "pet2")
	_check_roll_pet(failures, "second two-star boundary", 0.38, "pet3")
	_check_roll_pet(failures, "first three-star boundary", 0.65, "pet4")
	_check_roll_pet(failures, "first four-star boundary", 0.80, "pet5")
	_check_roll_pet(failures, "first five-star boundary", 0.88, "pet6")
	_check_roll_pet(failures, "pet7 boundary", 0.93, "pet7")
	_check_roll_pet(failures, "pet8 boundary", 0.96, "pet8")
	_check_roll_pet(failures, "pet9 boundary", 0.98, "pet9")
	_check_roll_pet(failures, "pet10 boundary", 0.9925, "pet10")
	_check_roll_pet(failures, "unit roll is safely clamped", 1.0, "pet10")


static func _check_growth_gates(failures: Array[String]) -> void:
	var previous_threshold := -1.0
	for entry_value in GachaProgression.PET_POOL:
		var entry := entry_value as Dictionary
		var pet_id := String(entry.get("pet_id", ""))
		var threshold := float(entry.get("min_faith_rate", -1.0))
		if threshold < previous_threshold:
			failures.append("gacha production thresholds must rise with pet combat tier")
			return
		previous_threshold = threshold
		var eligible_ids: Array[String] = []
		for eligible_value in GachaProgression.make_eligible_pool(threshold):
			eligible_ids.append(String((eligible_value as Dictionary).get("pet_id", "")))
		if not eligible_ids.has(pet_id):
			failures.append("%s must enter the pool exactly at its production threshold" % pet_id)
			return
		if threshold > 0.0:
			for locked_value in GachaProgression.make_eligible_pool(threshold - 0.001):
				if String((locked_value as Dictionary).get("pet_id", "")) == pet_id:
					failures.append("%s must remain unavailable below its production threshold" % pet_id)
					return

	var armed_pity := GachaProgression.NEW_PET_PITY_DRAWS - 1
	var low_growth_result := GachaProgression.roll_pet(
		0.999,
		["pet1", "pet2"],
		armed_pity,
		0.0
	)
	if bool(low_growth_result.get("is_new", true)) or String(low_growth_result.get("pet_id", "")) != "pet2":
		failures.append("pity must not bypass the production gate for a higher-stage pet")
	var stale_locked_pool := GachaProgression.make_locked_pool(
		GachaProgression.make_unlocked_lookup(["pet1", "pet2"]),
		1_000_000.0
	)
	var stale_pool_result := GachaProgression.roll_pet_with_context(
		0.999,
		GachaProgression.make_unlocked_lookup(["pet1", "pet2"]),
		stale_locked_pool,
		armed_pity,
		0.0
	)
	if bool(stale_pool_result.get("is_new", true)) or String(stale_pool_result.get("pet_id", "")) != "pet2":
		failures.append("a stale cached pity pool must still be filtered by the current production gate")
	var pet3_threshold := float(GachaProgression.get_pool_entry("pet3").get("min_faith_rate", INF))
	var newly_eligible_result := GachaProgression.roll_pet(
		0.0,
		["pet1", "pet2"],
		armed_pity,
		pet3_threshold
	)
	if String(newly_eligible_result.get("pet_id", "")) != "pet3" or not bool(newly_eligible_result.get("is_new", false)):
		failures.append("armed pity must wait and then unlock a pet after its production stage opens")


static func _check_new_and_duplicate_results(failures: Array[String]) -> void:
	var first_pet2 := GachaProgression.roll_pet(0.0, ["pet1"], 0)
	if not bool(first_pet2.get("is_new", false)):
		failures.append("drawing a locked pet must mark it as newly unlocked")
	if GachaProgression.duplicate_faith_reward(1000, first_pet2) != 0:
		failures.append("a newly unlocked pet must not also return duplicate faith")

	var duplicate_pet2 := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	if bool(duplicate_pet2.get("is_new", true)):
		failures.append("drawing an unlocked pet must be a duplicate result")
	if GachaProgression.duplicate_faith_reward(1000, duplicate_pet2) != 650:
		failures.append("a duplicate two-star pet must return its star-based faith reward")


static func _check_new_pet_pity(failures: Array[String]) -> void:
	var unlocked := [
		"pet1", "pet2", "pet3", "pet4", "pet6", "pet7",
		"pet8", "pet9", "pet10"
	]
	var pity_count := 0
	for draw_index in GachaProgression.NEW_PET_PITY_DRAWS - 1:
		var duplicate := GachaProgression.roll_pet(0.0, unlocked, pity_count, 12.0)
		if bool(duplicate.get("is_new", true)):
			failures.append("pre-pity draws must still be allowed to repeat an owned pet")
			return
		pity_count = GachaProgression.next_pity_count(pity_count, duplicate)
	_check_equal(
		failures,
		"four consecutive duplicates arm the fifth-draw guarantee",
		pity_count,
		GachaProgression.NEW_PET_PITY_DRAWS - 1
	)
	var guaranteed := GachaProgression.roll_pet(0.0, unlocked, pity_count, 12.0)
	_check_equal(failures, "pity chooses the only locked pet", guaranteed.get("pet_id", ""), "pet5")
	if not bool(guaranteed.get("is_new", false)):
		failures.append("the fifth draw after repeated duplicates must unlock a new pet")
	_check_equal(
		failures,
		"a new pet resets pity",
		GachaProgression.next_pity_count(pity_count, guaranteed),
		0
	)

	var all_unlocked := PetCatalog.ACTIVE_DESKTOP_PETS.duplicate()
	var all_owned_result := GachaProgression.roll_pet(0.0, all_unlocked, pity_count)
	if bool(all_owned_result.get("is_new", true)):
		failures.append("a complete collection must keep producing duplicate level rewards")


static func _check_static_machine_and_eggs(failures: Array[String]) -> void:
	if not FileAccess.file_exists(GachaWindow.GACHA_UI_TEXTURE):
		failures.append("the pet gacha must use the supplied gacha UI background")
	if not FileAccess.file_exists(GachaWindow.GACHA_MACHINE_TEXTURE):
		failures.append("the pet gacha must use the supplied static machine image")
	if not FileAccess.file_exists(GachaWindow.GACHA_EGG_TEXTURE):
		failures.append("the pet gacha must use the supplied egg image")
	var window := GachaWindow.new()
	window.setup()
	# This suite verifies the authored Chinese result copy. Default-English
	# behavior is covered by the localization integration suite.
	window.set_language("zh")
	var background := window.get_node_or_null("GachaRoot/GachaBackground") as TextureRect
	if background == null or background.texture == null:
		failures.append("the supplied gacha UI must render as the window background")
	var machine: TextureRect = window.get("_machine_view")
	if machine == null or machine.texture == null:
		failures.append("the gacha machine must remain a visible static UI layer")
	var egg_views: Array = window.get("_egg_views")
	if egg_views.size() != GachaWindow.EGG_COUNT:
		failures.append("the machine must contain a full, readable pile of eggs")
	for egg_value in egg_views:
		var egg := egg_value as TextureRect
		if egg == null or egg.texture == null:
			failures.append("every egg in the pile must use the supplied egg image")
			break
		if not GachaWindow.EGG_POSITION_BOUNDS.has_point(egg.position):
			failures.append("egg pile positions must remain inside the machine chamber")
			break
		if egg.z_index <= 0 or (machine != null and egg.z_index >= machine.z_index):
			failures.append("eggs must render above the UI background and below the machine face")
			break
	var amount_buttons: Dictionary = window.get("_draw_amount_buttons")
	if amount_buttons.size() != 5:
		failures.append("gacha must offer 1, 10, 100, 1000 and custom draw counts")
	else:
		window.call("_on_draw_amount_preset_pressed", 1000)
		if int(window.call("_selected_draw_amount")) != 1000:
			failures.append("the 1000-draw option must request all one thousand rolls")
		window.call("_on_draw_amount_preset_pressed", -1)
		var custom_input: LineEdit = window.get("_custom_draw_input")
		custom_input.text = "23abc7"
		window.call("_on_custom_draw_text_changed", custom_input.text)
		if not custom_input.editable or custom_input.focus_mode == Control.FOCUS_NONE:
			failures.append("the custom draw count must be a focusable editable text field")
		if custom_input.text != "237" or int(window.call("_selected_draw_amount")) != 237:
			failures.append("the custom draw option must accept directly typed numeric input")
	var min_home := Vector2(INF, INF)
	var max_home := Vector2(-INF, -INF)
	for home_value in GachaWindow.EGG_HOME_POSITIONS:
		var home := home_value as Vector2
		min_home = min_home.min(home)
		max_home = max_home.max(home)
	var home_span := max_home - min_home
	if home_span.x > 160.01 or home_span.y > 52.01:
		failures.append("the initial egg pile must stay tightly stacked inside the chamber")
	var before_shuffle: Array[Vector2] = []
	for egg_value in egg_views:
		before_shuffle.append((egg_value as TextureRect).position)
	window.call("_apply_egg_shuffle_step", 0)
	var moved_count := 0
	for egg_index in egg_views.size():
		var shuffled_egg := egg_views[egg_index] as TextureRect
		if shuffled_egg.position.distance_to(before_shuffle[egg_index]) >= 18.0:
			moved_count += 1
		if not GachaWindow.EGG_POSITION_BOUNDS.has_point(shuffled_egg.position):
			failures.append("shuffled eggs must remain inside the machine chamber")
			break
	if moved_count < GachaWindow.EGG_COUNT / 2:
		failures.append("a gacha beat must visibly exchange most eggs instead of barely nudging them")
	if GachaWindow.EGG_MOTION_STEP_SECONDS < 0.14:
		failures.append("the gacha shuffle should use a deliberately coarse frame cadence")

	window.set("_animation_playing", true)
	var result := GachaProgression.roll_pet(0.0, ["pet1"], 0)
	result["name"] = "测试宠物"
	window.show_result(result)
	var result_title: Label = window.get("_result_title")
	if result_title.text != "等待抽取":
		failures.append("a pet result must remain hidden while the eggs are moving")
	window.call("_finish_draw_animation")
	if result_title.text != "测试宠物":
		failures.append("the result popup must appear when the egg movement completes")
	var result_detail: RichTextLabel = window.get("_result_detail")
	if result_detail == null or not result_detail.text.contains("★★"):
		failures.append("gacha results must present catalog stars instead of rarity names")
	elif result_detail.text.contains("普通") or result_detail.text.contains("史诗") or result_detail.text.contains("传说"):
		failures.append("gacha results must not show generic rarity copy")

	var duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	duplicate["name"] = "测试宠物"
	duplicate["duplicate_faith"] = 30
	window.show_results([result, duplicate])
	var action_button: Button = window.get("_result_action_button")
	if action_button == null or not action_button.text.begins_with("跳过"):
		failures.append("multi-draw results must expose a skip-to-next action")
	else:
		window.call("_on_result_advance_pressed")
		if result_detail == null or not result_detail.text.contains("重复获得  +30 信仰"):
			failures.append("skip must advance to a direct duplicate faith result")
		elif result_detail.text.contains("重复转化") or result_detail.text.contains("点数"):
			failures.append("duplicate results must avoid redundant conversion copy")
	window.show_results([result, duplicate])
	window.call("_show_batch_summary")
	if not result_detail.text.contains("+30") or not result_detail.text.contains("新宠物"):
		failures.append("skip all must show only new pets and combined duplicate faith")

	var localized_result := GachaProgression.roll_pet(0.0, ["pet1"], 0)
	var localized_pet_id := String(localized_result.get("pet_id", ""))
	localized_result["name"] = PetCatalog.get_localized_name(localized_pet_id, "zh")
	localized_result["use_localized_name"] = true
	window.show_result(localized_result)
	window.call("_finish_draw_animation")
	window.set_language("en")
	if result_title.text != PetCatalog.get_localized_name(localized_pet_id, "en"):
		failures.append("an open gacha result must switch its authored pet name to English")
	window.set_language("zh")
	if result_title.text != PetCatalog.get_localized_name(localized_pet_id, "zh"):
		failures.append("an open gacha result must switch its authored pet name back to Chinese")
	window.free()


static func _check_roll_pet(
	failures: Array[String],
	label: String,
	unit_roll: float,
	expected_pet_id: String
) -> void:
	var result := GachaProgression.roll_pet(unit_roll, ["pet1"], 0, 1_000_000.0)
	_check_equal(failures, label, String(result.get("pet_id", "")), expected_pet_id)


static func _check_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


static func _check_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float,
	tolerance: float
) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])
