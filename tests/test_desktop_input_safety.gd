extends RefCounted

const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var main := Main.new()
	main.set("_pet_window_size", Vector2i(1920, 1094))
	if bool(main.call("_is_offering_drop_zone", Vector2(900.0, 1090.0))):
		failures.append("the taskbar strip must always pass clicks to Windows")
	if bool(main.call("_is_offering_drop_zone", Vector2(900.0, 300.0))):
		failures.append("the upper desktop must remain clickable while carrying an offering")
	if not bool(main.call("_is_offering_drop_zone", Vector2(900.0, 900.0))):
		failures.append("offerings must remain droppable inside the bottom pet stage")
	main.free()
	return failures
