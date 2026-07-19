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
	if target_size != Vector2i(1920, 1080):
		failures.append("the visual pet window must exactly match the Windows usable work area")
	if Main.PET_TASKBAR_OVERLAP_PIXELS != 0 or Main.EnemyActor.FOOT_TASKBAR_OVERLAP != 0.0:
		failures.append("grounded pets, enemies, and believers must share the exact taskbar contact line")
	var grounded_pet := Main.DesktopPetActor.new()
	grounded_pet.setup("pet1", target_size, 0.0, float(target_size.x), 500.0, float(target_size.y), false)
	var grounded_rect: Rect2 = grounded_pet.call("_get_sprite_visual_rect")
	if absf(grounded_rect.end.y - float(target_size.y)) > 1.1:
		failures.append("a grounded pet's final visible foot pixel must touch the usable-area bottom")
	grounded_pet.free()
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
