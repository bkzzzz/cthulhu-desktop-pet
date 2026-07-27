extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const InventoryWindow = preload("res://scripts/inventory_window.gd")
const EvolutionWindow = preload("res://scripts/evolution_window.gd")
const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_evolution_assets_and_frames(failures)
	_test_evolved_actor_animation_and_direction(failures)
	_test_attack_frames_keep_visual_floor(failures)
	_test_form_specific_authored_facing(failures)
	_test_evolution_detail_and_confirmation_windows(failures)
	_test_evolution_state_and_power(failures)
	return failures


static func _test_attack_frames_keep_visual_floor(failures: Array[String]) -> void:
	for evolved in [false, true]:
		for pet_id in PetCatalog.ACTIVE_DESKTOP_PETS:
			var actor := DesktopPetActor.new()
			actor.setup(pet_id, Vector2i(1200, 720), 0.0, 1200.0, 700.0, 720.0, false, evolved, 100 if evolved else 50)
			actor.set_battle_mode(true)
			var sprite := actor.get_node_or_null("%sSprite" % pet_id) as AnimatedSprite2D
			if sprite == null:
				actor.free()
				continue
			var root_y := actor.position.y
			var visual_bottom := float(actor.call("_get_current_frame_visual_bottom_y"))
			actor.play_battle_attack_toward(-1.0)
			if not is_equal_approx(actor.position.y, root_y):
				failures.append("%s attack must not teleport the actor root vertically" % pet_id)
			for frame_index in sprite.sprite_frames.get_frame_count("attack"):
				sprite.frame = frame_index
				actor.call("_on_sprite_frame_changed")
				var attack_bottom := float(actor.call("_get_current_frame_visual_bottom_y"))
				if absf(attack_bottom - visual_bottom) > 0.1:
					failures.append("%s %s attack frame %d must keep the pre-attack visual floor" % [pet_id, "evolved" if evolved else "base", frame_index])
					break
			actor.free()


static func _test_evolution_assets_and_frames(failures: Array[String]) -> void:
	for pet_id in PetCatalog.ACTIVE_DESKTOP_PETS:
		if not PetCatalog.has_evolution(pet_id):
			failures.append("%s must expose its imported evolution form" % pet_id)
			continue
		var definition := PetCatalog.get_evolution_definition(pet_id)
		var required_keys := ["icon", "idle", "walk", "attack"]
		for key in required_keys:
			if not FileAccess.file_exists(String(definition.get(key, ""))):
				failures.append("%s evolution must load its %s asset" % [pet_id, key])
		for animation_name in ["idle", "walk", "attack"]:
			var base_path := String(PetCatalog.get_definition(pet_id).get(animation_name, ""))
			var evolution_path := String(definition.get(animation_name, ""))
			if not base_path.is_empty() and base_path == evolution_path:
				failures.append("%s base and evolved %s animations must never share an asset" % [pet_id, animation_name])
		var frames := PetCatalog.build_frames(pet_id, true)
		for animation_name in ["idle", "walk", "attack"]:
			var expected_count := 16 if pet_id == "pet3" and animation_name == "attack" else 12
			if frames.get_frame_count(animation_name) != expected_count:
				failures.append("%s evolved %s must use %d authored frames" % [pet_id, animation_name, expected_count])
	if PetCatalog.build_frames("pet1", true).get_frame_count("attack") != 12:
		failures.append("pet1 evolution must use all twelve imported attack frames")
	if PetCatalog.build_frames("pet3", true).get_frame_count("attack") != 16:
		failures.append("pet3 evolution must use all sixteen imported attack frames")
	if PetCatalog.build_frames("pet3", true).get_frame_count("burrow") != 12:
		failures.append("pet3 evolution must use all twelve imported burrow frames")
	var base_pet6 := PetCatalog.build_frames("pet6", false)
	var evolved_pet6 := PetCatalog.build_frames("pet6", true)
	if base_pet6.get_frame_texture("idle", 0).get_size() != Vector2(128, 128):
		failures.append("base pet6 must use 128x128 source cells")
	if evolved_pet6.get_frame_texture("idle", 0).get_size() != Vector2(256, 256):
		failures.append("evolved pet6 idle/walk art must use 256x256 source cells")
	if evolved_pet6.get_frame_texture("attack", 0).get_size() != Vector2(384, 384):
		failures.append("evolved pet6 attack art must use 384x384 source cells")
	if bool(PetCatalog.get_definition("pet1").get("faces_right", true)):
		failures.append("base pet1 walk art must be registered as authored facing left")
	if not bool(PetCatalog.get_definition("pet1").get("attack_faces_right", false)):
		failures.append("base pet1 attack art must retain its independently authored right facing")
	if bool(PetCatalog.get_definition("pet3").get("attack_faces_right", true)):
		failures.append("base pet3 spider attack art must be registered as authored facing left")
	if bool(PetCatalog.get_definition("pet6").get("faces_right", true)):
		failures.append("base pet6 idle/walk art must remain authored facing left")
	if bool(PetCatalog.get_definition("pet6").get("attack_faces_right", true)):
		failures.append("base pet6 attack art must remain authored facing left")
	if bool(PetCatalog.get_evolution_definition("pet6").get("faces_right", true)):
		failures.append("evolved pet6 idle/walk art must remain authored facing left")
	if not bool(PetCatalog.get_evolution_definition("pet6").get("attack_faces_right", false)):
		failures.append("evolved pet6's separate attack art must be registered as authored facing right")


static func _test_evolved_actor_animation_and_direction(failures: Array[String]) -> void:
	for pet_id in PetCatalog.ACTIVE_DESKTOP_PETS:
		var actor := DesktopPetActor.new()
		actor.setup(pet_id, Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, true)
		if not bool(actor.get("is_evolved")):
			failures.append("%s actor must retain its evolved runtime form" % pet_id)
		var sprite := actor.get_node_or_null("%sSprite" % pet_id) as AnimatedSprite2D
		if sprite == null:
			failures.append("%s evolution must create its animation sprite" % pet_id)
			actor.free()
			continue
		actor.set_battle_mode(true)
		var evolved_definition := PetCatalog.get_evolution_definition(pet_id)
		var authored_faces_right := bool(evolved_definition.get("faces_right", false))
		if sprite.flip_h != authored_faces_right:
			failures.append("%s evolution must face left consistently when battle starts" % pet_id)
		actor.play_battle_attack_toward(-1.0)
		var attack_faces_right := bool(evolved_definition.get("attack_faces_right", authored_faces_right))
		if sprite.animation != "attack" or sprite.flip_h != attack_faces_right:
			failures.append("%s evolution attack must face a target approaching from the left" % pet_id)
		actor.call("_on_animation_finished")
		if sprite.animation != "idle":
			failures.append("%s evolution must return to idle after its attack" % pet_id)
		actor.free()


static func _test_form_specific_authored_facing(failures: Array[String]) -> void:
	var base_pet1 := DesktopPetActor.new()
	base_pet1.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, false, 50)
	base_pet1.set_battle_mode(true)
	var pet1_sprite := base_pet1.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	base_pet1.battle_move_toward(500.0, 0.1, 100.0, -1.0)
	if pet1_sprite == null or pet1_sprite.flip_h:
		failures.append("base pet1's left-authored walk must stay unflipped toward a left-side enemy")
	base_pet1.battle_move_toward(700.0, 0.1, 100.0, 1.0)
	if pet1_sprite != null and not pet1_sprite.flip_h:
		failures.append("base pet1's left-authored walk must flip toward a right-side enemy")
	base_pet1.play_battle_attack_toward(-1.0)
	if pet1_sprite == null or pet1_sprite.animation != "attack" or not pet1_sprite.flip_h:
		failures.append("base pet1's right-authored attack must retain its left-target orientation")
	base_pet1.call("_on_animation_finished")
	base_pet1.play_battle_attack_toward(1.0)
	if pet1_sprite != null and pet1_sprite.flip_h:
		failures.append("base pet1's right-authored attack must retain its right-target orientation")
	base_pet1.free()

	var base_pet3 := DesktopPetActor.new()
	base_pet3.setup("pet3", Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, false, 50)
	base_pet3.set_battle_mode(true)
	var pet3_sprite := base_pet3.get_node_or_null("pet3Sprite") as AnimatedSprite2D
	base_pet3.play_battle_attack_toward(-1.0)
	if pet3_sprite == null or pet3_sprite.animation != "attack" or pet3_sprite.flip_h:
		failures.append("base pet3's left-authored attack must stay unflipped toward a left-side enemy")
	base_pet3.call("_on_animation_finished")
	base_pet3.play_battle_attack_toward(1.0)
	if pet3_sprite != null and not pet3_sprite.flip_h:
		failures.append("base pet3's left-authored attack must flip toward a right-side enemy")
	base_pet3.free()

	var evolved_pet6 := DesktopPetActor.new()
	evolved_pet6.setup("pet6", Vector2i(1000, 720), 0.0, 1000.0, 600.0, 704.0, false, true, 100)
	evolved_pet6.set_battle_mode(true)
	var pet6_sprite := evolved_pet6.get_node_or_null("pet6Sprite") as AnimatedSprite2D
	if pet6_sprite == null or pet6_sprite.flip_h:
		failures.append("evolved pet6 idle must remain unflipped while watching a left-side enemy")
	evolved_pet6.play_battle_attack_toward(-1.0)
	if pet6_sprite == null or pet6_sprite.animation != "attack" or not pet6_sprite.flip_h:
		failures.append("evolved pet6's right-authored attack must flip toward a left-side enemy")
	evolved_pet6.call("_on_animation_finished")
	evolved_pet6.play_battle_attack_toward(1.0)
	if pet6_sprite != null and pet6_sprite.flip_h:
		failures.append("evolved pet6's right-authored attack must stay unflipped toward a right-side enemy")
	evolved_pet6.free()


static func _test_evolution_detail_and_confirmation_windows(failures: Array[String]) -> void:
	var entry := PetCatalog.make_inventory_entry("pet1")
	entry["level"] = 99
	entry["has_evolution"] = true
	entry["evolved"] = false
	var inventory := InventoryWindow.new()
	inventory.setup([entry])
	inventory.call("_show_detail_panel", 0)
	var evolution_preview := inventory.get("_detail_evolution_icon") as TextureRect
	var evolution_button := inventory.get("_detail_evolution_button") as Button
	var evolution_label := inventory.get("_detail_evolution_label") as Label
	if evolution_preview == null or evolution_preview.texture == null or not evolution_button.disabled:
		failures.append("inventory detail must show the real locked evolution art before level 100")
	if evolution_label == null or "自动" in evolution_label.text or "Lv.100" not in evolution_label.text:
		failures.append("inventory evolution detail must avoid automatic wording while preserving the level-100 hook")
	entry["level"] = 100
	inventory.set_pets([entry])
	inventory.call("_show_detail_panel", 0)
	if evolution_button.visible or not evolution_button.disabled:
		failures.append("level-100 evolution must be automatic rather than requiring an inventory button")
	inventory.free()

	var evolution_window := EvolutionWindow.new()
	evolution_window.setup("zh")
	evolution_window.open_for_pet("pet1", "腐生眷族", 100)
	if not evolution_window.visible:
		failures.append("level-100 evolution must open a before/after confirmation window")
	var before_icon := evolution_window.get("_before_icon") as TextureRect
	var after_icon := evolution_window.get("_after_icon") as TextureRect
	var title_label := evolution_window.get("_title_label") as Label
	var hint_label := evolution_window.get("_hint_label") as Label
	if before_icon == null or before_icon.texture == null or after_icon == null or after_icon.texture == null:
		failures.append("evolution confirmation must visibly compare the original and evolved forms")
	if title_label == null or title_label.text != "进化完成":
		failures.append("the evolution confirmation title must say only evolution complete")
	if hint_label == null or "自动" in hint_label.text:
		failures.append("the evolution confirmation copy must not mention automatic evolution")
	evolution_window.set_language("en")
	var before_label := evolution_window.get("_before_label") as Label
	var after_label := evolution_window.get("_after_label") as Label
	if before_label == null or not before_label.text.contains(PetCatalog.get_localized_name("pet1", "en")):
		failures.append("an open evolution window must translate the authored pet name to English")
	if after_label == null or after_label.text != PetCatalog.get_localized_evolution_name("pet1", "en"):
		failures.append("an open evolution window must translate the evolved form name to English")
	if hint_label == null or not hint_label.text.contains("Evolution completed"):
		failures.append("an open evolution window must translate its explanation to English")
	evolution_window.free()


static func _test_evolution_state_and_power(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_unlocked_pet_ids", ["pet1"])
	main.set("_deployed_pet_ids", [])
	main.set("_pet_states", {"pet1": {"upgrade_level": 99}})
	var base_rate := float(main.call("_get_pet_faith_per_second", "pet1", 100))
	if bool(main.call("_apply_automatic_evolution_thresholds")):
		failures.append("evolution must not happen before level 100")
	var threshold_state: Dictionary = (main.get("_pet_states") as Dictionary)["pet1"]
	threshold_state["upgrade_level"] = 100
	(main.get("_pet_states") as Dictionary)["pet1"] = threshold_state
	if not bool(main.call("_apply_automatic_evolution_thresholds")):
		failures.append("reaching level 100 must automatically evolve the pet")
	var state: Dictionary = main.call("_get_pet_state", "pet1")
	if not bool(state.get("evolved", false)):
		failures.append("confirmed evolution must be retained in the pet's persistent state")
	var evolved_rate := float(main.call("_get_pet_faith_per_second", "pet1", 100))
	if not is_equal_approx(evolved_rate, base_rate * PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER):
		failures.append("evolution must apply its documented production multiplier")
	if PetCatalog.get_combat_power("pet1", 100, true) <= PetCatalog.get_combat_power("pet1", 100, false):
		failures.append("evolution must increase the pet's hidden combat power")
	var loaded: Dictionary = main.call("_sanitize_loaded_pet_states", {"pet1": {"upgrade_level": 100, "evolved": true}})
	if not bool((loaded.get("pet1", {}) as Dictionary).get("evolved", false)):
		failures.append("evolved forms must survive save-state sanitization")
	var downgraded_save: Dictionary = main.call("_sanitize_loaded_pet_states", {"pet1": {"upgrade_level": 99, "evolved": true}})
	if bool((downgraded_save.get("pet1", {}) as Dictionary).get("evolved", false)):
		failures.append("a saved pet below level 100 must always load in its initial form")
	var unlocked_with_pet4: Array[String] = ["pet1", "pet4"]
	main.set("_unlocked_pet_ids", unlocked_with_pet4)
	(main.get("_pet_states") as Dictionary)["pet4"] = {"upgrade_level": 100}
	main.call("_apply_automatic_evolution_thresholds")
	if not bool((main.call("_get_pet_state", "pet4") as Dictionary).get("evolved", false)):
		failures.append("every pet must receive automatic evolution state at level 100")
	main.free()

	var runtime_main := Main.new()
	runtime_main.set("_persistence_enabled", false)
	runtime_main.set("_pet_window_size", Vector2i(1000, 720))
	runtime_main.set("_unlocked_pet_ids", ["pet1"])
	runtime_main.set("_deployed_pet_ids", ["pet1"])
	runtime_main.set("_pet_states", {"pet1": {"upgrade_level": 100, "evolved": true}})
	var first_actor := runtime_main.call("_spawn_desktop_pet", "pet1", 600.0) as Node2D
	if first_actor == null or not bool(first_actor.get("is_evolved")):
		failures.append("a deployed level-100 pet must spawn in its evolved form")
	else:
		var runtime_state: Dictionary = runtime_main.call("_get_pet_state", "pet1")
		runtime_state["upgrade_level"] = 99
		(runtime_main.get("_pet_states") as Dictionary)["pet1"] = runtime_state
		if not bool(runtime_main.call("_apply_automatic_evolution_thresholds")):
			failures.append("lowering a pet below level 100 must trigger an immediate form change")
		var reverted_state: Dictionary = runtime_main.call("_get_pet_state", "pet1")
		var reverted_actor := (runtime_main.get("_pets") as Array).front() as Node2D
		if bool(reverted_state.get("evolved", false)) or reverted_actor == null or bool(reverted_actor.get("is_evolved")):
			failures.append("lowering a deployed pet below level 100 must restore its initial form")
		reverted_state["upgrade_level"] = 100
		(runtime_main.get("_pet_states") as Dictionary)["pet1"] = reverted_state
		runtime_main.call("_apply_automatic_evolution_thresholds")
		var reevolved_actor := (runtime_main.get("_pets") as Array).front() as Node2D
		if (
			not bool((runtime_main.call("_get_pet_state", "pet1") as Dictionary).get("evolved", false))
			or reevolved_actor == null
			or not bool(reevolved_actor.get("is_evolved"))
		):
			failures.append("returning a deployed pet to level 100 must evolve and replace it again")
	runtime_main.free()
