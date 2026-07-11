extends RefCounted

const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_sleep_transition(failures)
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


static func _test_burrow_reaction(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet3", Vector2i(820, 420), 72.0, 724.0, 420.0)
	actor.react_to_petting("confused")
	var sprite := actor.get_node("pet3Sprite") as AnimatedSprite2D
	if sprite.animation != "burrow":
		failures.append("pet3 confused reaction must start burrowing")
	actor.free()
