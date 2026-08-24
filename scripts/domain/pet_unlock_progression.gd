extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")

## Permanent baseline faith-per-second gates. Temporary food and sofa boosts do
## not unlock roster members, so an unlock can never disappear with a buff.
const UNLOCK_THRESHOLDS := {
	"pet1": 0.0,
	"pet2": 0.75,
	"pet3": 20.0,
	"pet4": 80.0,
	"pet5": 450.0,
	"pet6": 6_500.0,
	"pet7": 26_000.0,
	"pet8": 85_000.0,
	"pet9": 260_000.0,
	"pet10": 540_000.0,
}


static func get_threshold(pet_id: String) -> float:
	return maxf(0.0, float(UNLOCK_THRESHOLDS.get(pet_id, INF)))


static func get_newly_eligible_pet_ids(growth_rate: float, unlocked_pet_ids: Array) -> Array[String]:
	var safe_rate := maxf(0.0, growth_rate) if is_finite(growth_rate) else 0.0
	var eligible: Array[String] = []
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		if unlocked_pet_ids.has(pet_id):
			continue
		if safe_rate + 0.000001 >= get_threshold(pet_id):
			eligible.append(pet_id)
	return eligible


static func get_next_unlock(unlocked_pet_ids: Array) -> Dictionary:
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		if not unlocked_pet_ids.has(pet_id):
			return {"pet_id": pet_id, "threshold": get_threshold(pet_id)}
	return {}
