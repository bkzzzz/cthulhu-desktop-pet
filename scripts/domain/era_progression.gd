extends RefCounted

# One progression tick is five minutes of simulation time. Godot scales process
# delta with Engine.time_scale, so the debug game-speed multiplier advances this
# clock, the displayed calendar, and pet ages together.
const SECONDS_PER_YEAR := 300.0
const SOLDIER_ERA_START_YEAR := 3
const VICTORIAN_ERA_START_YEAR := 6
const MODERN_ERA_START_YEAR := 10
const OUTER_SPACE_ERA_START_YEAR := 14

# The compact game timeline uses recognizable real-world dates instead of a
# fictional "Year 1" calendar. Early/late medieval chapters move by centuries;
# once the Victorian era begins the calendar proceeds one year per tick.
const MEDIEVAL_START_CALENDAR_YEAR := 1066
const SOLDIER_ERA_START_CALENDAR_YEAR := 1300
const VICTORIAN_ERA_START_CALENDAR_YEAR := 1837
const MODERN_ERA_START_CALENDAR_YEAR := 1914
const OUTER_SPACE_ERA_START_CALENDAR_YEAR := 2200
const MEDIEVAL_CALENDAR_STEP_YEARS := 100


static func get_year(total_runtime_seconds: float) -> int:
	return maxi(1, int(floor(maxf(0.0, total_runtime_seconds) / SECONDS_PER_YEAR)) + 1)


static func get_calendar_year(total_runtime_seconds: float) -> int:
	var progression_year := get_year(total_runtime_seconds)
	if progression_year >= OUTER_SPACE_ERA_START_YEAR:
		return OUTER_SPACE_ERA_START_CALENDAR_YEAR + progression_year - OUTER_SPACE_ERA_START_YEAR
	if progression_year >= MODERN_ERA_START_YEAR:
		return MODERN_ERA_START_CALENDAR_YEAR + progression_year - MODERN_ERA_START_YEAR
	if progression_year >= VICTORIAN_ERA_START_YEAR:
		return VICTORIAN_ERA_START_CALENDAR_YEAR + progression_year - VICTORIAN_ERA_START_YEAR
	if progression_year >= SOLDIER_ERA_START_YEAR:
		return (
			SOLDIER_ERA_START_CALENDAR_YEAR
			+ (progression_year - SOLDIER_ERA_START_YEAR) * MEDIEVAL_CALENDAR_STEP_YEARS
		)
	return (
		MEDIEVAL_START_CALENDAR_YEAR
		+ (progression_year - 1) * MEDIEVAL_CALENDAR_STEP_YEARS
	)


static func get_elapsed_calendar_years(total_runtime_seconds: float) -> int:
	return maxi(0, get_calendar_year(total_runtime_seconds) - MEDIEVAL_START_CALENDAR_YEAR)


static func get_era_index(total_runtime_seconds: float) -> int:
	var progression_year := get_year(total_runtime_seconds)
	if progression_year >= OUTER_SPACE_ERA_START_YEAR:
		return 4
	if progression_year >= MODERN_ERA_START_YEAR:
		return 3
	if progression_year >= VICTORIAN_ERA_START_YEAR:
		return 2
	return 1 if progression_year >= SOLDIER_ERA_START_YEAR else 0


static func get_era_name(total_runtime_seconds: float, language := "zh") -> String:
	var era_index := get_era_index(total_runtime_seconds)
	if era_index >= 4:
		return "OUTER SPACE" if language == "en" else "外太空时代"
	if era_index >= 3:
		return "MODERN WAR" if language == "en" else "现代战争"
	if era_index >= 2:
		return "VICTORIAN ERA" if language == "en" else "维多利亚时代"
	if era_index >= 1:
		return "MEDIEVAL ARMS" if language == "en" else "中世纪·兵戈"
	return "MEDIEVAL VILLAGES" if language == "en" else "中世纪·村落"


static func get_display_text(total_runtime_seconds: float, language := "zh") -> String:
	var calendar_year := get_calendar_year(total_runtime_seconds)
	return (
		"%s · AD %d" % [get_era_name(total_runtime_seconds, language), calendar_year]
		if language == "en"
		else "%s · 公元 %d 年" % [get_era_name(total_runtime_seconds, language), calendar_year]
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
	if get_era_index(total_runtime_seconds) >= 3:
		schedule = [
			{"time": 0.0, "types": ["modern2", "victorian1"]},
			{"time": 5.0, "types": ["modern3", "modern2"]},
			{"time": 10.5, "types": ["modern2", "modern3", "victorian_boss"]},
			{"time": 17.5, "types": ["modern3", "modern2", "modern3"]}
		]
	if get_era_index(total_runtime_seconds) >= 4:
		schedule = [
			{"time": 0.0, "types": ["modern3", "outerspace1"]},
			{"time": 4.5, "types": ["outerspace1", "outerspace2"]},
			{"time": 9.5, "types": ["modern2", "outerspace2", "outerspace3"]},
			{"time": 15.5, "types": ["outerspace3", "outerspace2", "modern3"]}
		]
	return schedule
