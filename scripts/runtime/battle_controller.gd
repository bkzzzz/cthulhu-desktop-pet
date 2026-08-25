extends "res://scripts/runtime/main_context.gd"

const ENCOUNTER_REWARD_KEY := "_encounter_reward_budget"
const ENCOUNTER_DIFFICULTY_KEY := "_encounter_difficulty_scale"
# Battles are deliberately infrequent, high-attention encounters. Their payout
# should feel like a real event instead of replacing only a few passive ticks.
const BATTLE_GOLD_REWARD_MINUTES := 18.0
const BATTLE_GOLD_REWARD_MIN_MINUTES := 12.0
const BATTLE_GOLD_REWARD_MAX_MINUTES := 24.0
const BATTLE_GOLD_REWARD_OPENING_FLOOR := 600.0
const BATTLE_FAITH_REWARD_BASE_SECONDS := 90.0
const BATTLE_FAITH_REWARD_MIN_SECONDS := 60.0
const BATTLE_FAITH_REWARD_MAX_SECONDS := 120.0
const BATTLE_FAITH_REWARD_MANUAL_CLICKS := 40.0
const BATTLE_FAITH_REWARD_UPGRADE_FRACTION := 0.10
const BATTLE_FAITH_REWARD_MAX_BASE_MULTIPLIER := 20.0
const BATTLE_REWARD_VISUAL_DROP_LIMIT := 8
const MAX_BATTLE_REWARD_VALUE := 9_000_000_000_000_000_000
const FINAL_BOSS_GOLD_REWARD_MULTIPLIER := 5.0
const FINAL_BOSS_FAITH_REWARD_MULTIPLIER := 3.0
const BATTLE_PET_RETARGET_INTERVAL := 0.12

var _battle_visual_reward_drops := 0
var _battle_warm_generation := 0
var _battle_enemy_damage_multiplier := 1.0
var _battle_enemy_roster_revision := 0
var _battle_enemy_roster_size := 0
var _battle_enemy_targetable_count := 0
var _battle_pet_enemy_target_revisions: Dictionary = {}
var _battle_pet_enemy_retarget_at: Dictionary = {}
var _battle_pet_pending_enemy_targets: Dictionary = {}
var _battle_pet_target_full_scan_count := 0


func _schedule_battle_asset_warmup(schedule: Array) -> void:
	_battle_warm_generation += 1
	call_deferred("_warm_battle_assets", schedule.duplicate(true), _battle_warm_generation)


func _cancel_battle_asset_warmup() -> void:
	_battle_warm_generation += 1


func _warm_battle_assets(schedule: Array, generation := -1) -> void:
	if generation < 0:
		_battle_warm_generation += 1
		generation = _battle_warm_generation
	if generation != _battle_warm_generation:
		return
	var enemy_ids: Array[String] = []
	for wave_value in schedule:
		var wave: Dictionary = wave_value
		for enemy_id_value in wave.get("types", []):
			var enemy_id := String(enemy_id_value)
			if not enemy_ids.has(enemy_id):
				enemy_ids.append(enemy_id)
	for enemy_id in enemy_ids:
		for stage in ["frames", "run_width", "battle_width"]:
			if generation != _battle_warm_generation:
				return
			EnemyActor.warm_up_stage(enemy_id, stage)
			if is_inside_tree():
				await get_tree().process_frame
	for pet_id in _deployed_pet_ids:
		if generation != _battle_warm_generation:
			return
		BattleEffectActor.warm_up_pet(String(pet_id))
		if is_inside_tree():
			await get_tree().process_frame
	for tier in BattleEffectActor.EXPLOSION_CONFIG.size():
		if generation != _battle_warm_generation:
			return
		BattleEffectActor.warm_up_explosion(tier)
		if is_inside_tree():
			await get_tree().process_frame
	if generation != _battle_warm_generation:
		return
	EnemyProjectileActor.warm_up()
	if is_inside_tree():
		await get_tree().process_frame
	if generation == _battle_warm_generation:
		_get_smoke_frames()


func _get_battle_average_pet_level() -> float:
	return EconomyBalance.average_level(_deployed_pet_ids, _pet_states)


func _build_battle_wave_schedule() -> Array[Dictionary]:
	if _host._should_offer_final_boss():
		return BattleBalance.build_final_boss_schedule()
	return BattleBalance.build_wave_schedule(
		EraProgression.get_wave_schedule(_get_era_runtime_seconds()),
		_get_battle_average_pet_level(),
		_host._is_endless_mode()
	)


func _get_battle_balance_schedule() -> Array[Dictionary]:
	if not _battle_wave_schedule.is_empty():
		return _battle_wave_schedule
	return _build_battle_wave_schedule()

func _get_base_battle_difficulty_scale() -> float:
	return BattleBalance.recommended_difficulty_scale(
		_get_pet_roster_combat_power(),
		_get_battle_balance_schedule(),
		_get_battle_average_pet_level(),
		_host._is_endless_mode(),
		_debug_enemy_power_scale,
		_get_peak_pet_combat_power(),
		_get_active_battle_pet_count()
	)


func _get_active_battle_pet_count() -> int:
	var active_pet_count := 0
	for pet in _pets:
		if is_instance_valid(pet):
			active_pet_count += 1
	return maxi(1, active_pet_count)

func _get_pet_roster_combat_power() -> float:
	var total = 0.0
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id = _host._get_actor_pet_id(pet)
		var state = _host._get_pet_state(pet_id)
		var level = PetProgression.progression_level(state)
		total += PetCatalog.get_combat_power(pet_id, level, bool(state.get("evolved", false)))
	if total <= 0.0:
		total = PetCatalog.get_combat_power("pet1", 1)
	return total

func _get_peak_pet_combat_power() -> float:
	var peak := 0.0
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id = _host._get_actor_pet_id(pet)
		var state = _host._get_pet_state(pet_id)
		var level = PetProgression.progression_level(state)
		peak = maxf(
			peak,
			PetCatalog.get_combat_power(
				pet_id,
				level,
				bool(state.get("evolved", false))
			)
		)
	if peak <= 0.0:
		peak = PetCatalog.get_combat_power("pet1", 1)
	return peak

func _get_enemy_schedule_combat_power() -> float:
	return BattleBalance.strongest_wave_power(_get_battle_balance_schedule())

func _roll_battle_difficulty_scale() -> float:
	var variance = _rng.randf_range(
		BATTLE_DIFFICULTY_VARIANCE_MIN,
		BATTLE_DIFFICULTY_VARIANCE_MAX
	)
	return _get_base_battle_difficulty_scale() * variance

func _get_battle_difficulty_scale() -> float:
	if _active_battle_difficulty_scale >= 0.0:
		return _active_battle_difficulty_scale
	return _get_base_battle_difficulty_scale()

func _get_battle_difficulty_text(difficulty_override := -1.0, language_override := "") -> String:
	var display_language := (
		LanguageSettings.sanitize(language_override)
		if not String(language_override).strip_edges().is_empty()
		else _language
	)
	var difficulty = (
		maxf(0.0, difficulty_override)
		if difficulty_override >= 0.0
		else _get_battle_difficulty_scale()
	)
	var schedule = _get_battle_balance_schedule()
	var counts = {}
	for wave in schedule:
		for enemy_id_value in (wave as Dictionary).get("types", []):
			var enemy_id = String(enemy_id_value)
			counts[enemy_id] = int(counts.get(enemy_id, 0)) + 1
	var parts: Array[String] = []
	for enemy_id_value in counts.keys():
		var enemy_id = String(enemy_id_value)
		parts.append("%s×%d" % [_get_enemy_display_name(enemy_id, display_language), int(counts[enemy_id])])
	var rewards = _get_battle_reward_budget(difficulty)
	var reward_gold_text := CurrencyDisplay.format_compact(int(rewards["gold"]))
	return (
		"ENEMIES: %s\nREWARD BUDGET: %s + %d FAITH"
		if display_language == "en"
		else "敌军编成：%s\n奖励预算：%s + %d 信仰"
	) % [(" · " if display_language == "en" else "、").join(parts), reward_gold_text, int(rewards["faith"])]

func _get_enemy_display_name(enemy_id: String, language_override := "") -> String:
	var display_language := (
		LanguageSettings.sanitize(language_override)
		if not String(language_override).strip_edges().is_empty()
		else _language
	)
	var names_zh = {
		"villager1": "村民", "villager2": "持械村民", "soldier1": "步兵", "soldier2": "弓兵",
		"victorian1": "维多利亚枪手", "victorian2": "维多利亚卫兵", "victorian_boss": "维多利亚统领",
		"modern2": "现代炮兵", "modern3": "现代术士", "outerspace1": "星际侦察兵",
		"outerspace2": "星际轰炸者", "outerspace3": "星际主宰", "final_boss": "终焉星械"
	}
	var names_en = {
		"villager1": "Villager", "villager2": "Armed Villager", "soldier1": "Infantry", "soldier2": "Archer",
		"victorian1": "Victorian Gunner", "victorian2": "Victorian Guard", "victorian_boss": "Victorian Commander",
		"modern2": "Modern Artillery", "modern3": "Modern Adept", "outerspace1": "Star Scout",
		"outerspace2": "Star Bomber", "outerspace3": "Star Overlord", "final_boss": "Final Orrery"
	}
	return String((names_en if display_language == "en" else names_zh).get(enemy_id, enemy_id))

func _get_battle_reward_budget(difficulty: float) -> Dictionary:
	var schedule := _get_battle_balance_schedule()
	if not schedule.is_empty():
		var first_wave: Dictionary = schedule[0]
		var locked_difficulty := float(first_wave.get(ENCOUNTER_DIFFICULTY_KEY, -1.0))
		var locked_reward_value: Variant = first_wave.get(ENCOUNTER_REWARD_KEY, {})
		if (
			locked_reward_value is Dictionary
			and not (locked_reward_value as Dictionary).is_empty()
			and is_equal_approx(difficulty, locked_difficulty)
		):
			return (locked_reward_value as Dictionary).duplicate(true)
	var potential_coin_rate := EconomyBalance.potential_coin_rate_per_minute(
		_unlocked_pet_ids,
		_pet_states
	)
	var level_cap := (
		PetProgression.MAX_LEVEL
		if _host._is_endless_mode()
		else EconomyBalance.CAMPAIGN_LEVEL_TARGET
	)
	var next_upgrade_cost := EconomyBalance.next_upgrade_cost(
		_unlocked_pet_ids,
		_pet_states,
		level_cap
	)
	var baseline_faith_rate: float = float(_host._get_baseline_faith_growth_rate())
	var manual_click_gain: float = float(_host._get_manual_faith_click_gain(1))
	var reward_budget := BattleBalance.reward_budget(
		schedule,
		difficulty,
		baseline_faith_rate,
		potential_coin_rate,
		next_upgrade_cost,
		_host._is_endless_mode(),
		manual_click_gain
	)
	var difficulty_factor := clampf(
		pow(maxf(0.20, difficulty), 0.12),
		0.80,
		1.20
	)
	var gold_minutes := clampf(
		BATTLE_GOLD_REWARD_MINUTES * difficulty_factor,
		BATTLE_GOLD_REWARD_MIN_MINUTES,
		BATTLE_GOLD_REWARD_MAX_MINUTES
	)
	var opening_gold_floor := BATTLE_GOLD_REWARD_OPENING_FLOOR * difficulty_factor
	var victory_gold := _safe_battle_reward_int(maxf(
		opening_gold_floor,
		potential_coin_rate * gold_minutes
	))
	var enemy_gold := maxi(0, int(reward_budget.get("enemy_gold", 0)))
	reward_budget["gold"] = _safe_battle_reward_int(float(enemy_gold + victory_gold))
	reward_budget["victory_gold"] = victory_gold

	var faith_seconds := clampf(
		BATTLE_FAITH_REWARD_BASE_SECONDS * difficulty_factor,
		BATTLE_FAITH_REWARD_MIN_SECONDS,
		BATTLE_FAITH_REWARD_MAX_SECONDS
	)
	var opening_faith_floor := _safe_battle_reward_int(5.0 * difficulty_factor)
	var manual_faith_floor := _safe_battle_reward_int(
		manual_click_gain
		* BATTLE_FAITH_REWARD_MANUAL_CLICKS
		* maxf(1.0, difficulty_factor)
	)
	var production_faith_floor := _safe_battle_reward_int(
		baseline_faith_rate * faith_seconds
	)
	var base_faith_reward := maxi(
		opening_faith_floor,
		maxi(manual_faith_floor, production_faith_floor)
	)
	var upgrade_faith_floor := _safe_battle_reward_int(
		float(next_upgrade_cost)
		* BATTLE_FAITH_REWARD_UPGRADE_FRACTION
		* difficulty_factor
	)
	var capped_upgrade_faith_floor := mini(
		upgrade_faith_floor,
		_safe_battle_reward_int(
			float(base_faith_reward) * BATTLE_FAITH_REWARD_MAX_BASE_MULTIPLIER
		)
	)
	reward_budget["faith"] = maxi(base_faith_reward, capped_upgrade_faith_floor)
	if BattleBalance.is_final_boss_schedule(schedule):
		var final_gold := _safe_battle_reward_int(
			float(reward_budget["gold"]) * FINAL_BOSS_GOLD_REWARD_MULTIPLIER
		)
		reward_budget["gold"] = final_gold
		reward_budget["victory_gold"] = final_gold
		reward_budget["faith"] = _safe_battle_reward_int(
			float(reward_budget["faith"]) * FINAL_BOSS_FAITH_REWARD_MULTIPLIER
		)
	return reward_budget


func _safe_battle_reward_int(value: float) -> int:
	if not is_finite(value) or value >= float(MAX_BATTLE_REWARD_VALUE):
		return MAX_BATTLE_REWARD_VALUE
	return clampi(int(round(maxf(0.0, value))), 0, MAX_BATTLE_REWARD_VALUE)

func _start_battle() -> void:
	if _battle_active or _pilgrimage_active or not _host._has_valid_desktop_pet():
		_active_battle_difficulty_scale = -1.0
		_pending_battle_difficulty_scale = -1.0
		_battle_wave_schedule.clear()
		_host._schedule_next_battle(_host._get_now_seconds())
		return
	for believer in _believers:
		if is_instance_valid(believer):
			believer.queue_free()
	_believers.clear()

	_battle_active = true
	# A comfort visit is a desktop-only activity. Clear it before snapshotting
	# battle positions so its production multiplier and seated pose never cross
	# into combat.
	_host._release_sofa_interaction("", false)
	if _active_battle_difficulty_scale < 0.0:
		_active_battle_difficulty_scale = _roll_battle_difficulty_scale()
	_battle_started_at = _host._get_now_seconds()
	_battle_ends_at = _battle_started_at + BATTLE_DURATION_SECONDS
	if _battle_wave_schedule.is_empty():
		_battle_wave_schedule = _build_battle_wave_schedule()
	_battle_next_wave_index = 0
	_battle_pet_health.clear()
	_battle_pet_max_health.clear()
	_battle_pet_attack_at.clear()
	_battle_pet_target_x.clear()
	_battle_pet_formed.clear()
	_reset_battle_pet_target_cache()
	_battle_pet5_rolls.clear()
	_battle_save_pending = false
	_battle_defeated_enemies = 0
	_battle_dropped_coin_budget = 0
	_battle_visual_reward_drops = 0
	_host._update_actor_window_bounds()

	var battle_pets: Array[Node2D] = []
	for pet in _pets:
		if is_instance_valid(pet):
			battle_pets.append(pet)
	_battle_enemy_damage_multiplier = BattleBalance.recommended_enemy_damage_multiplier(
		_get_pet_roster_combat_power(),
		_get_battle_average_pet_level(),
		battle_pets.size(),
		_get_battle_balance_schedule(),
		_debug_enemy_power_scale
	)
	for pet in battle_pets:
		var pet_id = _host._get_actor_pet_id(pet)
		var level = PetProgression.progression_level(_host._get_pet_state(pet_id))
		var rarity = clampi(int(PetCatalog.get_definition(pet_id).get("rarity_stars", 1)), 1, 5)
		var pet_combat_power = PetCatalog.get_combat_power(pet_id, level, bool(_host._get_pet_state(pet_id).get("evolved", false)))
		var health_power_scale = clampf(sqrt(pet_combat_power / 20.0), 0.70, 3.0)
		var is_ranged_pet = pet_id in RANGED_BATTLE_PET_IDS
		var role_health_scale = RANGED_BATTLE_HEALTH_MULTIPLIER if is_ranged_pet else MELEE_BATTLE_HEALTH_MULTIPLIER
		var max_health = (
			(7.0 + float(rarity) * 1.8 + sqrt(float(level)) * 0.42)
			* health_power_scale
			* role_health_scale
		)
		var actor_key = str(pet.get_instance_id())
		_battle_pet_health[actor_key] = max_health
		_battle_pet_max_health[actor_key] = max_health
		_battle_pet_attack_at[actor_key] = _battle_started_at + _rng.randf_range(0.6, 1.2)
		_battle_pet_formed[actor_key] = true
		_battle_pet_target_x[actor_key] = pet.position.x
		if pet.has_method("set_battle_mode"):
			pet.call("set_battle_mode", true)
		_attach_battle_health_bar(pet, max_health, max_health)

	_host._show_pilgrimage_broadcast(
		"BATTLE EVENT" if _language == "en" else "战斗事件",
		BATTLE_DRAG_HINT_EN if _language == "en" else BATTLE_DRAG_HINT_ZH,
		{
			"title_en": "BATTLE EVENT",
			"subtitle_en": BATTLE_DRAG_HINT_EN,
			"title_zh": "战斗事件",
			"subtitle_zh": BATTLE_DRAG_HINT_ZH
		}
	)
	_host._publish_news({
		"category": "公告",
		"headline": "战斗事件：宠物会从当前桌面位置投入战斗，可随时拖动它们调整战线。",
		"headline_en": "BATTLE: Pets are engaging from their current desktop positions."
	}, true, false)
	_update_battle(0.0)

func _update_battle(delta: float) -> void:
	if not _battle_active:
		return
	_cleanup_battle_enemies()
	var now = _host._get_now_seconds()
	var elapsed = maxf(0.0, now - _battle_started_at)
	while _battle_next_wave_index < _battle_wave_schedule.size():
		var wave: Dictionary = _battle_wave_schedule[_battle_next_wave_index]
		if elapsed + 0.001 < float(wave.get("time", 0.0)):
			break
		_spawn_battle_wave(wave, _battle_next_wave_index)
		_battle_next_wave_index += 1
	_refresh_battle_enemy_targetability_revision()

	var alive_pets = _get_alive_battle_pets()
	if alive_pets.is_empty():
		_finish_battle(false)
		return
	var alive_defenders := _get_alive_battle_defenders()

	for enemy in _battle_enemies:
		if not is_instance_valid(enemy):
			continue
		var target = _get_battle_target_for_enemy(enemy, alive_defenders)
		if enemy.has_method("set_target"):
			enemy.call("set_target", target)

	for pet in alive_pets:
		var actor_key = str(pet.get_instance_id())
		if pet.has_method("is_pointer_captured") and bool(pet.call("is_pointer_captured")):
			continue
		if not bool(_battle_pet_formed.get(actor_key, false)):
			continue
		if pet.has_method("is_battle_ready") and not bool(pet.call("is_battle_ready")):
			continue
		if _battle_enemies.is_empty():
			continue
		if now < float(_battle_pet_attack_at.get(actor_key, now)):
			continue
		var enemy_target = _get_battle_target_for_pet(pet)
		if enemy_target == null:
			continue
		var pet_id = _host._get_actor_pet_id(pet)
		var pet_data = PetCatalog.get_definition(pet_id)
		var rarity = clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
		var level = PetProgression.progression_level(_host._get_pet_state(pet_id))
		var pet_combat_power = PetCatalog.get_combat_power(pet_id, level, bool(_host._get_pet_state(pet_id).get("evolved", false)))
		var damage_power_scale = clampf(pow(pet_combat_power / 20.0, 0.35), 0.80, 2.5)
		var damage = (1.05 + float(rarity) * 0.24 + sqrt(float(level)) * 0.055) * damage_power_scale
		var is_ranged_pet = pet_id in RANGED_BATTLE_PET_IDS
		var melee_attack_range = 155.0
		if pet.has_method("get_battle_attack_range"):
			melee_attack_range = float(pet.call("get_battle_attack_range"))
		var attack_direction = enemy_target.position.x - pet.position.x
		if is_zero_approx(attack_direction):
			attack_direction = -1.0
		if (
			pet_id == "pet5"
			and pet.has_method("uses_battle_roll_attack")
			and bool(pet.call("uses_battle_roll_attack"))
		):
			var roll_target_x = enemy_target.position.x + signf(attack_direction) * PET5_ROLL_OVERSHOOT
			var roll_distance = absf(clampf(
				roll_target_x,
				float(pet.call("_get_drag_min_x")),
				float(pet.call("_get_drag_max_x"))
			) - pet.position.x)
			if bool(pet.call("begin_battle_roll_attack", roll_target_x, PET5_ROLL_SPEED)):
				_battle_pet5_rolls[actor_key] = {
					"damage": damage,
					"knockback": 12.0 + float(rarity) * 1.5,
					"visual_power": _get_battle_visual_power(rarity, level),
					"hit_ids": {}
				}
				_battle_pet_attack_at[actor_key] = now + maxf(
					1.05,
					roll_distance / PET5_ROLL_SPEED + 0.38
				)
			else:
				_battle_pet_attack_at[actor_key] = now + 0.18
			continue
		if not is_ranged_pet and absf(pet.position.x - enemy_target.position.x) > melee_attack_range:
			continue
		if pet.has_method("play_battle_attack_toward"):
			pet.call("play_battle_attack_toward", signf(attack_direction))
		elif pet.has_method("play_battle_attack"):
			pet.call("play_battle_attack")
		var knockback = 12.0 + float(rarity) * 1.5
		if is_ranged_pet:
			var visual_power = _get_battle_visual_power(rarity, level)
			_spawn_pet_projectile(pet, pet_id, enemy_target, signf(attack_direction), damage, knockback, visual_power)
		elif enemy_target.has_method("take_damage"):
			var hit_direction := -1.0 if enemy_target.position.x < pet.position.x else 1.0
			enemy_target.call("take_damage", damage, knockback, Vector2.ZERO, hit_direction)
		var next_attack_delay = _rng.randf_range(0.95, 1.35)
		if pet.has_method("get_battle_attack_duration"):
			next_attack_delay = maxf(
				next_attack_delay,
				float(pet.call("get_battle_attack_duration")) + 0.05
			)
		_battle_pet_attack_at[actor_key] = now + next_attack_delay

	_update_battle_status(now)
	if _battle_next_wave_index >= _battle_wave_schedule.size() and _battle_enemies.is_empty():
		_finish_battle(true)
	elif now >= _battle_ends_at:
		_finish_battle(false)

func _update_battle_pet_formation(delta: float) -> void:
	if not _battle_active:
		return
	_refresh_battle_enemy_targetability_revision()
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var actor_key = str(pet.get_instance_id())
		if not _battle_pet_health.has(actor_key):
			continue
		if pet.has_method("is_pointer_captured") and bool(pet.call("is_pointer_captured")):
			continue
		if not bool(_battle_pet_formed.get(actor_key, false)):
			var formation_x = float(_battle_pet_target_x.get(actor_key, float(_pet_window_size.x) * 0.78))
			var reached_formation = true
			if pet.has_method("battle_move_toward"):
				reached_formation = bool(pet.call(
					"battle_move_toward",
					formation_x,
					delta,
					235.0,
					-1.0
				))
			if reached_formation:
				_battle_pet_formed[actor_key] = true
			continue
		if _battle_enemies.is_empty():
			continue
		if pet.has_method("is_battle_ready") and not bool(pet.call("is_battle_ready")):
			continue
		if pet.has_method("is_battle_attack_playing") and bool(pet.call("is_battle_attack_playing")):
			continue
		var enemy_target = _get_battle_target_for_pet(pet)
		if enemy_target == null:
			continue
		var target_direction = enemy_target.position.x - pet.position.x
		if is_zero_approx(target_direction):
			target_direction = -1.0
		var pet_id = _host._get_actor_pet_id(pet)
		if pet_id in RANGED_BATTLE_PET_IDS:
			if pet.has_method("face_battle_target"):
				pet.call("face_battle_target", target_direction)
			continue
		var attack_range = 155.0
		if pet.has_method("get_battle_attack_range"):
			attack_range = float(pet.call("get_battle_attack_range"))
		var current_distance = absf(target_direction)
		if current_distance <= attack_range * 0.90:
			if pet.has_method("face_battle_target"):
				pet.call("face_battle_target", target_direction)
			continue
		var standoff_distance = maxf(46.0, attack_range * 0.72)
		var chase_x = enemy_target.position.x - signf(target_direction) * standoff_distance
		var chase_speed = PET5_BATTLE_CHASE_SPEED if pet_id == "pet5" else MELEE_BATTLE_CHASE_SPEED
		if pet.has_method("battle_move_toward"):
			pet.call(
				"battle_move_toward",
				chase_x,
				delta,
				chase_speed,
				target_direction,
				true
			)

func _spawn_battle_wave(wave: Dictionary, wave_index: int) -> void:
	var enemy_types: Array = wave.get("types", [])
	var spawned_enemy := false
	for enemy_index in enemy_types.size():
		var enemy_id = String(enemy_types[enemy_index])
		var spawn_from_right := (enemy_index + wave_index) % 2 == 1
		var formation_weight := (
			0.5
			if enemy_types.size() <= 1
			else float(enemy_index) / float(enemy_types.size() - 1)
		)
		var spawn_position = Vector2(
			(
				float(_pet_window_size.x) + 82.0 + float(enemy_index) * 52.0
				if spawn_from_right
				else -82.0 - float(enemy_index) * 52.0
			),
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
		)
		var enemy: Node2D = EnemyActor.new()
		enemy.set_meta("battle_runtime", true)
		var era_scale = _get_battle_difficulty_scale()
		var wave_scale = 1.0 + float(wave_index) * 0.025
		var left_entry_x: float = (
			lerpf(
				float(_pet_window_size.x) * 0.12,
				float(_pet_window_size.x) * 0.42,
				formation_weight
			)
			if enemy_id in ["soldier2", "victorian1", "modern2", "modern3", "outerspace1", "outerspace2", "outerspace3", "final_boss"]
			else lerpf(
				float(_pet_window_size.x) * 0.06,
				float(_pet_window_size.x) * 0.25,
				formation_weight
			)
		)
		var entry_x: float = (
			float(_pet_window_size.x) - left_entry_x
			if spawn_from_right
			else left_entry_x
		)
		enemy.call(
			"setup",
			enemy_id,
			spawn_position,
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
			era_scale * wave_scale,
			entry_x,
			float(_pet_window_size.x),
			_battle_enemy_damage_multiplier
		)
		enemy.connect("attack_landed", Callable(self, "_on_enemy_attack_landed"))
		enemy.connect("projectile_requested", Callable(self, "_on_enemy_projectile_requested"))
		enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))
		enemy.connect("swallowed", Callable(self, "_on_enemy_swallowed"))
		add_child(enemy)
		_battle_enemies.append(enemy)
		spawned_enemy = true
	if spawned_enemy:
		_mark_battle_enemy_roster_changed()

func _on_enemy_projectile_requested(
	enemy: Node2D,
	target: Node2D,
	damage: float,
	projectile_kind: String,
	power_scale: float
) -> void:
	if not _battle_active or enemy == null or not is_instance_valid(enemy):
		return
	if target == null or not is_instance_valid(target):
		return
	if _battle_effects.size() >= BATTLE_EFFECT_LIMIT:
		return
	var start_position = enemy.position + Vector2(38.0, -68.0)
	if enemy.has_method("get_projectile_origin"):
		start_position = enemy.call("get_projectile_origin")
	var projectile: Node2D = EnemyProjectileActor.new()
	projectile.set_meta("battle_runtime", true)
	projectile.call(
		"setup",
		projectile_kind,
		start_position,
		target,
		damage,
		power_scale,
		_get_alive_battle_defenders()
	)
	projectile.connect("impacted", Callable(self, "_on_enemy_projectile_impacted"))
	projectile.tree_exited.connect(_on_battle_effect_tree_exited.bind(projectile))
	add_child(projectile)
	_battle_effects.append(projectile)

func _on_enemy_projectile_impacted(
	projectile: Node2D,
	target: Node2D,
	damage: float,
	splash_radius: float,
	knockback: float
) -> void:
	if not _battle_active:
		return
	var impact_position := projectile.position if projectile != null and is_instance_valid(projectile) else Vector2.ZERO
	var projectile_direction := 1.0
	if projectile != null and is_instance_valid(projectile) and projectile.has_method("get_travel_direction"):
		var travel_direction: Vector2 = projectile.call("get_travel_direction")
		if not is_zero_approx(travel_direction.x):
			projectile_direction = signf(travel_direction.x)
	if splash_radius <= 0.0:
		if target == null or not is_instance_valid(target):
			return
		_damage_battle_defender(target, damage, projectile_direction * knockback)
		return
	_spawn_battle_explosion(impact_position, clampf(splash_radius / 32.0, 3.0, 7.5))
	for defender in _get_alive_battle_defenders():
		var hit_position = defender.position + Vector2(0.0, -48.0)
		if defender.has_method("get_battle_hit_position"):
			hit_position = defender.call("get_battle_hit_position")
		var distance = hit_position.distance_to(impact_position)
		if distance > splash_radius:
			continue
		var falloff = lerpf(1.0, 0.45, distance / maxf(1.0, splash_radius))
		var splash_direction := projectile_direction
		if not is_zero_approx(hit_position.x - impact_position.x):
			splash_direction = signf(hit_position.x - impact_position.x)
		_damage_battle_defender(defender, damage * falloff, splash_direction * knockback * falloff)

func _get_battle_visual_power(rarity: int, level: int) -> float:
	return clampf(float(rarity) + log(float(maxi(1, level))) / log(10.0) * 0.72, 1.0, 7.5)

func _spawn_pet_projectile(
	pet: Node2D,
	pet_id: String,
	target: Node2D,
	direction: float,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	if target == null or not is_instance_valid(target):
		return
	var start_position = pet.position + Vector2((-1.0 if direction < 0.0 else 1.0) * 42.0, -46.0)
	if pet.has_method("get_battle_attack_origin"):
		start_position = pet.call("get_battle_attack_origin", direction)
	var effect: Node2D = BattleEffectActor.new()
	effect.set_meta("battle_runtime", true)
	effect.call(
		"setup_projectile",
		pet_id,
		start_position,
		target,
		visual_power,
		bool(pet.get("is_evolved"))
	)
	effect.connect(
		"projectile_impacted",
		Callable(self, "_on_pet_projectile_impacted").bind(damage, knockback, visual_power)
	)
	effect.tree_exited.connect(_on_battle_effect_tree_exited.bind(effect))
	add_child(effect)
	_battle_effects.append(effect)


func _on_pet_projectile_impacted(
	_effect: Node2D,
	target: Node2D,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	if not _battle_active or target == null or not is_instance_valid(target):
		return
	var impact_position = target.position + Vector2(0.0, -52.0)
	if target.has_method("get_battle_hit_position"):
		impact_position = target.call("get_battle_hit_position")
	_spawn_battle_explosion(impact_position, visual_power)
	if target.has_method("take_damage"):
		var hit_direction := -1.0
		if _effect != null and is_instance_valid(_effect) and _effect.has_method("get_travel_direction"):
			var travel_direction: Vector2 = _effect.call("get_travel_direction")
			if not is_zero_approx(travel_direction.x):
				hit_direction = signf(travel_direction.x)
		target.call("take_damage", damage, knockback, Vector2.ZERO, hit_direction)

func _spawn_battle_explosion(world_position: Vector2, visual_power: float) -> void:
	if _battle_effects.size() >= BATTLE_EFFECT_LIMIT:
		return
	var effect: Node2D = BattleEffectActor.new()
	effect.set_meta("battle_runtime", true)
	effect.call("setup_explosion", world_position, visual_power)
	effect.tree_exited.connect(_on_battle_effect_tree_exited.bind(effect))
	add_child(effect)
	_battle_effects.append(effect)

func _on_battle_effect_tree_exited(effect: Node2D) -> void:
	_battle_effects.erase(effect)

func _cleanup_battle_enemies() -> void:
	var roster_changed := false
	for index in range(_battle_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_battle_enemies[index]) or _battle_enemies[index].is_queued_for_deletion():
			_battle_enemies.remove_at(index)
			roster_changed = true
	if roster_changed:
		_mark_battle_enemy_roster_changed()
		_invalidate_battle_pet_target_caches()

func _get_alive_battle_pets() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _battle_pet_health.has(str(pet.get_instance_id())):
			alive.append(pet)
	return alive


func _get_alive_battle_defenders() -> Array[Node2D]:
	return _get_alive_battle_pets()


func _attach_battle_health_bar(
	actor: Node2D,
	current_health: float,
	maximum_health: float
) -> Node2D:
	if actor == null or not is_instance_valid(actor):
		return null
	var existing := actor.get_node_or_null("CombatHealthBar") as Node2D
	var health_bar := existing
	if health_bar == null:
		health_bar = CombatHealthBar.new()
		health_bar.name = "CombatHealthBar"
		health_bar.set_meta("battle_runtime", true)
		health_bar.call("setup", false, false, 76.0)
		actor.add_child(health_bar)
	var hit_position := actor.position + Vector2(0.0, -64.0)
	if actor.has_method("get_battle_hit_position"):
		hit_position = actor.call("get_battle_hit_position")
	health_bar.position = actor.to_local(hit_position) + Vector2(0.0, -34.0)
	health_bar.call("set_health", current_health, maximum_health, existing == null)
	return health_bar


func _remove_battle_health_bar(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var health_bar := actor.get_node_or_null("CombatHealthBar")
	if health_bar != null:
		health_bar.queue_free()

func _get_nearest_battle_pet(enemy: Node2D, candidates: Array[Node2D]) -> Node2D:
	var nearest: Node2D
	var nearest_distance = INF
	for pet in candidates:
		if pet == null or not is_instance_valid(pet) or pet.is_queued_for_deletion():
			continue
		var distance = pet.position.distance_squared_to(enemy.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = pet
	return nearest


func _get_battle_target_for_enemy(enemy: Node2D, candidates: Array[Node2D]) -> Node2D:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return null
	return _get_nearest_battle_pet(enemy, candidates)


func _scan_nearest_battle_enemy(pet: Node2D, actor_key := "") -> Node2D:
	_battle_pet_target_full_scan_count += 1
	var nearest: Node2D
	var nearest_distance = INF
	var nearest_pending: Node2D
	var nearest_pending_distance = INF
	for enemy in _battle_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var distance = pet.position.distance_squared_to(enemy.position)
		if _is_battle_enemy_targetable(enemy) and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
		elif distance < nearest_pending_distance:
			nearest_pending_distance = distance
			nearest_pending = enemy
	if not actor_key.is_empty():
		if nearest_pending == null:
			_battle_pet_pending_enemy_targets.erase(actor_key)
		else:
			_battle_pet_pending_enemy_targets[actor_key] = nearest_pending
	return nearest


func _get_nearest_battle_enemy(pet: Node2D) -> Node2D:
	if pet == null or not is_instance_valid(pet):
		return null
	return _scan_nearest_battle_enemy(pet)


func _is_battle_enemy_targetable(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	# Spawn protection is an engagement rule, not invulnerability: enemies may
	# take incidental damage while entering, but pets cannot lock or chase them
	# until their complete run sprite is inside the combat area.
	if enemy.has_method("has_entered_battlefield") and not bool(enemy.call("has_entered_battlefield")):
		return false
	if enemy.has_method("is_targetable"):
		return bool(enemy.call("is_targetable"))
	if enemy.has_method("is_defeated"):
		return not bool(enemy.call("is_defeated"))
	return true

func _get_battle_target_for_pet(pet: Node2D) -> Node2D:
	if pet == null or not is_instance_valid(pet):
		return null
	_sync_battle_enemy_roster_revision()
	var actor_key := str(pet.get_instance_id())
	var cached_revision := int(_battle_pet_enemy_target_revisions.get(actor_key, -1))
	var revision_matches := cached_revision == _battle_enemy_roster_revision
	var cached_target: Node2D
	var cached_target_was_invalid := false
	if _battle_pet_enemy_targets.has(actor_key):
		var cached_value: Variant = _battle_pet_enemy_targets.get(actor_key, null)
		if is_instance_valid(cached_value):
			cached_target = cached_value as Node2D
		cached_target_was_invalid = (
			cached_target == null
			or not _is_battle_enemy_targetable(cached_target)
		)

	var pending_target: Node2D
	var pending_target_was_invalid := false
	if _battle_pet_pending_enemy_targets.has(actor_key):
		var pending_value: Variant = _battle_pet_pending_enemy_targets.get(actor_key, null)
		if is_instance_valid(pending_value):
			pending_target = pending_value as Node2D
		pending_target_was_invalid = (
			pending_target == null
			or pending_target.is_queued_for_deletion()
			or (
				pending_target.has_method("is_defeated")
				and bool(pending_target.call("is_defeated"))
			)
		)
	var pending_target_became_targetable := (
		pending_target != null
		and not pending_target_was_invalid
		and _is_battle_enemy_targetable(pending_target)
	)
	# Target throttling follows simulation time so paused/headless tests do not
	# depend on wall-clock scheduling and battle speed changes stay deterministic.
	var now: float = maxf(0.0, float(_simulation_now_seconds))
	var retarget_due: bool = now >= float(
		_battle_pet_enemy_retarget_at.get(actor_key, -INF)
	)
	if (
		revision_matches
		and not cached_target_was_invalid
		and not pending_target_was_invalid
		and not pending_target_became_targetable
		and not retarget_due
	):
		return cached_target

	var next_target := _scan_nearest_battle_enemy(pet, actor_key)
	_battle_pet_enemy_target_revisions[actor_key] = _battle_enemy_roster_revision
	_battle_pet_enemy_retarget_at[actor_key] = now + BATTLE_PET_RETARGET_INTERVAL
	if next_target == null:
		_battle_pet_enemy_targets.erase(actor_key)
	else:
		_battle_pet_enemy_targets[actor_key] = next_target
	return next_target


func _mark_battle_enemy_roster_changed() -> void:
	_battle_enemy_roster_revision += 1
	_battle_enemy_roster_size = _battle_enemies.size()
	_battle_enemy_targetable_count = _count_targetable_battle_enemies()


func _count_targetable_battle_enemies() -> int:
	var targetable_count := 0
	for enemy in _battle_enemies:
		if is_instance_valid(enemy) and _is_battle_enemy_targetable(enemy):
			targetable_count += 1
	return targetable_count


func _refresh_battle_enemy_targetability_revision() -> void:
	# Entry protection can change without mutating the enemy array. Poll that
	# transition once per controller update, then let every pet share the same
	# revision instead of each pet rescanning every enemy independently.
	var targetable_count := _count_targetable_battle_enemies()
	if targetable_count == _battle_enemy_targetable_count:
		return
	_battle_enemy_targetable_count = targetable_count
	_battle_enemy_roster_revision += 1


func _sync_battle_enemy_roster_revision() -> void:
	# Production mutations explicitly bump the revision. Keeping a size guard also
	# preserves direct test/debug array injection without paying an O(enemy count)
	# fingerprint cost on every target lookup.
	if _battle_enemy_roster_size != _battle_enemies.size():
		_mark_battle_enemy_roster_changed()


func _clear_battle_pet_target_cache(actor_key: String) -> void:
	_battle_pet_enemy_targets.erase(actor_key)
	_battle_pet_enemy_target_revisions.erase(actor_key)
	_battle_pet_enemy_retarget_at.erase(actor_key)
	_battle_pet_pending_enemy_targets.erase(actor_key)


func _invalidate_battle_pet_target_caches() -> void:
	_battle_pet_enemy_targets.clear()
	_battle_pet_enemy_target_revisions.clear()
	_battle_pet_enemy_retarget_at.clear()
	_battle_pet_pending_enemy_targets.clear()


func _reset_battle_pet_target_cache() -> void:
	_invalidate_battle_pet_target_caches()
	_mark_battle_enemy_roster_changed()


func _reset_battle_pet_target_full_scan_count() -> void:
	_battle_pet_target_full_scan_count = 0


func _get_battle_pet_target_full_scan_count() -> int:
	return _battle_pet_target_full_scan_count

func _on_pet5_battle_roll_swept(actor: Node2D, from_x: float, to_x: float) -> void:
	if not _battle_active or actor == null or not is_instance_valid(actor):
		return
	var actor_key = str(actor.get_instance_id())
	var roll_data: Dictionary = _battle_pet5_rolls.get(actor_key, {})
	if roll_data.is_empty():
		return
	var hit_ids: Dictionary = roll_data.get("hit_ids", {})
	var sweep_min = minf(from_x, to_x) - PET5_ROLL_HIT_RADIUS
	var sweep_max = maxf(from_x, to_x) + PET5_ROLL_HIT_RADIUS
	for enemy in _battle_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		if enemy.position.x < sweep_min or enemy.position.x > sweep_max:
			continue
		var enemy_key = str(enemy.get_instance_id())
		if hit_ids.has(enemy_key):
			continue
		hit_ids[enemy_key] = true
		var impact_position: Vector2 = enemy.position + Vector2(0.0, -48.0)
		if enemy.has_method("get_battle_hit_position"):
			impact_position = enemy.call("get_battle_hit_position")
		_spawn_battle_explosion(impact_position, float(roll_data.get("visual_power", 1.0)) * 0.88)
		if enemy.has_method("take_damage"):
			enemy.call(
				"take_damage",
				float(roll_data.get("damage", 0.0)),
				float(roll_data.get("knockback", 0.0)),
				Vector2.ZERO,
				(-1.0 if to_x < from_x else 1.0)
			)
	roll_data["hit_ids"] = hit_ids
	_battle_pet5_rolls[actor_key] = roll_data

func _on_pet5_battle_roll_finished(actor: Node2D) -> void:
	if actor == null:
		return
	_battle_pet5_rolls.erase(str(actor.get_instance_id()))

func _on_enemy_attack_landed(enemy: Node2D, target: Node2D, damage: float) -> void:
	var knockback_direction := 1.0
	if enemy != null and is_instance_valid(enemy) and target != null and is_instance_valid(target):
		knockback_direction = -1.0 if target.position.x < enemy.position.x else 1.0
	_damage_battle_defender(target, damage, knockback_direction * 13.0)

func _damage_battle_pet(target: Node2D, damage: float, knockback: float) -> void:
	if not _battle_active or target == null or not is_instance_valid(target):
		return
	var actor_key = str(target.get_instance_id())
	if not _battle_pet_health.has(actor_key):
		return
	var next_health = float(_battle_pet_health[actor_key]) - maxf(0.0, damage)
	_battle_pet_health[actor_key] = next_health
	_attach_battle_health_bar(
		target,
		next_health,
		float(_battle_pet_max_health.get(actor_key, maxf(0.000001, next_health)))
	)
	if target.has_method("receive_battle_hit"):
		target.call("receive_battle_hit", knockback)
	if next_health <= 0.0:
		_defeat_battle_pet(target)


func _damage_battle_defender(target: Node2D, damage: float, knockback: float) -> void:
	_damage_battle_pet(target, damage, knockback)

func _on_enemy_defeated(enemy: Node2D, reward_count: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var defeat_position = enemy.position + Vector2(0.0, -62.0)
	var roster_changed := _battle_enemies.has(enemy)
	_battle_enemies.erase(enemy)
	if roster_changed:
		_mark_battle_enemy_roster_changed()
	_clear_battle_target_locks_for_enemy(enemy)
	_spawn_battle_reward(defeat_position, reward_count)
	_spawn_smoke_effect(defeat_position)
	enemy.queue_free()

func _on_enemy_swallowed(enemy: Node2D, reward_count: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var reward_position = enemy.position + Vector2(0.0, -18.0)
	var roster_changed := _battle_enemies.has(enemy)
	_battle_enemies.erase(enemy)
	if roster_changed:
		_mark_battle_enemy_roster_changed()
	_clear_battle_target_locks_for_enemy(enemy)
	_spawn_battle_reward(reward_position, reward_count)
	enemy.queue_free()

func _clear_battle_target_locks_for_enemy(enemy: Node2D) -> void:
	var actor_keys: Dictionary = {}
	for actor_key_value in _battle_pet_enemy_targets.keys():
		actor_keys[String(actor_key_value)] = true
	for actor_key_value in _battle_pet_pending_enemy_targets.keys():
		actor_keys[String(actor_key_value)] = true
	for actor_key_value in actor_keys.keys():
		var actor_key = String(actor_key_value)
		var target_value: Variant = _battle_pet_enemy_targets.get(actor_key, null)
		var pending_value: Variant = _battle_pet_pending_enemy_targets.get(actor_key, null)
		if (
			(_battle_pet_enemy_targets.has(actor_key) and (
				not is_instance_valid(target_value)
				or target_value == enemy
			))
			or (_battle_pet_pending_enemy_targets.has(actor_key) and (
				not is_instance_valid(pending_value)
				or pending_value == enemy
			))
		):
			_clear_battle_pet_target_cache(actor_key)

func _spawn_battle_reward(drop_position: Vector2, reward_count: int) -> void:
	_battle_defeated_enemies += 1
	if (
		_battle_visual_reward_drops >= BATTLE_REWARD_VISUAL_DROP_LIMIT
		or _coin_drops.size() >= DESKTOP_COIN_LIMIT
	):
		return
	var visual_type := CoinDrop.get_visual_type_for_value(reward_count)
	var visual_coin: Node2D = _host._spawn_coin(
		visual_type,
		drop_position + Vector2(
			_rng.randf_range(-12.0, 12.0),
			_rng.randf_range(-14.0, 8.0)
		)
	)
	if visual_coin != null and is_instance_valid(visual_coin):
		visual_coin.set("value", 0)
		visual_coin.set_meta("battle_reward_visual", true)
		_battle_visual_reward_drops += 1

func _defeat_battle_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id = _host._get_actor_pet_id(actor)
	var actor_key = str(actor.get_instance_id())
	_battle_pet_health.erase(actor_key)
	_battle_pet_max_health.erase(actor_key)
	_battle_pet_attack_at.erase(actor_key)
	_battle_pet_target_x.erase(actor_key)
	_battle_pet_formed.erase(actor_key)
	_clear_battle_pet_target_cache(actor_key)
	_battle_pet5_rolls.erase(actor_key)
	# Settle a paid offering before this actor leaves every runtime roster. The
	# feed also keeps a pet_id fallback, but closing the lifecycle here prevents
	# a stale target from surviving until the next world-maintenance tick.
	_host._finish_pending_offering_for_actor(actor)
	_spawn_smoke_effect(actor.position + Vector2(0.0, -58.0))
	if actor.has_method("hide_for_battle_defeat"):
		actor.call("hide_for_battle_defeat")
	_set_pet_recovery(pet_id)
	_deployed_pet_ids.erase(pet_id)
	_pets.erase(actor)
	_next_pet_coin_drop_at.erase(actor_key)
	_pet_coin_drop_intervals.erase(actor_key)
	_host._clear_pet_runtime_effects(pet_id)
	_battle_save_pending = true
	if _hovered_pet == actor:
		_hovered_pet = null
	if _selected_pet_id == pet_id:
		_selected_pet_id = _host._get_first_desktop_pet_id()
	actor.queue_free()
	_pet_upgrade_stats_dirty = true


func _set_pet_recovery(pet_id: String) -> void:
	if pet_id.is_empty():
		return
	var state = _host._get_pet_state(pet_id)
	var rarity = clampi(int(PetCatalog.get_definition(pet_id).get("rarity_stars", 1)), 1, 5)
	var duration = clampf(
		BATTLE_PET_RECOVERY_MIN_SECONDS + float(rarity - 1) * 18.0,
		BATTLE_PET_RECOVERY_MIN_SECONDS,
		BATTLE_PET_RECOVERY_MAX_SECONDS
	)
	var now = _host._get_now_seconds()
	state["recovery_started_at"] = now
	state["recover_until"] = now + duration
	state["recovery_duration"] = duration
	_pet_states[pet_id] = state

func _cancel_battle_for_debug() -> void:
	# Replacing a debug encounter must not award a win or synchronously create a
	# burst of smoke/broadcast nodes for the old battlefield.
	_finish_battle(false, true)


func _finish_battle(victory: bool, suppress_presentation := false) -> void:
	if not _battle_active:
		return
	var was_final_boss_encounter := BattleBalance.is_final_boss_schedule(_battle_wave_schedule)
	var settlement = _get_battle_reward_budget(_get_battle_difficulty_scale())
	var settlement_gold = int(settlement.get("gold", 0))
	var settlement_faith = int(settlement.get("faith", 0))
	if victory:
		_gold_coins = CurrencyDisplay.add_gold(_gold_coins, settlement_gold)
		_faith_points += float(settlement_faith)
		_lifetime_faith += float(settlement_faith)
		_battle_victories += 1
	_battle_active = false
	_battle_started_at = 0.0
	_battle_ends_at = 0.0
	if _pilgrimage_status_label != null:
		_pilgrimage_status_label.visible = false
	for enemy in _battle_enemies:
		if is_instance_valid(enemy):
			if not suppress_presentation:
				_spawn_smoke_effect(enemy.position + Vector2(0.0, -62.0))
			enemy.queue_free()
	_battle_enemies.clear()
	for effect in _battle_effects.duplicate():
		if is_instance_valid(effect):
			effect.queue_free()
	_battle_effects.clear()
	_clear_battle_runtime_nodes()
	for pet in _pets:
		if is_instance_valid(pet):
			_remove_battle_health_bar(pet)
			if pet.has_method("set_battle_mode"):
				pet.call("set_battle_mode", false)
	_battle_pet_health.clear()
	_battle_pet_max_health.clear()
	_battle_pet_attack_at.clear()
	_battle_pet_target_x.clear()
	_battle_pet_formed.clear()
	_reset_battle_pet_target_cache()
	_battle_pet5_rolls.clear()
	_battle_wave_schedule.clear()
	_battle_enemy_damage_multiplier = 1.0
	_active_battle_difficulty_scale = -1.0
	_host._update_actor_window_bounds()
	var now = _host._get_now_seconds()
	_host._schedule_next_battle(now)
	_last_believer_spawn_at = now
	_host._schedule_next_believer_spawn(now)
	_host._sync_achievement_state()
	if suppress_presentation:
		# A pet may already have been defeated before a debug replacement. Preserve
		# that real state without rebuilding every visible panel during the swap.
		if _battle_save_pending:
			_host._sync_inventory_window()
			_host._sync_shop_state()
			_host._refresh_pet_stats(true)
			_host._request_save()
		_battle_save_pending = false
		return
	var title = "BATTLE WON" if victory and _language == "en" else "BATTLE ENDED" if _language == "en" else "战斗胜利" if victory else "防线失守"
	var settlement_gold_text := CurrencyDisplay.format_compact(settlement_gold)
	var subtitle = (
		"LOOT: %s + %d FAITH · %d ENEMIES DEFEATED" % [settlement_gold_text, settlement_faith, _battle_defeated_enemies]
		if victory and _language == "en"
		else "战利品结算：%s + %d 信仰 · 击退 %d 名敌人" % [settlement_gold_text, settlement_faith, _battle_defeated_enemies]
		if victory
		else "Surviving pets have left the field" if _language == "en" else "受伤宠物已返回仓库休整"
	)
	_host._show_pilgrimage_broadcast(title, subtitle, {
		"title_en": "BATTLE WON" if victory else "BATTLE ENDED",
		"subtitle_en": (
			"LOOT: %s + %d FAITH · %d ENEMIES DEFEATED" % [settlement_gold_text, settlement_faith, _battle_defeated_enemies]
			if victory
			else "Surviving pets have left the field"
		),
		"title_zh": "战斗胜利" if victory else "防线失守",
		"subtitle_zh": (
			"战利品结算：%s + %d 信仰 · 击退 %d 名敌人" % [settlement_gold_text, settlement_faith, _battle_defeated_enemies]
			if victory
			else "受伤宠物已返回仓库休整"
		)
	}, settlement_gold if victory else 0)
	if victory:
		_host._show_faith_change_popup(
			Vector2(
				float(_pet_window_size.x) * 0.5,
				minf(float(_pet_window_size.y) - 84.0, float(_pet_window_size.y) * 0.72)
			),
			float(settlement_faith)
		)
	_host._publish_news({
		"category": "公告",
		"headline": "战斗结束。被击倒的宠物已返回仓库休整。",
		"headline_en": "The battle ended. Defeated pets are recovering in storage."
	}, true, false)
	_host._sync_inventory_window()
	_host._sync_shop_state()
	_host._refresh_pet_stats(true)
	if victory or _battle_save_pending:
		_host._request_save()
	_battle_save_pending = false
	if victory and was_final_boss_encounter:
		_host._on_final_boss_defeated()

func _clear_battle_runtime_nodes() -> void:
	for child in get_children():
		if is_instance_valid(child) and bool(child.get_meta("battle_runtime", false)):
			child.queue_free()

func _update_battle_status(now: float) -> void:
	if _pilgrimage_status_label == null:
		return
	var seconds_left = maxi(0, int(ceil(_battle_ends_at - now)))
	_pilgrimage_status_label.text = (
		"BATTLE  %02d:%02d  ·  %d ENEMIES"
		if _language == "en"
		else "战斗  %02d:%02d  ·  敌人 %d"
	) % [int(seconds_left / 60), seconds_left % 60, _battle_enemies.size()]
	_pilgrimage_status_label.visible = _battle_active

func _spawn_smoke_effect(effect_position: Vector2) -> void:
	var frames = _get_smoke_frames()
	if frames == null:
		return
	var smoke = AnimatedSprite2D.new()
	smoke.sprite_frames = frames
	smoke.position = effect_position
	smoke.scale = Vector2.ONE * 1.35
	smoke.z_index = 350
	add_child(smoke)
	smoke.animation_finished.connect(smoke.queue_free)
	smoke.play("smoke")

func _get_smoke_frames() -> SpriteFrames:
	if _smoke_frames != null:
		return _smoke_frames
	var sheet = load(SMOKE_SHEET_TEXTURE) as Texture2D
	if sheet == null:
		return null
	_smoke_frames = SpriteFrames.new()
	_smoke_frames.remove_animation("default")
	_smoke_frames.add_animation("smoke")
	_smoke_frames.set_animation_loop("smoke", false)
	_smoke_frames.set_animation_speed("smoke", 14.0)
	var frame_width = float(sheet.get_width()) / float(SMOKE_FRAME_COUNT)
	for frame_index in SMOKE_FRAME_COUNT:
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(sheet.get_height()))
		_smoke_frames.add_frame("smoke", atlas)
	return _smoke_frames
