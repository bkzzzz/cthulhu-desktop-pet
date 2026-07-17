extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")

const OPENING_SECONDS := 60.0


static func run() -> Array[String]:
	var failures: Array[String] = []
	_check_starter_curve(failures)
	_check_unlock_curve(failures)
	_check_duplicate_reward(failures)
	_check_draw_price_curve(failures)
	return failures


static func _check_starter_curve(failures: Array[String]) -> void:
	var starter_rate := _pet_rate("pet1", 1)
	if starter_rate <= 0.0 or starter_rate >= 1.0:
		failures.append("pet1 must provide a small positive opening faith rate, got %.6f/s" % starter_rate)
	if starter_rate * OPENING_SECONDS >= float(GachaProgression.draw_cost(0)):
		failures.append("the first passive minute must not automatically skip the opening progression")
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
	var common_duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	var legendary_duplicate := GachaProgression.roll_pet(0.999, PetCatalog.ACTIVE_DESKTOP_PETS, 0)
	var common_refund := GachaProgression.duplicate_faith_reward(draw_cost, common_duplicate)
	var legendary_refund := GachaProgression.duplicate_faith_reward(draw_cost, legendary_duplicate)
	if common_refund <= 0 or common_refund >= draw_cost:
		failures.append("a duplicate common pet must return some faith without refunding the full draw")
	if legendary_refund <= common_refund or legendary_refund >= draw_cost:
		failures.append("rarer duplicate pets must return more faith while preserving a draw cost")


static func _check_draw_price_curve(failures: Array[String]) -> void:
	var guarantee_cycle_cost := 0
	for draw_index in GachaProgression.NEW_PET_PITY_DRAWS:
		guarantee_cycle_cost += GachaProgression.draw_cost(draw_index)
	if guarantee_cycle_cost <= GachaProgression.draw_cost(0):
		failures.append("the full new-pet guarantee cycle must cost more than a single draw")
	var late_cost := GachaProgression.draw_cost(1000000)
	if late_cost <= 0 or late_cost > GachaProgression.MAX_DRAW_COST:
		failures.append("late-game draw costs must remain positive and safely capped")


static func _pet_rate(pet_id: String, level: int) -> float:
	return PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)
