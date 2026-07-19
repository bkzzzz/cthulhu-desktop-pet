extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const EconomyBalance = preload("res://scripts/domain/economy_balance.gd")
const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")

const OPENING_SECONDS := 10.0
const ACTIVE_CAMPAIGN_MIN_HOURS := 40.0
const ACTIVE_CAMPAIGN_MAX_HOURS := 60.0
const PASSIVE_CAMPAIGN_MIN_HOURS := 80.0
const PASSIVE_CAMPAIGN_MAX_HOURS := 100.0
const ROSTER_UNLOCK_MAX_MINUTES := 5.0
const ALL_LEVEL_10_MAX_MINUTES := 8.0
const ALL_LEVEL_20_MAX_MINUTES := 15.0
const ALL_LEVEL_50_MAX_HOURS := 8.0
const MAX_SIMULATION_STEPS := 2000
const OFFERING_ACTIVE_BONUS_MIN := 0.23
const OFFERING_ACTIVE_BONUS_MAX := 0.30


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
	if GachaProgression.draw_cost(0) < 1 or GachaProgression.draw_cost(0) > 5:
		failures.append("the opening gacha price must suit a scarce click-earned currency")
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
	var five_star_duplicate := GachaProgression.roll_pet(
		0.89,
		PetCatalog.ACTIVE_DESKTOP_PETS,
		0,
		1_000_000.0
	)
	var two_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, two_star_duplicate)
	var five_star_reward := GachaProgression.duplicate_faith_reward(draw_cost, five_star_duplicate)
	if two_star_reward != 650:
		failures.append("a duplicate two-star pet must return a clear 65% faith reward")
	if five_star_reward <= draw_cost or five_star_reward <= two_star_reward:
		failures.append("a duplicate five-star pet must feel like a faith jackpot")


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
	_check_campaign_milestones(passive_campaign, failures)


static func _simulate_campaign(earned_faith_multiplier := 1.0) -> Dictionary:
	var levels := {"pet1": 1}
	var unlocked: Array[String] = ["pet1"]
	var faith := 0.0
	var gold := 0.0
	var elapsed_seconds := 0.0
	var draw_count := 0
	var gacha_gold_spent := 0.0
	var duplicate_faith_earned := 0.0
	var steps := 0
	var milestone_hours := {
		"roster_unlocked": INF,
		"all_level_10": INF,
		"all_level_20": INF,
		"all_level_50": INF,
		"all_level_100": INF
	}

	# Gold and faith advance over the same wall-clock time, but they never pay
	# each other's costs. Unlock the roster as soon as collectible gold can fund
	# each worst-case pity cycle; accumulated faith remains available for levels.
	while (
		unlocked.size() < PetCatalog.ACTIVE_DESKTOP_PETS.size()
		and steps < MAX_SIMULATION_STEPS
	):
		steps += 1
		var faith_rate := _total_rate(levels, unlocked)
		var gold_rate_per_second := _total_coin_rate(levels, unlocked) / 60.0
		if faith_rate <= 0.0 or gold_rate_per_second <= 0.0:
			break
		var draw_amount := (
			1
			if draw_count == 0
			else GachaProgression.NEW_PET_PITY_DRAWS
		)
		var cycle_cost := GachaProgression.draw_cost_total(draw_count, draw_amount)
		var wait_seconds := maxf(
			0.0,
			(cycle_cost - gold) / gold_rate_per_second
		)
		faith += faith_rate * maxf(1.0, earned_faith_multiplier) * wait_seconds
		gold = maxf(
			0.0,
			gold + gold_rate_per_second * wait_seconds - cycle_cost
		)
		elapsed_seconds += wait_seconds
		gacha_gold_spent += cycle_cost

		for draw_offset in draw_amount:
			var draw_cost := GachaProgression.draw_cost(draw_count)
			if draw_offset < draw_amount - 1:
				var duplicate_reward := float(
					_two_star_duplicate_reward(draw_cost)
				)
				faith += duplicate_reward
				duplicate_faith_earned += duplicate_reward
			draw_count += 1

		var next_pet_id := String(
			PetCatalog.ACTIVE_DESKTOP_PETS[unlocked.size()]
		)
		unlocked.append(next_pet_id)
		levels[next_pet_id] = 1
		if unlocked.size() == PetCatalog.ACTIVE_DESKTOP_PETS.size():
			milestone_hours["roster_unlocked"] = elapsed_seconds / 3600.0

	while not _campaign_complete(levels, unlocked) and steps < MAX_SIMULATION_STEPS:
		steps += 1
		var total_rate := (
			_total_rate(levels, unlocked)
			* maxf(1.0, earned_faith_multiplier)
		)
		var action := _best_upgrade_action(levels, unlocked)
		if action.is_empty() or total_rate <= 0.0:
			break

		var pet_id := String(action.get("pet_id", ""))
		var cost := float(action.get("cost", INF))
		var wait_seconds := maxf(0.0, (cost - faith) / total_rate)
		faith = maxf(0.0, faith + total_rate * wait_seconds - cost)
		elapsed_seconds += wait_seconds
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
		"gacha_gold_spent": gacha_gold_spent,
		"gacha_faith_spent": 0.0,
		"duplicate_faith_earned": duplicate_faith_earned,
		"milestone_hours": milestone_hours,
		"levels": levels,
		"steps": steps
	}


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
	var checks := [
		["roster_unlocked", ROSTER_UNLOCK_MAX_MINUTES / 60.0, "full roster"],
		["all_level_10", ALL_LEVEL_10_MAX_MINUTES / 60.0, "all pets Lv.10"],
		["all_level_20", ALL_LEVEL_20_MAX_MINUTES / 60.0, "all pets Lv.20"],
		["all_level_50", ALL_LEVEL_50_MAX_HOURS, "all pets Lv.50"]
	]
	for check_value in checks:
		var check: Array = check_value
		var elapsed_hours := float(milestones.get(String(check[0]), INF))
		var maximum_hours := float(check[1])
		if elapsed_hours > maximum_hours:
			failures.append(
				"%s milestone must arrive within %.2f hours, got %.2f"
				% [String(check[2]), maximum_hours, elapsed_hours]
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
	if guarantee_cycle_cost > 15:
		failures.append("the opening guarantee cycle must remain affordable with click-earned coins")
	var late_cost := GachaProgression.draw_cost(1000000)
	if late_cost <= 0 or late_cost != GachaProgression.MAX_DRAW_COST or late_cost > 20:
		failures.append("late-game draw costs must remain positive and capped at a small amount")


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
	if int(starter_goods[0].get("price", 0)) != int(base_goods[0].get("price", 0)):
		failures.append("the first food must retain its affordable authored opening price")

	var level_one_states := {}
	var campaign_states := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		level_one_states[pet_id] = {"upgrade_level": 1}
		# Potential income derives evolution from the campaign level even if a
		# frame has not yet persisted the redundant evolved flag.
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
