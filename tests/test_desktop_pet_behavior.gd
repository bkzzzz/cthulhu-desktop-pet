extends RefCounted

const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if DesktopPetActor.GRAB_HOLD_SECONDS != 0.0:
		failures.append("pet grabbing must begin on the press frame")
	_test_catalog_movement_tuning(failures)
	_test_sleep_transition(failures)
	_test_generic_doze(failures)
	_test_hide_then_pop(failures)
	_test_air_roaming(failures)
	_test_ground_alignment(failures)
	_test_pet6_taskbar_alignment_and_wall_rule(failures)
	_test_wall_alignment_and_descent(failures)
	_test_grab_offset(failures)
	_test_burrow_reaction(failures)
	return failures


static func _test_catalog_movement_tuning(failures: Array[String]) -> void:
	var expected_ranges := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var definition := PetCatalog.get_definition(pet_id)
		var actor := DesktopPetActor.new()
		actor.setup(pet_id, Vector2i(2000, 1000), 72.0, 1900.0, 1000.0)
		var expected_min := float(definition.get("walk_distance_min", 40.0))
		var expected_max := float(definition.get("walk_distance_max", 180.0))
		if not is_equal_approx(float(actor.get("_walk_distance_min")), expected_min):
			failures.append("%s must read its minimum walk distance from the catalog" % pet_id)
		if not is_equal_approx(float(actor.get("_walk_distance_max")), expected_max):
			failures.append("%s must read its maximum walk distance from the catalog" % pet_id)

		var actor_rng := actor.get("_rng") as RandomNumberGenerator
		actor_rng.seed = 8128
		actor.call("_choose_general_walk_target")
		var chosen_distance := absf(float(actor.get("_target_x")) - actor.position.x)
		if chosen_distance < expected_min - 0.01 or chosen_distance > expected_max + 0.01:
			failures.append("%s walk target must honor its configured distance range" % pet_id)
		expected_ranges[Vector2(expected_min, expected_max)] = true
		actor.free()

	if expected_ranges.size() < 4:
		failures.append("desktop pets must keep visibly different walk distances")

	var pet2 := DesktopPetActor.new()
	pet2.setup("pet2", Vector2i(1600, 1000), 72.0, 1500.0, 800.0)
	var pet2_definition := PetCatalog.get_definition("pet2")
	if not is_equal_approx(
		float(pet2.get("_float_bob_amplitude")),
		float(pet2_definition.get("float_bob_amplitude", DesktopPetActor.FLOAT_BOB_AMPLITUDE))
	):
		failures.append("pet2 must read its floating amplitude from the catalog")
	if int(pet2.get("_air_roam_legs_min")) != int(pet2_definition.get("air_roam_legs_min", 1)):
		failures.append("pet2 must read its minimum air-roam legs from the catalog")
	if int(pet2.get("_air_roam_legs_max")) != int(pet2_definition.get("air_roam_legs_max", 1)):
		failures.append("pet2 must read its maximum air-roam legs from the catalog")
	pet2.free()


static func _test_sleep_transition(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet2", Vector2i(820, 420), 72.0, 724.0, 320.0)
	var sleeping_height := 150.0
	actor.position.y = sleeping_height
	actor.set("_float_anchor_y", sleeping_height)
	actor.react_to_petting("sleepy")
	var sprite := actor.get_node("pet2Sprite") as AnimatedSprite2D
	if sprite.animation != "close_eye":
		failures.append("pet2 sleepy reaction must start closing its eye")
	actor.call("_on_animation_finished")
	if sprite.animation != "sleep":
		failures.append("pet2 must remain visibly closed-eyed after closing animation")
	if not sprite.sprite_frames.get_animation_loop("sleep"):
		failures.append("pet2 closed-eye sleep animation must loop")
	actor.set("_special_time", 0.0)
	actor.call("_update_pet", 0.1)
	actor.call("_on_animation_finished")
	if not is_equal_approx(float(actor.get("_float_anchor_y")), sleeping_height):
		failures.append("pet2 must wake at its airborne sleeping height instead of snapping to the bottom")
	actor.free()


static func _test_generic_doze(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet6", Vector2i(1200, 720), 72.0, 1100.0, 600.0)
	var sprite := actor.get_node("pet6Sprite") as AnimatedSprite2D
	actor.call("_start_dozing")
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.DOZING:
		failures.append("generic dozing must use a non-walking behavior state")
	if sprite.animation != "idle" or sprite.speed_scale >= 1.0:
		failures.append("pets without sleep art must visibly doze through a slowed idle animation")
	actor.set("_special_time", 0.0)
	actor.call("_update_pet", 0.01)
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.IDLE:
		failures.append("generic dozing must return to idle after its configured duration")
	if not is_equal_approx(sprite.speed_scale, 1.0):
		failures.append("leaving a doze must restore the normal animation speed")
	actor.free()


static func _test_hide_then_pop(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet2", Vector2i(1200, 744), 72.0, 1100.0, 600.0, 720.0)
	var sprite := actor.get_node("pet2Sprite") as AnimatedSprite2D
	var actor_rng := actor.get("_rng") as RandomNumberGenerator
	actor_rng.seed = 424242
	actor.call("_start_hiding")
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.WALK or not bool(actor.get("_hide_pending")):
		failures.append("hiding must first walk toward the desktop-icon area")
	actor.position.x = float(actor.get("_target_x"))
	actor.call("_update_walking", 0.01)
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.HIDDEN or sprite.visible:
		failures.append("a hiding pet must become invisible instead of continuing its walk loop")
	actor.call("_update_interaction_area")
	if actor.get_interaction_rect().size != Vector2.ZERO:
		failures.append("a hidden pet must not leave an invisible input target")

	actor.set("_special_time", 0.0)
	actor.call("_update_pet", 0.01)
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.POPPING or not sprite.visible:
		failures.append("a hidden pet must become visible when it suddenly pops out")
	var pop_start: Vector2 = actor.get("_pop_start_position")
	var pop_target: Vector2 = actor.get("_pop_target_position")
	if is_equal_approx(pop_start.x, pop_target.x):
		failures.append("a pop-out must jump away from its hiding place")
	actor.call("_update_popping", 10.0)
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.IDLE:
		failures.append("a pop-out must land and resume idle behavior")
	if not actor.position.is_equal_approx(pop_target):
		failures.append("a pop-out must finish on its selected grounded target")

	actor.call("_start_hidden")
	actor.walk_to_offering_x(900.0)
	if not sprite.visible or bool(actor.get("_hide_pending")):
		failures.append("an offering target must immediately reveal and interrupt a hiding pet")
	if int(actor.get("_behavior")) != DesktopPetActor.Behavior.WALK or not bool(actor.get("_forced_target_pending")):
		failures.append("offering travel must take priority over hide/pop behavior")
	actor.position.x = 900.0
	actor.walk_to_offering_x(900.0)
	if bool(actor.get("_forced_target_pending")):
		failures.append("an already-near offering must clear forced travel after reporting arrival")
	actor.free()

	var non_hider := DesktopPetActor.new()
	non_hider.setup("pet6", Vector2i(1200, 744), 72.0, 1100.0, 600.0, 720.0)
	var non_hider_sprite := non_hider.get_node("pet6Sprite") as AnimatedSprite2D
	non_hider.call("_start_hiding")
	if int(non_hider.get("_behavior")) != DesktopPetActor.Behavior.IDLE or not non_hider_sprite.visible:
		failures.append("pets other than pet2 must reject hide-and-pop behavior even when called directly")
	non_hider.free()


static func _test_ground_alignment(failures: Array[String]) -> void:
	for pet_id in ["pet1", "pet3", "pet4", "pet5"]:
		var actor := DesktopPetActor.new()
		actor.setup(pet_id, Vector2i(1200, 720), 72.0, 1100.0, 600.0)
		var sprite := actor.get_node("%sSprite" % pet_id) as AnimatedSprite2D
		for animation_name in ["idle", "walk"]:
			for frame_index in sprite.sprite_frames.get_frame_count(animation_name):
				var texture := sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
				var image := texture.get_image()
				var bounds := _get_visible_alpha_bounds(image)
				var local_bottom := float(bounds.end.y) - (float(image.get_height()) * 0.5)
				var visible_bottom := actor.position.y + (local_bottom * sprite.scale.y)
				if absf(visible_bottom - 720.0) > 0.05:
					failures.append(
						"%s %s frame %d feet must reach the taskbar boundary (got %.2f)"
						% [pet_id, animation_name, frame_index, visible_bottom]
					)
		actor.call("_update_interaction_area")
		var interaction_rect: Rect2 = actor.get_interaction_rect()
		if interaction_rect.end.y > 720.01:
			failures.append("%s input proxy must not overlap the taskbar" % pet_id)
		actor.free()


static func _test_pet6_taskbar_alignment_and_wall_rule(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet6", Vector2i(1200, 744), 72.0, 1100.0, 600.0, 720.0)
	var sprite := actor.get_node("pet6Sprite") as AnimatedSprite2D
	var definition := PetCatalog.get_definition("pet6")
	var contact_line := actor.position.y + (
		(float(definition.get("frame_foot_y", 0)) + 1.0 - float(definition.get("frame_center_y", 0.0)))
		* float(definition.get("desktop_scale", 1.0))
	)
	if absf(contact_line - 720.0) > 0.05:
		failures.append("pet6's authored feet must stand on the usable taskbar boundary")

	var idle_image := sprite.sprite_frames.get_frame_texture("idle", 0).get_image()
	var idle_bounds := _get_visible_alpha_bounds(idle_image)
	var local_visible_bottom := float(idle_bounds.end.y) - (float(idle_image.get_height()) * 0.5)
	var visible_bottom := actor.position.y + (local_visible_bottom * sprite.scale.y)
	if visible_bottom <= 720.0 or visible_bottom >= 744.0:
		failures.append("pet6's lower hand may overlap below its foot line without leaving the visual window")
	actor.call("_update_interaction_area")
	if actor.get_interaction_rect().end.y > 720.01:
		failures.append("pet6's taskbar-overlapping hand must remain click-through")

	if bool(actor.get("_can_wall_crawl")):
		failures.append("pet6's humanoid body must explicitly forbid wall crawling")
	actor.call("_start_wall_trip")
	if bool(actor.get("_wall_pending")) or int(actor.get("_behavior")) in [
		DesktopPetActor.Behavior.WALL_MOUNT,
		DesktopPetActor.Behavior.WALL_CRAWL_UP,
		DesktopPetActor.Behavior.WALL_PAUSE,
		DesktopPetActor.Behavior.WALL_CRAWL_DOWN,
		DesktopPetActor.Behavior.WALL_LANDING
	]:
		failures.append("pet6 must reject wall trips even when requested directly")
	actor.free()


static func _test_air_roaming(failures: Array[String]) -> void:
	var actor := DesktopPetActor.new()
	actor.setup("pet2", Vector2i(1600, 1000), 72.0, 1500.0, 800.0)
	var y_bounds: Vector2 = actor.call("_get_air_roam_y_bounds")
	if y_bounds.y - y_bounds.x < 500.0:
		failures.append("pet2 awake air-roam range must cover a large part of the desktop")

	actor.set("_air_roam_legs_min", 3)
	actor.set("_air_roam_legs_max", 3)
	var actor_rng := actor.get("_rng") as RandomNumberGenerator
	actor_rng.seed = 271828
	var starting_position := actor.position
	actor.call("_start_air_roam")
	if int(actor.get("_air_roam_legs_remaining")) != 2:
		failures.append("pet2 must schedule every configured air-roam leg")
	actor.call("_update_air_roam", 0.5)
	if actor.position.is_equal_approx(starting_position):
		failures.append("pet2 air roaming must move away from its bottom resting area")

	for expected_remaining in [1, 0]:
		actor.call("_update_air_roam", 1000.0)
		actor.set("_special_time", 0.0)
		actor.call("_update_pet", 0.01)
		if int(actor.get("_air_roam_legs_remaining")) != expected_remaining:
			failures.append("pet2 multi-leg air roaming must continue before settling")

	actor.call("_update_air_roam", 1000.0)
	var final_air_target: Vector2 = actor.get("_air_path_target")
	actor.set("_special_time", 0.0)
	actor.call("_update_pet", 0.01)
	if not is_equal_approx(float(actor.get("_float_anchor_y")), final_air_target.y):
		failures.append("pet2 must remain at the final airborne height after a multi-leg roam")
	actor.free()


static func _test_wall_alignment_and_descent(failures: Array[String]) -> void:
	for pet_id in ["pet1", "pet4", "pet5"]:
		var actor := DesktopPetActor.new()
		actor.setup(pet_id, Vector2i(1200, 720), 72.0, 1100.0, 600.0)
		var sprite := actor.get_node("%sSprite" % pet_id) as AnimatedSprite2D

		actor.set("_wall_edge", -1)
		actor.call("_face_direction", -1.0)
		var approach_x := float(actor.call("_get_wall_approach_x"))
		actor.position.x = approach_x
		var pre_mount_position := actor.position
		actor.call("_start_wall_mount")
		if actor.position.distance_to(pre_mount_position) > 0.05:
			failures.append("%s must enter its left-wall mount without a position jump" % pet_id)
		for _step in 4:
			actor.call("_update_wall_mount", DesktopPetActor.WALL_CORNER_TURN_DURATION / 4.0)
			var mount_rect: Rect2 = actor.call("_get_sprite_visual_rect")
			if absf(mount_rect.position.x) > 0.05 or absf(mount_rect.end.y - 720.0) > 0.05:
				failures.append("%s must stay attached to the wall-floor corner while mounting" % pet_id)
				break
		if int(actor.get("_behavior")) != DesktopPetActor.Behavior.WALL_CRAWL_UP:
			failures.append("%s must start climbing after its wall-mount transition" % pet_id)
		var left_up_rotation := sprite.rotation
		var left_up_flip := sprite.flip_h
		var left_up_position := actor.position
		var left_rect: Rect2 = actor.call("_get_sprite_visual_rect")
		if absf(left_rect.position.x) > 0.05:
			failures.append("%s alpha bounds must touch the left screen edge while climbing" % pet_id)
		actor.call("_start_wall_descent")
		left_rect = actor.call("_get_sprite_visual_rect")
		if not is_equal_approx(sprite.rotation, left_up_rotation):
			failures.append("%s must keep its body bottom against the left edge when descending" % pet_id)
		if sprite.flip_h == left_up_flip:
			failures.append("%s must reverse only its head direction before descending the left edge" % pet_id)
		if actor.position.distance_to(left_up_position) > 0.05:
			failures.append("%s must not jump when turning downward on the left edge" % pet_id)
		if absf(left_rect.position.x) > 0.05:
			failures.append("%s must remain flush with the left edge after turning around" % pet_id)
		if sprite.animation != "walk":
			failures.append("%s must use its walk animation while descending" % pet_id)

		actor.position.y = float(actor.call("_get_wall_floor_target_y"))
		actor.call("_update_wall_crawl", 0.01, 1.0)
		if int(actor.get("_behavior")) != DesktopPetActor.Behavior.WALL_LANDING:
			failures.append("%s must use a corner transition instead of teleporting off the wall" % pet_id)
		actor.call("_update_wall_landing", DesktopPetActor.WALL_CORNER_TURN_DURATION * 0.5)
		var landing_rect: Rect2 = actor.call("_get_sprite_visual_rect")
		if absf(landing_rect.position.x) > 0.05 or absf(landing_rect.end.y - 720.0) > 0.05:
			failures.append("%s must stay attached to both edges during its landing turn" % pet_id)
		actor.call("_update_wall_landing", DesktopPetActor.WALL_CORNER_TURN_DURATION)
		if int(actor.get("_behavior")) != DesktopPetActor.Behavior.WALK:
			failures.append("%s must walk inward after landing instead of snapping to idle" % pet_id)
		if not is_zero_approx(sprite.rotation):
			failures.append("%s must be upright after finishing its wall landing" % pet_id)
		var landed_x := actor.position.x
		var walk_delta := 0.05
		var maximum_step := float(actor.get("_base_walk_speed")) * walk_delta
		actor.call("_update_walking", walk_delta)
		var inward_step := actor.position.x - landed_x
		if inward_step <= 0.0 or inward_step > maximum_step + 0.01:
			failures.append("%s must leave the left wall continuously at its configured speed" % pet_id)

		actor.set("_wall_edge", 1)
		actor.call("_start_wall_crawl")
		var right_up_rotation := sprite.rotation
		var right_up_flip := sprite.flip_h
		var right_up_position := actor.position
		var right_rect: Rect2 = actor.call("_get_sprite_visual_rect")
		var right_edge := right_rect.position.x + right_rect.size.x
		if absf(right_edge - 1200.0) > 0.05:
			failures.append("%s alpha bounds must touch the right screen edge while climbing" % pet_id)
		actor.call("_start_wall_descent")
		right_rect = actor.call("_get_sprite_visual_rect")
		right_edge = right_rect.position.x + right_rect.size.x
		if not is_equal_approx(sprite.rotation, right_up_rotation):
			failures.append("%s must keep its body bottom against the right edge when descending" % pet_id)
		if sprite.flip_h == right_up_flip:
			failures.append("%s must reverse only its head direction before descending the right edge" % pet_id)
		if actor.position.distance_to(right_up_position) > 0.05:
			failures.append("%s must not jump when turning downward on the right edge" % pet_id)
		if absf(right_edge - 1200.0) > 0.05:
			failures.append("%s must remain flush with the right edge after turning around" % pet_id)
		actor.free()


static func _get_visible_alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


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
