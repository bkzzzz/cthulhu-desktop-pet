extends RefCounted

const PetProgression = preload("res://scripts/domain/pet_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_close(failures, "level zero produces no faith", PetProgression.faith_per_second({"base_fps": 2.0}, 0), 0.0)
	var level_two_opening_progress := (
		(PetProgression.OPENING_BOOST_END_LEVEL - 2.0)
		/ (PetProgression.OPENING_BOOST_END_LEVEL - 1.0)
	)
	var expected_level_two_rate := (
		4.84
		* PetProgression.CAMPAIGN_BASE_PRODUCTION_MULTIPLIER
		* (
			1.0
			+ PetProgression.OPENING_EXTRA_PRODUCTION_MULTIPLIER
			* level_two_opening_progress
			* level_two_opening_progress
		)
	)
	_check_close(
		failures,
		"faith applies growth and the opening production boost",
		PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1.1}, 2),
		expected_level_two_rate
	)
	_check_equal(failures, "faith production is finite for hostile data", is_finite(PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1000.0}, 100_000)), true)
	var money_at_one := PetProgression.money_drop_value_per_minute({"base_money_rate": 10.0}, 1)
	var money_at_two := PetProgression.money_drop_value_per_minute({"base_money_rate": 10.0}, 2)
	_check_close(failures, "level one uses the authored dropped-money rate", money_at_one, 10.0)
	if money_at_two <= money_at_one:
		failures.append("pet upgrades must increase collectible dropped-money production")
	if PetProgression.money_drop_value_per_minute({"base_money_rate": 1.0e300}, 100_000) > PetProgression.MAX_MONEY_VALUE_PER_MINUTE:
		failures.append("dropped-money production must remain within its collectible runtime cap")
	_check_equal(failures, "upgrade cost applies growth", PetProgression.upgrade_cost({"upgrade_cost_base": 10, "upgrade_cost_growth": 1.2}, {"upgrade_level": 2}), 14)
	_check_equal(failures, "upgrade cost remains positive", PetProgression.upgrade_cost({"upgrade_cost_base": 1, "upgrade_cost_growth": 0.0}, {"upgrade_level": 3}), 1)
	_check_equal(failures, "legacy saves derive progression from count", PetProgression.progression_level({"count": 42}), 42)
	_check_equal(failures, "explicit progression level wins", PetProgression.progression_level({"count": 2000, "upgrade_level": 123}), 123)
	_check_equal(failures, "progression level remains positive", PetProgression.progression_level({"upgrade_level": -4}), 1)
	_check_equal(failures, "progression level is capped", PetProgression.progression_level({"upgrade_level": PetProgression.MAX_LEVEL + 1}), PetProgression.MAX_LEVEL)
	_check_upgrade_cost_ignores_legacy_population(failures)
	_check_opening_production_curve(failures)
	_check_large_level_costs(failures)
	return failures


static func _check_upgrade_cost_ignores_legacy_population(failures: Array[String]) -> void:
	var pet_data := {"upgrade_cost_base": 10, "upgrade_cost_growth": 1.18}
	_check_equal(
		failures,
		"legacy population does not change a level-based upgrade cost",
		PetProgression.upgrade_cost(pet_data, {"count": 20_000, "upgrade_level": 100}),
		PetProgression.upgrade_cost(pet_data, {"upgrade_level": 100})
	)


static func _check_opening_production_curve(failures: Array[String]) -> void:
	var pet_data := {
		"base_fps": 0.0025,
		"power_growth": 1.035,
		"upgrade_cost_base": 1,
		"upgrade_cost_growth": 1.18
	}
	var previous_rate := 0.0
	for level in range(1, 21):
		var rate := PetProgression.faith_per_second(pet_data, level)
		if rate <= previous_rate:
			failures.append("opening production must increase at every level through Lv.%d" % level)
		previous_rate = rate

	var first_upgrade_seconds := (
		float(PetProgression.upgrade_cost(pet_data, {"upgrade_level": 1}))
		/ maxf(PetProgression.faith_per_second(pet_data, 1), 0.0000001)
	)
	if first_upgrade_seconds > 10.0:
		failures.append(
			"opening passive progress must fund the first upgrade within 10 seconds, got %.1f"
			% first_upgrade_seconds
		)


static func _check_large_level_costs(failures: Array[String]) -> void:
	var pet_data := {"upgrade_cost_base": 300, "upgrade_cost_growth": 1.18}
	var cost_at_100 := PetProgression.upgrade_cost(pet_data, {"upgrade_level": 100})
	var cost_at_290 := PetProgression.upgrade_cost(pet_data, {"upgrade_level": 290})
	if cost_at_290 <= cost_at_100:
		failures.append("large-level upgrade cost must remain monotonic")
	if cost_at_290 <= 0 or cost_at_290 > PetProgression.MAX_UPGRADE_COST:
		failures.append("large-level upgrade cost must fit the safe integer range")
	_check_equal(
		failures,
		"overflowing upgrade costs are capped",
		PetProgression.upgrade_cost({"upgrade_cost_base": 1.0e200, "upgrade_cost_growth": 1.0e200}, {"upgrade_level": 20_000}),
		PetProgression.MAX_UPGRADE_COST
	)


static func _check_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


static func _check_close(failures: Array[String], label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
