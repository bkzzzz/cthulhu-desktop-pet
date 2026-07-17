extends RefCounted

const BASE_DRAW_COST := 5.0
const DRAW_COST_GROWTH := 1.60
const MAX_DRAW_COST := 8_000_000_000_000_000_000
const NEW_PET_PITY_DRAWS := 5

const PET_POOL := [
	{
		"pet_id": "pet2",
		"rarity": "普通",
		"weight": 32.0,
		"duplicate_refund_ratio": 0.30,
		"color": "#b8c4b2"
	},
	{
		"pet_id": "pet3",
		"rarity": "普通",
		"weight": 32.0,
		"duplicate_refund_ratio": 0.30,
		"color": "#a9c6a0"
	},
	{
		"pet_id": "pet4",
		"rarity": "稀有",
		"weight": 18.0,
		"duplicate_refund_ratio": 0.45,
		"color": "#78c7b8"
	},
	{
		"pet_id": "pet5",
		"rarity": "史诗",
		"weight": 10.0,
		"duplicate_refund_ratio": 0.60,
		"color": "#8caee8"
	},
	{
		"pet_id": "pet6",
		"rarity": "传说",
		"weight": 5.0,
		"duplicate_refund_ratio": 0.80,
		"color": "#e8bd62"
	},
	{
		"pet_id": "pet7",
		"rarity": "传说",
		"weight": 3.0,
		"duplicate_refund_ratio": 0.90,
		"color": "#f0cf86"
	}
]


static func draw_cost(draw_count: int) -> int:
	var safe_count := maxi(0, draw_count)
	var raw_cost := BASE_DRAW_COST * pow(DRAW_COST_GROWTH, float(safe_count))
	if not is_finite(raw_cost) or raw_cost >= float(MAX_DRAW_COST):
		return MAX_DRAW_COST
	return maxi(1, int(round(raw_cost)))


static func draw_cost_total(draw_count: int, draw_amount: int) -> float:
	var safe_count := maxi(0, draw_count)
	var safe_amount := clampi(draw_amount, 1, 10)
	var total := 0.0
	for draw_offset in safe_amount:
		total += float(draw_cost(safe_count + draw_offset))
	return total


static func roll_pet(unit_roll: float, unlocked_pet_ids: Array, pity_count := 0) -> Dictionary:
	var unlocked := {}
	for pet_id_value in unlocked_pet_ids:
		unlocked[String(pet_id_value)] = true

	var locked_pool: Array = []
	for entry_value in PET_POOL:
		var entry: Dictionary = entry_value
		if not unlocked.has(String(entry.get("pet_id", ""))):
			locked_pool.append(entry)

	var pool: Array = PET_POOL
	if not locked_pool.is_empty() and maxi(0, pity_count) >= NEW_PET_PITY_DRAWS - 1:
		pool = locked_pool
	var result := _roll_from_pool(pool, unit_roll)
	if result.is_empty():
		return {}
	result["is_new"] = not unlocked.has(String(result.get("pet_id", "")))
	result["duplicate_faith"] = 0
	return result


static func duplicate_faith_reward(draw_cost_value: int, result: Dictionary) -> int:
	var draw_cost := maxi(0, draw_cost_value)
	if draw_cost <= 0 or bool(result.get("is_new", false)):
		return 0
	var refund_ratio := clampf(float(result.get("duplicate_refund_ratio", 0.30)), 0.0, 0.95)
	return clampi(int(round(float(draw_cost) * refund_ratio)), 1, draw_cost)


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
