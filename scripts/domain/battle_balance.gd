extends RefCounted

## Adaptive encounter and reward rules. Enemy pressure follows the deployed pet
## roster, while rewards follow the same faith and coin rates used elsewhere.

const EnemyActor = preload("res://scripts/enemy_actor.gd")

## Encounters should become denser gradually, not begin as a screen full of
## enemies. The authored schedules already contain two or three enemies per
## wave, which is the right opening pace. One reinforcement is added at each
## campaign milestone and endless mode keeps extending that curve.
const CAMPAIGN_LEVELS_PER_REINFORCEMENT := 30.0
const ENDLESS_LEVELS_PER_REINFORCEMENT := 45.0
const CAMPAIGN_MAX_ENEMIES_PER_WAVE := 6
const ENDLESS_MAX_ENEMIES_PER_WAVE := 10
const MAX_REWARD_VALUE := 9_000_000_000_000_000_000.0


static func build_wave_schedule(
	base_schedule: Array[Dictionary],
	average_pet_level: float,
	endless_mode: bool
) -> Array[Dictionary]:
	if base_schedule.is_empty():
		return []
	var safe_level := maxf(1.0, average_pet_level)
	var reinforcements := int(floor(
		(minf(100.0, safe_level) - 1.0) / CAMPAIGN_LEVELS_PER_REINFORCEMENT
	))
	if endless_mode and safe_level > 100.0:
		reinforcements += int(floor(
			(safe_level - 100.0) / ENDLESS_LEVELS_PER_REINFORCEMENT
		))
	var wave_cap := (
		ENDLESS_MAX_ENEMIES_PER_WAVE
		if endless_mode
		else CAMPAIGN_MAX_ENEMIES_PER_WAVE
	)
	var schedule: Array[Dictionary] = []
	for wave_value in base_schedule:
		var wave := wave_value.duplicate(true)
		var source_types: Array = wave.get("types", [])
		wave["types"] = _expand_types(source_types, reinforcements, wave_cap)
		schedule.append(wave)
	return schedule


static func strongest_wave_power(schedule: Array[Dictionary]) -> float:
	var strongest := 1.0
	for wave_value in schedule:
		var wave_power := 0.0
		for enemy_id_value in wave_value.get("types", []):
			wave_power += EnemyActor.get_combat_power(String(enemy_id_value))
		strongest = maxf(strongest, wave_power)
	return strongest


static func recommended_difficulty_scale(
	pet_roster_power: float,
	schedule: Array[Dictionary],
	average_pet_level: float,
	endless_mode: bool,
	debug_multiplier: float
) -> float:
	if debug_multiplier <= 0.0:
		return 0.0
	var wave_power := strongest_wave_power(schedule)
	var roster_ratio := maxf(0.03, pet_roster_power) / maxf(1.0, wave_power)
	var campaign_pressure := 1.10 + clampf(average_pet_level / 100.0, 0.0, 1.0) * 0.60
	var endless_pressure := 0.0
	if endless_mode and average_pet_level > 100.0:
		endless_pressure = log(1.0 + (average_pet_level - 100.0) / 40.0) / log(2.0) * 0.22
	var adaptive_scale := pow(roster_ratio, 0.78) * (campaign_pressure + endless_pressure)
	return clampf(
		maxf(0.0, debug_multiplier) * adaptive_scale,
		0.20,
		1_000_000_000_000_000.0
	)


static func reward_budget(
	schedule: Array[Dictionary],
	difficulty: float,
	faith_rate_per_second: float,
	coin_rate_per_minute: float,
	next_upgrade_cost: int,
	endless_mode: bool,
	manual_click_gain := 0.0
) -> Dictionary:
	var enemy_gold := 0
	for wave_value in schedule:
		for enemy_id_value in wave_value.get("types", []):
			enemy_gold += EnemyActor.get_reward_count(String(enemy_id_value))
	var reward_factor := clampf(pow(maxf(0.20, difficulty), 0.18), 0.78, 1.35)
	var gold_minutes := (0.42 if not endless_mode else 0.48) * reward_factor
	var victory_gold := _safe_reward_int(maxf(
		55.0 * reward_factor,
		maxf(0.0, coin_rate_per_minute) * gold_minutes
	))
	var faith_seconds := clampf(
		(24.0 if not endless_mode else 26.0) * reward_factor,
		22.0,
		30.0
	)
	var click_floor := (
		maxf(0.0, manual_click_gain)
		* 75.0
		* maxf(1.0, reward_factor)
	)
	# Upgrade cost is only a gentle relevance floor. It is capped by the same
	# thirty-second production budget so a victory cannot skip whole late-game
	# tiers or destabilise the fruit economy.
	var upgrade_floor := minf(
		float(maxi(0, next_upgrade_cost)) * 0.0025 * reward_factor,
		maxf(0.0, faith_rate_per_second) * 30.0
	)
	var faith_reward := _safe_reward_int(maxf(
		maxf(35.0 * reward_factor, click_floor),
		maxf(
			maxf(0.0, faith_rate_per_second) * faith_seconds,
			upgrade_floor
		)
	))
	return {
		"gold": enemy_gold + victory_gold,
		"enemy_gold": enemy_gold,
		"victory_gold": victory_gold,
		"faith": faith_reward
	}


static func _expand_types(source_types: Array, reinforcements: int, limit: int) -> Array[String]:
	var result: Array[String] = []
	if source_types.is_empty():
		return result
	for enemy_id_value in source_types:
		result.append(String(enemy_id_value))
	var target_count := mini(limit, result.size() + maxi(0, reinforcements))
	var source_index := 0
	while result.size() < target_count:
		result.append(String(source_types[source_index % source_types.size()]))
		source_index += 1
	return result


static func _safe_reward_int(value: float) -> int:
	if not is_finite(value):
		return int(MAX_REWARD_VALUE)
	return int(round(clampf(value, 0.0, MAX_REWARD_VALUE)))
