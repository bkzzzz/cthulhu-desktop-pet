extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")

const BASE_DRAW_COST := 50
const DRAW_COST_QUADRATIC_STEP := 10
const OPENING_DRAW_COST_MULTIPLIER := 0.20
const OPENING_DRAW_DISCOUNT_END_COUNT := 20.0
const OPENING_DRAW_DISCOUNT_POWER := 2.5
const MAX_DRAW_COST := 500_000
const MAX_DUPLICATE_FAITH_REWARD := 9_000_000_000_000_000_000
const NEW_PET_PITY_DRAWS := 5
const MAX_BATCH_DRAWS := 10_000
const DUPLICATE_REWARD_RATIOS := [0.0, 0.08, 0.10, 0.12, 0.15, 0.18]

const PET_POOL := [
	{
		"pet_id": "pet1",
		"weight": 33.333334,
		"min_faith_rate": 0.0
	},
	{
		"pet_id": "pet2",
		"weight": 25.333333,
		"min_faith_rate": 0.0
	},
	{
		"pet_id": "pet3",
		"weight": 18.0,
		"min_faith_rate": 8.0
	},
	{
		"pet_id": "pet4",
		"weight": 10.0,
		"min_faith_rate": 80.0
	},
	{
		"pet_id": "pet5",
		"weight": 5.333333,
		"min_faith_rate": 400.0
	},
	{
		"pet_id": "pet6",
		"weight": 3.333333,
		"min_faith_rate": 6_500.0
	},
	{
		"pet_id": "pet7",
		"weight": 2.0,
		"min_faith_rate": 26_000.0
	},
	{
		"pet_id": "pet8",
		"weight": 1.333333,
		"min_faith_rate": 85_000.0
	},
	{
		"pet_id": "pet9",
		"weight": 0.833333,
		"min_faith_rate": 260_000.0
	},
	{
		"pet_id": "pet10",
		"weight": 0.5,
		"min_faith_rate": 540_000.0
	}
]


static func draw_cost(draw_count: int) -> int:
	var safe_count := maxi(0, draw_count)
	var raw_cost := float(BASE_DRAW_COST) + (
		float(DRAW_COST_QUADRATIC_STEP) * pow(float(safe_count), 2.0)
	)
	if float(safe_count) < OPENING_DRAW_DISCOUNT_END_COUNT:
		var opening_progress := clampf(
			float(safe_count) / OPENING_DRAW_DISCOUNT_END_COUNT,
			0.0,
			1.0
		)
		var opening_multiplier := lerpf(
			OPENING_DRAW_COST_MULTIPLIER,
			1.0,
			pow(opening_progress, OPENING_DRAW_DISCOUNT_POWER)
		)
		raw_cost *= opening_multiplier
	if not is_finite(raw_cost) or raw_cost >= float(MAX_DRAW_COST):
		return MAX_DRAW_COST
	return mini(int(round(raw_cost)), MAX_DRAW_COST)


static func draw_cost_total(draw_count: int, draw_amount: int) -> float:
	var safe_count := maxi(0, draw_count)
	var safe_amount := clampi(draw_amount, 1, MAX_BATCH_DRAWS)
	var total := 0.0
	var remaining := safe_amount
	var cursor := safe_count
	while remaining > 0:
		var cost := draw_cost(cursor)
		var draws_at_cost := 1 if cost < MAX_DRAW_COST else remaining
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
	var safe_rate := (
		maxf(0.0, faith_growth_rate)
		if is_finite(faith_growth_rate)
		else 0.0
	)
	var eligible_pool: Array = []
	for entry_value in PET_POOL:
		var entry := entry_value as Dictionary
		if safe_rate + 0.000001 >= float(entry.get("min_faith_rate", 0.0)):
			eligible_pool.append(entry.duplicate(true))
	return eligible_pool


static func make_progression_pool(
	unlocked_lookup: Dictionary,
	faith_growth_rate := 0.0
) -> Array:
	var highest_owned_index := 0
	for pool_index in PET_POOL.size():
		var pet_id := String((PET_POOL[pool_index] as Dictionary).get("pet_id", ""))
		if unlocked_lookup.has(pet_id):
			highest_owned_index = maxi(highest_owned_index, pool_index)
	var maximum_pool_index := mini(PET_POOL.size() - 1, highest_owned_index + 1)
	var eligible_ids := {}
	for entry_value in make_eligible_pool(faith_growth_rate):
		var entry := entry_value as Dictionary
		eligible_ids[String(entry.get("pet_id", ""))] = true
	var progression_pool: Array = []
	for pool_index in PET_POOL.size():
		var entry := PET_POOL[pool_index] as Dictionary
		var pet_id := String(entry.get("pet_id", ""))
		if (
			unlocked_lookup.has(pet_id)
			or (pool_index <= maximum_pool_index and eligible_ids.has(pet_id))
		):
			progression_pool.append(entry.duplicate(true))
	return progression_pool


static func make_locked_pool(unlocked_lookup: Dictionary, faith_growth_rate := 0.0) -> Array:
	var locked_pool: Array = []
	for entry_value in make_progression_pool(unlocked_lookup, faith_growth_rate):
		var entry: Dictionary = entry_value
		if not unlocked_lookup.has(String(entry.get("pet_id", ""))):
			locked_pool.append(entry)
	return locked_pool


static func roll_pet_with_context(
	unit_roll: float,
	unlocked_lookup: Dictionary,
	locked_pool: Array,
	pity_count := 0,
	faith_growth_rate := 0.0
) -> Dictionary:
	# Revalidate the batch-start candidates against the permanent faith rate on
	# every draw. Ownership may change during a batch, but its tier ceiling may
	# not; this prevents large pull requests from laddering through the roster.
	var live_pool := make_progression_pool(unlocked_lookup, faith_growth_rate)
	var frozen_locked_ids := {}
	for entry_value in locked_pool:
		var entry := entry_value as Dictionary
		frozen_locked_ids[String(entry.get("pet_id", ""))] = true
	var pool: Array = []
	var eligible_locked_pool: Array = []
	for entry_value in live_pool:
		var entry := entry_value as Dictionary
		var pet_id := String(entry.get("pet_id", ""))
		if unlocked_lookup.has(pet_id):
			pool.append(entry)
		elif frozen_locked_ids.has(pet_id):
			pool.append(entry)
			eligible_locked_pool.append(entry)
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


static func get_next_progression_entry(unlocked_lookup: Dictionary) -> Dictionary:
	var highest_owned_index := 0
	for pool_index in PET_POOL.size():
		var entry := PET_POOL[pool_index] as Dictionary
		if unlocked_lookup.has(String(entry.get("pet_id", ""))):
			highest_owned_index = maxi(highest_owned_index, pool_index)
	var next_index := highest_owned_index + 1
	if next_index < 0 or next_index >= PET_POOL.size():
		return {}
	return (PET_POOL[next_index] as Dictionary).duplicate(true)


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
