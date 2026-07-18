extends RefCounted

const SECONDS_PER_YEAR := 300.0
const SOLDIER_ERA_START_YEAR := 3
const VICTORIAN_ERA_START_YEAR := 6


static func get_year(total_runtime_seconds: float) -> int:
	return maxi(1, int(floor(maxf(0.0, total_runtime_seconds) / SECONDS_PER_YEAR)) + 1)


static func get_era_index(total_runtime_seconds: float) -> int:
	var year := get_year(total_runtime_seconds)
	if year >= VICTORIAN_ERA_START_YEAR:
		return 2
	return 1 if year >= SOLDIER_ERA_START_YEAR else 0


static func get_era_name(total_runtime_seconds: float, language := "zh") -> String:
	var era_index := get_era_index(total_runtime_seconds)
	if era_index >= 2:
		return "VICTORIAN AGE" if language == "en" else "维多利亚年代"
	if era_index >= 1:
		return "AGE OF ARMS" if language == "en" else "兵戈年代"
	return "VILLAGE AGE" if language == "en" else "村落年代"


static func get_display_text(total_runtime_seconds: float, language := "zh") -> String:
	var year := get_year(total_runtime_seconds)
	return (
		"%s · YEAR %d" % [get_era_name(total_runtime_seconds, language), year]
		if language == "en"
		else "%s · 第 %d 年" % [get_era_name(total_runtime_seconds, language), year]
	)


static func get_wave_schedule(total_runtime_seconds: float) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = [
		{"time": 0.0, "types": ["villager1", "villager2"]},
		{"time": 5.0, "types": ["villager1", "villager1", "villager2"]},
		{"time": 11.0, "types": ["villager2", "villager1"]},
		{"time": 18.0, "types": ["villager1", "villager2", "villager2"]}
	]
	if get_era_index(total_runtime_seconds) >= 1:
		schedule = [
			{"time": 0.0, "types": ["villager1", "soldier1"]},
			{"time": 5.5, "types": ["villager2", "soldier2"]},
			{"time": 12.0, "types": ["soldier1", "villager1", "villager2"]},
			{"time": 19.0, "types": ["soldier2", "soldier1", "villager2"]}
		]
	if get_era_index(total_runtime_seconds) >= 2:
		schedule = [
			{"time": 0.0, "types": ["soldier1", "victorian2"]},
			{"time": 5.5, "types": ["victorian1", "victorian2"]},
			{"time": 11.5, "types": ["victorian2", "victorian1", "soldier2"]},
			{"time": 18.5, "types": ["victorian_boss", "victorian2", "victorian1"]}
		]
	return schedule
