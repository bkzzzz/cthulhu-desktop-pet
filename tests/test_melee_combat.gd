extends RefCounted

const Main = preload("res://scripts/main.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_battle_facing_is_target_stable(failures)
	_test_melee_chases_while_ranged_holds(failures)
	_test_battle_pet_safe_horizontal_bounds(failures)
	_test_pet_target_cache_avoids_repeated_scans(failures)
	_test_freed_target_lock_recovers(failures)
	_test_enemy_entry_can_take_damage(failures)
	_test_melee_enemy_finishes_entry_before_engaging(failures)
	_test_waves_enter_from_both_sides(failures)
	_test_ranged_enemy_attacks_when_fully_visible(failures)
	_test_two_sided_knockback(failures)
	_test_combat_health_bars_and_hit_reaction(failures)
	_test_pet5_form_specific_rolling(failures)
	_test_pet5_roll_crushes_each_enemy_once(failures)
	return failures


static func _test_battle_facing_is_target_stable(failures: Array[String]) -> void:
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false)
	pet.set_battle_mode(true)
	var sprite := pet.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	var authored_faces_right := bool(pet.get("_faces_right"))
	if sprite == null:
		failures.append("battle-facing test pet must build its sprite")
		pet.free()
		return
	if sprite.flip_h != authored_faces_right:
		failures.append("every pet must face left as soon as a battle starts")
	pet.battle_move_toward(620.0, 1.0, 500.0, 1.0)
	if sprite.flip_h == authored_faces_right:
		failures.append("a pet must face right when its locked enemy is genuinely on the right")
	pet.battle_move_toward(380.0, 1.0, 500.0, -1.0)
	if sprite.flip_h != authored_faces_right:
		failures.append("arriving at a left-side target must not create a one-frame right-facing flicker")
	pet.free()


static func _test_melee_chases_while_ranged_holds(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_pet_window_size", Vector2i(1100, 720))
	var melee := Main.DesktopPetActor.new()
	melee.setup("pet1", Vector2i(1100, 720), 0.0, 1100.0, 850.0, 704.0, false)
	melee.set_battle_mode(true)
	main.add_child(melee)
	(main.get("_pets") as Array).append(melee)
	var melee_key := str(melee.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[melee_key] = 20.0
	(main.get("_battle_pet_formed") as Dictionary)[melee_key] = true

	var ranged := Main.DesktopPetActor.new()
	ranged.setup("pet2", Vector2i(1100, 720), 0.0, 1100.0, 930.0, 704.0, false)
	ranged.set_battle_mode(true)
	main.add_child(ranged)
	(main.get("_pets") as Array).append(ranged)
	var ranged_key := str(ranged.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[ranged_key] = 10.0
	(main.get("_battle_pet_formed") as Dictionary)[ranged_key] = true

	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(210.0, 704.0), 704.0, 1.0, 210.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	var melee_start_x := melee.position.x
	var ranged_start_x := ranged.position.x
	main.call("_update_battle_pet_formation", 0.1)
	if melee.position.x >= melee_start_x:
		failures.append("formed melee pets must actively seek and charge a distant enemy")
	if not is_equal_approx(ranged.position.x, ranged_start_x):
		failures.append("ranged pets must hold the rear line while melee pets charge")

	var locked_target := main.call("_get_battle_target_for_pet", melee) as Node2D
	var second_enemy := EnemyActor.new()
	second_enemy.setup("villager2", Vector2(melee.position.x + 20.0, 704.0), 704.0, 1.0, melee.position.x + 20.0)
	main.add_child(second_enemy)
	(main.get("_battle_enemies") as Array).append(second_enemy)
	if main.call("_get_battle_target_for_pet", melee) != second_enemy:
		failures.append("pets must replace an old target when another target becomes nearer")
	if locked_target == second_enemy:
		failures.append("nearest-target test must begin with a genuinely different cached enemy")

	melee.position.x = 270.0
	var candidates: Array[Node2D] = [ranged, melee]
	if main.call("_get_battle_target_for_enemy", enemy, candidates) != melee:
		failures.append("a player-positioned front-line melee pet must intercept enemy targeting before rear pets")
	ranged.position = enemy.position + Vector2(4.0, 0.0)
	if main.call("_get_battle_target_for_enemy", enemy, candidates) != ranged:
		failures.append("enemies must immediately replace their target when another living pet becomes nearer")

	melee.play_battle_attack_toward(-1.0)
	var melee_sprite := melee.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	main.call("_update_battle_pet_formation", 0.1)
	if melee_sprite != null and melee_sprite.animation != "attack":
		failures.append("melee pursuit must not cancel an authored attack animation on its next frame")
	main.free()


static func _test_battle_pet_safe_horizontal_bounds(failures: Array[String]) -> void:
	var left_pet := Main.DesktopPetActor.new()
	left_pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 12.0, 704.0, false)
	var left_start_x := left_pet.position.x
	left_pet.set_battle_mode(true)
	if not is_equal_approx(left_pet.position.x, left_start_x):
		failures.append("entering battle must not teleport a pet away from its current edge position")
	left_pet.battle_move_toward(-200.0, 1.0, 500.0, -1.0)
	if not is_equal_approx(left_pet.position.x, float(left_pet.get("_min_x"))):
		failures.append("battle movement must stop at the pet's visible left screen limit")
	var left_visual_rect: Rect2 = left_pet.call("_get_sprite_visual_rect")
	if left_visual_rect.position.x < -0.01:
		failures.append("a pursuing melee pet must remain fully visible at the left screen edge")
	left_pet.position.x = 140.0
	left_pet.receive_battle_hit(-24.0)
	if not is_equal_approx(left_pet.position.x, 116.0):
		failures.append("leftward knockback must preserve its displacement instead of snapping to a formation inset")

	var right_pet := Main.DesktopPetActor.new()
	right_pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 988.0, 704.0, false)
	var right_start_x := right_pet.position.x
	right_pet.set_battle_mode(true)
	if not is_equal_approx(right_pet.position.x, right_start_x):
		failures.append("entering battle must preserve a pet's current right-edge position")
	right_pet.battle_move_toward(1200.0, 1.0, 500.0, 1.0)
	if not is_equal_approx(right_pet.position.x, float(right_pet.get("_max_x"))):
		failures.append("battle movement must stop at the pet's visible right screen limit")
	var right_visual_rect: Rect2 = right_pet.call("_get_sprite_visual_rect")
	if right_visual_rect.end.x > 1000.01:
		failures.append("a pursuing melee pet must remain fully visible at the right screen edge")
	left_pet.free()
	right_pet.free()

	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_pet_window_size", Vector2i(1000, 720))
	var pursuing_pet := Main.DesktopPetActor.new()
	pursuing_pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false)
	pursuing_pet.set_battle_mode(true)
	main.add_child(pursuing_pet)
	(main.get("_pets") as Array).append(pursuing_pet)
	var actor_key := str(pursuing_pet.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[actor_key] = 10.0
	(main.get("_battle_pet_formed") as Dictionary)[actor_key] = true
	var edge_enemy := EnemyActor.new()
	edge_enemy.setup("villager1", Vector2(32.0, 704.0), 704.0, 1.0, 32.0)
	edge_enemy.set("_entered", true)
	main.add_child(edge_enemy)
	(main.get("_battle_enemies") as Array).append(edge_enemy)
	main.call("_update_battle_pet_formation", 2.0)
	var attack_range := float(pursuing_pet.get_battle_attack_range())
	if pursuing_pet.position.x >= 160.0 or pursuing_pet.position.x < float(pursuing_pet.get("_min_x")):
		failures.append("melee formation AI must pursue edge enemies to the visible screen limit")
	if pursuing_pet.position.distance_to(edge_enemy.position) > attack_range:
		failures.append("melee pursuit must bring an edge-positioned enemy inside the pet's attack range")
	main.free()


static func _test_pet_target_cache_avoids_repeated_scans(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var controller := main.get("_battle_controller") as Node
	var pet := Node2D.new()
	pet.position = Vector2(700.0, 704.0)
	main.add_child(pet)
	var first_enemy := Node2D.new()
	first_enemy.position = Vector2(420.0, 704.0)
	main.add_child(first_enemy)
	(main.get("_battle_enemies") as Array).append(first_enemy)
	controller.call("_reset_battle_pet_target_full_scan_count")
	if main.call("_get_battle_target_for_pet", pet) != first_enemy:
		failures.append("pet target caching must acquire the nearest enemy on its first lookup")
	for lookup_index in 64:
		if main.call("_get_battle_target_for_pet", pet) != first_enemy:
			failures.append("a stable enemy roster must preserve the cached pet target")
			break
	if int(controller.call("_get_battle_pet_target_full_scan_count")) != 1:
		failures.append("65 stable pet target lookups must perform exactly one full enemy scan")
	for frame_index in 60:
		main.set("_simulation_now_seconds", float(frame_index + 1) / 60.0)
		main.call("_get_battle_target_for_pet", pet)
	var steady_second_scans := int(controller.call("_get_battle_pet_target_full_scan_count"))
	if steady_second_scans > 10:
		failures.append("60 Hz stable targeting must be throttled to at most ten full scans per second")

	var nearer_enemy := Node2D.new()
	nearer_enemy.position = Vector2(680.0, 704.0)
	main.add_child(nearer_enemy)
	(main.get("_battle_enemies") as Array).append(nearer_enemy)
	if main.call("_get_battle_target_for_pet", pet) != nearer_enemy:
		failures.append("adding a nearer enemy must bypass target throttling and retarget immediately")
	if int(controller.call("_get_battle_pet_target_full_scan_count")) != steady_second_scans + 1:
		failures.append("an enemy roster addition must cause one immediate replacement scan")

	nearer_enemy.free()
	if main.call("_get_battle_target_for_pet", pet) != first_enemy:
		failures.append("an invalid cached enemy must be replaced immediately without waiting for the throttle")
	if int(controller.call("_get_battle_pet_target_full_scan_count")) != steady_second_scans + 2:
		failures.append("an invalid cached target must cause one immediate recovery scan")
	main.free()


static func _test_freed_target_lock_recovers(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 700.0, 704.0, false)
	main.add_child(pet)
	var first_enemy := EnemyActor.new()
	first_enemy.setup("villager1", Vector2(520.0, 704.0), 704.0, 1.0, 520.0)
	main.add_child(first_enemy)
	var next_enemy := EnemyActor.new()
	next_enemy.setup("villager2", Vector2(410.0, 704.0), 704.0, 1.0, 410.0)
	main.add_child(next_enemy)
	var enemies: Array = main.get("_battle_enemies")
	enemies.append_array([first_enemy, next_enemy])
	var actor_key := str(pet.get_instance_id())
	(main.get("_battle_pet_enemy_targets") as Dictionary)[actor_key] = first_enemy
	enemies.erase(first_enemy)
	first_enemy.free()
	var replacement := main.call("_get_battle_target_for_pet", pet) as Node2D
	if replacement != next_enemy:
		failures.append("a freed enemy target lock must be discarded and retargeted without aborting battle updates")
	next_enemy.set("_dead", true)
	if main.call("_get_battle_target_for_pet", pet) != null:
		failures.append("a defeated cached enemy must be discarded immediately even before roster cleanup")
	if (main.get("_battle_pet_enemy_targets") as Dictionary).has(actor_key):
		failures.append("defeated enemy target locks must be removed from the shared battle cache")
	main.free()


static func _test_enemy_entry_can_take_damage(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet10", Vector2i(1000, 720), 0.0, 1000.0, 140.0, 704.0, false)
	main.add_child(pet)
	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(-80.0, 704.0), 704.0, 1.0, 180.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	var health_before := enemy.get_health()
	enemy.take_damage(health_before * 0.25, 0.0)
	if not is_equal_approx(enemy.get_health(), health_before * 0.75):
		failures.append("an enemy must take damage while its running entrance animation is active")
	if main.call("_get_battle_target_for_pet", pet) != null:
		failures.append("pets must not target or chase an enemy while it remains in the spawn zone")
	enemy.call("_process", 3.0)
	if not bool(enemy.call("has_entered_battlefield")):
		failures.append("a melee enemy must still finish running to its authored entry post")
	elif main.call("_get_battle_target_for_pet", pet) != enemy:
		failures.append("pets must retain their incoming target after its entrance ends")
	main.free()


static func _test_melee_enemy_finishes_entry_before_engaging(failures: Array[String]) -> void:
	var target := Node2D.new()
	target.position = Vector2(-20.0, 704.0)
	var melee := EnemyActor.new()
	melee.setup("villager1", Vector2(-90.0, 704.0), 704.0, 1.0, 420.0)
	melee.set_target(target)
	var melee_start_x := melee.position.x
	melee.call("_process", 0.1)
	var melee_sprite := melee.get_node_or_null("EnemySprite") as AnimatedSprite2D
	if melee.position.x <= melee_start_x:
		failures.append("a melee enemy must continue its entrance past pets waiting in the spawn zone")
	if melee_sprite == null or melee_sprite.animation != "run":
		failures.append("a melee enemy must keep running until fully inside the combat area")
	melee.call("_process", 4.0)
	melee.call("_process", 0.01)
	if not bool(melee.call("has_entered_battlefield")):
		failures.append("a melee enemy must complete its visible entrance before engaging")

	var ranged := EnemyActor.new()
	ranged.setup("soldier2", Vector2(-90.0, 704.0), 704.0, 1.0, 420.0)
	ranged.set_target(target)
	var ranged_start_x := ranged.position.x
	ranged.call("_process", 0.1)
	var ranged_sprite := ranged.get_node_or_null("EnemySprite") as AnimatedSprite2D
	if ranged.position.x <= ranged_start_x or ranged_sprite == null or ranged_sprite.animation != "run":
		failures.append("ranged enemies must retain their fully-visible entrance behavior")

	melee.free()
	ranged.free()
	target.free()


static func _test_waves_enter_from_both_sides(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_active_battle_difficulty_scale", 1.0)
	main.set("_pet_window_size", Vector2i(1000, 720))
	main.call("_spawn_battle_wave", {"types": ["villager1", "soldier2"]}, 0)
	var enemies: Array = main.get("_battle_enemies")
	if enemies.size() != 2:
		failures.append("a two-member wave must spawn both authored enemies")
		main.free()
		return
	var left_enemy := enemies[0] as Node2D
	var right_enemy := enemies[1] as Node2D
	if left_enemy.position.x >= 0.0 or right_enemy.position.x <= 1000.0:
		failures.append("wave members must visibly enter from opposite screen edges")
	if int(left_enemy.call("get_entry_side")) != -1 or int(right_enemy.call("get_entry_side")) != 1:
		failures.append("enemy actors must retain their left/right entry side for combat behavior")
	if bool(right_enemy.call("has_entered_battlefield")):
		failures.append("a right-side ranged enemy must keep running until its full sprite is visible")
	var right_health_before := float(right_enemy.call("get_health"))
	right_enemy.call("take_damage", right_health_before * 0.25, 0.0)
	if not is_equal_approx(float(right_enemy.call("get_health")), right_health_before * 0.75):
		failures.append("right-side enemies must also take damage during their entrance")
	right_enemy.call("_process", 6.0)
	if not bool(right_enemy.call("has_entered_battlefield")):
		failures.append("a right-side enemy must finish entering from its mirrored edge")
	main.free()


static func _test_ranged_enemy_attacks_when_fully_visible(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_pet_window_size", Vector2i(1000, 720))
	var target := Node2D.new()
	target.position = Vector2(850.0, 704.0)
	main.add_child(target)

	var ranged := EnemyActor.new()
	ranged.setup("soldier2", Vector2(-90.0, 704.0), 704.0, 1.0, 420.0)
	main.add_child(ranged)
	ranged.set_target(target)
	var ranged_goal := float(ranged.call("_get_entry_destination_x"))
	if ranged_goal >= 420.0:
		failures.append("a ranged enemy's firing threshold must be the visible edge, not its deep formation post")
	ranged.call("_process", 4.0)
	ranged.set("_attack_animation_remaining", 0.0)
	ranged.set("_attack_pending", false)
	ranged.set("_attack_cooldown", 0.0)
	ranged.call("_process", 0.01)
	var ranged_sprite := ranged.get_node_or_null("EnemySprite") as AnimatedSprite2D
	if not bool(ranged.call("has_entered_battlefield")):
		failures.append("a ranged enemy must finish entering as soon as its full run sprite is visible")
	if not is_equal_approx(ranged.position.x, ranged_goal):
		failures.append("a ranged enemy must stop at the first fully-visible firing position")
	if ranged_sprite == null or ranged_sprite.animation != "attack":
		failures.append("a fully-visible ranged enemy with a target must attack immediately")

	var melee := EnemyActor.new()
	melee.setup("villager1", Vector2(-90.0, 704.0), 704.0, 1.0, 420.0)
	main.add_child(melee)
	melee.set_target(target)
	melee.call("_process", 1.0)
	if bool(melee.call("has_entered_battlefield")) or melee.position.x >= 420.0:
		failures.append("melee enemies must retain their authored run-in behavior")
	melee.call("_process", 4.0)
	melee.call("_process", 0.01)
	if not bool(melee.call("has_entered_battlefield")):
		failures.append("melee enemies must still enter at their authored formation post")

	main.free()


static func _test_combat_health_bars_and_hit_reaction(failures: Array[String]) -> void:
	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(320.0, 704.0), 704.0, 1.0, 320.0)
	var enemy_bar := enemy.get_node_or_null("CombatHealthBar") as Node2D
	if enemy_bar == null:
		failures.append("every combat enemy must create a visible health bar")
	else:
		enemy.take_damage(enemy.max_health * 0.5, 0.0)
		if not is_equal_approx(float(enemy_bar.call("get_health_ratio")), 0.5):
			failures.append("enemy health bars must track damage using the actor's exact health ratio")
		if float(enemy_bar.call("get_display_ratio")) <= 0.5:
			failures.append("damage bars must retain a trailing animated chip instead of snapping instantly")
	var enemy_sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
	var resting_scale := Vector2.ONE * float(enemy.get("_visual_scale"))
	enemy.call("_process", 0.04)
	if enemy_sprite == null or enemy_sprite.scale.is_equal_approx(resting_scale):
		failures.append("enemy hits must produce a brief squash reaction alongside the damage flash")
	enemy.free()

	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 700.0, 704.0, false)
	main.add_child(pet)
	(main.get("_pets") as Array).append(pet)
	var pet_key := str(pet.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[pet_key] = 20.0
	(main.get("_battle_pet_max_health") as Dictionary)[pet_key] = 20.0
	main.call("_attach_battle_health_bar", pet, 20.0, 20.0)
	main.call("_damage_battle_pet", pet, 5.0, 0.0)
	var pet_bar := pet.get_node_or_null("CombatHealthBar") as Node2D
	if pet_bar == null or not is_equal_approx(float(pet_bar.call("get_health_ratio")), 0.75):
		failures.append("pet health bars must synchronize with controller-owned combat health")
	main.free()


static func _test_two_sided_knockback(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false)
	pet.set_battle_mode(true)
	main.add_child(pet)
	var pet_key := str(pet.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[pet_key] = 100.0
	(main.get("_battle_pet_max_health") as Dictionary)[pet_key] = 100.0
	var enemy := Node2D.new()
	main.add_child(enemy)
	enemy.position = Vector2(300.0, 704.0)
	main.call("_on_enemy_attack_landed", enemy, pet, 1.0)
	if pet.position.x <= 500.0:
		failures.append("left-side enemies must knock pets away toward the right")
	pet.position.x = 500.0
	enemy.position.x = 700.0
	main.call("_on_enemy_attack_landed", enemy, pet, 1.0)
	if pet.position.x >= 500.0:
		failures.append("right-side enemies must knock pets away toward the left")
	main.free()

	var bounded_enemy := EnemyActor.new()
	bounded_enemy.setup("villager1", Vector2(120.0, 704.0), 704.0, 1.0, 120.0, 1000.0)
	var visual_margin := float(bounded_enemy.call("_get_battle_visual_half_width"))
	bounded_enemy.position.x = visual_margin + 2.0
	bounded_enemy.take_damage(0.0, 500.0, Vector2(-900.0, -220.0), -1.0)
	if bounded_enemy.position.x < visual_margin - 0.01:
		failures.append("enemy knockback must stop with the complete sprite inside the left desktop edge")
	bounded_enemy.position.x = 1000.0 - visual_margin - 2.0
	bounded_enemy.take_damage(0.0, 500.0, Vector2(900.0, -220.0), 1.0)
	if bounded_enemy.position.x > 1000.0 - visual_margin + 0.01:
		failures.append("enemy knockback must stop with the complete sprite inside the right desktop edge")
	bounded_enemy.free()


static func _test_pet5_form_specific_rolling(failures: Array[String]) -> void:
	var base_pet5 := Main.DesktopPetActor.new()
	base_pet5.setup("pet5", Vector2i(1000, 720), 0.0, 1000.0, 620.0, 704.0, false, false)
	if not base_pet5.uses_battle_roll_attack():
		failures.append("base pet5 must expose its ball-form rolling attack")
	base_pet5.set("_behavior", Main.DesktopPetActor.Behavior.WALK)
	base_pet5.set("_target_x", base_pet5.position.x - 120.0)
	base_pet5.set("_walk_speed", 180.0)
	base_pet5.call("_update_walking", 0.1)
	var base_sprite := base_pet5.get_node_or_null("pet5Sprite") as AnimatedSprite2D
	if base_sprite == null or is_zero_approx(base_sprite.rotation):
		failures.append("base pet5 must continuously rotate whenever ordinary movement changes its position")
	base_pet5.call("_start_idle")
	if base_sprite != null and not is_zero_approx(base_sprite.rotation):
		failures.append("base pet5 must settle upright after it stops rolling")
	base_pet5.free()

	if not Main.PetCatalog.has_evolution("pet5"):
		failures.append("pet5 evolved assets must be registered so the worm form can stay separate")
		return
	var evolved_pet5 := Main.DesktopPetActor.new()
	evolved_pet5.setup("pet5", Vector2i(1000, 720), 0.0, 1000.0, 620.0, 704.0, false, true)
	if evolved_pet5.uses_battle_roll_attack():
		failures.append("evolved pet5 is a worm and must use its own walk/attack instead of rotating as a ball")
	evolved_pet5.set_battle_mode(true)
	if evolved_pet5.begin_battle_roll_attack(300.0):
		failures.append("evolved pet5 must never enter the base ball-form crush animation")
	evolved_pet5.free()


static func _test_pet5_roll_crushes_each_enemy_once(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_simulation_now_seconds", 100.0)
	main.set("_battle_started_at", 100.0)
	main.set("_battle_ends_at", 200.0)
	main.set("_battle_wave_schedule", [])
	main.set("_battle_next_wave_index", 0)
	main.set("_pet_window_size", Vector2i(1100, 720))
	var pet5 := Main.DesktopPetActor.new()
	pet5.setup("pet5", Vector2i(1100, 720), 0.0, 1100.0, 820.0, 704.0, false, false)
	pet5.set_battle_mode(true)
	pet5.battle_roll_swept.connect(Callable(main, "_on_pet5_battle_roll_swept"))
	pet5.battle_roll_finished.connect(Callable(main, "_on_pet5_battle_roll_finished"))
	main.add_child(pet5)
	(main.get("_pets") as Array).append(pet5)
	var pet_key := str(pet5.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[pet_key] = 30.0
	(main.get("_battle_pet_max_health") as Dictionary)[pet_key] = 30.0
	(main.get("_battle_pet_formed") as Dictionary)[pet_key] = true
	(main.get("_battle_pet_attack_at") as Dictionary)[pet_key] = 0.0

	var enemy_a := EnemyActor.new()
	enemy_a.setup("victorian_boss", Vector2(720.0, 704.0), 704.0, 1.0, 720.0)
	main.add_child(enemy_a)
	(main.get("_battle_enemies") as Array).append(enemy_a)
	var enemy_b := EnemyActor.new()
	enemy_b.setup("victorian_boss", Vector2(650.0, 704.0), 704.0, 1.0, 650.0)
	main.add_child(enemy_b)
	(main.get("_battle_enemies") as Array).append(enemy_b)
	var health_a_before := enemy_a.get_health()
	var health_b_before := enemy_b.get_health()
	main.call("_update_battle", 0.016)
	if not pet5.is_battle_roll_active():
		failures.append("base pet5 attacks must begin a real movement-based roll toward the enemy")
		main.free()
		return
	var roll_data: Dictionary = (main.get("_battle_pet5_rolls") as Dictionary).get(pet_key, {})
	var expected_damage := float(roll_data.get("damage", 0.0))
	pet5.call("_update_pet", 0.1)
	pet5.call("_update_pet", 0.1)
	if not is_equal_approx(health_a_before - enemy_a.get_health(), expected_damage):
		failures.append("pet5 must damage the first enemy crossed by its rolling path exactly once")
	if not is_equal_approx(health_b_before - enemy_b.get_health(), expected_damage):
		failures.append("pet5 must damage every additional enemy crossed by the same roll exactly once")
	var health_a_after := enemy_a.get_health()
	var health_b_after := enemy_b.get_health()
	main.call("_on_pet5_battle_roll_swept", pet5, 744.0, 668.0)
	if not is_equal_approx(enemy_a.get_health(), health_a_after) or not is_equal_approx(enemy_b.get_health(), health_b_after):
		failures.append("one pet5 roll must not repeatedly damage an enemy on overlapping sweep frames")
	if (main.get("_battle_effects") as Array).size() < 2:
		failures.append("each enemy crushed by pet5 must receive a visible impact effect")
	pet5.call("_update_pet", 0.2)
	if pet5.is_battle_roll_active():
		failures.append("pet5 must stop and settle after reaching the far side of its crush target")
	main.free()
