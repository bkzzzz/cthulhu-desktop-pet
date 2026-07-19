extends RefCounted

## Shared long-term economy rules. Runtime systems use the same potential income
## model so shop prices, battle rewards, and campaign completion cannot drift
## away from pet progression again.

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")

const CAMPAIGN_LEVEL_TARGET := 100
const BASELINE_COIN_RATE_PER_MINUTE := 10.0
# Active play (battles, taps, and sustainable food use together) is budgeted to
# progress about 1.7x as fast as passive play. Runtime rewards can use this same
# target without duplicating a second campaign estimate.
const EXPECTED_ACTIVE_FAITH_MULTIPLIER := 1.70

# A one-minute food is priced by the extra production it grants. At the
# strongest campaign pet's roster share, 1.10 minutes of total roster coin
# income per extra multiplier keeps sustainable feeding near a 25% account-wide
# gain. The authored catalog price remains the opening floor.
const OFFERING_PRICE_MINUTES_PER_BONUS := 1.10


static func potential_coin_rate_per_minute(
	unlocked_pet_ids: Array,
	pet_states: Dictionary
) -> float:
	var total := 0.0
	for pet_id_value in unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		if not PetCatalog.DEFINITIONS.has(pet_id):
			continue
		var state_value: Variant = pet_states.get(pet_id, {})
		var state: Dictionary = state_value if state_value is Dictionary else {}
		var level := PetProgression.progression_level(state)
		var rate := PetProgression.money_drop_value_per_minute(
			PetCatalog.get_definition(pet_id),
			level
		)
		if (
			level >= CAMPAIGN_LEVEL_TARGET
			or bool(state.get("evolved", false))
		):
			rate *= PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER
		total += rate
	return maxf(0.0, total)


static func make_dynamic_shop_goods(
	goods: Array[Dictionary],
	potential_coin_rate: float
) -> Array[Dictionary]:
	var priced_goods: Array[Dictionary] = []
	for good_value in goods:
		var good := good_value.duplicate(true)
		var base_price := maxi(1, int(good.get("base_price", good.get("price", 1))))
		var multiplier := maxf(1.0, float(good.get("multiplier", 1.0)))
		good["base_price"] = base_price
		good["price"] = dynamic_offering_price(
			base_price,
			multiplier,
			potential_coin_rate
		)
		priced_goods.append(good)
	return priced_goods


static func dynamic_offering_price(
	base_price: int,
	multiplier: float,
	potential_coin_rate: float
) -> int:
	var scalable_rate := maxf(
		0.0,
		maxf(0.0, potential_coin_rate) - BASELINE_COIN_RATE_PER_MINUTE
	)
	var income_minutes := (
		maxf(0.0, multiplier - 1.0)
		* OFFERING_PRICE_MINUTES_PER_BONUS
	)
	var raw_price := float(maxi(1, base_price)) + scalable_rate * income_minutes
	return maxi(base_price, _round_friendly_price(raw_price))


static func average_level(pet_ids: Array, pet_states: Dictionary) -> float:
	if pet_ids.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for pet_id_value in pet_ids:
		var pet_id := String(pet_id_value)
		if not PetCatalog.DEFINITIONS.has(pet_id):
			continue
		var state_value: Variant = pet_states.get(pet_id, {})
		var state: Dictionary = state_value if state_value is Dictionary else {}
		total += float(PetProgression.progression_level(state))
		count += 1
	return total / float(maxi(1, count))


static func campaign_progress(unlocked_pet_ids: Array, pet_states: Dictionary) -> float:
	var target_count := PetCatalog.ACTIVE_DESKTOP_PETS.size()
	if target_count <= 0:
		return 0.0
	var level_progress := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		if not unlocked_pet_ids.has(pet_id):
			continue
		var state_value: Variant = pet_states.get(pet_id, {})
		var state: Dictionary = state_value if state_value is Dictionary else {}
		level_progress += clampf(
			float(PetProgression.progression_level(state)) / float(CAMPAIGN_LEVEL_TARGET),
			0.0,
			1.0
		)
	return level_progress / float(target_count)


static func is_campaign_complete(unlocked_pet_ids: Array, pet_states: Dictionary) -> bool:
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		if not unlocked_pet_ids.has(pet_id):
			return false
		var state_value: Variant = pet_states.get(pet_id, {})
		var state: Dictionary = state_value if state_value is Dictionary else {}
		if PetProgression.progression_level(state) < CAMPAIGN_LEVEL_TARGET:
			return false
	return true


static func next_upgrade_cost(
	unlocked_pet_ids: Array,
	pet_states: Dictionary,
	level_cap: int
) -> int:
	var cheapest := PetProgression.MAX_UPGRADE_COST
	var found := false
	for pet_id_value in unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		if not PetCatalog.DEFINITIONS.has(pet_id):
			continue
		var state_value: Variant = pet_states.get(pet_id, {})
		var state: Dictionary = state_value if state_value is Dictionary else {}
		if PetProgression.progression_level(state) >= level_cap:
			continue
		cheapest = mini(
			cheapest,
			PetProgression.upgrade_cost(PetCatalog.get_definition(pet_id), state)
		)
		found = true
	return cheapest if found else 0


static func _round_friendly_price(value: float) -> int:
	var safe_value := clampf(value, 1.0, 9_000_000_000_000_000_000.0)
	var step := 1.0
	if safe_value >= 100_000.0:
		step = 1000.0
	elif safe_value >= 10_000.0:
		step = 250.0
	elif safe_value >= 1000.0:
		step = 25.0
	elif safe_value >= 100.0:
		step = 5.0
	return int(round(safe_value / step) * step)
