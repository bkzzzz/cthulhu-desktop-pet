extends RefCounted

const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if DesktopPetActor.GRAB_HOLD_SECONDS != 0.0:
		failures.append("pet grabbing must begin on the press frame")
	if DesktopPetActor.FLOAT_BOB_AMPLITUDE < 12.0:
		failures.append("pet2 bottom hovering must have a visible vertical range")
	_test_sleep_transition(failures)
	_test_air_roaming(failures)
	_test_grab_offset(failures)
	_test_burrow_reaction(failures)
	return failures


static func _test_sleep_transition(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet2", Vector2i(820, 420), 72.0, 724.0, 320.0)
	actor.react_to_petting("sleepy")
	var sprite := actor.get_node("pet2Sprite") as AnimatedSprite2D
	if sprite.animation != "close_eye":
		failures.append("pet2 sleepy reaction must start closing its eye")
	actor.call("_on_animation_finished")
	if sprite.animation != "sleep":
		failures.append("pet2 must remain visibly closed-eyed after closing animation")
	if not sprite.sprite_frames.get_animation_loop("sleep"):
		failures.append("pet2 closed-eye sleep animation must loop")
	actor.free()


static func _test_air_roaming(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet2", Vector2i(820, 720), 72.0, 724.0, 320.0)
	var starting_position := actor.position
	actor.call("_start_air_roam")
	actor.call("_update_air_roam", 0.5)
	if actor.position.is_equal_approx(starting_position):
		failures.append("pet2 air roaming must move away from its bottom resting area")
	actor.free()


static func _test_grab_offset(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet1", Vector2i(820, 420), 72.0, 724.0, 320.0)
	var stable_hit_image: Image = actor.get("_stable_hit_image")
	if stable_hit_image == null or stable_hit_image.is_empty():
		failures.append("pet interaction must use a stable animation hit mask")
	var expected_offset := Vector2(23.0, -11.0)
	actor.set("_grab_offset", expected_offset)
	actor.call("_begin_grab")
	var actual_offset: Vector2 = actor.get("_grab_offset")
	if not actual_offset.is_equal_approx(expected_offset):
		failures.append("dragging must preserve the initial press offset without lag")
	actor.free()


static func _test_burrow_reaction(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet3", Vector2i(820, 420), 72.0, 724.0, 420.0)
	actor.react_to_petting("confused")
	var sprite := actor.get_node("pet3Sprite") as AnimatedSprite2D
	if sprite.animation != "burrow":
		failures.append("pet3 confused reaction must start burrowing")
	actor.free()
