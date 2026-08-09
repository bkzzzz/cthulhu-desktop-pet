extends RefCounted

const DesktopItemActor = preload("res://scripts/desktop_item_actor.gd")
const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const Main = preload("res://scripts/main.gd")
const SofaController = preload("res://scripts/runtime/sofa_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_sofa_pet_climb_and_departure(failures)
	_test_sofa_guest_can_cross_restricted_activity_range(failures)
	_test_sofa_renders_below_pet(failures)
	_test_manual_sofa_drop(failures)
	_test_single_guest_production_boost_and_release(failures)
	_test_sofa_approach_timeout(failures)
	_test_sofa_state_save_sanitization(failures)
	_test_sofa_catalog_copy(failures)
	return failures


static func _test_sofa_pet_climb_and_departure(failures: Array[String]) -> void:
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 320.0, 720.0)
	var reached_count := [0]
	var departed_count := [0]
	pet.sofa_reached.connect(func(_actor: Node2D) -> void: reached_count[0] += 1)
	pet.sofa_departed.connect(func(_actor: Node2D) -> void: departed_count[0] += 1)
	var ground_y := pet.position.y
	# Keep this actor-level test focused on the climb/rest state machine. The
	# controller test below covers a long horizontal walk to a real sofa actor.
	if not pet.begin_sofa_visit(320.0, 620.0):
		failures.append("an available desktop pet must accept a sofa visit")
	else:
		for _step in 12:
			pet.call("_update_pet", 0.1)
		if not pet.is_sofa_seated() or reached_count[0] != 1:
			failures.append("a sofa guest must climb up and report a seated arrival")
		elif pet.position.y >= ground_y - 8.0:
			failures.append("a seated sofa guest must remain visibly above its taskbar resting line")
		pet.leave_sofa_visit(false)
		if pet.is_sofa_visit_active() or pet.is_sofa_seated() or departed_count[0] != 1:
			failures.append("leaving a sofa must clear the seated visit exactly once")
		elif not is_equal_approx(pet.position.y, ground_y):
			failures.append("a pet leaving a sofa without animation must return to the taskbar ground")
	pet.free()


static func _test_sofa_guest_can_cross_restricted_activity_range(failures: Array[String]) -> void:
	var pet := DesktopPetActor.new()
	const restricted_max_x := 520.0
	const sofa_x := 920.0
	pet.setup("pet1", Vector2i(1200, 720), 0.0, restricted_max_x, 260.0, 720.0)
	if not pet.begin_sofa_visit(sofa_x, 620.0):
		failures.append("a sofa visit must allow a guest to leave its normal activity segment")
		pet.free()
		return
	for _step in 8:
		pet.call("_update_pet", 0.1)
	# A level-up and a taskbar/desktop resize must not re-clamp the in-flight
	# guest to the configured left-half activity segment.
	pet.set_pet_level(2)
	pet.set_window_bounds(Vector2i(1200, 700), 0.0, restricted_max_x, 700.0, true)
	for _step in 96:
		pet.call("_update_pet", 0.1)
	var seat_position: Vector2 = pet.get("_sofa_seat_position")
	if not pet.is_sofa_seated():
		failures.append("a guest must still reach a sofa on the other side after a resize")
	elif pet.position.x <= restricted_max_x + 8.0 or absf(pet.position.x - seat_position.x) > 1.0:
		failures.append("a sofa guest must sit at the actual sofa seat, not its activity-range edge")
	pet.leave_sofa_visit(false)
	if pet.position.x > restricted_max_x + 0.1:
		failures.append("a departing sofa guest must return to its configured activity segment")
	pet.free()


static func _test_sofa_renders_below_pet(failures: Array[String]) -> void:
	var sofa := DesktopItemActor.new()
	sofa.setup("sofa", Vector2(680.0, 720.0), Vector2i(1200, 720))
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 680.0, 720.0)
	var sofa_sprite := sofa.get_node_or_null("DesktopItemSprite") as Sprite2D
	if sofa_sprite == null:
		failures.append("a deployed sofa must create a visual sprite")
	elif sofa_sprite.z_index >= pet.z_index:
		failures.append("the sofa visual must render behind desktop pets")
	elif not pet.begin_sofa_visit(sofa.position.x, 650.0):
		failures.append("a pet must be able to begin a sofa visit for layer verification")
	else:
		for _step in 8:
			pet.call("_update_pet", 0.1)
		if not pet.is_sofa_seated() or sofa_sprite.z_index >= pet.z_index:
			failures.append("a seated pet must remain visibly above the sofa surface")
	pet.free()
	sofa.free()


static func _test_manual_sofa_drop(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.set("_simulation_now_seconds", 1_000.0)
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 320.0, 720.0)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	pet.sofa_reached.connect(main._on_pet_sofa_reached)
	pet.sofa_departed.connect(main._on_pet_sofa_departed)
	var sofa := DesktopItemActor.new()
	sofa.setup("sofa", Vector2(720.0, 720.0), Vector2i(1200, 720))
	main.add_child(sofa)
	(main.get("_desktop_items") as Array).append(sofa)
	main.set("_item_states", {
		"sofa": {"owned": true, "deployed": true, "position_x": sofa.position.x}
	})
	# The actor origin is above its visible feet, so this position makes the pet
	# body overlap the sofa in exactly the same way a user drop does.
	pet.position = Vector2(sofa.position.x, sofa.position.y - 110.0)
	# A real release enters FALLING before the new drag_released signal reaches
	# DesktopController. Reproduce that post-release state without relying on a
	# live test window or desktop mouse position.
	pet.set("_behavior", DesktopPetActor.Behavior.FALLING)
	main.call("_on_pet_drag_released", pet)
	var state: Dictionary = (main.get("_item_states") as Dictionary).get("sofa", {})
	var session: Dictionary = state.get("sofa_session", {})
	if String(session.get("pet_id", "")) != "pet1" or String(session.get("phase", "")) != "approaching":
		failures.append("dropping a pet on a deployed sofa must start that pet's rest visit")
	else:
		for _step in 8:
			pet.call("_update_pet", 0.1)
		if not pet.is_sofa_seated() or float(main.call("_get_pet_sofa_multiplier", "pet1")) != SofaController.SOFA_FAITH_MULTIPLIER:
			failures.append("a manually dropped sofa guest must receive the normal seated comfort boost")
	main.call("_release_sofa_interaction", "pet1", false)
	pet.position = Vector2(80.0, sofa.position.y - 110.0)
	main.call("_on_pet_drag_released", pet)
	state = (main.get("_item_states") as Dictionary).get("sofa", {})
	if state.has("sofa_session"):
		failures.append("dropping a pet outside the sofa must not start a rest visit")
	main.free()


static func _test_single_guest_production_boost_and_release(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.set("_simulation_now_seconds", 1_000.0)
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 280.0, 720.0)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	pet.sofa_reached.connect(main._on_pet_sofa_reached)
	pet.sofa_departed.connect(main._on_pet_sofa_departed)

	var sofa := DesktopItemActor.new()
	sofa.setup("sofa", Vector2(720.0, 720.0), Vector2i(1200, 720))
	main.add_child(sofa)
	(main.get("_desktop_items") as Array).append(sofa)
	var now := float(main.call("_get_now_seconds"))
	main.set("_item_states", {
		"sofa": {
			"owned": true,
			"deployed": true,
			"position_x": sofa.position.x,
			"sofa_next_visit_at": now - 0.01
		}
	})
	var baseline := float(main.call("_get_faith_growth_rate"))
	main.call("_update_sofa_interaction", 0.1)
	var state: Dictionary = (main.get("_item_states") as Dictionary).get("sofa", {})
	var session: Dictionary = state.get("sofa_session", {})
	if String(session.get("pet_id", "")) != "pet1":
		failures.append("one deployed sofa must reserve exactly one available pet as its guest")
	else:
		if (
			String(session.get("phase", "")) != "approaching"
			or session.has("ends_at")
			or float(session.get("approach_expires_at", 0.0)) <= now
		):
			failures.append("a sofa comfort timer must not start until the guest reaches its seat")
		elif float(main.call("_get_pet_sofa_multiplier", "pet1")) != 1.0:
			failures.append("an approaching sofa guest must not receive the comfort production boost")
		main.set("_simulation_now_seconds", now + 8.0)
		for _step in 56:
			pet.call("_update_pet", 0.1)
		if not pet.is_sofa_seated():
			failures.append("the controller-selected sofa guest must reach the sofa seat")
		else:
			state = (main.get("_item_states") as Dictionary).get("sofa", {})
			session = state.get("sofa_session", {})
			var expected_ends_at := float(main.call("_get_now_seconds")) + SofaController.SOFA_VISIT_DURATION_SECONDS
			if (
				String(session.get("phase", "")) != "seated"
				or session.has("approach_expires_at")
				or absf(float(session.get("ends_at", 0.0)) - expected_ends_at) > 0.01
			):
				failures.append("a sofa guest must receive the full comfort duration when seated")
			var multiplier := float(main.call("_get_pet_sofa_multiplier", "pet1"))
			var boosted := float(main.call("_get_faith_growth_rate"))
			if not is_equal_approx(multiplier, SofaController.SOFA_FAITH_MULTIPLIER):
				failures.append("only a seated sofa guest must receive the configured comfort multiplier")
			elif not is_equal_approx(boosted, baseline * SofaController.SOFA_FAITH_MULTIPLIER):
				failures.append("the sofa multiplier must feed the same faith-production calculation as food boosts")
			main.call("_release_sofa_interaction", "pet1", false)
			if float(main.call("_get_pet_sofa_multiplier", "pet1")) != 1.0:
				failures.append("recalling a sofa or its guest must remove the production multiplier immediately")
			elif not is_equal_approx(float(main.call("_get_faith_growth_rate")), baseline):
				failures.append("removing the sofa guest must restore the pet's normal faith production")
	main.free()


static func _test_sofa_approach_timeout(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(1200, 720))
	main.set("_simulation_now_seconds", 1_000.0)
	var pet := DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1200, 720), 0.0, 1200.0, 280.0, 720.0)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	var sofa := DesktopItemActor.new()
	sofa.setup("sofa", Vector2(720.0, 720.0), Vector2i(1200, 720))
	main.add_child(sofa)
	(main.get("_desktop_items") as Array).append(sofa)
	var now := float(main.call("_get_now_seconds"))
	main.set("_item_states", {
		"sofa": {
			"owned": true,
			"deployed": true,
			"position_x": sofa.position.x,
			"sofa_session": {
				"pet_id": "pet1",
				"phase": "approaching",
				"approach_expires_at": now - 0.01
			}
		}
	})
	main.call("_update_sofa_interaction", 0.1)
	var state: Dictionary = (main.get("_item_states") as Dictionary).get("sofa", {})
	if state.has("sofa_session"):
		failures.append("an overdue sofa approach must end without starting a comfort session")
	elif float(main.call("_get_pet_sofa_multiplier", "pet1")) != 1.0:
		failures.append("an overdue sofa approach must never grant a production boost")
	main.free()


static func _test_sofa_state_save_sanitization(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	var now := float(main.call("_get_now_seconds"))
	var sanitized: Dictionary = main.call("_sanitize_item_states", {
		"sofa": {
			"owned": true,
			"deployed": true,
			"position_x": 500.0,
			"sofa_session": {
				"pet_id": "pet1",
				"phase": "seated",
				"ends_at": now + 30.0
			}
		}
	})
	var state: Dictionary = sanitized.get("sofa", {})
	var session: Dictionary = state.get("sofa_session", {})
	if String(session.get("pet_id", "")) != "pet1" or String(session.get("phase", "")) != "seated":
		failures.append("an active deployed sofa visit must survive save sanitization for restore")
	var approaching_sanitized: Dictionary = main.call("_sanitize_item_states", {
		"sofa": {
			"owned": true,
			"deployed": true,
			"sofa_session": {
				"pet_id": "pet1",
				"phase": "approaching",
				"approach_expires_at": now + 20.0
			}
		}
	})
	var approaching_state: Dictionary = approaching_sanitized.get("sofa", {})
	var approaching_session: Dictionary = approaching_state.get("sofa_session", {})
	if (
		String(approaching_session.get("phase", "")) != "approaching"
		or not approaching_session.has("approach_expires_at")
		or approaching_session.has("ends_at")
	):
		failures.append("an approaching sofa visit must persist a separate reach timeout, not comfort time")
	var rejected: Dictionary = main.call("_sanitize_item_states", {
		"sofa": {
			"owned": true,
			"deployed": false,
			"sofa_session": {"pet_id": "pet1", "phase": "seated", "ends_at": now + 30.0}
		}
	})
	if (rejected.get("sofa", {}) as Dictionary).has("sofa_session"):
		failures.append("a recalled sofa must never restore an occupant or comfort boost from save data")
	main.free()


static func _test_sofa_catalog_copy(failures: Array[String]) -> void:
	var sofa := DesktopItemCatalog.get_definition("sofa")
	if SofaController.SOFA_FAITH_MULTIPLIER <= 1.0:
		failures.append("the sofa comfort multiplier must be a configurable positive production boost")
	if not ("1.5" in String(sofa.get("description", ""))) or not ("x1.5" in String(sofa.get("description_en", ""))):
		failures.append("the sofa shop copy must clearly explain its x1.5 faith-production benefit")
