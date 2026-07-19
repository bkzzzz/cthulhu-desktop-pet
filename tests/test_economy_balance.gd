extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")

const OPENING_SECONDS := 60.0
const CAMPAIGN_MIN_HOURS := 600.0
const CAMPAIGN_MAX_HOURS := 1000.0
const MAX_SIMULATION_STEPS := 2000


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_starter_curve(failures)
	_check_unlock_curve(failures)
	_check_duplicate_reward(failures)
	_check_accelerating_output(failures)
	_check_campaign_curve(failures)
	_check_draw_price_curve(failures)
	return failures


static func _check_starter_curve(failures: Array[String]) -> void:
	var starter_rate := _pet_rate("pet1", 1)
	if starter_rate <= 0.0 or starter_rate >= 1.0:
		failures.append("pet1 must provide a small positive opening faith rate, got %.6f/s" % starter_rate)
	if GachaProgression.draw_cost(0) < 1 or GachaProgression.draw_cost(0) > 5:
		failures.append("the opening gacha price must suit a scarce click-earned currency")
	if PetCatalog.STARTER_UNLOCKED_PETS != ["pet1"]:
		failures.append("a fresh game must begin with only pet1 unlocked")


static func _check_unlock_curve(failures: Array[String]) -> void:
	var starter_rate := _pet_rate("pet1", 1)
	var complete_rate := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		complete_rate += _pet_rate(String(pet_id_value), 1)
	if complete_rate <= starter_rate:
		failures.append("unlocking additional pets must materially increase passive faith production")
	for pet_id_value in PetCatalog.GACHA_PETS:
		if _pet_rate(String(pet_id_value), 1) <= 0.0:
			failures.append("every gacha pet must begin producing faith immediately after unlock")


static func _check_duplicate_reward(failures: Array[String]) -> void:
	var draw_cost := 1000
	var two_star_duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	# The final pool entry is now pet10 (four stars); sample the pet6 boundary
	# explicitly so this remains a genuine five-star duplicate comparison.
	var five_star_duplicate := GachaProgression.roll_pet(0.73, PetCatalog.ACTIVE_DESKTOP_PETS, 0)
	var two_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, two_star_duplicate)
	var five_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, five_star_duplicate)
	if two_star_reward != 650:
		failures.append("a duplicate two-star pet must return a clear 65% faith reward")
	if five_star_reward <= draw_cost or five_star_reward <= two_star_reward:
		failures.append("a duplicate five-star pet must feel like a faith jackpot")


static func _check_accelerating_output(failures: Array[String]) -> void:
	var early_gain := _pet_rate("pet1", 21) - _pet_rate("pet1", 20)
	var middle_gain := _pet_rate("pet1", 61) - _pet_rate("pet1", 60)
	var late_gain := _pet_rate("pet1", 100) - _pet_rate("pet1", 99)
	var post_target_gain := _pet_rate("pet1", 101) - _pet_rate("pet1", 100)
	if not (early_gain < middle_gain and middle_gain < late_gain):
		failures.append("faith gained per upgrade must visibly accelerate from early to late game")
	if post_target_gain < late_gain:
		failures.append("the momentum curve must continue smoothly after the campaign target")


static func _check_campaign_curve(failures: Array[String]) -> void:
	var campaign := _simulate_campaign()
	var elapsed_hours := float(campaign.get("elapsed_hours", INF))
	if elapsed_hours < CAMPAIGN_MIN_HOURS or elapsed_hours > CAMPAIGN_MAX_HOURS:
		failures.append(
			"optimized campaign must finish in %.0f-%.0f hours, got %.2f (target %.0f)"
			% [
				CAMPAIGN_MIN_HOURS,
				CAMPAIGN_MAX_HOURS,
				elapsed_hours,
				PetProgression.CAMPAIGN_TARGET_HOURS
			]
		)
	if not bool(campaign.get("completed", false)):
		failures.append("campaign simulation must unlock every pet and reach the level target")
	if int(campaign.get("steps", MAX_SIMULATION_STEPS)) >= MAX_SIMULATION_STEPS:
		failures.append("campaign economy simulation did not converge")


static func _simulate_campaign() -> Dictionary:
	var levels := {"pet1": 1}
	var unlocked: Array[String] = ["pet1"]
	var faith := 0.0
	var elapsed_seconds := 0.0
	var draw_count := 0
	var steps := 0

	while not _campaign_complete(levels, unlocked) and steps < MAX_SIMULATION_STEPS:
		steps += 1
		var total_rate := _total_rate(levels, unlocked)
		var action := _best_value_action(levels, unlocked, draw_count)
		if action.is_empty() or total_rate <= 0.0:
			break

		if String(action.get("kind", "")) == "upgrade":
			var pet_id := String(action.get("pet_id", ""))
			var cost := float(action.get("cost", INF))
			var wait_seconds := maxf(0.0, (cost - faith) / total_rate)
			faith = maxf(0.0, faith + total_rate * wait_seconds - cost)
			elapsed_seconds += wait_seconds
			levels[pet_id] = int(levels.get(pet_id, 1)) + 1
			continue

		var draw_amount := 1 if draw_count == 0 else GachaProgression.NEW_PET_PITY_DRAWS
		for draw_offset in draw_amount:
			var cost := float(GachaProgression.draw_cost(draw_count))
			var wait_seconds := maxf(0.0, (cost - faith) / total_rate)
			faith = maxf(0.0, faith + total_rate * wait_seconds - cost)
			elapsed_seconds += wait_seconds
			if draw_offset < draw_amount - 1:
				faith += float(_two_star_duplicate_reward(int(cost)))
			draw_count += 1
		var new_pet_id := String(action.get("pet_id", ""))
		unlocked.append(new_pet_id)
		levels[new_pet_id] = 1

	return {
		"completed": _campaign_complete(levels, unlocked),
		"elapsed_hours": elapsed_seconds / 3600.0,
		"draw_count": draw_count,
		"levels": levels,
		"steps": steps
	}


static func _best_value_action(
	levels: Dictionary,
	unlocked: Array[String],
	draw_count: int
) -> Dictionary:
	var best_action: Dictionary = {}
	var best_payback := INF

	for pet_id in unlocked:
		var level := int(levels.get(pet_id, 1))
		if level >= PetProgression.CAMPAIGN_PET_LEVEL_TARGET:
			continue
		var pet_data := PetCatalog.get_definition(pet_id)
		var current_rate := PetProgression.faith_per_second(pet_data, level)
		var next_rate := PetProgression.faith_per_second(pet_data, level + 1)
		var rate_gain := next_rate - current_rate
		var cost := PetProgression.upgrade_cost(pet_data, {"upgrade_level": level})
		var payback := float(cost) / maxf(rate_gain, 0.0000001)
		if payback < best_payback:
			best_payback = payback
			best_action = {"kind": "upgrade", "pet_id": pet_id, "cost": cost}

	if unlocked.size() < PetCatalog.ACTIVE_DESKTOP_PETS.size():
		var next_pet_id := String(PetCatalog.ACTIVE_DESKTOP_PETS[unlocked.size()])
		var unlock_cost := _next_unlock_cycle_cost(draw_count)
		var unlock_rate := _pet_rate(next_pet_id, 1)
		var unlock_payback := unlock_cost / maxf(unlock_rate, 0.0000001)
		if unlock_payback < best_payback:
			best_action = {
				"kind": "unlock",
				"pet_id": next_pet_id,
				"cost": unlock_cost
			}

	return best_action


static func _next_unlock_cycle_cost(draw_count: int) -> float:
	var draw_amount := 1 if draw_count == 0 else GachaProgression.NEW_PET_PITY_DRAWS
	var total := 0.0
	for draw_offset in draw_amount:
		var cost := GachaProgression.draw_cost(draw_count + draw_offset)
		total += float(cost)
		if draw_offset < draw_amount - 1:
			total -= float(_two_star_duplicate_reward(cost))
	return maxf(0.0, total)


static func _two_star_duplicate_reward(draw_cost: int) -> int:
	return GachaProgression.duplicate_faith_reward(
		draw_cost,
		{"pet_id": "pet2", "is_new": false}
	)


static func _total_rate(levels: Dictionary, unlocked: Array[String]) -> float:
	var total := 0.0
	for pet_id in unlocked:
		total += _pet_rate(pet_id, int(levels.get(pet_id, 1)))
	return total


static func _campaign_complete(levels: Dictionary, unlocked: Array[String]) -> bool:
	if unlocked.size() < PetCatalog.ACTIVE_DESKTOP_PETS.size():
		return false
	for pet_id in unlocked:
		if int(levels.get(pet_id, 0)) < PetProgression.CAMPAIGN_PET_LEVEL_TARGET:
			return false
	return true


static func _check_draw_price_curve(failures: Array[String]) -> void:
	var guarantee_cycle_cost := 0
	for draw_index in GachaProgression.NEW_PET_PITY_DRAWS:
		guarantee_cycle_cost += GachaProgression.draw_cost(draw_index)
	if guarantee_cycle_cost <= GachaProgression.draw_cost(0):
		failures.append("the full new-pet guarantee cycle must cost more than a single draw")
	if guarantee_cycle_cost > 15:
		failures.append("the opening guarantee cycle must remain affordable with click-earned coins")
	var late_cost := GachaProgression.draw_cost(1000000)
	if late_cost <= 0 or late_cost != GachaProgression.MAX_DRAW_COST or late_cost > 20:
		failures.append("late-game draw costs must remain positive and capped at a small amount")


static func _pet_rate(pet_id: String, level: int) -> float:
	return PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)
