extends RefCounted

const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_draw_costs(failures)
	_check_weight_boundaries(failures)
	_check_twelve_draw_pity(failures)
	_check_additive_stacking(failures)
	return failures


static func _check_draw_costs(failures: Array[String]) -> void:
	var expected_opening_costs := [75, 120, 192, 307, 492, 786]
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

	var previous_cost := GachaProgression.draw_cost(0)
	for draw_count in range(1, 41):
		var next_cost := GachaProgression.draw_cost(draw_count)
		if next_cost <= previous_cost:
			failures.append(
				"draw costs must strictly increase at draw %d: %d <= %d"
				% [draw_count + 1, next_cost, previous_cost]
			)
		previous_cost = next_cost


static func _check_weight_boundaries(failures: Array[String]) -> void:
	_check_roll_id(failures, "normal roll starts in common", 0.0, 0, "whisper")
	_check_roll_id(failures, "common upper interior", 0.649999, 0, "whisper")
	_check_roll_id(failures, "uncommon lower boundary", 0.65, 0, "omen")
	_check_roll_id(failures, "uncommon upper interior", 0.899999, 0, "omen")
	_check_roll_id(failures, "rare lower boundary", 0.90, 0, "revelation")
	_check_roll_id(failures, "rare upper interior", 0.979999, 0, "revelation")
	_check_roll_id(failures, "mythic lower boundary", 0.98, 0, "outer_blessing")
	_check_roll_id(failures, "unit roll is safely clamped", 1.0, 0, "outer_blessing")

	_check_roll_id(failures, "pity pool starts with rare", 0.0, 11, "revelation")
	_check_roll_id(failures, "pity rare upper interior", 0.799999, 11, "revelation")
	_check_roll_id(failures, "pity mythic lower boundary", 0.80, 11, "outer_blessing")
	_check_roll_id(failures, "pity pool ends with mythic", 1.0, 11, "outer_blessing")

	var total_weight := 0.0
	for buff_value in GachaProgression.BUFFS:
		var buff: Dictionary = buff_value
		total_weight += float(buff.get("weight", 0.0))
	_check_close(failures, "normal rarity weights total 100", total_weight, 100.0, 0.0001)


static func _check_twelve_draw_pity(failures: Array[String]) -> void:
	var pity_count := 0
	for failed_draw in 11:
		var common := GachaProgression.roll(0.0, pity_count)
		if float(common.get("bonus", 0.0)) >= 0.40:
			failures.append("draw %d must still allow a low-rarity result" % (failed_draw + 1))
			return
		pity_count = GachaProgression.next_pity_count(pity_count, common)

	_check_equal(failures, "eleven misses arm the pity draw", pity_count, 11)
	var guaranteed := GachaProgression.roll(0.0, pity_count)
	if float(guaranteed.get("bonus", 0.0)) < 0.40:
		failures.append("the twelfth draw must be rare or better")
	_check_equal(
		failures,
		"rare-or-better result resets pity",
		GachaProgression.next_pity_count(pity_count, guaranteed),
		0
	)


static func _check_additive_stacking(failures: Array[String]) -> void:
	var total_bonus := 0.0
	total_bonus = GachaProgression.apply_buff(total_bonus, {"bonus": 0.10})
	total_bonus = GachaProgression.apply_buff(total_bonus, {"bonus": 0.20})
	total_bonus = GachaProgression.apply_buff(total_bonus, {"bonus": 0.40})
	_check_close(failures, "buffs stack additively", total_bonus, 0.70, 0.0001)
	_check_close(
		failures,
		"invalid negative state cannot reduce an earned buff",
		GachaProgression.apply_buff(-5.0, {"bonus": 0.20}),
		0.20,
		0.0001
	)
	_check_close(
		failures,
		"negative buff values are ignored",
		GachaProgression.apply_buff(0.30, {"bonus": -1.0}),
		0.30,
		0.0001
	)


static func _check_roll_id(
	failures: Array[String],
	label: String,
	unit_roll: float,
	pity_count: int,
	expected_id: String
) -> void:
	var result := GachaProgression.roll(unit_roll, pity_count)
	_check_equal(failures, label, String(result.get("id", "")), expected_id)


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
