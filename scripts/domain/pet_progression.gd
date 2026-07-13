extends RefCounted

## Pure progression rules. This layer deliberately has no scene, window, or input
## dependencies so gameplay balancing can be tested without starting the UI.

const MAX_EVOLUTION_STAGE := 2
const MAX_UPGRADE_COST := 8_000_000_000_000_000_000
const MAX_FAITH_PER_SECOND := 1.0e300

# The original curve is preserved through level 100. Later levels approach an
# effective exponent of 160 instead of growing without bound. This keeps the
# established opening balance while making thousand-scale populations viable.
const FULL_GROWTH_LEVEL := 100.0
const SOFT_GROWTH_EXTRA_LEVELS := 60.0
const SOFT_GROWTH_SPAN := 300.0


static func progression_level(state: Dictionary) -> int:
	return maxi(1, int(state.get("upgrade_level", state.get("count", 1))))


static func population_gain(count: int) -> int:
	var safe_count := maxi(0, count)
	if safe_count < 100:
		return 1
	if safe_count < 1_000:
		return mini(10, 1_000 - safe_count)
	if safe_count < 10_000:
		return mini(100, 10_000 - safe_count)
	return 1_000


static func faith_per_second(pet_data: Dictionary, count: int, upgrade_level := -1) -> float:
	if count <= 0:
		return 0.0

	var base_fps := maxf(0.0, float(pet_data.get("base_fps", 0.05)))
	var power_growth := maxf(0.0, float(pet_data.get("power_growth", 1.035)))
	var safe_level := count if int(upgrade_level) < 0 else maxi(0, int(upgrade_level))
	var power_multiplier := pow(power_growth, float(safe_level))
	var result := base_fps * float(count) * power_multiplier
	if not is_finite(result):
		return MAX_FAITH_PER_SECOND
	return clampf(result, 0.0, MAX_FAITH_PER_SECOND)


static func upgrade_cost(pet_data: Dictionary, state: Dictionary) -> int:
	var count := maxi(1, int(state.get("count", 1)))
	var base_cost := maxf(1.0, float(pet_data.get("upgrade_cost_base", 10)))
	var growth := maxf(0.0, float(pet_data.get("upgrade_cost_growth", 1.3)))
	var level := progression_level(state)
	var batch_size := population_gain(count)
	var raw_cost := base_cost * float(batch_size) * pow(growth, _softened_growth_level(level))
	if not is_finite(raw_cost) or raw_cost >= float(MAX_UPGRADE_COST):
		return MAX_UPGRADE_COST
	return clampi(int(round(raw_cost)), 1, MAX_UPGRADE_COST)


static func evolution_stage(state: Dictionary) -> int:
	return clampi(int(state.get("evolution_stage", 0)), 0, MAX_EVOLUTION_STAGE)


static func next_evolution_threshold(pet_data: Dictionary, state: Dictionary) -> int:
	var stage := evolution_stage(state)
	if stage >= MAX_EVOLUTION_STAGE:
		return 0

	var thresholds_value: Variant = pet_data.get("evolution_thresholds", [])
	if not thresholds_value is Array:
		return 0
	var thresholds: Array = thresholds_value
	if stage >= thresholds.size():
		return 0
	return maxi(0, int(thresholds[stage]))


static func can_evolve(pet_data: Dictionary, state: Dictionary) -> bool:
	var threshold := next_evolution_threshold(pet_data, state)
	return threshold > 0 and int(state.get("count", 1)) >= threshold


static func evolution_multiplier(pet_data: Dictionary, state: Dictionary) -> float:
	var stage := evolution_stage(state)
	var multipliers_value: Variant = pet_data.get("evolution_multipliers", [])
	if not multipliers_value is Array:
		return 1.0
	var multipliers: Array = multipliers_value
	if stage >= multipliers.size():
		return 1.0

	var multiplier := float(multipliers[stage])
	if not is_finite(multiplier) or multiplier <= 0.0:
		return 1.0
	return multiplier


static func _softened_growth_level(level: int) -> float:
	var safe_level := float(maxi(1, level))
	if safe_level <= FULL_GROWTH_LEVEL:
		return safe_level

	var excess := safe_level - FULL_GROWTH_LEVEL
	return FULL_GROWTH_LEVEL + SOFT_GROWTH_EXTRA_LEVELS * (
		1.0 - exp(-excess / SOFT_GROWTH_SPAN)
	)
