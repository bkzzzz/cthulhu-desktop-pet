extends RefCounted

## Pure progression rules. This layer deliberately has no scene, window, or input
## dependencies so gameplay balancing can be tested without starting the UI.

const MAX_UPGRADE_COST := 8_000_000_000_000_000_000
const MAX_FAITH_PER_SECOND := 1.0e300
const MAX_LEVEL := 100_000

# The original curve is preserved through level 100. Later levels approach an
# effective exponent of 160 instead of growing without bound. This keeps the
# established opening balance while making high-level upgrades viable.
const FULL_GROWTH_LEVEL := 100.0
const SOFT_GROWTH_EXTRA_LEVELS := 60.0
const SOFT_GROWTH_SPAN := 300.0


static func progression_level(state: Dictionary) -> int:
	return clampi(int(state.get("upgrade_level", state.get("count", 1))), 1, MAX_LEVEL)


static func faith_per_second(pet_data: Dictionary, level: int) -> float:
	if level <= 0:
		return 0.0

	var base_fps := maxf(0.0, float(pet_data.get("base_fps", 0.05)))
	var power_growth := maxf(0.0, float(pet_data.get("power_growth", 1.035)))
	var safe_level := maxi(0, level)
	var power_multiplier := pow(power_growth, float(safe_level))
	var result := base_fps * float(safe_level) * power_multiplier
	if not is_finite(result):
		return MAX_FAITH_PER_SECOND
	return clampf(result, 0.0, MAX_FAITH_PER_SECOND)


static func upgrade_cost(pet_data: Dictionary, state: Dictionary) -> int:
	var base_cost := maxf(1.0, float(pet_data.get("upgrade_cost_base", 10)))
	var growth := maxf(0.0, float(pet_data.get("upgrade_cost_growth", 1.3)))
	var level := progression_level(state)
	var raw_cost := base_cost * pow(growth, _softened_growth_level(level))
	if not is_finite(raw_cost) or raw_cost >= float(MAX_UPGRADE_COST):
		return MAX_UPGRADE_COST
	return clampi(int(round(raw_cost)), 1, MAX_UPGRADE_COST)


static func _softened_growth_level(level: int) -> float:
	var safe_level := float(maxi(1, level))
	if safe_level <= FULL_GROWTH_LEVEL:
		return safe_level

	var excess := safe_level - FULL_GROWTH_LEVEL
	return FULL_GROWTH_LEVEL + SOFT_GROWTH_EXTRA_LEVELS * (
		1.0 - exp(-excess / SOFT_GROWTH_SPAN)
	)
