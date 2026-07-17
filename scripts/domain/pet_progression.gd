extends RefCounted

## Pure progression rules. This layer deliberately has no scene, window, or input
## dependencies so gameplay balancing can be tested without starting the UI.

const MAX_UPGRADE_COST := 8_000_000_000_000_000_000
const MAX_FAITH_PER_SECOND := 1.0e300
const MAX_MONEY_VALUE_PER_MINUTE := 2500.0
const MAX_LEVEL := 100_000
const CAMPAIGN_TARGET_HOURS := 800.0
const CAMPAIGN_PET_LEVEL_TARGET := 100

# Early levels stay deliberately restrained. From level 20 onward, each upgrade
# contributes increasingly more power until the campaign target, creating a
# visible slow-to-fast payoff without changing the established opening.
const MOMENTUM_START_LEVEL := 20.0
const MOMENTUM_TARGET_LEVEL := float(CAMPAIGN_PET_LEVEL_TARGET)
const MOMENTUM_EXTRA_POWER_LEVELS := 70.0
const POST_TARGET_EXTRA_POWER_LEVELS := 525.0
const POST_TARGET_MOMENTUM_SPAN := 300.0

# Upgrade prices retain their full exponential growth through level 100. Later
# price exponents soften toward 160 so the accelerating output remains playable.
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
	var power_multiplier := pow(power_growth, _accelerated_power_level(safe_level))
	var result := base_fps * float(safe_level) * power_multiplier
	if not is_finite(result):
		return MAX_FAITH_PER_SECOND
	return clampf(result, 0.0, MAX_FAITH_PER_SECOND)


static func money_drop_value_per_minute(pet_data: Dictionary, level: int) -> float:
	if level <= 0:
		return 0.0
	var rarity := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
	var base_rate := maxf(0.0, float(pet_data.get(
		"base_money_rate",
		4.0 + (float(rarity) * 3.0)
	)))
	var excess_levels := float(maxi(0, level - 1))
	var effective_levels := minf(excess_levels, 200.0)
	if excess_levels > 200.0:
		effective_levels += sqrt(excess_levels - 200.0) * 4.0
	var result := base_rate * pow(1.012, effective_levels)
	if not is_finite(result):
		return MAX_MONEY_VALUE_PER_MINUTE
	return clampf(result, 0.0, MAX_MONEY_VALUE_PER_MINUTE)


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


static func _accelerated_power_level(level: int) -> float:
	var safe_level := float(maxi(0, level))
	if safe_level <= MOMENTUM_START_LEVEL:
		return safe_level
	if safe_level <= MOMENTUM_TARGET_LEVEL:
		var progress := (safe_level - MOMENTUM_START_LEVEL) / (
			MOMENTUM_TARGET_LEVEL - MOMENTUM_START_LEVEL
		)
		return safe_level + MOMENTUM_EXTRA_POWER_LEVELS * progress * progress

	var excess := safe_level - MOMENTUM_TARGET_LEVEL
	return (
		safe_level
		+ MOMENTUM_EXTRA_POWER_LEVELS
		+ POST_TARGET_EXTRA_POWER_LEVELS * (
			1.0 - exp(-excess / POST_TARGET_MOMENTUM_SPAN)
		)
	)
