extends RefCounted

const EnemyActor = preload("res://scripts/enemy_actor.gd")

const CAMPAIGN_LEVELS_PER_REINFORCEMENT := 25.0
const ENDLESS_LEVELS_PER_REINFORCEMENT := 45.0
const CAMPAIGN_MAX_ENEMIES_PER_WAVE := 6
const ENDLESS_MAX_ENEMIES_PER_WAVE := 10
const MAX_REWARD_VALUE := 9_000_000_000_000_000_000.0
const HIGH_POWER_CARRY_THRESHOLD := 32.0
const HIGH_POWER_CARRY_PRESSURE := 0.65
const FINAL_BOSS_ENCOUNTER_KEY := "final_boss_encounter"
const TARGET_STRONGEST_WAVE_CLEAR_SECONDS := 9.0
const FINAL_BOSS_TARGET_CLEAR_SECONDS := 18.0
const TARGET_STRONGEST_WAVE_DAMAGE_FRACTION := 0.030
const MIN_DIFFICULTY_SCALE := 0.003


static func build_final_boss_schedule() -> Array[Dictionary]:
	return [
		{
			"time": 0.0,
			"types": ["outerspace1", "outerspace2"],
			FINAL_BOSS_ENCOUNTER_KEY: true
		},
		{"time": 6.0, "types": ["outerspace3", "modern3"]},
		{"time": 13.0, "types": ["outerspace2", "outerspace3", "modern3"]},
		{"time": 21.0, "types": ["final_boss"]}
	]


static func is_final_boss_schedule(schedule: Array[Dictionary]) -> bool:
	return (
		not schedule.is_empty()
		and bool(schedule[0].get(FINAL_BOSS_ENCOUNTER_KEY, false))
	)


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


static func strongest_wave_base_health(schedule: Array[Dictionary]) -> float:
	var strongest := 1.0
	for wave_value in schedule:
		var wave_health := 0.0
		for enemy_id_value in wave_value.get("types", []):
			var enemy_id := String(enemy_id_value)
			wave_health += (
				float(EnemyActor.DEFINITIONS.get(enemy_id, {}).get("hp", 1.0))
				* EnemyActor.get_health_multiplier(enemy_id)
			)
		strongest = maxf(strongest, wave_health)
	return strongest


static func strongest_wave_base_volley_damage(schedule: Array[Dictionary]) -> float:
	var strongest := 0.01
	for wave_value in schedule:
		var wave_damage := 0.0
		for enemy_id_value in wave_value.get("types", []):
			var enemy_id := String(enemy_id_value)
			var data: Dictionary = EnemyActor.DEFINITIONS.get(enemy_id, {})
			wave_damage += (
				float(data.get("damage", 0.1))
				* EnemyActor.get_damage_multiplier(enemy_id)
				* float(maxi(1, int(data.get("projectiles_per_attack", 1))))
			)
		strongest = maxf(strongest, wave_damage)
	return strongest


static func estimate_roster_damage_per_second(
	pet_roster_power: float,
	average_pet_level: float,
	active_pet_count: int
) -> float:
	var safe_pet_count := maxi(1, active_pet_count)
	var average_pet_power := maxf(1.0, pet_roster_power) / float(safe_pet_count)
	var rarity_proxy := clampf(1.0 + (average_pet_power - 12.0) / 10.0, 1.0, 3.0)
	var damage_power_scale := clampf(pow(average_pet_power / 20.0, 0.35), 0.80, 2.5)
	var hit_damage := (
		1.05 + rarity_proxy * 0.24 + sqrt(maxf(1.0, average_pet_level)) * 0.055
	) * damage_power_scale
	return maxf(0.80, float(safe_pet_count) * hit_damage / 1.15)


static func estimate_roster_health(
	pet_roster_power: float,
	average_pet_level: float,
	active_pet_count: int
) -> float:
	var safe_pet_count := maxi(1, active_pet_count)
	var average_pet_power := maxf(1.0, pet_roster_power) / float(safe_pet_count)
	var rarity_proxy := clampf(1.0 + (average_pet_power - 12.0) / 10.0, 1.0, 3.0)
	var health_power_scale := clampf(sqrt(average_pet_power / 20.0), 0.70, 3.0)
	# Most early rosters are melee-heavy; this weighted proxy stays close to the
	# actual mixed formation without letting an era's projectile count decide it.
	var role_health_scale := 1.45
	return maxf(
		8.0,
		float(safe_pet_count)
		* (7.0 + rarity_proxy * 1.8 + sqrt(maxf(1.0, average_pet_level)) * 0.42)
		* health_power_scale
		* role_health_scale
	)


static func recommended_difficulty_scale(
	pet_roster_power: float,
	schedule: Array[Dictionary],
	average_pet_level: float,
	endless_mode: bool,
	debug_multiplier: float,
	peak_pet_power := 0.0,
	active_pet_count := 1
) -> float:
	if debug_multiplier <= 0.0:
		return 0.0
	var safe_pet_count := maxi(1, active_pet_count)
	var carry_pressure := maxf(
		0.0,
		maxf(0.0, peak_pet_power) - HIGH_POWER_CARRY_THRESHOLD
	) * HIGH_POWER_CARRY_PRESSURE
	var carry_bonus := 1.0 + clampf(carry_pressure / maxf(120.0, pet_roster_power), 0.0, 0.18)
	var target_clear_seconds := (
		FINAL_BOSS_TARGET_CLEAR_SECONDS
		if is_final_boss_schedule(schedule)
		else TARGET_STRONGEST_WAVE_CLEAR_SECONDS
	)
	if endless_mode and average_pet_level > 100.0:
		target_clear_seconds += minf(
			2.5,
			log(1.0 + (average_pet_level - 100.0) / 40.0) / log(2.0)
		)
	var target_wave_health := (
		estimate_roster_damage_per_second(
			pet_roster_power,
			average_pet_level,
			safe_pet_count
		)
		* target_clear_seconds
		* carry_bonus
	)
	var health_scale := target_wave_health / strongest_wave_base_health(schedule)
	var adaptive_scale := pow(maxf(MIN_DIFFICULTY_SCALE, health_scale), 1.0 / 0.68)
	return clampf(
		maxf(0.0, debug_multiplier) * adaptive_scale,
		MIN_DIFFICULTY_SCALE,
		1_000_000_000_000_000.0
	)


static func recommended_enemy_damage_multiplier(
	pet_roster_power: float,
	average_pet_level: float,
	active_pet_count: int,
	schedule: Array[Dictionary],
	debug_multiplier: float
) -> float:
	if debug_multiplier <= 0.0:
		return 0.0
	var target_wave_volley := estimate_roster_health(
		pet_roster_power,
		average_pet_level,
		active_pet_count
	) * TARGET_STRONGEST_WAVE_DAMAGE_FRACTION
	return clampf(
		maxf(0.0, debug_multiplier) * target_wave_volley / strongest_wave_base_volley_damage(schedule),
		0.0,
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
	var gold_minutes := (0.60 if not endless_mode else 0.68) * reward_factor
	var victory_gold := _safe_reward_int(maxf(
		50.0 * reward_factor,
		maxf(0.0, coin_rate_per_minute) * gold_minutes
	))
	var faith_seconds := clampf(
		(12.0 if not endless_mode else 14.0) * reward_factor,
		10.0,
		16.0
	)
	var click_floor := (
		maxf(0.0, manual_click_gain)
		* 5.0
		* maxf(1.0, reward_factor)
	)
	var upgrade_floor := minf(
		float(maxi(0, next_upgrade_cost)) * 0.0025 * reward_factor,
		maxf(0.0, faith_rate_per_second) * 16.0
	)
	var faith_reward := _safe_reward_int(maxf(
		maxf(5.0 * reward_factor, click_floor),
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
