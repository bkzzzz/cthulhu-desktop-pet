extends RefCounted

const AchievementProgression = preload("res://scripts/domain/achievement_progression.gd")
const PetUnlockProgression = preload("res://scripts/domain/pet_unlock_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if AchievementProgression.DEFINITIONS.size() < 12:
		failures.append("achievements must cover a substantial set of progression milestones")
	var seen_ids := {}
	for definition_value in AchievementProgression.DEFINITIONS:
		var definition := definition_value as Dictionary
		var achievement_id := String(definition.get("id", ""))
		if achievement_id.is_empty() or seen_ids.has(achievement_id):
			failures.append("every achievement must have a unique non-empty id")
		seen_ids[achievement_id] = true
		if int(definition.get("gold", 0)) <= 0 or float(definition.get("faith", 0.0)) <= 0.0:
			failures.append("every achievement must award both meaningful gold and faith")
	var first := AchievementProgression.get_definition("battle_1")
	if AchievementProgression.is_complete(first, {"battle_victories": 0}):
		failures.append("an unmet achievement must remain locked")
	if not AchievementProgression.is_complete(first, {"battle_victories": 1}):
		failures.append("an achievement must complete exactly at its target")
	var sanitized := AchievementProgression.sanitize_claimed_ids(["battle_1", "missing", "battle_1"])
	if sanitized != ["battle_1"]:
		failures.append("claimed achievement persistence must reject unknown and duplicate ids")
	if PetUnlockProgression.get_newly_eligible_pet_ids(0.74, ["pet1"]) != []:
		failures.append("pet2 must remain locked below its permanent growth threshold")
	if PetUnlockProgression.get_newly_eligible_pet_ids(0.75, ["pet1"]) != ["pet2"]:
		failures.append("pet2 must unlock exactly at its permanent growth threshold")
	var thresholds: Array[float] = []
	for pet_id in PetUnlockProgression.UNLOCK_THRESHOLDS:
		thresholds.append(float(PetUnlockProgression.UNLOCK_THRESHOLDS[pet_id]))
	thresholds.sort()
	if thresholds.size() != 10 or thresholds.front() != 0.0 or thresholds.back() < 500_000.0:
		failures.append("growth unlock thresholds must span the complete campaign")
	return failures
