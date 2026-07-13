extends RefCounted

const PetProgression = preload("res://scripts/domain/pet_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_close(failures, "zero pets produce no faith", PetProgression.faith_per_second({"base_fps": 2.0}, 0), 0.0)
	_check_close(failures, "faith applies count and power growth", PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1.1}, 2), 4.84)
	_check_close(failures, "faith uses the separate upgrade level", PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1.1}, 2000, 2), 4840.0)
	_check_equal(failures, "faith production is finite for hostile data", is_finite(PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1000.0}, 20_000, 100_000)), true)
	_check_equal(failures, "upgrade cost applies growth", PetProgression.upgrade_cost({"upgrade_cost_base": 10, "upgrade_cost_growth": 1.2}, {"count": 2}), 14)
	_check_equal(failures, "upgrade cost remains positive", PetProgression.upgrade_cost({"upgrade_cost_base": 1, "upgrade_cost_growth": 0.0}, {"count": 3}), 1)
	_check_equal(failures, "legacy saves derive progression from count", PetProgression.progression_level({"count": 42}), 42)
	_check_equal(failures, "explicit progression level wins", PetProgression.progression_level({"count": 2000, "upgrade_level": 123}), 123)
	_check_equal(failures, "progression level remains positive", PetProgression.progression_level({"upgrade_level": -4}), 1)
	_check_population_gain(failures)
	_check_large_population_costs(failures)
	_check_evolution_rules(failures)
	return failures


static func _check_population_gain(failures: Array[String]) -> void:
	_check_equal(failures, "population grows singly before 100", PetProgression.population_gain(99), 1)
	_check_equal(failures, "population grows by ten at 100", PetProgression.population_gain(100), 10)
	_check_equal(failures, "population stops exactly at 1000", PetProgression.population_gain(999), 1)
	_check_equal(failures, "population grows by hundred at 1000", PetProgression.population_gain(1000), 100)
	_check_equal(failures, "population stops exactly at 10000", PetProgression.population_gain(9999), 1)
	_check_equal(failures, "population grows by thousand at 10000", PetProgression.population_gain(10_000), 1000)


static func _check_large_population_costs(failures: Array[String]) -> void:
	var pet_data := {"upgrade_cost_base": 300, "upgrade_cost_growth": 1.18}
	var cost_at_100 := PetProgression.upgrade_cost(pet_data, {"count": 100, "upgrade_level": 100})
	var cost_at_20k := PetProgression.upgrade_cost(pet_data, {"count": 20_000, "upgrade_level": 290})
	if cost_at_20k <= cost_at_100:
		failures.append("large-population upgrade cost must remain monotonic")
	if cost_at_20k <= 0 or cost_at_20k > PetProgression.MAX_UPGRADE_COST:
		failures.append("large-population upgrade cost must fit the safe integer range")
	_check_equal(
		failures,
		"overflowing upgrade costs are capped",
		PetProgression.upgrade_cost({"upgrade_cost_base": 1.0e200, "upgrade_cost_growth": 1.0e200}, {"count": 20_000, "upgrade_level": 20_000}),
		PetProgression.MAX_UPGRADE_COST
	)


static func _check_evolution_rules(failures: Array[String]) -> void:
	var pet_data := {
		"evolution_thresholds": [200, 2000],
		"evolution_multipliers": [1.0, 1.6, 2.55]
	}
	_check_equal(failures, "missing evolution stage starts at zero", PetProgression.evolution_stage({}), 0)
	_check_equal(failures, "evolution stage is capped at two", PetProgression.evolution_stage({"evolution_stage": 9}), 2)
	_check_equal(failures, "first evolution exposes its threshold", PetProgression.next_evolution_threshold(pet_data, {"evolution_stage": 0}), 200)
	_check_equal(failures, "second evolution exposes its threshold", PetProgression.next_evolution_threshold(pet_data, {"evolution_stage": 1}), 2000)
	_check_equal(failures, "max evolution has no next threshold", PetProgression.next_evolution_threshold(pet_data, {"evolution_stage": 2}), 0)
	_check_equal(failures, "one below threshold cannot evolve", PetProgression.can_evolve(pet_data, {"count": 199, "evolution_stage": 0}), false)
	_check_equal(failures, "exact threshold can evolve", PetProgression.can_evolve(pet_data, {"count": 200, "evolution_stage": 0}), true)
	_check_equal(failures, "second stage still needs manual first evolution", PetProgression.can_evolve(pet_data, {"count": 2000, "evolution_stage": 0}), true)
	_check_equal(failures, "max stage cannot evolve again", PetProgression.can_evolve(pet_data, {"count": 20_000, "evolution_stage": 2}), false)
	_check_close(failures, "base evolution multiplier", PetProgression.evolution_multiplier(pet_data, {"evolution_stage": 0}), 1.0)
	_check_close(failures, "first evolution multiplier", PetProgression.evolution_multiplier(pet_data, {"evolution_stage": 1}), 1.6)
	_check_close(failures, "second evolution multiplier", PetProgression.evolution_multiplier(pet_data, {"evolution_stage": 2}), 2.55)
	_check_close(failures, "malformed multiplier falls back safely", PetProgression.evolution_multiplier({"evolution_multipliers": [1.0, -2.0]}, {"evolution_stage": 1}), 1.0)


static func _check_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


static func _check_close(failures: Array[String], label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
