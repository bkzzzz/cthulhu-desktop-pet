extends RefCounted

const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if SideDrawer.RATE_SUFFIX != "/s":
		failures.append("all growth rates must use the /s suffix")
	if SideDrawer.MENU_WINDOW_SIZE.x < 650:
		failures.append("the menu handle must leave clear space beside the altar")
	if SideDrawer.MENU_TO_DRAWER_GAP > 4:
		failures.append("the menu handle must sit farther right near the drawer edge")
	if FileAccess.file_exists("res://scripts/windows_clickthrough_helper.ps1"):
		failures.append("desktop input must not depend on an asynchronous clickthrough helper")
	var formatter := SideDrawer.new()
	_check(failures, formatter.call("_format_number", 1250.0, false, true), "1.25K")
	_check(failures, formatter.call("_format_number", 18400.0, false, true), "18.4K")
	_check(failures, formatter.call("_format_number", 125000.0, false, true), "125K")
	_check(failures, formatter.call("_get_population_progress_text", {
		"count": 99,
		"next_evolution_threshold": 100,
		"is_max_evolution": false
	}), "99 / 100")
	_check(failures, formatter.call("_get_population_progress_text", {
		"count": 100,
		"next_evolution_threshold": 1000,
		"is_max_evolution": false
	}), "100 / 1.00K")
	_check(failures, formatter.call("_get_population_progress_text", {
		"count": 1000,
		"next_evolution_threshold": 0,
		"is_max_evolution": true
	}), "1.00K / MAX")
	_check(failures, formatter.call("_get_upgrade_cost_text", {"cost": 25, "can_evolve": false}), "消耗 25")
	_check(failures, formatter.call("_get_upgrade_cost_text", {"can_evolve": true}), "点击进化")
	_check(failures, formatter.call("_get_upgrade_tooltip_text", {"can_evolve": false}), "点击增加种群")
	formatter.free()
	return failures


static func _check(failures: Array[String], actual: String, expected: String) -> void:
	if actual != expected:
		failures.append("number format: expected %s, got %s" % [expected, actual])
