extends RefCounted

const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var formatter := SideDrawer.new()
	_check(failures, formatter.call("_format_number", 1250.0, false, true), "1.25K")
	_check(failures, formatter.call("_format_number", 18400.0, false, true), "18.4K")
	_check(failures, formatter.call("_format_number", 125000.0, false, true), "125K")
	formatter.free()
	return failures


static func _check(failures: Array[String], actual: String, expected: String) -> void:
	if actual != expected:
		failures.append("number format: expected %s, got %s" % [expected, actual])
