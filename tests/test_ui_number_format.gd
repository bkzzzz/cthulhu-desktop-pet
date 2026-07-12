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
	formatter.free()
	return failures


static func _check(failures: Array[String], actual: String, expected: String) -> void:
	if actual != expected:
		failures.append("number format: expected %s, got %s" % [expected, actual])
