extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const EconomyBalance = preload("res://scripts/domain/economy_balance.gd")
const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")

const OPENING_SECONDS := 10.0
const EARLY_CHECKPOINT_SECONDS := {
	"10_minutes": 10.0 * 60.0,
	"30_minutes": 30.0 * 60.0,
	"1_hour": 1.0 * 3600.0,
	"3_hours": 3.0 * 3600.0,
	"5_hours": 5.0 * 3600.0
}
const ACTIVE_CAMPAIGN_MIN_HOURS := 82.0
const ACTIVE_CAMPAIGN_MAX_HOURS := 98.0
const PASSIVE_CAMPAIGN_MIN_HOURS := 105.0
const PASSIVE_CAMPAIGN_MAX_HOURS := 118.0
const MAX_SIMULATION_STEPS := 2000
const OFFERING_ACTIVE_BONUS_MIN := 0.115
const OFFERING_ACTIVE_BONUS_MAX := 0.155


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_starter_curve(failures)
	_check_unlock_curve(failures)
	_check_duplicate_reward(failures)
	_check_accelerating_output(failures)
	_check_full_upgrade_cost_curve(failures)
	_check_endless_payback_curve(failures)
	_check_campaign_curve(failures)
	_check_draw_price_curve(failures)
	_check_dynamic_offering_prices(failures)
	return failures


static func _check_starter_curve(failures: Array[String]) -> void:
	var starter_rate := _pet_rate("pet1", 1)
	if starter_rate <= 0.0 or starter_rate >= 1.0:
		failures.append("pet1 must provide a small positive opening faith rate, got %.6f/s" % starter_rate)
	if GachaProgression.draw_cost(0) < 8 or GachaProgression.draw_cost(0) > 20:
		failures.append("the first gacha pull must be reachable during the opening minutes")
	if PetCatalog.STARTER_UNLOCKED_PETS != ["pet1"]:
		failures.append("a fresh game must begin with only pet1 unlocked")
	var first_upgrade_seconds := (
		float(PetProgression.upgrade_cost(
			PetCatalog.get_definition("pet1"),
			{"upgrade_level": 1}
		))
		/ maxf(starter_rate, 0.0000001)
	)
	if first_upgrade_seconds > OPENING_SECONDS:
		failures.append(
			"the starter's first passive upgrade must arrive within %.0f seconds, got %.1f"
			% [OPENING_SECONDS, first_upgrade_seconds]
		)
	var starter_data := PetCatalog.get_definition("pet1")
	var starter_coin_rate := PetProgression.money_drop_value_per_minute(
		starter_data,
		1
	)
	if starter_coin_rate <= float(starter_data.get("base_money_rate", 0.0)):
		failures.append("starter gold income must receive a temporary opening boost")
	var settled_coin_rate := PetProgression.money_drop_value_per_minute(
		starter_data,
		int(PetProgression.OPENING_MONEY_BOOST_END_LEVEL)
	)
	var expected_settled_rate := (
		float(starter_data.get("base_money_rate", 0.0))
		* pow(
			PetProgression.MONEY_LEVEL_GROWTH,
			PetProgression.OPENING_MONEY_BOOST_END_LEVEL - 1.0
		)
	)
	if not is_equal_approx(settled_coin_rate, expected_settled_rate):
		failures.append("the temporary gold boost must fully taper out by its end level")


static func _check_unlock_curve(failures: Array[String]) -> void:
	var starter_rate := _pet_rate("pet1", 1)
	var complete_rate := 0.0
	var previous_base_rate := -1.0
	var previous_upgrade_base := -1
	var previous_gold_rate := -1.0
	var previous_combat_power := -1.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var pet_data := PetCatalog.get_definition(pet_id)
		var base_rate := float(pet_data.get("base_fps", 0.0))
		var upgrade_base := int(pet_data.get("upgrade_cost_base", 0))
		var gold_rate := float(pet_data.get("base_money_rate", 0.0))
		var combat_power := float(PetCatalog.BASE_COMBAT_POWER.get(pet_id, 0.0))
		complete_rate += _pet_rate(pet_id, 1)
		if (
			base_rate <= previous_base_rate
			or upgrade_base <= previous_upgrade_base
			or gold_rate <= previous_gold_rate
			or combat_power <= previous_combat_power
		):
			failures.append("pet faith, upgrade, gold and combat bases must rise monotonically by tier")
			break
		previous_base_rate = base_rate
		previous_upgrade_base = upgrade_base
		previous_gold_rate = gold_rate
		previous_combat_power = combat_power
	if complete_rate <= starter_rate:
		failures.append("unlocking additional pets must materially increase passive faith production")
	for pet_id_value in PetCatalog.GACHA_PETS:
		if _pet_rate(String(pet_id_value), 1) <= 0.0:
			failures.append("every gacha pet must begin producing faith immediately after unlock")


static func _check_duplicate_reward(failures: Array[String]) -> void:
	var draw_cost := 1000
	var two_star_duplicate := GachaProgression.roll_pet(0.8, ["pet1", "pet2"], 0)
	var five_star_duplicate := GachaProgression.roll_pet(
		0.93,
		PetCatalog.ACTIVE_DESKTOP_PETS,
		0,
		1_000_000.0
	)
	var two_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, two_star_duplicate)
	var five_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, five_star_duplicate)
	if two_star_reward != 100:
		failures.append("a duplicate two-star pet must return the balanced 10% faith exchange")
	if five_star_reward != 180 or five_star_reward <= two_star_reward:
		failures.append("a duplicate five-star pet must return the balanced premium exchange")


static func _check_accelerating_output(failures: Array[String]) -> void:
	var early_gain := _base_pet_rate("pet1", 21) - _base_pet_rate("pet1", 20)
	var middle_gain := _base_pet_rate("pet1", 61) - _base_pet_rate("pet1", 60)
	var late_gain := _base_pet_rate("pet1", 100) - _base_pet_rate("pet1", 99)
	var post_target_gain := _base_pet_rate("pet1", 101) - _base_pet_rate("pet1", 100)
	if not (early_gain < middle_gain and middle_gain < late_gain):
		failures.append("faith gained per upgrade must visibly accelerate from early to late game")
	if post_target_gain <= 0.0:
		failures.append("endless production must keep increasing after the campaign target")


static func _check_full_upgrade_cost_curve(failures: Array[String]) -> void:
	var early_pet_data := PetCatalog.get_definition("pet3")
	var early_level := 1
	var full_early_cost := int(round(
		float(early_pet_data.get("upgrade_cost_base", 1))
		* pow(
			float(early_pet_data.get("upgrade_cost_growth", 1.0)),
			float(early_level)
		)
	))
	var discounted_early_cost := PetProgression.upgrade_cost(
		early_pet_data,
		{"upgrade_level": early_level}
	)
	if discounted_early_cost >= full_early_cost:
		failures.append("Pets 1-5 must receive a meaningful initial upgrade discount")
	var mid_pet_data := PetCatalog.get_definition("pet6")
	var full_mid_cost := int(round(
		float(mid_pet_data.get("upgrade_cost_base", 1))
		* float(mid_pet_data.get("upgrade_cost_growth", 1.0))
	))
	if PetProgression.upgrade_cost(
		mid_pet_data,
		{"upgrade_level": 1}
	) != full_mid_cost:
		failures.append("the opening upgrade discount must not spill into Pet 6+")

	var pet_data := {
		"upgrade_cost_base": 100,
		"upgrade_cost_growth": 1.18
	}
	var level := 25
	var expected := int(round(100.0 * pow(1.18, float(level))))
	var actual := PetProgression.upgrade_cost(
		pet_data,
		{"upgrade_level": level}
	)
	if actual != expected:
		failures.append(
			"campaign upgrades must retain their full authored cost: expected %d, got %d"
			% [expected, actual]
		)


static func _check_endless_payback_curve(failures: Array[String]) -> void:
	var pet_data := PetCatalog.get_definition("pet10")
	var previous_rate := 0.0
	for level in [100, 200, 500, 1000, 5000]:
		var evolved_rate := (
			PetProgression.faith_per_second(pet_data, level)
			* PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER
		)
		var cost := PetProgression.upgrade_cost(
			pet_data,
			{"upgrade_level": level}
		)
		var self_payback_seconds := float(cost) / maxf(evolved_rate, 0.0000001)
		if self_payback_seconds < 43_000.0:
			failures.append(
				"endless Lv.%d upgrade payback collapsed to %.1f seconds"
				% [level, self_payback_seconds]
			)
		if evolved_rate <= previous_rate:
			failures.append("endless pet production must remain monotonic at Lv.%d" % level)
		previous_rate = evolved_rate


static func _check_campaign_curve(failures: Array[String]) -> void:
	var passive_campaign := _simulate_campaign()
	var active_campaign := _simulate_campaign(
		EconomyBalance.EXPECTED_ACTIVE_FAITH_MULTIPLIER
	)
	var imperfect_collection_campaign := _simulate_campaign(1.0, 0.70)
	var passive_hours := float(passive_campaign.get("elapsed_hours", INF))
	var active_hours := float(active_campaign.get("elapsed_hours", INF))
	if (
		passive_hours < PASSIVE_CAMPAIGN_MIN_HOURS
		or passive_hours > PASSIVE_CAMPAIGN_MAX_HOURS
	):
		failures.append(
			"passive campaign must finish in %.0f-%.0f hours, got %.2f (target %.0f)"
			% [
				PASSIVE_CAMPAIGN_MIN_HOURS,
				PASSIVE_CAMPAIGN_MAX_HOURS,
				passive_hours,
				PetProgression.CAMPAIGN_PASSIVE_TARGET_HOURS
			]
		)
	if (
		active_hours < ACTIVE_CAMPAIGN_MIN_HOURS
		or active_hours > ACTIVE_CAMPAIGN_MAX_HOURS
	):
		failures.append(
			"active campaign must finish in %.0f-%.0f hours, got %.2f (target %.0f)"
			% [
				ACTIVE_CAMPAIGN_MIN_HOURS,
				ACTIVE_CAMPAIGN_MAX_HOURS,
				active_hours,
				PetProgression.CAMPAIGN_TARGET_HOURS
			]
		)
	if not bool(passive_campaign.get("completed", false)):
		failures.append("campaign simulation must unlock every pet and reach the level target")
	if not bool(active_campaign.get("completed", false)):
		failures.append("active campaign simulation must reach the level target")
	if int(passive_campaign.get("steps", MAX_SIMULATION_STEPS)) >= MAX_SIMULATION_STEPS:
		failures.append("campaign economy simulation did not converge")
	if float(passive_campaign.get("gacha_gold_spent", 0.0)) <= 0.0:
		failures.append("campaign pet draws must spend the gold economy")
	if not is_zero_approx(float(passive_campaign.get("gacha_faith_spent", INF))):
		failures.append("campaign pet draws must never spend upgrade faith")
	if float(passive_campaign.get("duplicate_faith_earned", 0.0)) <= 0.0:
		failures.append("worst-case pity duplicates must return faith while unlocking")
	if int(passive_campaign.get("draw_count", 0)) != 45:
		failures.append("ten tiers must require the deterministic worst-case 45-draw pity path")
	if float(imperfect_collection_campaign.get("elapsed_hours", INF)) > 120.0:
		failures.append("70% ambient gold collection must still finish the campaign within 120 hours")
	_check_campaign_milestones(passive_campaign, failures)
	_check_active_unlock_milestones(active_campaign, failures)
	_check_early_checkpoints(passive_campaign, failures)


static func _simulate_campaign(
	earned_faith_multiplier := 1.0,
	gold_collection_efficiency := 1.0
) -> Dictionary:
	var levels := {"pet1": 1}
	var unlocked: Array[String] = ["pet1"]
	var faith := 0.0
	var gold := 0.0
	var elapsed_seconds := 0.0
	var draw_count := 0
	var pity_count := 0
	var gacha_gold_spent := 0.0
	var duplicate_faith_earned := 0.0
	var steps := 0
	var early_checkpoints := {}
	var milestone_hours := {
		"roster_unlocked": INF,
		"pet2_unlocked": INF,
		"pet3_unlocked": INF,
		"pet4_unlocked": INF,
		"pet5_unlocked": INF,
		"pet6_unlocked": INF,
		"pet7_unlocked": INF,
		"pet8_unlocked": INF,
		"pet9_unlocked": INF,
		"pet10_unlocked": INF,
		"all_level_10": INF,
		"all_level_20": INF,
		"all_level_50": INF,
		"all_level_100": INF
	}

	while not _campaign_complete(levels, unlocked) and steps < MAX_SIMULATION_STEPS:
		steps += 1
		var baseline_faith_rate := _total_rate(levels, unlocked)
		var earned_faith_rate := (
			baseline_faith_rate
			* maxf(1.0, earned_faith_multiplier)
		)
		var gold_rate_per_second := (
			_total_coin_rate(levels, unlocked)
			/ 60.0
			* clampf(gold_collection_efficiency, 0.0, 1.0)
		)
		if earned_faith_rate <= 0.0 or gold_rate_per_second <= 0.0:
			break

		var unlocked_lookup := GachaProgression.make_unlocked_lookup(unlocked)
		var locked_pool := GachaProgression.make_locked_pool(
			unlocked_lookup,
			baseline_faith_rate
		)
		var next_draw_cost := float(GachaProgression.draw_cost(draw_count))
		if not locked_pool.is_empty() and gold + 0.000001 >= next_draw_cost:
			var result := GachaProgression.roll_pet(
				0.0,
				unlocked,
				pity_count,
				baseline_faith_rate
			)
			if result.is_empty():
				break
			gold = maxf(0.0, gold - next_draw_cost)
			gacha_gold_spent += next_draw_cost
			draw_count += 1
			if bool(result.get("is_new", false)):
				var new_pet_id := String(result.get("pet_id", ""))
				if new_pet_id.is_empty() or unlocked.has(new_pet_id):
					break
				unlocked.append(new_pet_id)
				levels[new_pet_id] = 1
				milestone_hours["%s_unlocked" % new_pet_id] = elapsed_seconds / 3600.0
				if unlocked.size() == PetCatalog.ACTIVE_DESKTOP_PETS.size():
					milestone_hours["roster_unlocked"] = elapsed_seconds / 3600.0
			else:
				var duplicate_reward := float(
					GachaProgression.duplicate_faith_reward(int(next_draw_cost), result)
				)
				faith += duplicate_reward
				duplicate_faith_earned += duplicate_reward
			pity_count = GachaProgression.next_pity_count(pity_count, result)
			continue

		var action := _best_upgrade_action(levels, unlocked)
		if action.is_empty():
			break
		var pet_id := String(action.get("pet_id", ""))
		var cost := float(action.get("cost", INF))
		var upgrade_wait_seconds := maxf(
			0.0,
			(cost - faith) / earned_faith_rate
		)
		var draw_wait_seconds := INF
		if not locked_pool.is_empty():
			draw_wait_seconds = maxf(
				0.0,
				(next_draw_cost - gold) / gold_rate_per_second
			)
		var wait_seconds := minf(upgrade_wait_seconds, draw_wait_seconds)
		if not is_finite(wait_seconds):
			break
		_record_early_checkpoints(
			early_checkpoints,
			levels,
			unlocked,
			draw_count,
			elapsed_seconds,
			wait_seconds,
			faith,
			gold,
			earned_faith_rate,
			gold_rate_per_second
		)
		faith += earned_faith_rate * wait_seconds
		gold += gold_rate_per_second * wait_seconds
		elapsed_seconds += wait_seconds
		if upgrade_wait_seconds <= draw_wait_seconds + 0.000001:
			faith = maxf(0.0, faith - cost)
			levels[pet_id] = int(levels.get(pet_id, 1)) + 1
			_record_campaign_milestones(
				levels,
				unlocked,
				elapsed_seconds,
				milestone_hours
			)

	return {
		"completed": _campaign_complete(levels, unlocked),
		"elapsed_hours": elapsed_seconds / 3600.0,
		"draw_count": draw_count,
		"pity_count": pity_count,
		"gacha_gold_spent": gacha_gold_spent,
		"gacha_faith_spent": 0.0,
		"duplicate_faith_earned": duplicate_faith_earned,
		"milestone_hours": milestone_hours,
		"early_checkpoints": early_checkpoints,
		"levels": levels,
		"steps": steps
	}


static func _record_early_checkpoints(
	checkpoints: Dictionary,
	levels: Dictionary,
	unlocked: Array[String],
	draw_count: int,
	elapsed_seconds: float,
	wait_seconds: float,
	faith: float,
	gold: float,
	faith_rate: float,
	gold_rate: float
) -> void:
	var wait_end := elapsed_seconds + wait_seconds
	for checkpoint_name_value in EARLY_CHECKPOINT_SECONDS:
		var checkpoint_name := String(checkpoint_name_value)
		if checkpoints.has(checkpoint_name):
			continue
		var checkpoint_seconds := float(EARLY_CHECKPOINT_SECONDS[checkpoint_name])
		if checkpoint_seconds < elapsed_seconds or checkpoint_seconds > wait_end:
			continue
		var projected_seconds := checkpoint_seconds - elapsed_seconds
		checkpoints[checkpoint_name] = {
			"unlocked_count": unlocked.size(),
			"draw_count": draw_count,
			"faith": faith + (faith_rate * projected_seconds),
			"gold": gold + (gold_rate * projected_seconds),
			"levels": levels.duplicate(true)
		}


static func _check_early_checkpoints(
	campaign: Dictionary,
	failures: Array[String]
) -> void:
	var checkpoints_value: Variant = campaign.get("early_checkpoints", {})
	var checkpoints: Dictionary = (
		checkpoints_value if checkpoints_value is Dictionary else {}
	)
	var minimum_draws := {
		"10_minutes": 4,
		"30_minutes": 7,
		"1_hour": 10,
		"3_hours": 15,
		"5_hours": 20
	}
	var minimum_pets := {
		"10_minutes": 1,
		"30_minutes": 2,
		"1_hour": 3,
		"3_hours": 4,
		"5_hours": 5
	}
	for checkpoint_name_value in EARLY_CHECKPOINT_SECONDS:
		var checkpoint_name := String(checkpoint_name_value)
		var snapshot_value: Variant = checkpoints.get(checkpoint_name, {})
		var snapshot: Dictionary = (
			snapshot_value if snapshot_value is Dictionary else {}
		)
		if snapshot.is_empty():
			failures.append("campaign simulation must record the %s checkpoint" % checkpoint_name)
			continue
		if int(snapshot.get("draw_count", 0)) < int(minimum_draws[checkpoint_name]):
			failures.append("opening gacha pace is too slow at %s" % checkpoint_name)
		if int(snapshot.get("unlocked_count", 0)) < int(minimum_pets[checkpoint_name]):
			failures.append("opening pet unlock pace is too slow at %s" % checkpoint_name)


static func _record_campaign_milestones(
	levels: Dictionary,
	unlocked: Array[String],
	elapsed_seconds: float,
	milestone_hours: Dictionary
) -> void:
	for target_level in [10, 20, 50, 100]:
		var key := "all_level_%d" % target_level
		if is_finite(float(milestone_hours.get(key, INF))):
			continue
		if _all_pets_at_least(levels, unlocked, target_level):
			milestone_hours[key] = elapsed_seconds / 3600.0


static func _all_pets_at_least(
	levels: Dictionary,
	unlocked: Array[String],
	target_level: int
) -> bool:
	if unlocked.size() < PetCatalog.ACTIVE_DESKTOP_PETS.size():
		return false
	for pet_id in unlocked:
		if int(levels.get(pet_id, 0)) < target_level:
			return false
	return true


static func _check_campaign_milestones(
	campaign: Dictionary,
	failures: Array[String]
) -> void:
	var milestones_value: Variant = campaign.get("milestone_hours", {})
	var milestones: Dictionary = (
		milestones_value if milestones_value is Dictionary else {}
	)
	var maximum_checks := [
		["pet2_unlocked", 1.5, "Pet 2"],
		["pet3_unlocked", 4.0, "Pet 3"],
		["pet4_unlocked", 8.0, "Pet 4"],
		["pet5_unlocked", 13.0, "Pet 5"],
		["pet6_unlocked", 24.0, "Pet 6"],
		["pet7_unlocked", 40.0, "Pet 7"],
		["pet8_unlocked", 60.0, "Pet 8"],
		["pet9_unlocked", 82.0, "Pet 9"],
		["pet10_unlocked", 100.0, "Pet 10"]
	]
	for check_value in maximum_checks:
		var check: Array = check_value
		var elapsed_hours := float(milestones.get(String(check[0]), INF))
		var maximum_hours := float(check[1])
		if elapsed_hours > maximum_hours:
			failures.append(
				"%s must unlock within %.2f hours, got %.2f"
				% [String(check[2]), maximum_hours, elapsed_hours]
			)
	var minimum_checks := [
		["pet3_unlocked", 0.5, "Pet 3"],
		["pet5_unlocked", 4.0, "Pet 5"],
		["pet6_unlocked", 16.0, "Pet 6"],
		["pet7_unlocked", 28.0, "Pet 7"],
		["pet9_unlocked", 65.0, "Pet 9"],
		["pet10_unlocked", 82.0, "Pet 10"]
	]
	for check_value in minimum_checks:
		var check: Array = check_value
		var elapsed_hours := float(milestones.get(String(check[0]), -INF))
		var minimum_hours := float(check[1])
		if elapsed_hours < minimum_hours:
			failures.append(
				"%s must remain gated until %.2f hours, got %.2f"
				% [String(check[2]), minimum_hours, elapsed_hours]
			)


static func _check_active_unlock_milestones(
	campaign: Dictionary,
	failures: Array[String]
) -> void:
	var milestones_value: Variant = campaign.get("milestone_hours", {})
	var milestones: Dictionary = (
		milestones_value if milestones_value is Dictionary else {}
	)
	var pet10_hours := float(milestones.get("pet10_unlocked", INF))
	if pet10_hours < 68.0 or pet10_hours > 80.0:
		failures.append(
			"engaged play must reach Pet 10 in the 68-80 hour late-game window, got %.2f"
			% pet10_hours
		)


static func _best_upgrade_action(
	levels: Dictionary,
	unlocked: Array[String]
) -> Dictionary:
	var best_action: Dictionary = {}
	var best_payback := INF

	for pet_id in unlocked:
		var level := int(levels.get(pet_id, 1))
		if level >= PetProgression.CAMPAIGN_PET_LEVEL_TARGET:
			continue
		var pet_data := PetCatalog.get_definition(pet_id)
		var current_rate := _pet_rate(pet_id, level)
		var next_rate := _pet_rate(pet_id, level + 1)
		var rate_gain := next_rate - current_rate
		var cost := PetProgression.upgrade_cost(pet_data, {"upgrade_level": level})
		var payback := float(cost) / maxf(rate_gain, 0.0000001)
		if payback < best_payback:
			best_payback = payback
			best_action = {"pet_id": pet_id, "cost": cost}

	return best_action


static func _total_rate(levels: Dictionary, unlocked: Array[String]) -> float:
	var total := 0.0
	for pet_id in unlocked:
		total += _pet_rate(pet_id, int(levels.get(pet_id, 1)))
	return total


static func _total_coin_rate(levels: Dictionary, unlocked: Array[String]) -> float:
	var total := 0.0
	for pet_id in unlocked:
		var level := int(levels.get(pet_id, 1))
		var pet_rate := PetProgression.money_drop_value_per_minute(
			PetCatalog.get_definition(pet_id),
			level
		)
		if level >= PetProgression.CAMPAIGN_PET_LEVEL_TARGET:
			pet_rate *= PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER
		total += pet_rate
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
	if guarantee_cycle_cost < 90 or guarantee_cycle_cost > 150:
		failures.append("the opening guarantee cycle must form a reachable 90-150 gold objective")
	if GachaProgression.draw_cost(20) != (
		GachaProgression.BASE_DRAW_COST
		+ GachaProgression.DRAW_COST_QUADRATIC_STEP * 20 * 20
	):
		failures.append("the opening gacha discount must fully taper out after four pity cycles")
	var late_cost := GachaProgression.draw_cost(1000000)
	if late_cost <= 0 or late_cost != GachaProgression.MAX_DRAW_COST:
		failures.append("late-game draw costs must remain positive and safely capped")


static func _check_dynamic_offering_prices(failures: Array[String]) -> void:
	var base_goods := OfferingCatalog.make_shop_goods()
	var starter_states := {"pet1": {"upgrade_level": 1}}
	var starter_rate := EconomyBalance.potential_coin_rate_per_minute(
		["pet1"],
		starter_states
	)
	var starter_goods := EconomyBalance.make_dynamic_shop_goods(
		base_goods,
		starter_rate
	)
	if starter_goods.is_empty():
		failures.append("dynamic offering pricing must retain the catalog")
		return
	if int(starter_goods[0].get("price", 0)) <= int(base_goods[0].get("price", 0)):
		failures.append("even the first food must cost meaningful time at the starter pet-money rate")

	var level_one_states := {}
	var campaign_states := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		level_one_states[pet_id] = {"upgrade_level": 1}
		campaign_states[pet_id] = {"upgrade_level": 100}

	var level_one_rate := EconomyBalance.potential_coin_rate_per_minute(
		PetCatalog.ACTIVE_DESKTOP_PETS,
		level_one_states
	)
	var campaign_rate := EconomyBalance.potential_coin_rate_per_minute(
		PetCatalog.ACTIVE_DESKTOP_PETS,
		campaign_states
	)
	if level_one_rate <= starter_rate or campaign_rate <= level_one_rate:
		failures.append("potential coin income must grow with roster and pet levels")

	var level_one_goods := EconomyBalance.make_dynamic_shop_goods(
		base_goods,
		level_one_rate
	)
	var campaign_goods := EconomyBalance.make_dynamic_shop_goods(
		base_goods,
		campaign_rate
	)
	var repriced_campaign_goods := EconomyBalance.make_dynamic_shop_goods(
		level_one_goods,
		campaign_rate
	)

	var total_campaign_faith := 0.0
	var strongest_pet_faith := 0.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_rate := _pet_rate(
			String(pet_id_value),
			PetProgression.CAMPAIGN_PET_LEVEL_TARGET
		)
		total_campaign_faith += pet_rate
		strongest_pet_faith = maxf(strongest_pet_faith, pet_rate)
	var strongest_pet_share := strongest_pet_faith / maxf(
		total_campaign_faith,
		0.0000001
	)
	var smallest_sustainable_bonus := INF
	var largest_sustainable_bonus := 0.0

	for index in base_goods.size():
		var base_good: Dictionary = base_goods[index]
		var level_one_good: Dictionary = level_one_goods[index]
		var campaign_good: Dictionary = campaign_goods[index]
		var repriced_good: Dictionary = repriced_campaign_goods[index]
		var base_price := int(base_good.get("price", 0))
		var level_one_price := int(level_one_good.get("price", 0))
		var campaign_price := int(campaign_good.get("price", 0))
		if level_one_price <= base_price or campaign_price <= level_one_price:
			failures.append(
				"%s price must rise with potential gold production"
				% String(base_good.get("id", "offering"))
			)
		if campaign_price != int(repriced_good.get("price", -1)):
			failures.append("dynamic offering repricing must not compound an earlier price")

		var income_minutes := float(campaign_price) / maxf(campaign_rate, 0.0000001)
		var duration_minutes := float(base_good.get("duration_seconds", 0.0)) / 60.0
		var sustainable_bonus := (
			strongest_pet_share
			* maxf(0.0, float(base_good.get("multiplier", 1.0)) - 1.0)
			* duration_minutes
			/ maxf(income_minutes, 0.0000001)
		)
		smallest_sustainable_bonus = minf(
			smallest_sustainable_bonus,
			sustainable_bonus
		)
		largest_sustainable_bonus = maxf(
			largest_sustainable_bonus,
			sustainable_bonus
		)

	if (
		smallest_sustainable_bonus < OFFERING_ACTIVE_BONUS_MIN
		or largest_sustainable_bonus > OFFERING_ACTIVE_BONUS_MAX
	):
		failures.append(
			"sustainable food use must stay inside the %.0f-%.0f%% active-growth budget, got %.1f-%.1f%%"
			% [
				OFFERING_ACTIVE_BONUS_MIN * 100.0,
				OFFERING_ACTIVE_BONUS_MAX * 100.0,
				smallest_sustainable_bonus * 100.0,
				largest_sustainable_bonus * 100.0
			]
		)


static func _base_pet_rate(pet_id: String, level: int) -> float:
	return PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)


static func _pet_rate(pet_id: String, level: int) -> float:
	var rate := _base_pet_rate(pet_id, level)
	if level >= PetProgression.CAMPAIGN_PET_LEVEL_TARGET:
		rate *= PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER
	return rate
