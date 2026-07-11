extends RefCounted

const PetProgression = preload("res://scripts/domain/pet_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_close(failures, "zero pets produce no faith", PetProgression.faith_per_second({"base_fps": 2.0}, 0), 0.0)
	_check_close(failures, "faith applies count and power growth", PetProgression.faith_per_second({"base_fps": 2.0, "power_growth": 1.1}, 2), 4.84)
	_check_equal(failures, "favor falls back to legacy trust", PetProgression.favor({"trust": 7}), 7)
	_check_equal(failures, "favor cannot be negative", PetProgression.favor({"favor": -3}), 0)
	_check_close(failures, "discount is capped", PetProgression.upgrade_discount({"favor": 999}, 0.004, 0.4), 0.4)
	_check_equal(failures, "upgrade cost applies growth", PetProgression.upgrade_cost({"upgrade_cost_base": 10, "upgrade_cost_growth": 1.2}, {"count": 2}, 0.004, 0.4), 14)
	_check_equal(failures, "upgrade cost applies favor discount", PetProgression.upgrade_cost({"upgrade_cost_base": 100, "upgrade_cost_growth": 1.0}, {"count": 1, "favor": 25}, 0.004, 0.4), 90)
	_check_equal(failures, "upgrade cost remains positive", PetProgression.upgrade_cost({"upgrade_cost_base": 1, "upgrade_cost_growth": 0.0}, {"count": 3, "favor": 999}, 1.0, 1.0), 1)
	return failures


static func _check_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])


static func _check_close(failures: Array[String], label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
