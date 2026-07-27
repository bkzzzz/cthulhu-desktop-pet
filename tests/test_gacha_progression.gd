extends RefCounted

const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const GachaWindow = preload("res://scripts/gacha_window.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_draw_costs(failures)
	_check_pet_pool(failures)
	_check_progression_gates(failures)
	_check_new_and_duplicate_results(failures)
	_check_new_pet_pity(failures)
	_check_static_machine_and_eggs(failures)
	return failures


static func _check_draw_costs(failures: Array[String]) -> void:
	var checkpoints := {
		0: 10,
		1: 12,
		5: 68,
		10: 358,
		20: 4050,
		40: 16050
	}
	for draw_count_value in checkpoints:
		var draw_count := int(draw_count_value)
		_check_equal(
			failures,
			"opening-tapered draw price at count %d" % draw_count,
			GachaProgression.draw_cost(draw_count),
			int(checkpoints[draw_count])
		)

	_check_equal(
		failures,
		"negative draw count uses the first cost",
		GachaProgression.draw_cost(-4),
		GachaProgression.draw_cost(0)
	)
	_check_equal(
		failures,
		"ten opening draws use the exact discounted total",
		GachaProgression.draw_cost_total(0, 10),
		878.0
	)
	_check_equal(
		failures,
		"one thousand draws use the full batch instead of clamping to ten",
		GachaProgression.draw_cost_total(0, 1000),
		425_215_184.0
	)

	var previous_cost := GachaProgression.draw_cost(0)
	for draw_count in range(1, 400):
		var next_cost := GachaProgression.draw_cost(draw_count)
		if next_cost < previous_cost:
			failures.append(
				"draw costs must remain monotonic at draw %d: %d after %d"
				% [draw_count + 1, next_cost, previous_cost]
			)
		previous_cost = next_cost
	_check_equal(
		failures,
		"draw price has a bounded permanent cap",
		GachaProgression.draw_cost(1000000),
		GachaProgression.MAX_DRAW_COST
	)


static func _check_pet_pool(failures: Array[String]) -> void:
	var expected_ids := [
		"pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
		"pet8", "pet9", "pet10"
	]
	var actual_ids: Array[String] = []
	var total_weight := 0.0
	for entry_value in GachaProgression.PET_POOL:
		var entry: Dictionary = entry_value
		actual_ids.append(String(entry.get("pet_id", "")))
		total_weight += float(entry.get("weight", 0.0))
	_check_equal(failures, "gacha pool contains all ten pet tiers", actual_ids, expected_ids)
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



static func _check_progression_gates(failures: Array[String]) -> void:
	var previous_threshold := -1.0
	for entry_value in GachaProgression.PET_POOL:
		var entry := entry_value as Dictionary
		var threshold := float(entry.get("min_faith_rate", -1.0))
		if threshold < previous_threshold:
			failures.append("permanent faith-rate gates must rise by pet tier")
			return
		previous_threshold = threshold

	for highest_tier in range(1, 11):
		var owned_ids: Array[String] = []
		for owned_tier in range(1, highest_tier + 1):
			owned_ids.append("pet%d" % owned_tier)
		var unlocked_lookup := GachaProgression.make_unlocked_lookup(owned_ids)
		var next_tier := highest_tier + 1
		var next_threshold := (
			INF
			if next_tier > 10
			else float(GachaProgression.get_pool_entry("pet%d" % next_tier).get("min_faith_rate", INF))
		)
		var below_rate := maxf(0.0, next_threshold - 0.001) if is_finite(next_threshold) else 0.0
		var below_pool := GachaProgression.make_progression_pool(unlocked_lookup, below_rate)
		var expected_below_size := (
			mini(10, highest_tier + 1)
			if next_threshold <= 0.0
			else highest_tier
		)
		if below_pool.size() != expected_below_size:
			failures.append("Pet %d must stay out of the pool below its permanent faith gate" % next_tier)
			return
		var progression_pool := GachaProgression.make_progression_pool(unlocked_lookup, next_threshold)
		var expected_maximum_tier := mini(10, next_tier)
		if progression_pool.size() != expected_maximum_tier:
			failures.append("owning Pet %d at the next faith gate must expose only Pets 1-%d" % [highest_tier, expected_maximum_tier])
			return
		var locked_pool := GachaProgression.make_locked_pool(unlocked_lookup, next_threshold)
		if locked_pool.size() != (0 if highest_tier == 10 else 1):
			failures.append("the combined gate must expose exactly one next unowned tier")
			return
		for unit_roll in [0.0, 0.25, 0.5, 0.75, 0.999999]:
			var result := GachaProgression.roll_pet(unit_roll, owned_ids, 0, next_threshold)
			var result_tier := int(String(result.get("pet_id", "")).trim_prefix("pet"))
			if result_tier > expected_maximum_tier:
				failures.append("a roll must never skip beyond one tier above Pet %d" % highest_tier)
				return

	var sparse_pool := GachaProgression.make_progression_pool(
		GachaProgression.make_unlocked_lookup(["pet1", "pet7"]),
		1_000_000.0
	)
	if sparse_pool.size() != 8 or String((sparse_pool.back() as Dictionary).get("pet_id", "")) != "pet8":
		failures.append("legacy sparse rosters must retain owned pets and every eligible lower tier")

	var armed_pity := GachaProgression.NEW_PET_PITY_DRAWS - 1
	var owned_lookup := GachaProgression.make_unlocked_lookup(["pet1"])
	var initial_locked_pool := GachaProgression.make_locked_pool(owned_lookup, 1_000_000.0)
	var pet2_result := GachaProgression.roll_pet_with_context(
		0.0, owned_lookup, initial_locked_pool, armed_pity, 1_000_000.0
	)
	if String(pet2_result.get("pet_id", "")) != "pet2":
		failures.append("armed pity must unlock Pet 2 from the starter pool")
		return
	owned_lookup["pet2"] = true
	var frozen_batch_result := GachaProgression.roll_pet_with_context(
		0.0, owned_lookup, initial_locked_pool, armed_pity, 1_000_000.0
	)
	if bool(frozen_batch_result.get("is_new", true)):
		failures.append("one batch must freeze its starting tier ceiling after unlocking Pet 2")
	var large_batch_owned := GachaProgression.make_unlocked_lookup(["pet1"])
	var large_batch_candidates := GachaProgression.make_locked_pool(large_batch_owned, 1_000_000.0)
	var large_batch_pity := 0
	var large_batch_unlocks := 0
	for _draw_index in GachaProgression.MAX_BATCH_DRAWS:
		var large_result := GachaProgression.roll_pet_with_context(
			0.0,
			large_batch_owned,
			large_batch_candidates,
			large_batch_pity,
			1_000_000.0
		)
		if bool(large_result.get("is_new", false)):
			var large_pet_id := String(large_result.get("pet_id", ""))
			large_batch_owned[large_pet_id] = true
			large_batch_unlocks += 1
			for candidate_index in large_batch_candidates.size():
				if String((large_batch_candidates[candidate_index] as Dictionary).get("pet_id", "")) == large_pet_id:
					large_batch_candidates.remove_at(candidate_index)
					break
		large_batch_pity = GachaProgression.next_pity_count(large_batch_pity, large_result)
	if large_batch_unlocks != 1 or large_batch_owned.has("pet3"):
		failures.append("a 10,000-pull batch must never chain beyond its one starting tier")
	var next_request_result := GachaProgression.roll_pet(
		0.0, ["pet1", "pet2"], armed_pity, 1_000_000.0
	)
	if String(next_request_result.get("pet_id", "")) != "pet3":
		failures.append("a later request may unlock Pet 3 once ownership and faith both qualify")

	var pet3_threshold := float(GachaProgression.get_pool_entry("pet3").get("min_faith_rate", INF))
	var locked_pity_result := GachaProgression.roll_pet(
		0.999, ["pet1", "pet2"], armed_pity, pet3_threshold - 0.001
	)
	if bool(locked_pity_result.get("is_new", true)):
		failures.append("armed pity must remain a duplicate below the permanent faith gate")
	if GachaProgression.next_pity_count(armed_pity, locked_pity_result) != armed_pity:
		failures.append("gate-locked pity must remain armed for a future eligible draw")
	var stale_pool := GachaProgression.make_locked_pool(owned_lookup, pet3_threshold)
	var stale_result := GachaProgression.roll_pet_with_context(
		0.0, owned_lookup, stale_pool, armed_pity, pet3_threshold - 0.001
	)
	if bool(stale_result.get("is_new", true)):
		failures.append("a stale cached pool must be revalidated against the current permanent rate")


static func _check_new_and_duplicate_results(failures: Array[String]) -> void:
	var first_pet2 := GachaProgression.roll_pet(0.999, ["pet1"], 0)
	if not bool(first_pet2.get("is_new", false)):
		failures.append("drawing a locked pet must mark it as newly unlocked")
	if GachaProgression.duplicate_faith_reward(1000, first_pet2) != 0:
		failures.append("a newly unlocked pet must not also return duplicate faith")

	var duplicate_pet2 := GachaProgression.roll_pet(0.8, ["pet1", "pet2"], 0)
	if bool(duplicate_pet2.get("is_new", true)):
		failures.append("drawing an unlocked pet must be a duplicate result")
	if GachaProgression.duplicate_faith_reward(1000, duplicate_pet2) != 100:
		failures.append("a duplicate two-star pet must return its star-based faith reward")


static func _check_new_pet_pity(failures: Array[String]) -> void:
	var unlocked := [
		"pet1", "pet2", "pet3", "pet4", "pet6", "pet7",
		"pet8", "pet9", "pet10"
	]
	var pity_count := 0
	for draw_index in GachaProgression.NEW_PET_PITY_DRAWS - 1:
		var duplicate := GachaProgression.roll_pet(0.0, unlocked, pity_count, 1_000.0)
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
	var guaranteed := GachaProgression.roll_pet(0.0, unlocked, pity_count, 1_000.0)
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
	window.set_language("en")
	window.refresh_state(1000.0, 0, GachaProgression.draw_cost(0), ["pet1", "pet2"], 0, [], 0.0)
	var progress_label := window.get("_progress_label") as Label
	if (
		progress_label == null
		or progress_label.text != "Next Pet: Pet 3\nRequired Faith Growth: 8 / s"
	):
		failures.append("the gacha UI must show the next pet and its minimum Faith Growth")
	window.refresh_state(1000.0, 0, GachaProgression.draw_cost(0), ["pet1", "pet2"], 0, [], 20.0)
	if progress_label == null or not progress_label.text.contains("Required Faith Growth: 8 / s"):
		failures.append("meeting a gate must keep its minimum requirement visible until the pet is owned")
	window.refresh_state(1000.0, 0, GachaProgression.draw_cost(0), ["pet1", "pet2", "pet3"], 0, [], 20.0)
	if progress_label == null or progress_label.text != "Next Pet: Pet 4\nRequired Faith Growth: 80 / s":
		failures.append("the gacha requirement must advance automatically with pet ownership")
	window.refresh_state(1000.0, 0, GachaProgression.draw_cost(0), ["pet1", "pet2", "pet3", "pet4", "pet5"], 0, [], 20.0)
	if progress_label == null or progress_label.text != "Next Pet: Pet 6\nRequired Faith Growth: 6.5K / s":
		failures.append("large Faith Growth requirements must remain compact and currency-free")
	window.refresh_state(
		1000.0,
		0,
		GachaProgression.draw_cost(0),
		PetCatalog.ACTIVE_DESKTOP_PETS,
		0,
		[],
		1_000_000.0
	)
	if progress_label == null or progress_label.text != "All Pets Unlocked":
		failures.append("a complete roster must replace the next-pet requirement")
	window.set_language("zh")
	var background := window.get_node_or_null("GachaRoot/GachaBackground") as TextureRect
	if background == null or background.texture == null:
		failures.append("the supplied gacha UI must render as the window background")
	elif background.size != GachaWindow.GACHA_FRAME_SIZE:
		failures.append("the authored gacha frame must keep its original aspect below the detached draw controls")
	var amount_footer := window.get_node_or_null("GachaRoot/DrawAmountFooter") as PanelContainer
	if amount_footer == null:
		failures.append("gacha draw choices must live in a dedicated footer")
	elif (
		amount_footer.position.y < GachaWindow.GACHA_FRAME_SIZE.y
		or amount_footer.position.y + amount_footer.size.y > float(GachaWindow.WINDOW_SIZE.y)
	):
		failures.append("the gacha draw footer must sit fully below the illustrated machine frame")
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
	if amount_buttons.size() != 3 or not amount_buttons.has(10) or not amount_buttons.has(100) or not amount_buttons.has(-1):
		failures.append("gacha must expose only the focused 10, 100 and custom draw choices")
	else:
		window.call("_on_draw_amount_preset_pressed", 100)
		if int(window.call("_selected_draw_amount")) != 100:
			failures.append("the 100-draw preset must request one hundred rolls")
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
	var result := GachaProgression.roll_pet(0.999, ["pet1"], 0)
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
