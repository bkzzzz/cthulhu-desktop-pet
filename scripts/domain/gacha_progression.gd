extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const BASE_DRAW_COST := 2
const DRAW_COST_INCREASE_INTERVAL := 10
const MAX_DRAW_COST := 20
const MAX_DUPLICATE_FAITH_REWARD := 9_000_000_000_000_000_000
const NEW_PET_PITY_DRAWS := 5
const MAX_BATCH_DRAWS := 10_000
const DUPLICATE_REWARD_RATIOS := [0.0, 0.50, 0.65, 0.80, 1.00, 1.25]

const PET_POOL := [
	{
		"pet_id": "pet2",
		"weight": 38.0,
		"min_faith_rate": 0.0
	},
	{
		"pet_id": "pet3",
		"weight": 27.0,
		"min_faith_rate": 0.75
	},
	{
		"pet_id": "pet4",
		"weight": 15.0,
		"min_faith_rate": 3.0
	},
	{
		"pet_id": "pet5",
		"weight": 8.0,
		"min_faith_rate": 12.0
	},
	{
		"pet_id": "pet6",
		"weight": 5.0,
		"min_faith_rate": 45.0
	},
	{
		"pet_id": "pet7",
		"weight": 3.0,
		"min_faith_rate": 65.0
	},
	{
		"pet_id": "pet8",
		"weight": 2.0,
		"min_faith_rate": 95.0
	},
	{
		"pet_id": "pet9",
		"weight": 1.25,
		"min_faith_rate": 145.0
	},
	{
		"pet_id": "pet10",
		"weight": 0.75,
		"min_faith_rate": 225.0
	}
]


static func draw_cost(draw_count: int) -> int:
	var safe_count := maxi(0, draw_count)
	var slow_increase := int(floor(float(safe_count) / float(DRAW_COST_INCREASE_INTERVAL)))
	return mini(BASE_DRAW_COST + slow_increase, MAX_DRAW_COST)


static func draw_cost_total(draw_count: int, draw_amount: int) -> float:
	var safe_count := maxi(0, draw_count)
	var safe_amount := clampi(draw_amount, 1, MAX_BATCH_DRAWS)
	var total := 0.0
	var remaining := safe_amount
	var cursor := safe_count
	while remaining > 0:
		var cost := draw_cost(cursor)
		var draws_at_cost := remaining
		if cost < MAX_DRAW_COST:
			var next_increase := (int(floor(float(cursor) / DRAW_COST_INCREASE_INTERVAL)) + 1) * DRAW_COST_INCREASE_INTERVAL
			draws_at_cost = mini(remaining, maxi(1, next_increase - cursor))
		total += float(draws_at_cost * cost)
		remaining -= draws_at_cost
		cursor += draws_at_cost
	return total


static func roll_pet(
	unit_roll: float,
	unlocked_pet_ids: Array,
	pity_count := 0,
	faith_growth_rate := 0.0
) -> Dictionary:
	var unlocked := make_unlocked_lookup(unlocked_pet_ids)
	var locked_pool := make_locked_pool(unlocked, faith_growth_rate)
	return roll_pet_with_context(
		unit_roll,
		unlocked,
		locked_pool,
		pity_count,
		faith_growth_rate
	)


static func make_unlocked_lookup(unlocked_pet_ids: Array) -> Dictionary:
	var unlocked := {}
	for pet_id_value in unlocked_pet_ids:
		unlocked[String(pet_id_value)] = true
	return unlocked


static func make_eligible_pool(faith_growth_rate: float) -> Array:
	var safe_rate := maxf(0.0, faith_growth_rate) if is_finite(faith_growth_rate) else 0.0
	var eligible_pool: Array = []
	for entry_value in PET_POOL:
		var entry: Dictionary = entry_value
		if safe_rate + 0.000001 >= float(entry.get("min_faith_rate", 0.0)):
			eligible_pool.append(entry)
	return eligible_pool


static func make_locked_pool(unlocked_lookup: Dictionary, faith_growth_rate := 0.0) -> Array:
	var locked_pool: Array = []
	for entry_value in make_eligible_pool(faith_growth_rate):
		var entry: Dictionary = entry_value
		if not unlocked_lookup.has(String(entry.get("pet_id", ""))):
			locked_pool.append(entry)
	return locked_pool


# Batch callers retain the owned set and eligible locked-pet pool between rolls.
# Eligibility is still checked here so no direct caller, stale batch data, or
# pity roll can bypass the permanent-production gate.
static func roll_pet_with_context(
	unit_roll: float,
	unlocked_lookup: Dictionary,
	locked_pool: Array,
	pity_count := 0,
	faith_growth_rate := 0.0
) -> Dictionary:

	var pool := make_eligible_pool(faith_growth_rate)
	var eligible_ids := {}
	for eligible_value in pool:
		eligible_ids[String((eligible_value as Dictionary).get("pet_id", ""))] = true
	var eligible_locked_pool: Array = []
	for locked_value in locked_pool:
		var locked_entry := locked_value as Dictionary
		if eligible_ids.has(String(locked_entry.get("pet_id", ""))):
			eligible_locked_pool.append(locked_entry)
	if (
		not eligible_locked_pool.is_empty()
		and maxi(0, pity_count) >= NEW_PET_PITY_DRAWS - 1
	):
		pool = eligible_locked_pool
	var result := _roll_from_pool(pool, unit_roll)
	if result.is_empty():
		return {}
	result["is_new"] = not unlocked_lookup.has(String(result.get("pet_id", "")))
	result["duplicate_faith"] = 0
	return result


static func duplicate_faith_reward(draw_cost_value: int, result: Dictionary) -> int:
	var draw_cost := maxi(0, draw_cost_value)
	if draw_cost <= 0 or bool(result.get("is_new", false)):
		return 0
	var pet_data := PetCatalog.get_definition(String(result.get("pet_id", "")))
	var stars := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
	var reward_ratio := float(DUPLICATE_REWARD_RATIOS[stars])
	var raw_reward := float(draw_cost) * reward_ratio
	if not is_finite(raw_reward) or raw_reward >= float(MAX_DUPLICATE_FAITH_REWARD):
		return MAX_DUPLICATE_FAITH_REWARD
	return clampi(int(round(raw_reward)), 1, MAX_DUPLICATE_FAITH_REWARD)


static func next_pity_count(current_pity: int, result: Dictionary) -> int:
	if bool(result.get("is_new", false)):
		return 0
	return mini(NEW_PET_PITY_DRAWS - 1, maxi(0, current_pity) + 1)


static func get_pool_entry(pet_id: String) -> Dictionary:
	for entry_value in PET_POOL:
		var entry: Dictionary = entry_value
		if String(entry.get("pet_id", "")) == pet_id:
			return entry.duplicate(true)
	return {}


static func _roll_from_pool(pool: Array, unit_roll: float) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight := 0.0
	for entry_value in pool:
		var entry: Dictionary = entry_value
		total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		return {}

	var safe_roll := clampf(unit_roll, 0.0, 0.999999) if is_finite(unit_roll) else 0.0
	var target := safe_roll * total_weight
	var accumulated := 0.0
	for entry_value in pool:
		var entry: Dictionary = entry_value
		accumulated += maxf(0.0, float(entry.get("weight", 0.0)))
		if target < accumulated:
			return entry.duplicate(true)
	return (pool.back() as Dictionary).duplicate(true)
