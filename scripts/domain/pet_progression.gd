extends RefCounted

const MAX_UPGRADE_COST := 8_000_000_000_000_000_000
const MAX_FAITH_PER_SECOND := 1.0e300
const MAX_MONEY_VALUE_PER_MINUTE := 2500.0
const MAX_LEVEL := 100_000
const CAMPAIGN_TARGET_HOURS := 100.0
const CAMPAIGN_PASSIVE_TARGET_HOURS := 125.0
const CAMPAIGN_PET_LEVEL_TARGET := 100
const MONEY_LEVEL_GROWTH := 1.010

const CAMPAIGN_BASE_PRODUCTION_MULTIPLIER := 3.25
const OPENING_EXTRA_PRODUCTION_MULTIPLIER := 12.0
const OPENING_BOOST_END_LEVEL := 50.0
const OPENING_MONEY_BOOST_END_LEVEL := 30.0
const OPENING_MONEY_EFFECTIVE_LEVEL_FRACTION := 0.80
const OPENING_UPGRADE_DISCOUNT := 0.35
const OPENING_UPGRADE_DISCOUNT_END_LEVEL := 20.0
const OPENING_UPGRADE_PET_IDS := ["pet1", "pet2", "pet3", "pet4", "pet5"]

const MOMENTUM_START_LEVEL := 12.0
const MOMENTUM_TARGET_LEVEL := float(CAMPAIGN_PET_LEVEL_TARGET)
const MOMENTUM_EXTRA_POWER_LEVELS := 111.0
const POST_TARGET_EXTRA_POWER_LEVELS := 300.0
const POST_TARGET_MOMENTUM_SPAN := 300.0
const ENDLESS_BASE_RATE_PAYBACK_SECONDS := 78_000.0

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
	var result := (
		base_fps
		* float(safe_level)
		* power_multiplier
		* CAMPAIGN_BASE_PRODUCTION_MULTIPLIER
		* _opening_production_multiplier(safe_level)
	)
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
	# Credit most of the remaining opening levels up front. Because each real
	# level replaces only part of that credit, coin output still rises on every
	# upgrade and joins the authored curve exactly at the taper endpoint.
	effective_levels += (
		maxf(0.0, OPENING_MONEY_BOOST_END_LEVEL - float(level))
		* OPENING_MONEY_EFFECTIVE_LEVEL_FRACTION
	)
	var result := base_rate * pow(MONEY_LEVEL_GROWTH, effective_levels)
	if not is_finite(result):
		return MAX_MONEY_VALUE_PER_MINUTE
	return clampf(result, 0.0, MAX_MONEY_VALUE_PER_MINUTE)


static func upgrade_cost(pet_data: Dictionary, state: Dictionary) -> int:
	var base_cost := maxf(1.0, float(pet_data.get("upgrade_cost_base", 10)))
	var growth := maxf(0.0, float(pet_data.get("upgrade_cost_growth", 1.3)))
	var level := progression_level(state)
	var raw_cost := (
		base_cost
		* pow(growth, _softened_growth_level(level))
		* _opening_upgrade_cost_multiplier(pet_data, level)
	)
	if level >= CAMPAIGN_PET_LEVEL_TARGET:
		raw_cost = maxf(
			raw_cost,
			faith_per_second(pet_data, level) * ENDLESS_BASE_RATE_PAYBACK_SECONDS
		)
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
		MOMENTUM_TARGET_LEVEL
		+ MOMENTUM_EXTRA_POWER_LEVELS
		+ POST_TARGET_EXTRA_POWER_LEVELS * (
			1.0 - exp(-excess / POST_TARGET_MOMENTUM_SPAN)
		)
	)


static func _opening_production_multiplier(level: int) -> float:
	var opening_progress := clampf(
		(OPENING_BOOST_END_LEVEL - float(maxi(1, level)))
		/ (OPENING_BOOST_END_LEVEL - 1.0),
		0.0,
		1.0
	)
	return 1.0 + (
		OPENING_EXTRA_PRODUCTION_MULTIPLIER
		* opening_progress
		* opening_progress
	)


static func _opening_upgrade_cost_multiplier(
	pet_data: Dictionary,
	level: int
) -> float:
	if not OPENING_UPGRADE_PET_IDS.has(String(pet_data.get("id", ""))):
		return 1.0
	var opening_progress := clampf(
		(OPENING_UPGRADE_DISCOUNT_END_LEVEL - float(maxi(1, level)))
		/ (OPENING_UPGRADE_DISCOUNT_END_LEVEL - 1.0),
		0.0,
		1.0
	)
	return 1.0 - (
		OPENING_UPGRADE_DISCOUNT
		* opening_progress
		* opening_progress
	)
