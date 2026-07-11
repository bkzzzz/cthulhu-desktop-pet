extends RefCounted

## Pure progression rules. This layer deliberately has no scene, window, or input
## dependencies so gameplay balancing can be tested without starting the UI.


static func faith_per_second(pet_data: Dictionary, count: int) -> float:
	if count <= 0:
		return 0.0

	var base_fps := maxf(0.0, float(pet_data.get("base_fps", 0.05)))
	var power_growth := maxf(0.0, float(pet_data.get("power_growth", 1.035)))
	return base_fps * float(count) * pow(power_growth, float(count))


static func favor(state: Dictionary) -> int:
	return maxi(0, int(state.get("favor", state.get("trust", 0))))


static func upgrade_discount(
	state: Dictionary,
	reduction_per_favor: float,
	maximum_discount: float
) -> float:
	var safe_maximum := clampf(maximum_discount, 0.0, 1.0)
	return clampf(float(favor(state)) * maxf(0.0, reduction_per_favor), 0.0, safe_maximum)


static func upgrade_cost(
	pet_data: Dictionary,
	state: Dictionary,
	reduction_per_favor: float,
	maximum_discount: float
) -> int:
	var count := maxi(1, int(state.get("count", 1)))
	var base_cost := maxf(1.0, float(pet_data.get("upgrade_cost_base", 10)))
	var growth := maxf(0.0, float(pet_data.get("upgrade_cost_growth", 1.3)))
	var raw_cost := base_cost * pow(growth, float(count))
	var discount := upgrade_discount(state, reduction_per_favor, maximum_discount)
	return maxi(1, int(round(raw_cost * (1.0 - discount))))
