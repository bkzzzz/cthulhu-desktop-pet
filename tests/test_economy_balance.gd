extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")

const OPENING_SECONDS := 60.0
const CAMPAIGN_MIN_HOURS := 720.0
const CAMPAIGN_MAX_HOURS := 880.0
const MAX_SIMULATION_STEPS := 2000
const PITY_DRAW_NUMBER := 12
const RARE_BONUS_THRESHOLD := 0.40


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_opening_curve(failures)
	_check_campaign_curve(failures)
	return failures


static func _check_opening_curve(failures: Array[String]) -> void:
	var initial_rate := _raw_faith_rate(_make_starting_levels())
	if initial_rate <= 0.0 or initial_rate >= 1.0:
		failures.append(
			"initial faith rate must start between 0 and 1/s, got %.6f/s" % initial_rate
		)
	if initial_rate * OPENING_SECONDS >= 100.0:
		failures.append(
			"one passive opening minute must stay below 100 faith, got %.3f"
			% (initial_rate * OPENING_SECONDS)
		)

	var opening := _simulate_for_seconds(OPENING_SECONDS)
	var generated := float(opening.get("generated", INF))
	if generated >= 100.0:
		failures.append(
			"one optimized opening minute must stay below 100 faith, got %.3f" % generated
		)
	if int(opening.get("steps", MAX_SIMULATION_STEPS)) >= MAX_SIMULATION_STEPS:
		failures.append("opening economy simulation did not converge")


static func _check_campaign_curve(failures: Array[String]) -> void:
	var expected_draw_bonus := _expected_bonus_per_draw_with_pity()
	if expected_draw_bonus < 0.17 or expected_draw_bonus > 0.20:
		failures.append(
			"expected pity-adjusted draw bonus must remain near 18%%, got %.4f"
			% expected_draw_bonus
		)

	var campaign := _simulate_campaign(expected_draw_bonus)
	var elapsed_hours := float(campaign.get("elapsed_hours", INF))
	if elapsed_hours < CAMPAIGN_MIN_HOURS or elapsed_hours > CAMPAIGN_MAX_HOURS:
		failures.append(
			"expected campaign should finish near %.0f hours, got %.2f (allowed %.0f-%.0f)"
			% [
				GachaProgression.CAMPAIGN_TARGET_HOURS,
				elapsed_hours,
				CAMPAIGN_MIN_HOURS,
				CAMPAIGN_MAX_HOURS
			]
		)
	if not bool(campaign.get("completed", false)):
		failures.append("campaign simulation must bring every pet level to its target")
	if int(campaign.get("steps", MAX_SIMULATION_STEPS)) >= MAX_SIMULATION_STEPS:
		failures.append("campaign economy simulation did not converge")


static func _simulate_for_seconds(duration: float) -> Dictionary:
	var levels := _make_starting_levels()
	var faith := 0.0
	var generated := 0.0
	var elapsed := 0.0
	var draw_count := 0
	var total_bonus := 0.0
	var steps := 0

	while elapsed < duration and steps < MAX_SIMULATION_STEPS:
		steps += 1
		var raw_rate := _raw_faith_rate(levels)
		var multiplier := 1.0 + total_bonus
		var total_rate := raw_rate * multiplier
		var action := _best_value_action(levels, draw_count, raw_rate, multiplier, 0.18)
		if action.is_empty() or total_rate <= 0.0:
			break

		var cost := float(action.get("cost", INF))
		var wait_seconds := maxf(0.0, (cost - faith) / total_rate)
		var remaining := duration - elapsed
		if wait_seconds >= remaining:
			faith += total_rate * remaining
			generated += total_rate * remaining
			elapsed = duration
			break

		faith += total_rate * wait_seconds
		generated += total_rate * wait_seconds
		elapsed += wait_seconds
		faith = maxf(0.0, faith - cost)
		if String(action.get("kind", "")) == "draw":
			draw_count += 1
			total_bonus += 0.18
		else:
			var pet_id := String(action.get("pet_id", ""))
			levels[pet_id] = int(levels.get(pet_id, 1)) + 1

	return {"generated": generated, "steps": steps}


static func _simulate_campaign(expected_draw_bonus: float) -> Dictionary:
	var levels := _make_starting_levels()
	var faith := 0.0
	var elapsed_seconds := 0.0
	var draw_count := 0
	var steps := 0

	while not _campaign_complete(levels) and steps < MAX_SIMULATION_STEPS:
		steps += 1
		var raw_rate := _raw_faith_rate(levels)
		var multiplier := 1.0 + (expected_draw_bonus * float(draw_count))
		var total_rate := raw_rate * multiplier
		var action := _best_value_action(
			levels,
			draw_count,
			raw_rate,
			multiplier,
			expected_draw_bonus
		)
		if action.is_empty() or total_rate <= 0.0:
			break

		var cost := float(action.get("cost", INF))
		var wait_seconds := maxf(0.0, (cost - faith) / total_rate)
		faith = maxf(0.0, faith + (total_rate * wait_seconds) - cost)
		elapsed_seconds += wait_seconds

		if String(action.get("kind", "")) == "draw":
			draw_count += 1
		else:
			var pet_id := String(action.get("pet_id", ""))
			levels[pet_id] = int(levels.get(pet_id, 1)) + 1

	return {
		"completed": _campaign_complete(levels),
		"elapsed_hours": elapsed_seconds / 3600.0,
		"draw_count": draw_count,
		"levels": levels,
		"steps": steps
	}


static func _best_value_action(
	levels: Dictionary,
	draw_count: int,
	raw_rate: float,
	multiplier: float,
	expected_draw_bonus: float
) -> Dictionary:
	var best_action: Dictionary = {}
	var best_payback := INF

	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var level := int(levels.get(pet_id, 1))
		if level >= GachaProgression.CAMPAIGN_PET_LEVEL_TARGET:
			continue

		var pet_data := PetCatalog.get_definition(pet_id)
		var current_rate := PetProgression.faith_per_second(pet_data, level)
		var next_rate := PetProgression.faith_per_second(pet_data, level + 1)
		var rate_gain := (next_rate - current_rate) * multiplier
		var cost := PetProgression.upgrade_cost(pet_data, {"upgrade_level": level})
		var payback := float(cost) / maxf(rate_gain, 0.0000001)
		if payback < best_payback:
			best_payback = payback
			best_action = {"kind": "upgrade", "pet_id": pet_id, "cost": cost}

	var draw_cost := GachaProgression.draw_cost(draw_count)
	var draw_rate_gain := raw_rate * expected_draw_bonus
	var draw_payback := float(draw_cost) / maxf(draw_rate_gain, 0.0000001)
	if draw_payback < best_payback:
		best_action = {"kind": "draw", "cost": draw_cost}

	return best_action


static func _expected_bonus_per_draw_with_pity() -> float:
	var low_weight := 0.0
	var high_weight := 0.0
	var low_weighted_bonus := 0.0
	var high_weighted_bonus := 0.0

	for buff_value in GachaProgression.BUFFS:
		var buff: Dictionary = buff_value
		var weight := maxf(0.0, float(buff.get("weight", 0.0)))
		var bonus := maxf(0.0, float(buff.get("bonus", 0.0)))
		if bonus >= RARE_BONUS_THRESHOLD:
			high_weight += weight
			high_weighted_bonus += weight * bonus
		else:
			low_weight += weight
			low_weighted_bonus += weight * bonus

	var total_weight := low_weight + high_weight
	if low_weight <= 0.0 or high_weight <= 0.0 or total_weight <= 0.0:
		return 0.0

	var low_probability := low_weight / total_weight
	var expected_cycle_length := 0.0
	for draw_index in PITY_DRAW_NUMBER:
		expected_cycle_length += pow(low_probability, float(draw_index))

	var low_mean := low_weighted_bonus / low_weight
	var high_mean := high_weighted_bonus / high_weight
	return (
		((expected_cycle_length - 1.0) * low_mean) + high_mean
	) / expected_cycle_length


static func _make_starting_levels() -> Dictionary:
	var levels := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		levels[String(pet_id_value)] = 1
	return levels


static func _raw_faith_rate(levels: Dictionary) -> float:
	var total_rate := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		total_rate += PetProgression.faith_per_second(
			PetCatalog.get_definition(pet_id),
			int(levels.get(pet_id, 1))
		)
	return total_rate


static func _campaign_complete(levels: Dictionary) -> bool:
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		if int(levels.get(String(pet_id_value), 0)) < GachaProgression.CAMPAIGN_PET_LEVEL_TARGET:
			return false
	return true
