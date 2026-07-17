extends RefCounted

const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const GachaWindow = preload("res://scripts/gacha_window.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_draw_costs(failures)
	_check_pet_pool(failures)
	_check_new_and_duplicate_results(failures)
	_check_new_pet_pity(failures)
	_check_static_machine_and_eggs(failures)
	return failures


static func _check_draw_costs(failures: Array[String]) -> void:
	var expected_opening_costs := [5, 8, 13, 20, 33, 52]
	for index in expected_opening_costs.size():
		_check_equal(
			failures,
			"draw %d cost" % (index + 1),
			GachaProgression.draw_cost(index),
			expected_opening_costs[index]
		)

	_check_equal(
		failures,
		"negative draw count uses the first cost",
		GachaProgression.draw_cost(-4),
		GachaProgression.draw_cost(0)
	)
	_check_equal(
		failures,
		"ten draws show and charge their complete progressive cost",
		GachaProgression.draw_cost_total(0, 10),
		908.0
	)

	var previous_cost := GachaProgression.draw_cost(0)
	for draw_count in range(1, 41):
		var next_cost := GachaProgression.draw_cost(draw_count)
		if next_cost <= previous_cost:
			failures.append(
				"draw costs must strictly increase at draw %d: %d <= %d"
				% [draw_count + 1, next_cost, previous_cost]
			)
		previous_cost = next_cost


static func _check_pet_pool(failures: Array[String]) -> void:
	var expected_ids := ["pet2", "pet3", "pet4", "pet5", "pet6", "pet7"]
	var actual_ids: Array[String] = []
	var total_weight := 0.0
	for entry_value in GachaProgression.PET_POOL:
		var entry: Dictionary = entry_value
		actual_ids.append(String(entry.get("pet_id", "")))
		total_weight += float(entry.get("weight", 0.0))
	_check_equal(failures, "gacha pool contains every non-starter pet", actual_ids, expected_ids)
	_check_equal(failures, "catalog gacha list matches the roll pool", PetCatalog.GACHA_PETS, expected_ids)
	_check_close(failures, "pet rarity weights total 100", total_weight, 100.0, 0.0001)

	_check_roll_pet(failures, "first common boundary", 0.0, "pet2")
	_check_roll_pet(failures, "second common boundary", 0.32, "pet3")
	_check_roll_pet(failures, "rare boundary", 0.64, "pet4")
	_check_roll_pet(failures, "epic boundary", 0.82, "pet5")
	_check_roll_pet(failures, "first legendary boundary", 0.92, "pet6")
	_check_roll_pet(failures, "pet7 legendary boundary", 0.97, "pet7")
	_check_roll_pet(failures, "unit roll is safely clamped", 1.0, "pet7")


static func _check_new_and_duplicate_results(failures: Array[String]) -> void:
	var first_pet2 := GachaProgression.roll_pet(0.0, ["pet1"], 0)
	if not bool(first_pet2.get("is_new", false)):
		failures.append("drawing a locked pet must mark it as newly unlocked")
	if GachaProgression.duplicate_faith_reward(1000, first_pet2) != 0:
		failures.append("a newly unlocked pet must not also return duplicate faith")

	var duplicate_pet2 := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	if bool(duplicate_pet2.get("is_new", true)):
		failures.append("drawing an unlocked pet must be a duplicate result")
	if GachaProgression.duplicate_faith_reward(1000, duplicate_pet2) != 300:
		failures.append("a duplicate common pet must convert into its configured faith refund")


static func _check_new_pet_pity(failures: Array[String]) -> void:
	var unlocked := ["pet1", "pet2", "pet3", "pet4", "pet6", "pet7"]
	var pity_count := 0
	for draw_index in GachaProgression.NEW_PET_PITY_DRAWS - 1:
		var duplicate := GachaProgression.roll_pet(0.0, unlocked, pity_count)
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
	var guaranteed := GachaProgression.roll_pet(0.0, unlocked, pity_count)
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

	window.set("_animation_playing", true)
	var result := GachaProgression.roll_pet(0.0, ["pet1"], 0)
	result["name"] = "测试宠物"
	window.show_result(result)
	var result_title: Label = window.get("_result_title")
	if result_title.text != "等待抽取":
		failures.append("a pet result must remain hidden while the eggs are moving")
	window.call("_finish_draw_animation")
	if result_title.text != "新宠物":
		failures.append("the result popup must appear when the egg movement completes")

	var duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	duplicate["name"] = "测试宠物"
	duplicate["duplicate_faith"] = 30
	window.show_results([result, duplicate])
	var action_button: Button = window.get("_result_action_button")
	if action_button == null or not action_button.text.begins_with("SKIP"):
		failures.append("multi-draw results must expose a skip-to-next action")
	else:
		window.call("_on_result_advance_pressed")
		if result_title.text != "重复转化":
			failures.append("skip must advance to the next multi-draw result")
	window.free()


static func _check_roll_pet(
	failures: Array[String],
	label: String,
	unit_roll: float,
	expected_pet_id: String
) -> void:
	var result := GachaProgression.roll_pet(unit_roll, ["pet1"], 0)
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
