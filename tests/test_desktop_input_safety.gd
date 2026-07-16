extends RefCounted

const Main = preload("res://scripts/main.gd")
const NativeVisualClickthrough = preload("res://scripts/native_visual_clickthrough.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists("res://scripts/windows_visual_clickthrough_once.ps1"):
		failures.append("Windows desktop click-through helper is missing")
	if NativeVisualClickthrough.apply(null):
		failures.append("click-through setup must reject a missing window")
	var main := Main.new()
	var target_size: Vector2i = main.call("_get_target_pet_window_size", Rect2i(0, 0, 1920, 1080))
	if target_size.y != 1080 + Main.PET_TASKBAR_OVERLAP_PIXELS:
		failures.append("the visual pet window must include only the configured taskbar art overlap")
	main.set("_pet_window_size", target_size)
	if not bool(main.call("_is_offering_drop_zone", Vector2(900.0, 300.0))):
		failures.append("offerings must be droppable across the upper desktop")
	if not bool(main.call("_is_offering_drop_zone", Vector2(900.0, 900.0))):
		failures.append("offerings must remain droppable inside the bottom pet stage")
	if bool(main.call("_is_offering_drop_zone", Vector2(900.0, 1100.0))):
		failures.append("the offering overlay must stop at the usable desktop boundary")
	main.set("_carried_offering", {"id": "focus_regression"})
	main.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var carried_after_focus: Dictionary = main.get("_carried_offering")
	if carried_after_focus.is_empty():
		failures.append("switching away from the shop must not discard a purchased offering")
	main.free()
	return failures
